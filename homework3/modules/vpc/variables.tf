##################################################################################
# VARIABLES
##################################################################################

variable "private_key_path" {}
variable "key_name" {}
variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "network_address_space" {
  type = string
}

variable "public_subnet_address_space" {
  type    = list(string)
}

variable "private_subnet_address_space" {
  type    = list(string)
}
