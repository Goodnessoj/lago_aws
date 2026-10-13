variable "name_prefix" {
  description = "Prefix for the dedicated Ansible SSM transfer bucket."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.name_prefix))
    error_message = "Use a lowercase prefix of 1-30 letters, digits, or hyphens, starting with a letter."
  }
}

variable "expiration_days" {
  description = "Fallback expiration for interrupted transfers; Ansible should delete objects immediately."
  type        = number
  default     = 1
  validation {
    condition     = var.expiration_days >= 1 && var.expiration_days <= 7 && floor(var.expiration_days) == var.expiration_days
    error_message = "Transfer expiration must be an integer from 1 to 7 days."
  }
}

variable "tags" {
  description = "Non-secret resource tags."
  type        = map(string)
  default     = {}
}
