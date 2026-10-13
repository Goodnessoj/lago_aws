output "instance_profile_name" {
  description = "Instance profile ready for host attachment."
  value       = aws_iam_instance_profile.host.name
}

output "role_arn" {
  description = "Runtime EC2 role ARN."
  value       = aws_iam_role.host.arn
}

output "parameter_arns" {
  description = "Allowed parameter ARNs; no secret values are read by Terraform."
  value       = local.parameter_arns
}
