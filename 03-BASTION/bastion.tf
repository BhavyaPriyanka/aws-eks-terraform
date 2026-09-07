# ---------------------------------------------------------
# Bastion EC2 Instance
# ---------------------------------------------------------

module "bastion" {

  source = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.project_name}-${var.environment}-bastion"

  instance_type = "t3.micro"

  vpc_security_group_ids = [
    data.aws_ssm_parameter.bastion_sg_id.value
  ]

  subnet_id = local.public_subnet_id

  ami = data.aws_ami.ami_info.id

  # IAM Instance Profile
  iam_instance_profile = aws_iam_instance_profile.bastion.name

  # Bastion setup script
  user_data = file("bastion.sh")

  user_data_replace_on_change = true

  # SSH Key
  key_name = aws_key_pair.bastion_key.key_name

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


# ---------------------------------------------------------
# IAM Role for Bastion
# ---------------------------------------------------------

resource "aws_iam_role" "bastion" {

  name = "${var.project_name}-${var.environment}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}


# ---------------------------------------------------------
# EKS Permissions for Bastion
# ---------------------------------------------------------

resource "aws_iam_role_policy" "bastion_eks" {

  name = "${var.project_name}-${var.environment}-bastion-eks-policy"

  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]

        Resource = "*"
      }
    ]
  })
}


# ---------------------------------------------------------
# IAM Instance Profile
# ---------------------------------------------------------

resource "aws_iam_instance_profile" "bastion" {

  name = "${var.project_name}-${var.environment}-bastion-profile"

  role = aws_iam_role.bastion.name

  tags = var.common_tags
}


# ---------------------------------------------------------
# Bastion SSH Private Key
# ---------------------------------------------------------

resource "tls_private_key" "bastion" {

  algorithm = "RSA"

  rsa_bits = 4096
}


# ---------------------------------------------------------
# Bastion SSH Key Pair
# ---------------------------------------------------------

resource "aws_key_pair" "bastion_key" {

  key_name = "${var.project_name}-${var.environment}-bastion-key"

  public_key = tls_private_key.bastion.public_key_openssh
}