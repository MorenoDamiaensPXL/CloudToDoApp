

# --- Route Table ID ---
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_rt.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id 
  }

  output "static_ip" {
  description = "Static public IP of the EC2 instance"
  value       = aws_instance.frontend.public_ip
}

