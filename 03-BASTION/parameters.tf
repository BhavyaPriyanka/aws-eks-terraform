resource "aws_ssm_parameter" "bastion_private_key" {
  name  = "/${var.project_name}/${var.environment}/bastion/private_key"
  type  = "SecureString"
  value = tls_private_key.bastion.private_key_pem
}