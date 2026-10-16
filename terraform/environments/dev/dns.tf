data "aws_route53_zone" "application" {
  name         = "phoniex.site."
  private_zone = false
}

locals {
  application_hostnames = {
    frontend = "app.phoniex.site"
    api      = "api.phoniex.site"
  }
}

resource "aws_route53_record" "application" {
  for_each = local.application_hostnames

  zone_id         = data.aws_route53_zone.application.zone_id
  name            = each.value
  type            = "A"
  ttl             = 300
  records         = [module.ec2.public_ip]
  allow_overwrite = false
}
