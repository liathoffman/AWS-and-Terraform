##################################################################################
# VARIABLES
##################################################################################

variable "private_key_path" {}
variable "key_name" {}
variable "aws_region" {
  default = "us-east-1"
}

variable "network_address_space" { 
    default = "10.0.0.0/16"
}

variable "public_subnet_address_space" { 
    type = list
    default = ["10.0.0.0/18", "10.0.64.0/18"]
}

variable "private_subnet_address_space" { 
    type = list
    default = ["10.0.128.0/18", "10.0.192.0/18"]
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
  network_address_space = var.network_address_space
  public_subnet_address_space = var.public_subnet_address_space
  private_subnet_address_space = var.private_subnet_address_space

}

module "EC2-LB-SG" {
  depends_on       = [
    module.vpc
  ]
  key_name         = var.key_name
  private_key_path = var.private_key_path
  source           = "./modules/EC2-LB-SG"

  vpc_id = module.vpc.vpc_id

  public_subnets = module.vpc.public_subnets

  private_subnets = module.vpc.private_subnets

  network_address_space = var.network_address_space

}

##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = module.EC2-LB-SG.elb
}

output "dns_nginx_servers" {
  value = module.EC2-LB-SG.dns_nginx_servers
}


