resource "aws_s3_bucket" "transfer" {
  bucket_prefix = "${var.name_prefix}-ssm-"
  force_destroy = false
  tags          = merge(var.tags, { Name = "${var.name_prefix}-ssm-transfer" })
}

resource "aws_s3_bucket_public_access_block" "transfer" {
  bucket                  = aws_s3_bucket.transfer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "transfer" {
  bucket = aws_s3_bucket.transfer.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transfer" {
  bucket = aws_s3_bucket.transfer.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Explicit suspension prevents version history retaining secret-bearing transfer payloads.
resource "aws_s3_bucket_versioning" "transfer" {
  bucket = aws_s3_bucket.transfer.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "transfer" {
  bucket = aws_s3_bucket.transfer.id
  rule {
    id     = "ExpireInterruptedTransfers"
    status = "Enabled"
    filter {}
    expiration {
      days = var.expiration_days
    }
    noncurrent_version_expiration {
      noncurrent_days = var.expiration_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = var.expiration_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.transfer]
}

resource "aws_s3_bucket_policy" "transfer" {
  bucket = aws_s3_bucket.transfer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Action    = "s3:*"
      Principal = "*"
      Resource  = [aws_s3_bucket.transfer.arn, "${aws_s3_bucket.transfer.arn}/*"]
      Condition = {
        Bool = { "aws:SecureTransport" = "false", "aws:PrincipalIsAWSService" = "false" }
      }
    }]
  })
}
