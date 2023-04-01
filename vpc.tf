terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.60.0"
    }
  } # bucket must be hard-coded
  backend "s3" {
    bucket = "bparent-tf-bucket"
    key = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create VPC; CIDR 10.0.0.0/16
resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true
  tags = {
    "Name" = "${var.default_tags.env}-VPC"
  }
}

# Public Subnets
resource "aws_subnet" "Public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  tags = {
    "Name" = "${var.default_tags.env}-Public-Subnet-${data.aws_availability_zones.availability_zone.names[count.index]}"
  }
  availability_zone = data.aws_availability_zones.availability_zone.names[count.index]
}
# Private Subnets
resource "aws_subnet" "Private" {
  count      = var.private_subnet_count
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + var.public_subnet_count)
  tags = {
    "Name" = "${var.default_tags.env}-Private-Subnet-${data.aws_availability_zones.availability_zone.names[count.index]}"
  }
  availability_zone = data.aws_availability_zones.availability_zone.names[count.index]
}
# Public Route Table
resource "aws_route_table" "Public" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.default_tags.env}-Public-RT"
  }
}
# Public Routes - for route table
resource "aws_route" "Public" {
  route_table_id = aws_route_table.Public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main_igw.id
}
# Publice Route Table Association
resource "aws_route_table_association" "Public" {
  count = var.public_subnet_count
  subnet_id = element(aws_subnet.Public.*.id, count.index)
  route_table_id = aws_route_table.Public.id
}
# Private Route Table
resource "aws_route_table" "Private" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.default_tags.env}-Private-RT"
  }
}
# Private Routes - for route table
resource "aws_route" "Private" {
  route_table_id = aws_route_table.Private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main_NAT.id
}
# Private Route Table Association
resource "aws_route_table_association" "name" {
  count = var.private_subnet_count
  subnet_id = element(aws_subnet.Private.*.id, count.index)
  route_table_id = aws_route_table.Private.id
}
# IGW
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id #attachment
  tags = {
    "Name" = "${var.default_tags.env}-IGW"
  }
}
# NGW
resource "aws_nat_gateway" "main_NAT" {
  allocation_id = aws_eip.NAT_EIP.id
  subnet_id = aws_subnet.Public.0.id
  tags = {
    "Name" = "${var.default_tags.env}-NGW"
  }
}
# EIP
resource "aws_eip" "NAT_EIP" {
  vpc = true
}