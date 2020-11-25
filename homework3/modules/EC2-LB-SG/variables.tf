##################################################################################
# VARIABLES
##################################################################################

variable "private_key_path" {}
variable "key_name" {}
variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "network_address_space" {
  type = string
}

variable "public_subnets" {
  type = list
}

variable "private_subnets" {
  type = list
}

