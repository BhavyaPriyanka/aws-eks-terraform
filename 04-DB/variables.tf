variable "project_name"{
    default = "localhelp"
}

variable "environment"{
    default = "dev"
}

variable "common_tags"{
    default = {
        Project = "localhelp"
        Environment = "dev"
        Terraform = "true"
    }
}

variable "zone_name"{
    default = "localhelp.store"
}

#localhelp-dev.cmfg0eig60hh.us-east-1.rds.amazonaws.com


