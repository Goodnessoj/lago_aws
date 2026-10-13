output "instance_id" {
  description = "Instance ID for SSM administration and monitoring."
  value       = aws_instance.host.id
}

output "public_ip" {
  description = "Explicit Elastic IP used by the HTTPS entry points."
  value       = aws_eip.host.public_ip
}

output "security_group_id" {
  description = "Application host security group; contains no SSH/database ingress."
  value       = aws_security_group.host.id
}

output "root_volume_id" {
  description = "Encrypted OS volume, deleted with the host."
  value       = aws_instance.host.root_block_device[0].volume_id
}

output "data_volume_id" {
  description = "Encrypted separately managed application volume, protected from Terraform destruction."
  value       = aws_ebs_volume.data.id
}
