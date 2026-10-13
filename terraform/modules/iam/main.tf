data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  parameter_arns = [
    for path in sort(tolist(var.parameter_paths)) :
    "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${path}"
  ]
  log_group_arns = [for arn in sort(tolist(var.log_group_arns)) : trimsuffix(arn, ":*")]
}

resource "aws_iam_role" "host" {
  name = "${var.name_prefix}-host"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "runtime" {
  name = "${var.name_prefix}-runtime"
  role = aws_iam_role.host.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid    = "SessionManager"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        # These Session Manager channel operations do not support resource scoping.
        Resource = ["*"]
      }],
      length(var.parameter_paths) == 0 ? [] : [{
        Sid      = "ReadNamedParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = local.parameter_arns
      }],
      length(var.parameter_kms_key_arns) == 0 ? [] : [{
        Sid      = "DecryptNamedParameters"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = sort(tolist(var.parameter_kms_key_arns))
        Condition = {
          StringEquals = {
            "kms:ViaService"                      = "ssm.${data.aws_region.current.region}.amazonaws.com"
            "kms:EncryptionContext:PARAMETER_ARN" = local.parameter_arns
          }
        }
      }],
      length(var.log_group_arns) == 0 ? [] : [{
        Sid      = "WriteNamedLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
        Resource = [for arn in local.log_group_arns : "${arn}:*"]
      }],
      [{
        Sid      = "PublishHostMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = ["*"]
        Condition = {
          StringEquals = { "cloudwatch:namespace" = var.metric_namespace }
        }
      }],
    )
  })

  lifecycle {
    precondition {
      condition     = length(var.parameter_kms_key_arns) == 0 || length(var.parameter_paths) > 0
      error_message = "Custom parameter decrypt permissions require explicit parameter paths."
    }
  }
}

resource "aws_iam_instance_profile" "host" {
  name = "${var.name_prefix}-host"
  role = aws_iam_role.host.name
  tags = var.tags

  depends_on = [aws_iam_role_policy.runtime]
}
