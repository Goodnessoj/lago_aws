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

output "instance_id" {
  description = "SSM host ID; no SSH key or port is provisioned."
  value       = module.ec2.instance_id
}

output "public_ip" {
  description = "Elastic IP for the reviewed frontend/API DNS records."
  value       = module.ec2.public_ip
}

output "security_group_id" {
  description = "Host application security group."
  value       = module.ec2.security_group_id
}

output "volume_ids" {
  description = "OS volume is ephemeral to the host; application volume remains separately managed."
  value       = { root = module.ec2.root_volume_id, data = module.ec2.data_volume_id }
}

output "instance_role_arn" {
  description = "Runtime role, separate from operator provisioning permissions."
  value       = module.iam.role_arn
}

output "ansible_connection" {
  description = "Non-secret connection settings for the later Ansible inventory."
  value = {
    instance_id                     = module.ec2.instance_id
    ansible_connection              = "amazon.aws.aws_ssm"
    ansible_aws_ssm_region          = "us-east-2"
    ansible_aws_ssm_bucket_name     = module.deployment_support.bucket_name
    ansible_aws_ssm_bucket_sse_mode = "AES256"
    data_volume_id                  = module.ec2.data_volume_id
    data_mount_path                 = local.data_mount_path
  }
}

output "controller_transfer_policy_json" {
  description = "Review-only S3 policy for the controller's host prefix; not automatically attached to the operator."
  value       = jsonencode(local.controller_transfer_policy)
}

output "log_group_names" {
  description = "Pre-created system, bootstrap, and application log groups."
  value       = module.observability.log_group_names
}

output "alarm_names" {
  description = "Host alarms; notification delivery remains unconfigured unless actions are supplied."
  value       = module.observability.alarm_names
}

output "cloudwatch_agent_config_json" {
  description = "Non-secret configuration to install through Ansible, not Terraform user data."
  value       = module.observability.agent_config_json
}

output "docker_logging" {
  description = "Non-secret per-container logging settings for the Ansible-managed Compose override."
  value       = module.observability.docker_logging
}
