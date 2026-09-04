module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.project_name}-${var.environment}-bastion"

  instance_type           = "t3.micro"
  vpc_security_group_ids  = [data.aws_ssm_parameter.bastion_sg_id.value]
  subnet_id               = local.public_subnet_id
  ami                     = data.aws_ami.ami_info.id
  key_name                = aws_key_pair.bastion_key.key_name

  depends_on = [
    aws_key_pair.bastion_key,
    aws_ssm_parameter.bastion_private_key
  ]


  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-bastion"
    }

  )
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "${var.project_name}-${var.environment}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}