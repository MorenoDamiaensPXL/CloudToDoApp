variable "my_region" {
    description = "AWS region"
    type = string
    default = "us-east-1"
}

variable "my_instance_type" {
    description = "my instance type"
    type = string
    default = "t3.micro"
}

variable "key_name" {
    description = "my keypair name for the EC2"
    type = string

}
// For SSH TEsting  
variable "allowed_client_cidr" {
    description = "my client ip address"
    type = string
    default = "84.195.212.134/32"
}

variable "userdata_file" {
  description = "The User data file thats needed for the golang app "
  default = "userdata.sh"
}
variable "ami" {
    description = "ubuntu ami"
    type = string
    default = "ami-0360c520857e3138f"
}