terraform {
  required_version = "~> 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.16"
    }
  }
  # Optioneel: remote state backend hier configureren
  # backend "s3" { ... }
}

provider "aws" {
  region = var.my_region
}

############################
# VPC + Networking
############################
resource "aws_vpc" "main" {
  cidr_block = "172.16.0.0/16"
  tags       = { Name = "todo-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags                    = { Name = "todo-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "todo-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "todo-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

############################
# Security Group
############################
resource "aws_security_group" "web_sg" {
  name   = "todo-sg"
  vpc_id = aws_vpc.main.id

  # SSH beperkt
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_client_cidr]
  }

  # Frontend HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend HTTP voor API GW proxy (HTTP API gebruikt publieke endpoint)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-sg" }
}

############################
# EC2 (immutable via digest + replace on change)
############################
resource "aws_instance" "frontend" {
  ami                    = var.ami
  instance_type          = var.my_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/userdata-frontend.sh", {
    DOCKER_NS       = var.docker_ns
    FRONTEND_DIGEST = var.frontend_digest
  })

  user_data_replace_on_change = true
  tags = { Name = "frontend-ec2" }
}

resource "aws_instance" "backend" {
  ami                    = var.ami
  instance_type          = var.my_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/userdata-backend.sh", {
    DOCKER_NS       = var.docker_ns
    BACKEND_DIGEST  = var.backend_digest
    # Gebruik digest indien opgegeven, anders fallback tag (minder immutable)
    MONGO_REF       = var.mongo_digest != "" ? "docker.io/library/mongo@${var.mongo_digest}" : "docker.io/library/mongo:7.0.14"
    DBURL           = "mongodb://root:password@mongodb:27017/sampledb?authSource=admin"
  })

  user_data_replace_on_change = true
  tags = { Name = "backend-ec2" }
}

############################
# Elastic IPs
############################
resource "aws_eip" "frontend_eip" {
  domain = "vpc"
  tags   = { Name = "todo-frontend-eip" }
  lifecycle { prevent_destroy = true }
}

resource "aws_eip" "backend_eip" {
  domain = "vpc"
  tags   = { Name = "todo-backend-eip" }
  lifecycle { prevent_destroy = true }
}

resource "aws_eip_association" "frontend_eip_assoc" {
  instance_id   = aws_instance.frontend.id
  allocation_id = aws_eip.frontend_eip.id
}

resource "aws_eip_association" "backend_eip_assoc" {
  instance_id   = aws_instance.backend.id
  allocation_id = aws_eip.backend_eip.id
}

############################
# API Gateway v2 (HTTP) + expliciete deployment
############################
resource "aws_apigatewayv2_api" "todo_api" {
  name          = "todo-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "todo_integration" {
  api_id                 = aws_apigatewayv2_api.todo_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "http://${aws_eip.backend_eip.public_ip}:3000/{proxy}"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "todo_route" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.todo_integration.id}"
}

resource "aws_apigatewayv2_deployment" "todo_deploy" {
  api_id = aws_apigatewayv2_api.todo_api.id
  triggers = {
    config = sha1(jsonencode({
      integration = aws_apigatewayv2_integration.todo_integration.id
      route       = aws_apigatewayv2_route.todo_route.route_key
    }))
  }
  depends_on = [aws_apigatewayv2_route.todo_route]
}

resource "aws_apigatewayv2_stage" "todo_stage" {
  api_id        = aws_apigatewayv2_api.todo_api.id
  name          = "prod"
  auto_deploy   = false
  deployment_id = aws_apigatewayv2_deployment.todo_deploy.id
}

