terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
  }

  backend "s3" {
    bucket         = "localhelp-remote-tfstate"
    key            = "localhelp-dev-argocd"
    region         = "us-east-1"
    dynamodb_table = "localhelp-locking"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "this" {
  name = "${var.project_name}-${var.environment}"
}

data "aws_eks_cluster_auth" "this" {
  name = data.aws_eks_cluster.this.name
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.this.endpoint

    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.this.certificate_authority[0].data
    )

    token = data.aws_eks_cluster_auth.this.token
  }
}