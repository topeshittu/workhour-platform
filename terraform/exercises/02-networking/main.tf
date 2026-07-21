data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_vpc" "practice" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "workhour-practice-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.practice.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "workhour-practice-public-subnet"
    Tier = "public"
  }
}

resource "aws_internet_gateway" "practice" {
  vpc_id = aws_vpc.practice.id

  tags = {
    Name = "workhour-practice-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.practice.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.practice.id
  }

  tags = {
    Name = "workhour-practice-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name_prefix = "workhour-practice-web-"
  description = "Allow public HTTP traffic"
  vpc_id      = aws_vpc.practice.id

  tags = {
    Name = "workhour-practice-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Public HTTP test access"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow outbound traffic"
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = <<-EOF2
    #!/bin/bash
    dnf install -y nginx
    echo "PostifyHQ Terraform networking rehearsal" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOF2

  tags = {
    Name = "workhour-practice-web"
  }
}
