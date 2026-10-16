mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_region" { defaults = { region = "us-east-2" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_availability_zones" { defaults = { names = ["us-east-2a", "us-east-2b", "us-east-2c"] } }
  mock_data "aws_subnet" { defaults = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-2a", map_public_ip_on_launch = false } }
  mock_data "aws_ami" { defaults = { id = "ami-09519cc56eb20524a", architecture = "x86_64" } }
  mock_data "aws_ec2_instance_type" { defaults = { supported_architectures = ["x86_64"] } }
  mock_data "aws_route53_zone" { defaults = { zone_id = "Z0123456789EXAMPLE", name = "phoniex.site.", private_zone = false } }
  mock_resource "aws_vpc" { defaults = { id = "vpc-0123456789abcdef0" } }
  mock_resource "aws_eip" { defaults = { public_ip = "203.0.113.10" } }
}

# Keep mock applies from writing or deleting the controller's real inventory.
mock_provider "local" {}

run "complete_dev_contract" {
  command = apply
  assert {
    condition = (
      local_file.ansible_inventory.file_permission == "0600" &&
      local_file.ansible_inventory.directory_permission == "0700" &&
      output.ansible_inventory_file == abspath("${path.root}/../../../ansible/inventories/dev/hosts.yml") &&
      keys(yamldecode(local_file.ansible_inventory.content).all.children.lago.hosts) == [output.instance_id] &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.hosts[output.instance_id].ansible_aws_ssm_instance_id == output.instance_id &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.hosts[output.instance_id].lago_data_volume_id == output.volume_ids.data
    )
    error_message = "Terraform must generate private inventory using the current host and data-volume outputs."
  }
  assert {
    condition = (
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.ansible_connection == "amazon.aws.aws_ssm" &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.ansible_aws_ssm_region == "us-east-2" &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.ansible_aws_ssm_bucket_name == output.ansible_connection.ansible_aws_ssm_bucket_name &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.ansible_aws_ssm_bucket_sse_mode == "AES256" &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.ansible_become == true &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.lago_data_mount_path == "/srv/lago-data"
    )
    error_message = "Generated YAML must preserve the SSM, encrypted transfer-storage, and mount contracts."
  }
  assert {
    condition = (
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.lago_cloudwatch_agent_config == jsondecode(output.cloudwatch_agent_config_json) &&
      yamldecode(local_file.ansible_inventory.content).all.children.lago.vars.lago_docker_logging == merge(output.docker_logging, {
        options = merge(output.docker_logging.options, {
          tag = "{% raw %}${output.docker_logging.options.tag}{% endraw %}"
        })
      })
    )
    error_message = "Host configuration must consume the same monitoring and logging settings as Terraform outputs."
  }
  assert {
    condition = (
      output.ansible_connection.ansible_connection == "amazon.aws.aws_ssm" &&
      output.ansible_connection.ansible_aws_ssm_region == "us-east-2" &&
      output.ansible_connection.ansible_aws_ssm_bucket_sse_mode == "AES256" &&
      output.ansible_connection.data_mount_path == "/srv/lago-data"
    )
    error_message = "The complete foundation must expose coherent, non-secret Ansible connection settings."
  }
  assert {
    condition = (
      output.docker_logging.driver == "awslogs" &&
      output.docker_logging.options["awslogs-group"] == output.log_group_names["application"] &&
      output.docker_logging.options["awslogs-create-group"] == "false" &&
      output.docker_logging.options["awslogs-region"] == "us-east-2" &&
      output.docker_logging.options.tag == "{{.Name}}/{{.ID}}" &&
      output.docker_logging.options["cache-max-file"] == "3"
    )
    error_message = "Container logging must use the pre-created application group, unique streams, and bounded local caching."
  }
  assert {
    condition = (
      contains(keys(output.public_subnet_ids), "public_a") &&
      length(output.volume_ids) == 2 && length(output.log_group_names) == 3 &&
      output.ansible_connection.ansible_aws_ssm_bucket_name != "lago-tfstate-us-east-2-f31e719a5b888b03e3bdf256df"
    )
    error_message = "The environment must compose every required module and keep transfer storage separate from state."
  }
  assert {
    condition = (
      jsondecode(output.controller_transfer_policy_json).Statement[2].Resource == ["${module.deployment_support.bucket_arn}/${output.instance_id}/*"] &&
      jsondecode(output.controller_transfer_policy_json).Statement[1].Condition.StringLike["s3:prefix"] == ["${output.instance_id}/*"]
    )
    error_message = "The controller's transfer permissions must be scoped to this host's object prefix."
  }
}

run "application_dns_contract" {
  command = plan
  assert {
    condition = (
      length(aws_route53_record.application) == 2 &&
      output.application_hostnames == { frontend = "app.phoniex.site", api = "api.phoniex.site" } &&
      data.aws_route53_zone.application.name == "phoniex.site." &&
      !data.aws_route53_zone.application.private_zone &&
      alltrue([for record in aws_route53_record.application :
        record.zone_id == "Z0123456789EXAMPLE" &&
        record.type == "A" && record.ttl == 300 &&
        record.records == toset([output.public_ip]) &&
        !record.allow_overwrite
      ])
    )
    error_message = "Only the two approved IPv4 hostnames may be created in the existing public zone, targeting the managed EIP without overwriting existing records."
  }
}
