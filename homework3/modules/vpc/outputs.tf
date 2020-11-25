##################################################################################
# OUTPUT
##################################################################################

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "network_address_space" {
  value = var.network_address_space
}

output "public_subnets" {
    value = aws_subnet.public_subnets
}

output "private_subnets" {
    value = aws_subnet.private_subnets
}