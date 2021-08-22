# S3-FTP

## Standalone Installation

### Pre-requisites

To install the S3-FTP project, you first need to install [terraform](https://www.terraform.io/downloads.html) and [packer](https://www.packer.io/downloads) on your system.

They both should be available from your PATH

### Creating the base AMI

For terraform to provision the infrastructure for the S3-FTP, you need to create the AMI in your own organization, to do so, we will use packer.

```bash
; cd images
; packer build image.pkr.hcl
```

In case of any issues, make sure that the AWS credentials are accessible in your terminal

### Deploying the infrastructure

Since the S3-FTP relies on AWS EC2, you need to create a keypair in order to make secure the SSH access to the server.

```bash
; ssh-keygen -t rsa -c "your.email@example.com" -f ./ssh_file
```

Make sure to change your email and ssh_file accordingly.

You can then proceed to create the backend configuration to store the states in a `backend.tf` file:

```hcl
terraform {
  backend "remote" {
    organization = "YOUR_TERRAFORM_ORGANIZATION"

    workspaces {
      name = "YOUR_TERRAFORM_WORKSPACE"
    }
  }

  required_version = ">= 1.0.0"
}
```

FInally, you can deploy the application:

```bash
; terraform apply -var="public_key=$(cat ./ssh_file.pub)" -var="private_key=$(cat ./ssh_file)" -auto-approve
```

Once set up, terraform will output relevant information

```
bucket = "...." # Name of the bucket in AWS
ftp_ip = "XXX.XXX.XXX.XXX" # IP of the FTP server
```
