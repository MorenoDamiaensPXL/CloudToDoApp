variable "my_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "my_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 keypair name"
  type        = string
}

variable "allowed_client_cidr" {
  description = "SSH source CIDR"
  type        = string
  default     = "84.195.212.134/32"
}

variable "ami" {
  description = "Ubuntu AMI (region-specific)"
  type        = string
  default     = "ami-0360c520857e3138f"
}

# Immutability inputs from CI
variable "docker_ns" {
  description = "Docker Hub namespace (will be lowercased in user-data)"
  type        = string
}

variable "backend_digest" {
  description = "Digest for backend image (sha256:...)"
  type        = string
}

variable "frontend_digest" {
  description = "Digest for frontend image (sha256:...)"
  type        = string
}

variable "mongo_digest" {
  description = "Digest for Mongo image (sha256:...). If empty, falls back to a pinned tag."
  type        = string
  default     = ""
}
