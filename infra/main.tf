terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">=5.0" }
  }
  required_version = ">=1.4.0"
}

# Provider neemt regio uit env (AWS_REGION / AWS_DEFAULT_REGION)
provider "aws" {}

# --- Zorg dat er subnets zijn (default VPC kan soms zonder default subnets zijn) ---
resource "aws_default_vpc" "default" {}

data "aws_availability_zones" "available" {}

# Eén default subnet is genoeg voor deze setup (je kunt er later meer toevoegen)
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

  # Backend API (publiek open om jouw huidige gedrag te matchen)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (overweeg te beperken tot jouw IP)
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

  # Injecteer exact te gebruiken backend image (immutable)
  user_data = templatefile("${path.module}/script_backend.sh", {
    backend_image = var.backend_image
  })

  # Maak nieuwe instance wanneer user_data wijzigt (dus bij nieuwe SHA)
  user_data_replace_on_change = true

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-backend" }
}

resource "aws_instance" "frontend" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_default_subnet.primary.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  # Injecteer backend IP + exacte frontend image (immutable)
  user_data = templatefile("${path.module}/script_frontend.sh", {
    backend_ip     = aws_instance.backend.public_ip
    frontend_image = var.frontend_image
  })

  user_data_replace_on_change = true

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name_prefix}-frontend" }
}

# --- Variabelen ---
# Hardcoded Ubuntu AMI ID for us-east-1
variable "ami_id" {
  type    = string
  default = "ami-0e2c8caa4b6378d8c" # Ubuntu 22.04 LTS (us-east-1)
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

# Exact te gebruiken images (door CI gevuld met SHA-tags)
variable "backend_image" {
  type        = string
  description = "Volledige image referentie voor backend, bv. 12301302/cloud2_backend:<sha>"
}

variable "frontend_image" {
  type        = string
  description = "Volledige image referentie voor frontend, bv. 12301302/cloud2_frontend:<sha>"
}

# --- Outputs ---
output "backend_public_ip" {
  value = aws_instance.backend.public_ip
}

output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}
