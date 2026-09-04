terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
  }

  backend "s3" {
    bucket         = "localhelp-remote-state"
    key            = "localhelp-dev-db"
    region         = "ap-south-1"
    dynamodb_table = "localhelp-locking"
  }
}

provider "aws" {
  region = var.aws_region
}