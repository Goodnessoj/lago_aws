mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-2" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
}

variables {
  name_prefix      = "lago-test"
  parameter_paths  = ["/lago/dev/postgres_password", "/lago/dev/secret_key_base"]
  log_group_arns   = ["arn:aws:logs:us-east-2:123456789012:log-group:/lago/dev/system"]
  metric_namespace = "Lago/Host"
}

run "scoped_host_permissions" {
  command = plan
  module { source = "../../modules/iam" }

  assert {
    condition = toset(one([
      for statement in jsondecode(aws_iam_role_policy.runtime.policy).Statement : statement
      if statement.Sid == "ReadNamedParameters"
      ]).Resource) == toset([
      "arn:aws:ssm:us-east-2:123456789012:parameter/lago/dev/postgres_password",
      "arn:aws:ssm:us-east-2:123456789012:parameter/lago/dev/secret_key_base",
    ])
    error_message = "The host must read only the named secret parameters."
  }
  assert {
    condition = alltrue([
      for statement in jsondecode(aws_iam_role_policy.runtime.policy).Statement :
      !contains(statement.Action, "ssm:GetParametersByPath") &&
      alltrue([for action in statement.Action : !startswith(action, "s3:")])
    ])
    error_message = "The host must not inherit broad parameter or transfer-bucket access."
  }
  assert {
    condition = one([
      for statement in jsondecode(aws_iam_role_policy.runtime.policy).Statement : statement
      if statement.Sid == "PublishHostMetrics"
    ]).Condition.StringEquals["cloudwatch:namespace"] == "Lago/Host"
    error_message = "Metric publication must be restricted to the chosen namespace."
  }
  assert {
    condition = one([
      for statement in jsondecode(aws_iam_role_policy.runtime.policy).Statement : statement
      if statement.Sid == "WriteNamedLogs"
    ]).Resource == ["arn:aws:logs:us-east-2:123456789012:log-group:/lago/dev/system:*"]
    error_message = "CloudWatch writes must be restricted to named log groups."
  }
}

run "reject_wildcard_secrets" {
  command = plan
  module { source = "../../modules/iam" }
  variables { parameter_paths = ["/lago/dev/*"] }
  expect_failures = [var.parameter_paths]
}

run "scope_customer_key_decryption" {
  command = plan
  module { source = "../../modules/iam" }
  variables {
    parameter_kms_key_arns = ["arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111"]
  }
  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.runtime.policy).Statement : statement if statement.Sid == "DecryptNamedParameters"]).Condition.StringEquals["kms:ViaService"] == "ssm.us-east-2.amazonaws.com" &&
      toset(one([for statement in jsondecode(aws_iam_role_policy.runtime.policy).Statement : statement if statement.Sid == "DecryptNamedParameters"]).Condition.StringEquals["kms:EncryptionContext:PARAMETER_ARN"]) == toset(output.parameter_arns)
    )
    error_message = "KMS decrypt must be constrained to SSM and the explicit parameter encryption contexts."
  }
}
