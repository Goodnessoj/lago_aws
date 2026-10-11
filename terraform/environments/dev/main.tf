data "aws_availability_zones" "available" {
  state = "available"
}

module "networking" {
  source = "../../modules/networking"

  name_prefix = var.name_prefix
  vpc_cidr    = var.vpc_cidr
  subnets     = var.subnets
  tags        = merge(var.tags, { Project = "lago", Environment = "dev", ManagedBy = "terraform" })
}
