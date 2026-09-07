terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3.0"
    }
  }

  backend "s3" {
    bucket         = "localhelp-remote-tfstate"
    key            = "localhelp-dev-eks"
    region         = "us-east-1"
    dynamodb_table = "localhelp-locking"
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        "us-east-1"
      ]
    }
  }
}