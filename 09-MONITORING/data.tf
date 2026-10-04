data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket         = "localhelp-remote-tfstate"
    key            = "localhelp-dev-eks"
    region         = "us-east-1"
    dynamodb_table = "localhelp-locking"
  }
}