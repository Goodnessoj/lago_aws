data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  for_each = var.log_groups

  name              = each.value
  retention_in_days = var.retention_days
  tags              = var.tags
}

locals {
  alarms = {
    cpu = {
      namespace = "AWS/EC2", metric = "CPUUtilization", threshold = var.alarm_thresholds.cpu_percent,
      statistic = "Average", period = 300, evaluations = 3, comparison = "GreaterThanThreshold"
    }
    status = {
      namespace = "AWS/EC2", metric = "StatusCheckFailed", threshold = 1,
      statistic = "Maximum", period = 60, evaluations = 2, comparison = "GreaterThanOrEqualToThreshold"
    }
    cpu_credits = {
      namespace = "AWS/EC2", metric = "CPUCreditBalance", threshold = 20,
      statistic = "Average", period = 300, evaluations = 2, comparison = "LessThanThreshold"
    }
    memory = {
      namespace = var.metric_namespace, metric = "mem_used_percent", threshold = var.alarm_thresholds.memory_percent,
      statistic = "Average", period = 60, evaluations = 3, comparison = "GreaterThanThreshold"
    }
    disk = {
      namespace = var.metric_namespace, metric = "disk_used_percent", threshold = var.alarm_thresholds.disk_percent,
      statistic = "Maximum", period = 60, evaluations = 3, comparison = "GreaterThanThreshold"
    }
  }
  agent_config = {
    agent = { metrics_collection_interval = 60, omit_hostname = true }
    metrics = {
      namespace              = var.metric_namespace
      append_dimensions      = { InstanceId = "$${aws:InstanceId}" }
      aggregation_dimensions = [["InstanceId"]]
      metrics_collected = {
        mem = { measurement = ["mem_used_percent"], metrics_collection_interval = 60 }
        disk = {
          measurement                 = ["used_percent"]
          resources                   = ["/", var.data_mount_path]
          drop_device                 = true
          drop_original_metrics       = ["disk_used_percent"]
          metrics_collection_interval = 60
        }
      }
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            { file_path = "/var/log/syslog", log_group_name = aws_cloudwatch_log_group.this["system"].name, log_stream_name = "{instance_id}/syslog" },
            { file_path = "/var/log/cloud-init-output.log", log_group_name = aws_cloudwatch_log_group.this["bootstrap"].name, log_stream_name = "{instance_id}/cloud-init" },
          ]
        }
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "host" {
  for_each = local.alarms

  alarm_name          = "${var.name_prefix}-${each.key}"
  alarm_description   = "Lago host ${each.key}; agent metrics require Ansible configuration"
  namespace           = each.value.namespace
  metric_name         = each.value.metric
  dimensions          = { InstanceId = var.instance_id }
  statistic           = each.value.statistic
  period              = each.value.period
  evaluation_periods  = each.value.evaluations
  datapoints_to_alarm = each.value.evaluations
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison
  treat_missing_data  = "missing"
  actions_enabled     = length(var.alarm_actions) > 0
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  tags                = var.tags
}
