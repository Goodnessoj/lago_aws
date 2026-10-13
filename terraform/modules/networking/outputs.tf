output "vpc_id" {
  description = "VPC ID for compute and security-group integration."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs indexed by stable input keys."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }

  # Consumers need the routed subnet, not just the subnet creation.
  depends_on = [aws_route.public_internet, aws_route_table_association.this]
}

output "route_table_ids" {
  description = "Route table IDs indexed by routing purpose."
  value       = { public = aws_route_table.public.id }
}
