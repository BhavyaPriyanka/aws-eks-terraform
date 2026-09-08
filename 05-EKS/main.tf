resource "aws_key_pair" "eks" {
  key_name = "eks"

  public_key = file("~/.ssh/eks.pub")
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = "1.32"

  cluster_endpoint_public_access = true

  authentication_mode = "API_AND_CONFIG_MAP"

  vpc_id                   = local.vpc_id
  subnet_ids               = split(",", local.private_subnet_ids)
  control_plane_subnet_ids = split(",", local.private_subnet_ids)

  create_cluster_security_group = false
  cluster_security_group_id     = local.cluster_sg_id

  create_node_security_group = false
  node_security_group_id      = local.node_sg_id

  # Cluster creator gets admin access
  enable_cluster_creator_admin_permissions = true

  # -------------------------------------------------------
  # Bastion EKS Access
  # -------------------------------------------------------

  access_entries = {
    bastion = {
      principal_arn = "arn:aws:iam::837206354502:role/localhelp-dev-bastion-role"

      policy_associations = {
        bastion_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # -------------------------------------------------------
  # EKS Addons
  # -------------------------------------------------------

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                 = {}
  }

  # -------------------------------------------------------
  # Managed Node Group
  # -------------------------------------------------------

  eks_managed_node_group_defaults = {
    instance_types = [
      "m6i.large",
      "m5.large",
      "m5n.large",
      "m5zn.large"
    ]
  }

  eks_managed_node_groups = {
    blue = {
      min_size      = 2
      max_size      = 10
      desired_size  = 2
      version       = "1.32"
      capacity_type = "SPOT"

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"

        AmazonElasticFileSystemFullAccess = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"

        ElasticLoadBalancingFullAccess = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
      }

      key_name = aws_key_pair.eks.key_name
    }
  }

  tags = var.common_tags
}


# =========================================================
# Cluster Autoscaler IAM Policy
# =========================================================

resource "aws_iam_policy" "cluster_autoscaler" {

  name = "${var.project_name}-${var.environment}-cluster-autoscaler"

  description = "Permissions for Kubernetes Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup"
        ]

        Resource = "*"
      }
    ]
  })
}


# =========================================================
# Cluster Autoscaler IAM Role
# =========================================================

module "cluster_autoscaler_irsa_role" {

  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  version = "~> 5.0"

  role_name = "${var.project_name}-${var.environment}-cluster-autoscaler"

  role_policy_arns = {
    cluster_autoscaler = aws_iam_policy.cluster_autoscaler.arn
  }

  oidc_providers = {

    main = {

      provider_arn = module.eks.oidc_provider_arn

      namespace_service_accounts = [
        "kube-system:cluster-autoscaler"
      ]
    }
  }
}


# =========================================================
# Cluster Autoscaler Helm Release
# =========================================================

resource "helm_release" "cluster_autoscaler" {

  name      = "cluster-autoscaler"
  namespace = "kube-system"

  repository = "https://kubernetes.github.io/autoscaler"

  chart   = "cluster-autoscaler"
  version = "9.59.0"

  set = [

    {
      name  = "autoDiscovery.clusterName"
      value = "${var.project_name}-${var.environment}"
    },

    {
      name  = "awsRegion"
      value = "us-east-1"
    },

    {
      name  = "rbac.serviceAccount.create"
      value = "true"
    },

    {
      name  = "rbac.serviceAccount.name"
      value = "cluster-autoscaler"
    },

    {
      name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.cluster_autoscaler_irsa_role.iam_role_arn
    }
  ]

  depends_on = [
    module.eks
  ]
}

resource "aws_iam_policy" "bastion_eks_access" {
  name        = "${var.project_name}-${var.environment}-bastion-eks-access"
  description = "EKS API permissions for Bastion"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeAccessEntry",
          "eks:ListAccessEntries",
          "eks:ListAssociatedAccessPolicies",
          "eks:AccessKubernetesApi"
        ]

        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_eks_access" {
  role       = data.aws_iam_role.bastion.name
  policy_arn = aws_iam_policy.bastion_eks_access.arn
}