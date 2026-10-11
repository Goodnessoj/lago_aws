terraform {
  backend "s3" {
    bucket       = "lago-tfstate-us-east-2-f31e719a5b888b03e3bdf256df"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}