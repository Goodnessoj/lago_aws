output "log_group_arns" {
  description = "Named log-group ARNs for scoped runtime IAM permissions."
  # Derive the canonical ARN from the planned group name so IAM is reviewable before apply.
  value = {
    for key, group in aws_cloudwatch_log_group.this : key =>
    "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${group.name}"
  }
}

output "log_group_names" {
  description = "Log-group names for host configuration and inspection."
  value       = { for key, group in aws_cloudwatch_log_group.this : key => group.name }
}

output "agent_config_json" {
  description = "Non-secret host metrics and log collection settings consumed by Ansible."
  value       = jsonencode(local.agent_config)
}

output "docker_logging" {
  description = "Compose logging settings for per-container CloudWatch streams and bounded local dual-log caching."
  value = {
    driver = "awslogs"
    options = {
      awslogs-region       = data.aws_region.current.region
      awslogs-group        = aws_cloudwatch_log_group.this["application"].name
      awslogs-create-group = "false"
      tag                  = "{{.Name}}/{{.ID}}"
      mode                 = "non-blocking"
      max-buffer-size      = "4m"
      cache-max-size       = "10m"
      cache-max-file       = "3"
    }
  }
}
