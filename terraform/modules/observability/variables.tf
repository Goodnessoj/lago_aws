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
  description = "Namespace shared by the agent and runtime IAM policy."
  type        = string
  default     = "Lago/Host"
  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]{1,255}$", var.metric_namespace)) && !startswith(var.metric_namespace, "AWS/")
    error_message = "Use a custom metric namespace, not an AWS/ namespace."
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
