mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-2" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
}

variables {
  log_groups = { system = "/lago/dev/system", application = "/lago/dev/application", bootstrap = "/lago/dev/bootstrap" }
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
      jsondecode(output.agent_config_json).metrics.namespace == "Lago/Host" &&
      jsondecode(output.agent_config_json).metrics.append_dimensions.InstanceId == "$${aws:InstanceId}" &&
      !contains(keys(jsondecode(output.agent_config_json).metrics), "aggregation_dimensions") &&
      jsondecode(output.agent_config_json).metrics.metrics_collected.mem.measurement == ["mem_used_percent"] &&
      jsondecode(output.agent_config_json).metrics.metrics_collected.disk.resources == ["/", "/srv/lago-data"] &&
      !contains(keys(jsondecode(output.agent_config_json).metrics.metrics_collected.disk), "drop_original_metrics") &&
      jsondecode(output.agent_config_json).metrics.metrics_collected.disk.drop_device == true
    )
    error_message = "Retain original disk metrics with their filesystem paths; do not replace them with an instance-wide rollup."
  }
  assert {
    condition = (
      jsondecode(output.agent_config_json).logs.logs_collected.files.collect_list[0].log_group_name == output.log_group_names["system"] &&
      jsondecode(output.agent_config_json).logs.logs_collected.files.collect_list[1].log_group_name == output.log_group_names["bootstrap"] &&
      output.docker_logging.options["awslogs-group"] == output.log_group_names["application"]
    )
    error_message = "Host and container logs must use the pre-created log groups."
  }
}

run "reject_unbounded_retention" {
  command = plan
  module { source = "../../modules/observability" }
  variables { retention_days = 0 }
  expect_failures = [var.retention_days]
}

run "reject_reserved_metric_namespace" {
  command = plan
  module { source = "../../modules/observability" }
  variables { metric_namespace = "AWS/EC2" }
  expect_failures = [var.metric_namespace]
}
