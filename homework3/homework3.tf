##################################################################################
# VARIABLES
##################################################################################

variable "private_key_path" {}
variable "key_name" {}
variable "aws_region" {
  default = "us-east-1"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  profile = "liat"
  region  = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "liat-terraform"
    key    = "C:\\Users\\snugglebutt\\opsschool\\aws and terraform\\homework3\\terraform.tfstate"
    region = "us-east-1"
  }
}


##################################################################################
# RESOURCES
##################################################################################

module "vpc" {
  key_name         = var.key_name
  private_key_path = var.private_key_path
  source           = "./modules/vpc"

  #optionally configurable CIDR Blocks
  # network_address_space = "192.168.0.0/16"

  # public_subnet_address_space = ["192.168.0.0/17", "192.168.128.0/18"]

  # private_subnet_address_space = ["192.168.192.0/19", "192.168.224.0/19"]

}

##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = module.vpc.elb
}

output "dns_nginx-1" {
  value = module.vpc.dns_nginx-1
}

output "dns_nginx-2" {
  value = module.vpc.dns_nginx-2
}
