##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

##################################################################################
# RESOURCES
##################################################################################


# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_address_space)
  cidr_block              = var.public_subnet_address_space[count.index]
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Tier = "Public"
  }
}

resource "aws_subnet" "private_subnets" {
  count                   = length(var.private_subnet_address_space)
  cidr_block              = var.private_subnet_address_space[count.index]
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "false"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "private subnet-AZ-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}



# ROUTING #
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Route table for Internet Gateway"
  }
}

resource "aws_route_table_association" "rta-IG-association" {
  count = length(var.public_subnet_address_space)

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "elastic_ip_for_nat" {
  count = length(var.public_subnet_address_space)
  vpc   = true
}

resource "aws_nat_gateway" "ngw" {
  count         = length(var.public_subnet_address_space)
  allocation_id = aws_eip.elastic_ip_for_nat[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
}

resource "aws_route_table" "nat-gateway-rt" {
  count  = length(var.public_subnet_address_space)
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw[count.index].id
  }

  tags = {
    Name = "Route table for NAT Gateway-AZ-${count.index + 1}"
  }

}

resource "aws_route_table_association" "nat-gateway-rt-association" {
  count          = length(var.public_subnet_address_space)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.nat-gateway-rt[count.index].id

}