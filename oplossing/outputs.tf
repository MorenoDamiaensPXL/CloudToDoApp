############################################
# Outputs
############################################
output "api_gateway_url" {
  value       = aws_apigatewayv2_api.todo_api.api_endpoint
  description = "Invoke URL van de HTTP API"
}

output "public_route_table_id" {
  description = "ID van de public route table"
  value       = aws_route_table.public_rt.id
}

output "internet_gateway_id" {
  value       = aws_internet_gateway.igw.id
  description = "ID van de Internet Gateway"
}

output "static_ip" {
  description = "Static public IP van de frontend EC2 (EIP)"
  value       = aws_eip.frontend_eip.public_ip
}
