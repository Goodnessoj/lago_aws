locals {
  # Compare IPv4 address bounds numerically after Terraform's CIDR functions parse them.
  vpc_range = {
    first = try(sum([for index, octet in split(".", cidrhost(var.vpc_cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]), -1)
    last  = try(sum([for index, octet in split(".", cidrhost(var.vpc_cidr, -1)) : tonumber(octet) * pow(256, 3 - index)]), -1)
  }
  subnet_ranges = {
    for key, subnet in var.subnets : key => {
      first = try(sum([for index, octet in split(".", cidrhost(subnet.cidr_block, 0)) : tonumber(octet) * pow(256, 3 - index)]), -1)
      last  = try(sum([for index, octet in split(".", cidrhost(subnet.cidr_block, -1)) : tonumber(octet) * pow(256, 3 - index)]), -1)
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })

  lifecycle {
    precondition {
      condition = alltrue([
        for subnet in local.subnet_ranges :
        subnet.first >= local.vpc_range.first && subnet.last <= local.vpc_range.last
      ])
      error_message = "All subnet CIDRs must be contained in the VPC CIDR."
    }

    precondition {
      condition = alltrue(flatten([
        for key, subnet in local.subnet_ranges : [
          for other_key, other in local.subnet_ranges :
          key == other_key || subnet.last < other.first || other.last < subnet.first
        ]
      ]))
      error_message = "Subnet CIDRs must not overlap."
    }
  }
}

# The default security group is unused and has no ingress or egress rules.
resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []

  tags = merge(var.tags, { Name = "${var.name_prefix}-default-unused" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-${each.key}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "this" {
  for_each = var.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public.id
}
