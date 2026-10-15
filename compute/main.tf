data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "umuttvar-aws-platform-tfstate"
    key    = "network/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "terraform_remote_state" "registry" {
  backend = "s3"
  config = {
    bucket = "umuttvar-aws-platform-tfstate"
    key    = "registry/terraform.tfstate"
    region = "eu-central-1"
  }
}

locals {
  ecr_repo  = data.terraform_remote_state.registry.outputs.repository_url
  ecr_host  = split("/", local.ecr_repo)[0]
  image_tag = var.image_tag
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
  security_group_id            = aws_security_group.web.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.web.name
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    dnf install -y docker
    systemctl enable --now docker
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${local.ecr_host}
    docker run -d --restart always -p 80:8000 ${local.ecr_repo}:${local.image_tag}
  EOF

  tags = {
    Name = "aws-platform-web"
  }
}

resource "aws_iam_role" "web" {
  name = "aws-platform-web"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "web" {
  name = "aws-platform-web"
  role = aws_iam_role.web.name

}


