locals {
  ansible_connection = {
    instance_id                     = module.ec2.instance_id
    ansible_connection              = "amazon.aws.aws_ssm"
    ansible_aws_ssm_region          = "us-east-2"
    ansible_aws_ssm_bucket_name     = module.deployment_support.bucket_name
    ansible_aws_ssm_bucket_sse_mode = "AES256"
    data_volume_id                  = module.ec2.data_volume_id
    data_mount_path                 = local.data_mount_path
  }
}

resource "local_file" "ansible_inventory" {
  filename             = abspath("${path.module}/../../../ansible/inventories/dev/hosts.yml")
  file_permission      = "0600"
  directory_permission = "0700"

  content = yamlencode({
    all = {
      children = {
        lago = {
          hosts = {
            (local.ansible_connection.instance_id) = {
              ansible_aws_ssm_instance_id = local.ansible_connection.instance_id
              lago_data_volume_id         = local.ansible_connection.data_volume_id
            }
          }
          vars = {
            ansible_connection              = local.ansible_connection.ansible_connection
            ansible_aws_ssm_region          = local.ansible_connection.ansible_aws_ssm_region
            ansible_aws_ssm_bucket_name     = local.ansible_connection.ansible_aws_ssm_bucket_name
            ansible_aws_ssm_bucket_sse_mode = local.ansible_connection.ansible_aws_ssm_bucket_sse_mode
            ansible_python_interpreter      = "/usr/bin/python3"
            ansible_become                  = true
            ansible_become_user             = "root"
            lago_data_mount_path            = local.ansible_connection.data_mount_path
            lago_cloudwatch_agent_config    = jsondecode(module.observability.agent_config_json)
            # Docker's Go template must reach the daemon without Jinja evaluation.
            lago_docker_logging = merge(module.observability.docker_logging, {
              options = merge(module.observability.docker_logging.options, {
                tag = "{% raw %}${module.observability.docker_logging.options.tag}{% endraw %}"
              })
            })
          }
        }
      }
    }
  })
}
