mock_provider "aws" {}

variables {
  name_prefix = "lago-test"
  vpc_cidr    = "10.42.0.0/16"
  subnets = {
    public_a = {
      cidr_block        = "10.42.1.0/24"
      availability_zone = "us-east-2a"
      type              = "public"
    }
  }
}

# Apply only to the mock provider to establish test state; no AWS calls occur.
run "baseline" {
  command = apply

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "VPC DNS support and hostnames must be enabled."
  }

  assert {
    condition     = !aws_subnet.this["public_a"].map_public_ip_on_launch
    error_message = "Public IPs must be attached explicitly through the compute module."
  }

  assert {
    condition = (
      aws_route.public_internet.destination_cidr_block == "0.0.0.0/0" &&
      aws_route.public_internet.gateway_id == aws_internet_gateway.this.id &&
      aws_route_table_association.this["public_a"].route_table_id == aws_route_table.public.id
    )
    error_message = "Public subnet must be associated with explicit internet-gateway routing."
  }

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "The unused default security group must not permit traffic."
  }
}

run "add_subnet_preserves_existing_ids" {
  command = plan

  variables {
    subnets = {
      public_a = {
        cidr_block        = "10.42.1.0/24"
        availability_zone = "us-east-2a"
        type              = "public"
      }
      public_b = {
        cidr_block        = "10.42.2.0/24"
        availability_zone = "us-east-2b"
        type              = "public"
      }
    }
  }

  assert {
    condition = (
      aws_vpc.this.id == run.baseline.vpc_id &&
      aws_subnet.this["public_a"].id == run.baseline.public_subnet_ids["public_a"] &&
      aws_route_table.public.id == run.baseline.route_table_ids["public"] &&
      length(aws_subnet.this) == 2 && length(aws_route_table_association.this) == 2
    )
    error_message = "Adding a subnet key must preserve existing VPC, subnet, and route-table identities."
  }
}

run "reject_overlapping_subnets" {
  command = plan

  variables {
    subnets = {
      public_a = {
        cidr_block        = "10.42.1.0/24"
        availability_zone = "us-east-2a"
        type              = "public"
      }
      public_b = {
        cidr_block        = "10.42.1.128/25"
        availability_zone = "us-east-2b"
        type              = "public"
      }
    }
  }

  expect_failures = [aws_vpc.this]
}

run "reject_subnet_outside_vpc" {
  command = plan

  variables {
    subnets = {
      public_a = {
        cidr_block        = "10.43.1.0/24"
        availability_zone = "us-east-2a"
        type              = "public"
      }
    }
  }

  expect_failures = [aws_vpc.this]
}

run "reject_noncanonical_cidr" {
  command = plan

  variables {
    subnets = {
      public_a = {
        cidr_block        = "10.42.1.10/24"
        availability_zone = "us-east-2a"
        type              = "public"
      }
    }
  }

  expect_failures = [var.subnets]
}
