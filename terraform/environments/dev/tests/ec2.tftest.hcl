mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-2a", map_public_ip_on_launch = false }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-09519cc56eb20524a", architecture = "x86_64" }
  }
  mock_data "aws_ec2_instance_type" { defaults = { supported_architectures = ["x86_64"] } }
}

variables {
  name_prefix           = "lago-test"
  vpc_id                = "vpc-0123456789abcdef0"
  subnet_id             = "subnet-0123456789abcdef0"
  ami_id                = "ami-09519cc56eb20524a"
  instance_profile_name = "lago-test-host"
}

run "ssm_only_encrypted_host" {
  command = apply
  module { source = "../../modules/ec2" }
  assert {
    condition = (
      aws_instance.host.metadata_options[0].http_tokens == "required" &&
      aws_instance.host.metadata_options[0].http_put_response_hop_limit == 1 &&
      !aws_instance.host.associate_public_ip_address &&
      aws_instance.host.credit_specification[0].cpu_credits == "standard" &&
      aws_instance.host.key_name == ""
    )
    error_message = "Host must require IMDSv2, use explicit EIP, standard CPU credits, and no SSH key."
  }
  assert {
    condition = alltrue([
      for rule in aws_vpc_security_group_ingress_rule.web :
      contains([80, 443], rule.from_port) && rule.from_port == rule.to_port
    ]) && length(aws_vpc_security_group_ingress_rule.web) == 2
    error_message = "Only Caddy's HTTP and HTTPS ports may be published."
  }
  assert {
    condition = (
      aws_instance.host.root_block_device[0].encrypted &&
      aws_instance.host.root_block_device[0].delete_on_termination &&
      aws_ebs_volume.data.encrypted && aws_ebs_volume.data.size == 30 &&
      !aws_volume_attachment.data.force_detach &&
      aws_volume_attachment.data.stop_instance_before_detaching
    )
    error_message = "Persistent data must use separately managed encrypted storage and safe attachment settings."
  }
}

run "https_only_restricted_audience" {
  command = plan
  module { source = "../../modules/ec2" }
  variables {
    enable_http       = false
    web_ingress_cidrs = ["203.0.113.0/24"]
  }
  assert {
    condition = length(aws_vpc_security_group_ingress_rule.web) == 1 && alltrue([
      for rule in aws_vpc_security_group_ingress_rule.web : rule.from_port == 443 && rule.cidr_ipv4 == "203.0.113.0/24"
    ])
    error_message = "Changing ingress policy must only expose the requested HTTPS audience."
  }
}

run "reject_incompatible_architecture" {
  command = plan
  module { source = "../../modules/ec2" }
  override_data {
    target = data.aws_ami.selected
    values = { id = "ami-09519cc56eb20524a", architecture = "arm64" }
  }
  expect_failures = [aws_instance.host]
}

run "reject_wrong_subnet_vpc" {
  command = plan
  module { source = "../../modules/ec2" }
  variables { vpc_id = "vpc-fffffffffffffffff" }
  expect_failures = [aws_instance.host]
}
