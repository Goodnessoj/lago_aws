variable "name_prefix" {
  description = "Name prefix for the development environment."
  type        = string
  default     = "lago-dev"
}

variable "vpc_cidr" {
  description = "VPC range; review overlap with any networks that may connect later."
  type        = string
  default     = "10.42.0.0/16"
}

variable "subnets" {
  description = "Currently deployed subnet allocations; future allocations remain documentation only."
  type = map(object({
    cidr_block        = string
    availability_zone = string
    type              = string
  }))
  default = {
    public_a = {
      cidr_block        = "10.42.1.0/24"
      availability_zone = "us-east-2a"
      type              = "public"
    }
  }

  validation {
    condition = alltrue([
      for subnet in var.subnets : contains(data.aws_availability_zones.available.names, subnet.availability_zone)
    ])
    error_message = "All selected availability zones must be available in the provider's Ohio region."
  }
}

variable "tags" {
  description = "Additional non-secret environment tags."
  type        = map(string)
  default     = {}
}

variable "host_subnet_key" {
  description = "Stable public subnet key used by the single application host."
  type        = string
  default     = "public_a"
  validation {
    condition     = contains(keys(var.subnets), var.host_subnet_key)
    error_message = "host_subnet_key must refer to a configured public subnet."
  }
}

variable "ami_id" {
  description = "Canonical Ubuntu 24.04 amd64, published 2026-10-04, verified in Ohio on 2026-10-11."
  type        = string
  default     = "ami-09519cc56eb20524a"
}

variable "instance_type" {
  description = "Proposed lab sizing: 2 vCPUs, 8 GiB RAM; suitability awaits measured deployment checks."
  type        = string
  default     = "t3a.large"
}

variable "root_volume_gib" {
  description = "Encrypted OS volume, deleted on termination."
  type        = number
  default     = 16
}

variable "data_volume_gib" {
  description = "Encrypted application volume, retained on host replacement and protected from destruction."
  type        = number
  default     = 30
}

variable "web_ingress_cidrs" {
  description = "Proposed public IPv4 application audience, subject to review before apply."
  type        = set(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_http" {
  description = "Allow Caddy redirects and ACME HTTP validation on port 80."
  type        = bool
  default     = true
}

variable "parameter_paths" {
  description = "Exact SecureString names; values are populated outside Terraform and fetched by host tasks."
  type        = set(string)
  default = [
    "/lago/dev/postgres_password",
    "/lago/dev/secret_key_base",
    "/lago/dev/rsa_private_key",
    "/lago/dev/encryption_primary_key",
    "/lago/dev/encryption_deterministic_key",
    "/lago/dev/encryption_key_derivation_salt",
    "/lago/dev/initial_admin_password",
  ]
}

variable "parameter_kms_key_arns" {
  description = "Explicit customer-managed parameter keys, if used; empty selects no extra KMS grants."
  type        = set(string)
  default     = []
}

variable "log_retention_days" {
  description = "Retention applied to every pre-created log group."
  type        = number
  default     = 7
}

variable "alarm_actions" {
  description = "Existing SNS topics, if supplied; no notifications are configured by default."
  type        = list(string)
  default     = []
}
