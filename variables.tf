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

variable "instance_type" {
  type = string
  default = "t3.micro"
}

variable "ssl_country" {
  type = string
  default = "FR"
}

variable "ssl_state" {
  type = string
  default = "Aquitaine"
}

variable "ssl_location" {
  type = string
  default = "Bordeaux"
}

variable "ssl_organization" {
  type = string
  default = "Dunforce"
}

variable "ssl_organization_unit" {
  type = string
  default = "IT"
}

variable "ssl_domain_name" {
  type = string
  default = "ftp.dunforce.io"
}
