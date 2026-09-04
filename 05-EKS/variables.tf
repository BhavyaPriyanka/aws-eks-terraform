variable "aws_region" {
  description = "AWS region where infrastructure will be deployed"
  type        = string
  default     = "ap-south-1"
}

variable "common_tags" {
  default = {
    Project     = "localhelp"
    Environment = "dev"
    Terraform   = "true"
  }
}

variable "sg_tags" {
  default = {}
}

variable "project_name" {
  default = "localhelp"
}
variable "environment" {
  default = "dev"
}

variable "cluster_service_ipv4_cidr" {
  default = "10.100.0.0/16"
}