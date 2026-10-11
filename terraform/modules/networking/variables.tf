variable "name_prefix" {
  description = "Prefix for resource Name tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.name_prefix))
    error_message = "Use a lowercase prefix of 1-40 letters, digits, or hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "Canonical IPv4 VPC CIDR, with an AWS-supported /16 through /28 prefix."
  type        = string

  validation {
    condition = try(
      can(cidrnetmask(var.vpc_cidr)) &&
      tonumber(split("/", var.vpc_cidr)[1]) >= 16 &&
      tonumber(split("/", var.vpc_cidr)[1]) <= 28 &&
      split("/", var.vpc_cidr)[0] == cidrhost(var.vpc_cidr, 0),
      false
    )
    error_message = "vpc_cidr must be a canonical IPv4 CIDR with a /16 through /28 prefix."
  }
}

variable "subnets" {
  description = "Subnets keyed by durable names; only public subnets are supported in this phase."
  type = map(object({
    cidr_block        = string
    availability_zone = string
    type              = string
  }))

  validation {
    condition = length(var.subnets) > 0 && alltrue([
      for key, subnet in var.subnets :
      can(regex("^[a-z][a-z0-9_]*$", key)) && subnet.type == "public" &&
      can(regex("^[a-z]{2}(-[a-z]+)+-[0-9][a-z]$", subnet.availability_zone))
    ])
    error_message = "Provide at least one public subnet with a stable lowercase key and a standard AWS availability-zone name."
  }

  validation {
    condition = alltrue([
      for subnet in var.subnets : try(
        can(cidrnetmask(subnet.cidr_block)) &&
        tonumber(split("/", subnet.cidr_block)[1]) >= 16 &&
        tonumber(split("/", subnet.cidr_block)[1]) <= 28 &&
        split("/", subnet.cidr_block)[0] == cidrhost(subnet.cidr_block, 0),
        false
      )
    ])
    error_message = "Each subnet must use a canonical IPv4 CIDR with a /16 through /28 prefix."
  }

}

variable "tags" {
  description = "Additional resource tags; Name is set by the module."
  type        = map(string)
  default     = {}
}
