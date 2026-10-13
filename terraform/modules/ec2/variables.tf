variable "name_prefix" {
  description = "Prefix for host, storage, and security-group names."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.name_prefix))
    error_message = "Use a lowercase prefix of 1-40 letters, digits, or hyphens, starting with a letter."
  }
}

variable "vpc_id" {
  description = "VPC containing the selected public subnet."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet with explicit internet routing and automatic public IPs disabled."
  type        = string
}

variable "instance_profile_name" {
  description = "SSM and scoped runtime instance profile."
  type        = string
}

variable "ami_id" {
  description = "Pinned Canonical Ubuntu 24.04 amd64 AMI ID in the provider region."
  type        = string
  validation {
    condition     = can(regex("^ami-[a-f0-9]{17}$", var.ami_id))
    error_message = "Provide an explicit long-format AMI ID, not a moving latest-image lookup."
  }
}

variable "instance_type" {
  description = "x86-64 burstable T3/T3a lab instance; standard credits avoid surplus CPU charges."
  type        = string
  default     = "t3a.large"
  validation {
    condition     = can(regex("^t3a?\\.(medium|large|xlarge|2xlarge)$", var.instance_type))
    error_message = "Use a T3/T3a instance with at least 4 GiB RAM; reassess sizing from workload measurements."
  }
}

variable "root_volume_gib" {
  description = "Encrypted gp3 OS volume, deleted on instance termination; application data belongs on the separate volume."
  type        = number
  default     = 16
  validation {
    condition     = var.root_volume_gib >= 16 && var.root_volume_gib <= 100 && floor(var.root_volume_gib) == var.root_volume_gib
    error_message = "Root storage must be an integer from 16 to 100 GiB."
  }
}

variable "data_volume_gib" {
  description = "Separately managed encrypted gp3 data volume, retained on host replacement and protected from Terraform destroy."
  type        = number
  default     = 30
  validation {
    condition     = var.data_volume_gib >= 20 && var.data_volume_gib <= 500 && floor(var.data_volume_gib) == var.data_volume_gib
    error_message = "Data storage must be an integer from 20 to 500 GiB."
  }
}

variable "web_ingress_cidrs" {
  description = "IPv4 audiences allowed to reach Caddy; only HTTP/HTTPS can be published by this module."
  type        = set(string)
  default     = ["0.0.0.0/0"]
  validation {
    condition     = length(var.web_ingress_cidrs) > 0 && alltrue([for cidr in var.web_ingress_cidrs : can(cidrnetmask(cidr))])
    error_message = "Provide at least one valid IPv4 CIDR for application ingress."
  }
}

variable "enable_http" {
  description = "Allow port 80 for redirects and ACME HTTP validation alongside port 443."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Non-secret resource tags."
  type        = map(string)
  default     = {}
}
