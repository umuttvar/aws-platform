terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 6.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = {
      Project = "aws-platform"
      ManagedBy = "terraform"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "umuttvar-aws-platform-tfstate"
    key = "eks/terraform.tfstate"
    region = "eu-central-1"
  }
}

data "aws_eks_cluster" "main" {
    name = data.terraform_remote_state.eks.outputs.cluster_name

}

provider "helm" {
  kubernetes = {
    host = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.main.name, "--region", "eu-central-1"]
    }
    
  }
}