terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
  }

  backend "s3" {
    bucket         = "localhelp-remote-tfstate"
    key            = "localhelp-dev-sg"
    region         = "us-east-1"
    dynamodb_table = "localhelp-locking"
  }
}

provider "aws" {
  region = "us-east-1"
}