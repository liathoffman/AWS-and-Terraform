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
  default = "10.0.0.0/16"
}

variable "public_subnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/19", "10.0.32.0/19"]
}

variable "private_subnet_address_space" {
  type    = list(string)
  default = ["10.0.64.0/18", "10.0.128.0/17"]
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

data "aws_elb_service_account" "main" {}

##################################################################################
# RESOURCES
##################################################################################


# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_address_space)
  cidr_block              = var.public_subnet_address_space[count.index]
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "public subnet-AZ-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
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
  count = 2

  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "elastic_ip_for_nat" {
  count = 2
  vpc   = true
}

resource "aws_nat_gateway" "ngw" {
  count         = 2
  allocation_id = aws_eip.elastic_ip_for_nat[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id
}

resource "aws_route_table" "nat-gateway-rt" {
  count  = 2
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
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.nat-gateway-rt[count.index].id

}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
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

# IAM ROLES #

resource "aws_iam_instance_profile" "s3_profile" {
  name = "s3_profile"
  role = aws_iam_role.s3_role.name
}

resource "aws_iam_role" "s3_role" {
  name = "s3_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.s3_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}


# S3 Bucket #
resource "aws_s3_bucket" "nginx_logs" {
  bucket = "liat-nginx-logs-282837837882"
  acl    = "private"
}


# INSTANCES #
resource "aws_instance" "nginx" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet[count.index].id
  vpc_security_group_ids      = [aws_security_group.instance-sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = "${file("install_nginx.sh")}"
  iam_instance_profile        = aws_iam_instance_profile.s3_profile.name

  tags = {
    Name = "nginx-AZ-${count.index + 1}"
  }

 # provisioner "file" {
  #  source = "script.sh"
  #  destination = "/tmp/script.sh"
 # }

 # provisioner "remote-exec" {
  #  inline = [
   #   "chmod +x /tmp/script.sh",
   #   "/tmp/script.sh"
   # ]
 # }

}

resource "aws_instance" "db-server" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet[count.index].id
  vpc_security_group_ids = [aws_security_group.db-sg.id]
  key_name               = var.key_name

  tags = {
    Name = "db-server-az-${count.index + 1}"
  }
}

# LOAD BALANCER #
resource "aws_lb" "web" {
  name                        = "web"
  internal                    = false
  load_balancer_type          = "application"
  subnets                     = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id]
  security_groups             = [aws_security_group.elb-sg.id]
}

  resource "aws_lb_target_group" "for_web" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  stickiness{
    type = "lb_cookie"
    cookie_duration = 60
    enabled = true
  }

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    matcher             = "200-299"
    interval            = 30
  }
}
  
resource "aws_lb_target_group_attachment" "for_web1" {
  target_group_arn = aws_lb_target_group.for_web.arn
  target_id        = aws_instance.nginx[0].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "for_web2" {
  target_group_arn = aws_lb_target_group.for_web.arn
  target_id        = aws_instance.nginx[1].id
  port             = 80
}

resource "aws_lb_listener" "web-servers" {
  load_balancer_arn = aws_lb.web.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.for_web.arn
  }
}


##################################################################################
# OUTPUT
##################################################################################

output "elb" {
  value = aws_lb.web.dns_name
}

output "dns_nginx-1" {
  value = aws_instance.nginx[0].public_dns
}

output "dns_nginx-2" {
  value = aws_instance.nginx[1].public_dns
}
