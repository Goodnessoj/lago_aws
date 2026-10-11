output "vpc_id" {
  description = "Lago development VPC ID."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs indexed by stable names."
  value       = module.networking.public_subnet_ids
}

output "route_table_ids" {
  description = "Environment route table IDs."
  value       = module.networking.route_table_ids
}
