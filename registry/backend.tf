terraform {
  backend "s3" {
    bucket       = "umuttvar-aws-platform-tfstate"
    key          = "registry/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}