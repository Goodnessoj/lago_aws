output "bucket_name" {
  description = "Ansible SSM transfer bucket, separate from Terraform state."
  value       = aws_s3_bucket.transfer.id
}

output "bucket_arn" {
  description = "Transfer bucket ARN for controller policy composition."
  value       = aws_s3_bucket.transfer.arn
}
