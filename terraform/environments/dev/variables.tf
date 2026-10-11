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
