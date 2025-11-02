terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">=5.0" }
  }
  required_version = ">=1.4.0"
}

# Provider gebruikt regio uit env (AWS_REGION / AWS_DEFAULT_REGION)
provider "aws" {}

# --- Infra: zorg voor (default) VPC + subnet zodat EC2 kan starten ---
# Maakt/claimt de default VPC
resource "aws_default_vpc" "default" {}

# Pak de eerste beschikbare AZ en maak/claim daar het default subnet
data "aws_availability_zones" "available" {}

resource "aws_default_subnet" "primary" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

# --- Security Group in de (default) VPC ---
resource "aws_security_group" "sg" {
  name_prefix = "${var.name_prefix}-sg-"
  vpc_id      = aws_default_vpc.default.id

  # HTTP (frontend)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API (publiek open zoals in jouw oorspronkelijke config)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-sg" }
}

# --- EC2 instances ---
resource "aws_instance" "backend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_default_subnet.primary.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null
  user_data                   = file("${path.module}/script_backend.sh")

  tags = { Name = "${var.name_prefix}-backend" }
}

resource "aws_instance" "frontend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_default_subnet.primary.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/script_frontend.sh", {
    backend_ip = aws_instance.backend.public_ip
  })

  tags = { Name = "${var.name_prefix}-frontend" }
}

# --- Variabelen ---
# Hardcoded Ubuntu AMI ID for us-east-1
variable "ami_id" {
  type    = string
  default = "ami-0e2c8caa4b6378d8c" # Ubuntu 22.04 LTS in us-east-1
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type    = string
  default = ""
}

variable "name_prefix" {
  type    = string
  default = "todoapp"
}

# --- Outputs ---
output "backend_public_ip" {
  value = aws_instance.backend.public_ip
}

output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}
