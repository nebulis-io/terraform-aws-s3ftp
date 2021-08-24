provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

resource "random_id" "this" {
  byte_length = 8
}

data "aws_caller_identity" "this" {}

resource "aws_s3_bucket" "this" {
  bucket = "${var.project_name}-${random_id.this.hex}"
  acl    = "private"
}

resource "aws_s3_bucket_notification" "this" {
  bucket = aws_s3_bucket.this.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".txt"
  }

  depends_on = [aws_lambda_permission.this]

}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.project_name}_lambda_logging_${random_id.this.hex}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_ssm" {
  name        = "${var.project_name}_lambda_ssm_${random_id.this.hex}"
  path        = "/"
  description = "IAM policy for using SSM on EC2 from a lambda"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "ssm:SendCommand",
        Resource = aws_ssm_document.this.arn,
        Effect   = "Allow"
      },
      {
        Action   = "ssm:SendCommand",
        Resource = aws_instance.this.arn,
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}


resource "aws_iam_role_policy_attachment" "lambda_ssm" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_ssm.arn
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}_lambda_${random_id.this.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_lambda_permission" "this" {
  statement_id  = "${var.project_name}_AllowExecutionFromS3Bucket_${random_id.this.hex}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.this.arn
}

data "archive_file" "generate_login" {
  type        = "zip"
  source_dir  = "${path.module}/lambdas/generate_login"
  excludes    = ["${path.module}/lambdas/generate_login/lambda.zip"]
  output_path = "${path.module}/lambdas/generate_login/lambda.zip"
}

resource "aws_lambda_function" "this" {

  filename         = data.archive_file.generate_login.output_path
  source_code_hash = data.archive_file.generate_login.output_base64sha256
  function_name    = "${var.project_name}_generate_login_${random_id.this.hex}"
  role             = aws_iam_role.lambda.arn
  handler          = "main.handler"
  runtime          = "nodejs12.x"

  environment {
    variables = {
      BUCKET_NAME                 = aws_s3_bucket.this.bucket,
      SSM_GENERATE_LOGIN_DOCUMENT = aws_ssm_document.this.name
      S3FTP_INSTANCE_ID           = aws_instance.this.id
    }
  }

}


resource "aws_iam_policy" "s3fs" {
  name = "${var.project_name}_S3FS-Policy_${random_id.this.hex}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = [aws_s3_bucket.this.arn]
      },
      {

        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Resource = ["${aws_s3_bucket.this.arn}/*"]
      }
    ]
  })
}

data "aws_iam_policy" "ssm_managed" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}_S3FS-Role_${random_id.this.hex}"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole",
          Principal = {
            Service = "ec2.amazonaws.com"
          },
          Effect = "Allow",
          Sid    = ""
        }
      ]
  })

}

resource "aws_iam_role_policy_attachment" "s3fs" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3fs.arn
}


resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2.name
  policy_arn = data.aws_iam_policy.ssm_managed.arn
}

data "aws_ami" "dunforce-s3ftp" {
  most_recent = true

  filter {
    name   = "name"
    values = ["s3ftp*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [data.aws_caller_identity.this.account_id]
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.project_name}_S3FS-Role-Profile_${random_id.this.hex}"
  role = aws_iam_role.ec2.name
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project_name}_${random_id.this.hex}"
  public_key = file("./tf-packer.pub")
}

resource "aws_security_group" "this" {
  name        = "${var.project_name}_security-group_${random_id.this.hex}"
  description = "Allow FTP, SSH, PASSV traffic"

  ingress {
    description = "FTP"
    from_port   = 21
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "PASSV FTP"
    from_port   = 40000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "this" {
  ami                  = data.aws_ami.dunforce-s3ftp.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.this.name

  key_name = aws_key_pair.this.key_name

  vpc_security_group_ids = [
    aws_security_group.this.id
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("tf-packer")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /home/ftp",
      "echo \"${aws_s3_bucket.this.bucket} /home/ftp fuse.s3fs _netdev,rw,allow_other,iam_role=${aws_iam_role.ec2.name},default_acl=private,uid=$(cat /etc/passwd | grep ftp | cut -d ':' -f 3),gid=$(cat /etc/passwd | grep nfsnobody | cut -d ':' -f 4),umask=222   0 0\" | sudo tee -a /etc/fstab",
      "sudo mount -a",
      "sudo fusermount -u /home/ftp",
      "sudo mount -a", # for "Transport endpoint not connected"
      "sudo generate_login.sh",
      "echo \"pasv_address=${aws_eip.this.public_ip}\" | sudo tee -a /etc/vsftpd/vsftpd.conf", # Setup PASSV Address
      "sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/private/vsftpd.pem -subj \"/C=${var.ssl_country}/ST=${var.ssl_state}/L=${var.ssl_location}/O=${var.ssl_organization}/OU=${var.ssl_organization_unit}/CN=${var.ssl_domain_name}\"",
      "sudo systemctl enable vsftpd",
      "sudo systemctl restart vsftpd"
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "this" {
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}

resource "aws_ssm_document" "this" {
  name          = "${var.project_name}_generate_login_${random_id.this.hex}"
  document_type = "Command"

  content = <<DOC
  {
    "schemaVersion": "1.2",
    "description": "Regenerate logins for the s3 FTP",
    "parameters": {

    },
    "runtimeConfig": {
      "aws:runShellScript": {
        "properties": [
          {
            "id": "0.aws:runShellScript",
            "runCommand": ["sudo generate_login.sh"]
          }
        ]
      }
    }
  }
DOC
}
