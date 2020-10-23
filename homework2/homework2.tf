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
  default = "10.0.1.0/24"
}
variable "private_subnet_address_space" {
  default = "10.0.100.0/24"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  profile = "liat"
  region  = var.aws_region
}


##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

##################################################################################
# RESOURCES
##################################################################################


# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block = var.network_address_space
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  depends_on              = [aws_vpc.vpc]
  cidr_block              = var.public_subnet_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
      Name = "public subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  depends_on              = [aws_vpc.vpc]
  cidr_block              = var.private_subnet_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[1]
    tags = {
      Name = "private subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  depends_on = [
      aws_vpc.vpc,
      aws_subnet.public_subnet,
      aws_subnet.private_subnet
  ]
  vpc_id = aws_vpc.vpc.id
}



# ROUTING #
resource "aws_route_table" "public_rt" {
  depends_on = [
      aws_vpc.vpc,
      aws_internet_gateway.igw
  ]
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
  depends_on = [
      aws_vpc.vpc,
      aws_subnet.public_subnet,
      aws_subnet.private_subnet,
      aws_route_table.public_rt
  ]

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "elastic_ip_for_nat" {
  depends_on = [
      aws_route_table_association.rta-IG-association
  ]
  vpc = true
}

resource "aws_nat_gateway" "ngw" {
    depends_on = [
        aws_eip.elastic_ip_for_nat
    ]
  allocation_id = aws_eip.elastic_ip_for_nat.id
  subnet_id     = aws_subnet.public_subnet.id
}

resource "aws_route_table" "nat-gateway-rt" {
    depends_on = [
        aws_nat_gateway.ngw
    ]

    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.ngw.id
    }

    tags = {
        Name = "Route table for NAT Gateway"
    }

}

resource "aws_route_table_association" "nat-gateway-rt-association" {
    depends_on = [
        aws_route_table.nat-gateway-rt
    ]

    subnet_id = aws_subnet.private_subnet.id

    route_table_id = aws_route_table.nat-gateway-rt.id

}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  depends_on = [
      aws_vpc.vpc,
      aws_subnet.public_subnet,
      aws_subnet.private_subnet
  ]

  name   = "nginx_elb_sg"
  vpc_id = aws_vpc.vpc.id

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instance security group 
resource "aws_security_group" "instance-sg" {
  name   = "instance-sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db-sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.vpc.id

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # SSH access from VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.network_address_space]
  }
}


# INSTANCES #
resource "aws_instance" "nginx" {
  depends_on = [
      aws_vpc.vpc,
      aws_subnet.public_subnet,
      aws_subnet.private_subnet,
      aws_security_group.elb-sg,
      aws_security_group.instance-sg
  ]

  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.instance-sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = "${file("install_nginx.sh")}"

  tags = {
      Name                        = "nginx-${count.index + 1}"
  }

}

resource "aws_instance" "db-server" {
  depends_on = [
      aws_subnet.private_subnet
  ]
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  key_name               = var.key_name

  tags = {
      Name                   = "db-server-${count.index + 1}"
  }
}

# LOAD BALANCER #
resource "aws_elb" "web" {
  depends_on = [
      aws_subnet.public_subnet,
      aws_subnet.private_subnet,
      aws_instance.nginx[0],
      aws_instance.nginx[1]
  ]
  name            = "web"
  subnets         = [aws_subnet.public_subnet.id]
  security_groups = [aws_security_group.elb-sg.id]
  instances       = [aws_instance.nginx[0].id, aws_instance.nginx[1].id]
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

}

##################################################################################
# OUTPUT
##################################################################################

output "aws_elb_public_dns" {
  value = aws_elb.web.dns_name
}

output "aws_instance_public_dns_nginx-1" {
  value = aws_instance.nginx[0].public_dns
}

output "aws_instance_public_dns_nginx-2" {
  value = aws_instance.nginx[1].public_dns
}

output "aws_instance_public_dns_db-server-1" {
  value = aws_instance.db-server[0].public_dns
}

output "aws_instance_public_dns_db-server-2" {
  value = aws_instance.db-server[1].public_dns
}