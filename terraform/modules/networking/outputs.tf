output "vpc_id" {
  description = "VPC ID for compute and security-group integration."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs indexed by stable input keys."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "route_table_ids" {
  description = "Route table IDs indexed by routing purpose."
  value       = { public = aws_route_table.public.id }
}
