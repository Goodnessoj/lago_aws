data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "selected" {
  owners = ["099720109477"]
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ec2_instance_type" "selected" {
  instance_type = var.instance_type
}

locals {
  ingress = {
    for rule in setproduct(var.enable_http ? [80, 443] : [443], var.web_ingress_cidrs) :
    "${rule[0]}:${rule[1]}" => { port = rule[0], cidr = rule[1] }
  }
}

resource "aws_security_group" "host" {
  name_prefix = "${var.name_prefix}-host-"
  description = "Caddy HTTP/HTTPS only; administration through outbound SSM"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-host" })
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = local.ingress

  security_group_id = aws_security_group.host.id
  description       = each.value.port == 443 ? "Caddy HTTPS" : "Caddy redirects and ACME"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.host.id
  description       = "SSM, DNS, OS repositories, registries, S3 and AWS APIs"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = var.tags
}

resource "aws_instance" "host" {
  ami                         = data.aws_ami.selected.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.host.id]
  iam_instance_profile        = var.instance_profile_name
  key_name                    = ""
  associate_public_ip_address = false
  disable_api_termination     = true
  user_data                   = file("${path.module}/bootstrap.sh")
  user_data_replace_on_change = true

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = var.root_volume_gib
    delete_on_termination = true
    tags                  = merge(var.tags, { Name = "${var.name_prefix}-root" })
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-host" })

  lifecycle {
    # The provider reads an attached EIP as true; retain false only at launch.
    ignore_changes = [associate_public_ip_address]

    precondition {
      condition     = data.aws_subnet.selected.vpc_id == var.vpc_id && !data.aws_subnet.selected.map_public_ip_on_launch
      error_message = "The subnet must belong to the selected VPC and have automatic public-IP assignment disabled."
    }
    precondition {
      condition     = contains(data.aws_ec2_instance_type.selected.supported_architectures, data.aws_ami.selected.architecture)
      error_message = "The pinned Ubuntu AMI and instance type must use compatible architectures."
    }
  }

  depends_on = [aws_vpc_security_group_egress_rule.outbound]
}

resource "aws_eip" "host" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-host" })
}

resource "aws_eip_association" "host" {
  allocation_id       = aws_eip.host.id
  instance_id         = aws_instance.host.id
  allow_reassociation = false
}

resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_subnet.selected.availability_zone
  type              = "gp3"
  size              = var.data_volume_gib
  encrypted         = true
  tags              = merge(var.tags, { Name = "${var.name_prefix}-data", Purpose = "application-data" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.data.id
  instance_id                    = aws_instance.host.id
  force_detach                   = false
  stop_instance_before_detaching = true
}
