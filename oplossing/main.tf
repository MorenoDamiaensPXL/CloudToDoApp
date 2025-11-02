provider "aws" {
  region = var.my_region
}

# -------------------------------
# VPC + Networking
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block = "172.16.0.0/16"
  tags = { Name = "todo-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# -------------------------------
# Security Group
# -------------------------------
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8090
    to_port     = 8090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}


# -------------------------------
# User Data Scripts
# -------------------------------
data "template_file" "frontend_userdata" {
  template = file("${path.module}/userdata-frontend.sh")
}

data "template_file" "backend_userdata" {
  template = file("${path.module}/userdata-backend.sh")
}

# -------------------------------
# EC2 Instances
# -------------------------------
resource "aws_instance" "frontend" {
  ami           = var.ami
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name      = var.key_name
  user_data     = base64encode(data.template_file.frontend_userdata.rendered)
  tags = { Name = "frontend-ec2" }
}

resource "aws_instance" "backend" {
  ami           = var.ami
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name      = var.key_name
  user_data     = base64encode(data.template_file.backend_userdata.rendered)
  tags = { Name = "backend-ec2" }
}

# -------------------------------
# Import existing Elastic IPs
# -------------------------------
data "aws_eip" "frontend_eip" {
  id = "eipalloc-023b2fcdd844df229"
}

data "aws_eip" "backend_eip" {
  id = "eipalloc-012bbf7ac1302229a"
}

resource "aws_eip_association" "frontend_eip_assoc" {
  instance_id   = aws_instance.frontend.id
  allocation_id = data.aws_eip.frontend_eip.id
}

resource "aws_eip_association" "backend_eip_assoc" {
  instance_id   = aws_instance.backend.id
  allocation_id = data.aws_eip.backend_eip.id
}

# -------------------------------
# API Gateway Setup
# -------------------------------
resource "aws_apigatewayv2_api" "todo_api" {
  name          = "todo-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "todo_integration" {
  api_id                 = aws_apigatewayv2_api.todo_api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = "http://${data.aws_eip.backend_eip.public_ip}:3000/{proxy}"
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "todo_route" {
  api_id    = aws_apigatewayv2_api.todo_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.todo_integration.id}"
}

resource "aws_apigatewayv2_stage" "todo_stage" {
  api_id      = aws_apigatewayv2_api.todo_api.id
  name        = "$default"
  auto_deploy = true
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.todo_api.api_endpoint
}
