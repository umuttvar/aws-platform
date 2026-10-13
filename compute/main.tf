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

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.web.name
  user_data_replace_on_change = true
  user_data = <<-EOF
	 #!/bin/bash
	 dnf install -y docker
	 systemctl enable --now docker
	 docker run -d --restart always -p 80:8000 ghcr.io/umuttvar/demo-app:1.0.37
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
  role = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "aws-platform-web"
  role = aws_iam_role.web.name
  
}


