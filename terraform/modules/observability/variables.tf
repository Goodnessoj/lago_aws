variable "name_prefix" {
  description = "Prefix for alarms and monitoring resources."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.name_prefix))
    error_message = "Use a lowercase prefix of 1-40 letters, digits, or hyphens, starting with a letter."
  }
}

variable "instance_id" {
  description = "Host monitored by native EC2 and CloudWatch agent metrics."
  type        = string
}

variable "log_groups" {
  description = "Log-group names keyed by purpose; system, application, and bootstrap are required."
  type        = map(string)
  validation {
    condition = (
      alltrue([for key in ["system", "application", "bootstrap"] : contains(keys(var.log_groups), key)]) &&
      alltrue([for name in values(var.log_groups) : can(regex("^/[A-Za-z0-9_./-]{1,511}$", name))]) &&
      length(distinct(values(var.log_groups))) == length(var.log_groups)
    )
    error_message = "Provide unique valid log-group names, including system, application, and bootstrap keys."
  }
}

variable "retention_days" {
  description = "Bounded CloudWatch log retention for the lab."
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.retention_days)
    error_message = "Choose 1, 3, 5, 7, 14, or 30 days of retention."
  }
}

variable "metric_namespace" {
  description = "Namespace shared by the agent, alarms, and runtime IAM policy."
  type        = string
  default     = "Lago/Host"
  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]{1,255}$", var.metric_namespace)) && !startswith(var.metric_namespace, "AWS/")
    error_message = "Use a custom metric namespace, not an AWS/ namespace."
  }
}

variable "alarm_actions" {
  description = "Existing Ohio SNS topic ARNs for alarm/recovery delivery; empty means inspect alarms manually."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for arn in var.alarm_actions : can(regex("^arn:aws:sns:us-east-2:[0-9]{12}:[A-Za-z0-9_-]+$", arn))])
    error_message = "Use explicit SNS topic ARNs in Ohio."
  }
}

variable "alarm_thresholds" {
  description = "CPU, memory, and disk utilization percentages."
  type = object({
    cpu_percent    = number
    memory_percent = number
    disk_percent   = number
  })
  default = { cpu_percent = 80, memory_percent = 85, disk_percent = 85 }
  validation {
    condition     = alltrue([for value in values(var.alarm_thresholds) : value > 0 && value <= 100])
    error_message = "Utilization thresholds must be greater than zero and at most 100."
  }
}

variable "data_mount_path" {
  description = "Mount path used by the later Ansible storage role and disk/log collection."
  type        = string
  default     = "/srv/lago-data"
  validation {
    condition     = can(regex("^/[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$", var.data_mount_path))
    error_message = "Use a non-root absolute path without traversal components."
  }
}

variable "tags" {
  description = "Non-secret resource tags."
  type        = map(string)
  default     = {}
}
