##################################################################################
# DATA
##################################################################################

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

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    Tier = "Public"
  }
}


##################################################################################
# RESOURCES
##################################################################################

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "nginx_elb_sg"
  vpc_id = var.vpc_id

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
  vpc_id = var.vpc_id

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
  vpc_id = var.vpc_id

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
  count                       = length(var.public_subnets)
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = var.public_subnets[count.index].id
  vpc_security_group_ids      = [aws_security_group.instance-sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  user_data                   = "${file("install_nginx.sh")}"
  iam_instance_profile        = aws_iam_instance_profile.s3_profile.name

  tags = {
    Name = "nginx-AZ-${count.index + 1}"
  }

}

resource "aws_instance" "db-server" {
  count                  = length(var.private_subnets)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = var.private_subnets[count.index].id
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
  subnets                     = data.aws_subnet_ids.public.ids
  security_groups             = [aws_security_group.elb-sg.id]
}

  resource "aws_lb_target_group" "for_web" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
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
