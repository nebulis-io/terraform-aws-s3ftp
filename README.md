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

## Module Installation

### Setting up a provider and registering the module

This is outside the scope of this README. For more information, go visit [the relevant documentation](https://www.terraform.io/docs/cloud/registry/publish.html)

### Creating the base AMI

For terraform to provision the infrastructure for the S3-FTP, you need to create the AMI in your own organization, to do so, we will use packer.

```bash
; cd images
; packer build image.pkr.hcl
```

In case of any issues, make sure that the AWS credentials are accessible in your terminal

### Using the module

In your terraform configuration, you can then use the module this way

```hcl
module "s3ftp" {
  source  = "app.terraform.io/YOUR_ORGANIZATION/s3ftp/aws"
  version = "1.0.0"
  # insert required variables here
}
```

And use outputs value as you would with a normal terraform resource

## Usage

This application makes heavy use of vsFTPd virtual users, and as such, no system users are required to access FTP.

To add or remove users, you need to create a file named `login.txt` with this sort of content:

```
USERNAME1
PASSWORD1
USERNAME2
PASSWORD2

```

**The trailing newline is essential for this to work.**

This will create two users, `USERNAME1` and `USERNAME2` with respectively `PASSWORD1` and `PASSWORD2` that will be able to use these to connect to the FTP server.

Once the file is created, you need to upload it to the root of the newly created S3 folder.

Once correctly processed, it will create two folders, `USERNAME1` and `USERNAME2` which will be the root of each users space.

Each folder will contain an `in` and `out` directory.

You will have this hierarchy on AWS S3

```
s3ftp
├── login.txt
├── USERNAME1/
│  ├── in/
│  └── out/
└── USERNAME2/
   ├── in/
   └── out/
```
