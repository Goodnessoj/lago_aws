mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-2" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
}

variables {
  name_prefix = "lago-test"
  instance_id = "i-0123456789abcdef0"
  log_groups  = { system = "/lago/dev/system", application = "/lago/dev/application", bootstrap = "/lago/dev/bootstrap" }
}

run "bounded_logs_and_matching_metrics" {
  command = plan
  module { source = "../../modules/observability" }
  assert {
    condition     = alltrue([for group in aws_cloudwatch_log_group.this : group.retention_in_days == 7]) && length(aws_cloudwatch_log_group.this) == 3
    error_message = "All three required log groups must have bounded retention."
  }
  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.host) == 5 &&
      aws_cloudwatch_metric_alarm.host["memory"].namespace == jsondecode(output.agent_config_json).metrics.namespace &&
      aws_cloudwatch_metric_alarm.host["disk"].dimensions["InstanceId"] == "i-0123456789abcdef0" &&
      length(aws_cloudwatch_metric_alarm.host["disk"].dimensions) == 1 &&
      jsondecode(output.agent_config_json).metrics.aggregation_dimensions == [["InstanceId"]]
    )
    error_message = "Agent metrics and alarm dimensions/namespaces must match."
  }
  assert {
    condition     = !output.notification_actions_configured && alltrue([for alarm in aws_cloudwatch_metric_alarm.host : !alarm.actions_enabled && alarm.treat_missing_data == "missing"])
    error_message = "Unconfigured delivery and missing agent data must not be presented as working alerts."
  }
}

run "reject_unbounded_retention" {
  command = plan
  module { source = "../../modules/observability" }
  variables { retention_days = 0 }
  expect_failures = [var.retention_days]
}

run "explicit_notification_destination" {
  command = plan
  module { source = "../../modules/observability" }
  variables { alarm_actions = ["arn:aws:sns:us-east-2:123456789012:lago-alerts"] }
  assert {
    condition     = output.notification_actions_configured && alltrue([for alarm in aws_cloudwatch_metric_alarm.host : alarm.actions_enabled && alarm.alarm_actions == toset(["arn:aws:sns:us-east-2:123456789012:lago-alerts"])])
    error_message = "Every alarm must target the explicit notification destination when supplied."
  }
}
