variable "name_prefix" {
  description = "Prefix for the EC2 role and instance profile."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.name_prefix))
    error_message = "Use a lowercase prefix of 1-40 letters, digits, or hyphens, starting with a letter."
  }
}

variable "parameter_paths" {
  description = "Exact SecureString parameter names retrieved by the host, never their values."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for path in var.parameter_paths : can(regex("^/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+$", path))])
    error_message = "Provide exact hierarchical parameter names without wildcard characters."
  }
}

variable "parameter_kms_key_arns" {
  description = "Optional customer-managed keys for these parameters; empty for the AWS-managed SSM key."
  type        = set(string)
  default     = []
  validation {
    condition     = alltrue([for arn in var.parameter_kms_key_arns : can(regex("^arn:aws:kms:us-east-2:[0-9]{12}:key/[a-f0-9-]+$", arn))])
    error_message = "Use explicit customer-managed KMS key ARNs in Ohio, not aliases or wildcards."
  }
}

variable "log_group_arns" {
  description = "Exact log-group ARNs created by observability, with or without the trailing :*."
  type        = set(string)
  default     = []
  validation {
    condition = alltrue([
      for arn in var.log_group_arns : can(regex("^arn:aws:logs:us-east-2:[0-9]{12}:log-group:[^*]+(:\\*)?$", arn))
    ])
    error_message = "Provide named Ohio CloudWatch log-group ARNs, without wildcard group names."
  }
}

variable "metric_namespace" {
  description = "Custom namespace to which the host may publish metrics."
  type        = string
  default     = "Lago/Host"
  validation {
    condition     = can(regex("^[A-Za-z0-9_./-]{1,255}$", var.metric_namespace)) && !startswith(var.metric_namespace, "AWS/")
    error_message = "Use a custom metric namespace, not an AWS/ namespace."
  }
}

variable "tags" {
  description = "Non-secret resource tags."
  type        = map(string)
  default     = {}
}
