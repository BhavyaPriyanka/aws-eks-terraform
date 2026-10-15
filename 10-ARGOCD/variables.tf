variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  default = {
    Project     = "localhelp"
    Environment = "dev"
    Terraform   = "true"
  }
}



variable "project_name" {
  description = "Project name"
  type        = string
  default     = "localhelp"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

