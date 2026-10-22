data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project_name}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "jenkins_agent_sg_id" {
  name = "/${var.project_name}/${var.environment}/tools_sg_id"
}