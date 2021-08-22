variable "project_name" {
  type    = string
  default = "s3ftp"
}

variable "environment" {
  type    = string
  default = "test"
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "public_key" {
  type = string
}

variable "private_key" {
  type      = string
  sensitive = true
}
