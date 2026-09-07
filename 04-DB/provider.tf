terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37.0"
    }
  }

  backend "s3" {
    bucket         = "localhelp-remote-tfstate"
    key            = "localhelp-dev-db"
    region         = "us-east-1"
    dynamodb_table = "localhelp-locking"
  }
}

provider "aws" {
  region = "us-east-1"
}