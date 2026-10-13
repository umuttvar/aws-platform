data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "umuttvar-aws-platform-tfstate"
    key    = "network/terraform.tfstate"
    region = "eu-central-1"
  }
}

resource "aws_security_group" "web" {
  name        = "aws-platform-web"
  description = "demo-app web server"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name = "aws-platform-web"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
