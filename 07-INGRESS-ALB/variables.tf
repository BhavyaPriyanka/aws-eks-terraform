variable "project_name" {
  default = "localhelp"
}

variable "environment" {
  default = "dev"
}

variable "common_tags" {
  default = {
    Project     = "localhelp"
    Environment = "dev"
    Terraform   = "true"
    Component   = "ingress-alb"
  }
}

variable "zone_name" {
  default = "localhelp.store"
}
