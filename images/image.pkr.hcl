variable "region" {
    type    = string
    default = "eu-west-1"
}

locals {
    timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "this" {
    ami_name      = "s3ftp-${local.timestamp}"
    ami_description = "Amazon Linux with vsFTPd and s3-fuse installed"
    instance_type = "t3.micro"
    region        = var.region
    
    source_ami_filter {
        filters = {
            name                = "amzn2-ami-hvm-*"
            root-device-type    = "ebs"
            virtualization-type = "hvm"
        }
        most_recent = true
        owners      = ["137112412989"] # Amazon
    }
    ssh_username = "ec2-user"

}

build {
    sources = ["source.amazon-ebs.this"]
    
    provisioner "file" {
        destination = "/tmp/generate_login.sh"
        source = "./files/generate_login.sh"
    }

    provisioner "file" {
        destination = "/tmp/vsftpd.conf"
        source = "./files/vsftpd.conf"
    }
    
    provisioner "shell" {
        script = "./files/setup.sh" 
    }

}

