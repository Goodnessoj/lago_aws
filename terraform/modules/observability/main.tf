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
