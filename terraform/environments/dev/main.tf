data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  tags             = merge(var.tags, { Project = "lago", Environment = "dev", ManagedBy = "terraform" })
  metric_namespace = "Lago/Host"
  data_mount_path  = "/srv/lago-data"
  log_groups = {
    system      = "/lago/dev/system"
    application = "/lago/dev/application"
    bootstrap   = "/lago/dev/bootstrap"
  }
  controller_transfer_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "LocateTransferBucket"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation"]
        Resource = [module.deployment_support.bucket_arn]
      },
      {
        Sid       = "ListHostTransferPrefix"
        Effect    = "Allow"
        Action    = ["s3:ListBucket"]
        Resource  = [module.deployment_support.bucket_arn]
        Condition = { StringLike = { "s3:prefix" = ["${module.ec2.instance_id}/*"] } }
      },
      {
        Sid      = "TransferHostModules"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${module.deployment_support.bucket_arn}/${module.ec2.instance_id}/*"]
      },
    ]
  }
}

module "networking" {
  source = "../../modules/networking"

  name_prefix = var.name_prefix
  vpc_cidr    = var.vpc_cidr
  subnets     = var.subnets
  tags        = local.tags
}

module "deployment_support" {
  source = "../../modules/deployment_support"

  name_prefix     = var.name_prefix
  expiration_days = 1
  tags            = local.tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix            = var.name_prefix
  parameter_paths        = var.parameter_paths
  parameter_kms_key_arns = var.parameter_kms_key_arns
  log_group_arns         = toset(values(module.observability.log_group_arns))
  metric_namespace       = local.metric_namespace
  tags                   = local.tags
}

module "ec2" {
  source = "../../modules/ec2"

  name_prefix           = var.name_prefix
  vpc_id                = module.networking.vpc_id
  subnet_id             = module.networking.public_subnet_ids[var.host_subnet_key]
  instance_profile_name = module.iam.instance_profile_name
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  root_volume_gib       = var.root_volume_gib
  data_volume_gib       = var.data_volume_gib
  web_ingress_cidrs     = var.web_ingress_cidrs
  enable_http           = var.enable_http
  tags                  = local.tags

}

module "observability" {
  source = "../../modules/observability"

  log_groups       = local.log_groups
  retention_days   = var.log_retention_days
  metric_namespace = local.metric_namespace
  data_mount_path  = local.data_mount_path
  tags             = local.tags
}
