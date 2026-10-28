data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket         = "localhelp-remote-tfstate"
    key            = "localhelp-dev-eks"
    region         = "us-east-1"
    dynamodb_table = "localhelp-locking"
  }
}

data "terraform_remote_state" "ingress" {
  backend = "s3"

  config = {
    bucket = "localhelp-remote-tfstate"
    key    = "localhelp-dev-ingress-alb"
    region = "us-east-1"
  }
}