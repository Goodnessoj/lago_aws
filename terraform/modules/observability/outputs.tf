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

output "alarm_names" {
  description = "Alarms keyed by CPU, status, CPU credits, memory, and disk."
  value       = { for key, alarm in aws_cloudwatch_metric_alarm.host : key => alarm.alarm_name }
}

output "agent_config_json" {
  description = "Non-secret agent configuration for later Ansible installation, matching alarm dimensions and paths."
  value       = jsonencode(local.agent_config)
}

output "notification_actions_configured" {
  description = "Whether actions were supplied; delivery must still be tested."
  value       = length(var.alarm_actions) > 0
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
