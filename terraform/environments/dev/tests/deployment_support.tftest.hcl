mock_provider "aws" {}

variables { name_prefix = "lago-test" }

# All applies in these tests use a mock provider, never AWS.
run "private_short_lived_transfer_storage" {
  command = apply
  module { source = "../../modules/deployment_support" }
  assert {
    condition = (
      aws_s3_bucket_public_access_block.transfer.block_public_acls &&
      aws_s3_bucket_public_access_block.transfer.block_public_policy &&
      aws_s3_bucket_public_access_block.transfer.ignore_public_acls &&
      aws_s3_bucket_public_access_block.transfer.restrict_public_buckets &&
      !aws_s3_bucket.transfer.force_destroy
    )
    error_message = "Transfer storage must block all public access and refuse blind data deletion."
  }
  assert {
    condition = (
      one(aws_s3_bucket_versioning.transfer.versioning_configuration).status == "Suspended" &&
      one(aws_s3_bucket_server_side_encryption_configuration.transfer.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256" &&
      one(aws_s3_bucket_lifecycle_configuration.transfer.rule).expiration[0].days == 1
    )
    error_message = "Transfers must be encrypted, unversioned/suspended, and short-lived."
  }
  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.transfer.policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.transfer.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    )
    error_message = "The transfer bucket must reject non-TLS transport."
  }
}

run "reject_long_transfer_retention" {
  command = plan
  module { source = "../../modules/deployment_support" }
  variables { expiration_days = 30 }
  expect_failures = [var.expiration_days]
}
