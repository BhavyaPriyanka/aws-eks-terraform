module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.project_name}-${var.environment}"

  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  db_name  = "appdb" #default schema for localhelp app
  username = "root"
  port     = "3306"


  vpc_security_group_ids = [data.aws_ssm_parameter.db_sg_id.value]


  # DB subnet group
 db_subnet_group_name             = data.aws_ssm_parameter.db_subnet_group_name.value

  # DB parameter group
  family = "mysql8.0"

  # DB option group
  major_engine_version = "8.0"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}"
    }
  )
  manage_master_user_password = true
  #master_password = var.password
  skip_final_snapshot = true

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}

# create r53 record for rds endpoint


resource "aws_route53_record" "db" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "db-${var.environment}"
  type    = "CNAME"
  ttl     = 1

  records = [module.db.db_instance_address]


  depends_on = [module.db]
}