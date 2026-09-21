resource "aws_key_pair" "eks" {
  key_name   = "eks"
  public_key = file("~/.ssh/eks.pub")
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = "1.32"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  authentication_mode = "API_AND_CONFIG_MAP"

  vpc_id                   = local.vpc_id
  subnet_ids               = split(",", local.private_subnet_ids)
  control_plane_subnet_ids = split(",", local.private_subnet_ids)

  create_cluster_security_group = false
  cluster_security_group_id     = local.cluster_sg_id

  create_node_security_group = false
  node_security_group_id     = local.node_sg_id

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
    vpc-cni                = {}
  }

  # -------------------------------------------------------
  # Managed Node Group Defaults
  # -------------------------------------------------------

  eks_managed_node_group_defaults = {
    instance_types = ["t3.small"]
  }

  # -------------------------------------------------------
  # Managed Node Groups
  # -------------------------------------------------------

  eks_managed_node_groups = {

    frontend = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      version        = "1.32"

      key_name = aws_key_pair.eks.key_name

      labels = {
        workload = "frontend"
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        # ElasticLoadBalancingFullAccess = "arn:aws:iam::aws:policy/service-role/ElasticLoadBalancingFullAccess"
      }
    }

    backend = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      version        = "1.32"

      key_name = aws_key_pair.eks.key_name

      labels = {
        workload = "backend"
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
        # ElasticLoadBalancingFullAccess = "arn:aws:iam::aws:policy/service-role/ElasticLoadBalancingFullAccess"
      }
    }

    #     database = {
    #       min_size     = 1
    #       max_size     = 3
    #       desired_size = 1

    #       instance_types = ["m6i.large"]
    #       capacity_type  = "ON_DEMAND"
    #       version        = "1.32"

    #       key_name = aws_key_pair.eks.key_name

    #       labels = {
    #         workload = "database"
    #       }

    #       iam_role_additional_policies = {
    #         AmazonEBSCSIDriverPolicy          = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    #         # AmazonElasticFileSystemFullAccess = "arn:aws:iam::aws:policy/service-role/AmazonElasticFileSystemFullAccess"
    #       }
    #     }

    #     monitoring = {
    #       min_size     = 1
    #       max_size     = 3
    #       desired_size = 1

    #       instance_types = ["m6i.large"]
    #       capacity_type  = "ON_DEMAND"
    #       version        = "1.32"

    #       key_name = aws_key_pair.eks.key_name

    #       labels = {
    #         workload = "monitoring"
    #       }

    #       iam_role_additional_policies = {
    #         AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    #       }
    #     }
    #   }
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

# =========================================================
# AWS Load Balancer Controller IAM Role
# =========================================================

module "load_balancer_controller_irsa_role" {

  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  version = "~> 5.0"

  role_name = "${var.project_name}-${var.environment}-load-balancer-controller"

  attach_load_balancer_controller_targetgroup_binding_only_policy = true

  oidc_providers = {

    main = {

      provider_arn = module.eks.oidc_provider_arn

      namespace_service_accounts = [
        "kube-system:aws-load-balancer-controller"
      ]
    }
  }
}


# =========================================================
# Bastion EKS Access Policy
# =========================================================

resource "aws_iam_policy" "bastion_eks_access" {
  name = "localhelp-dev-bastion-eks-access"

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

          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeLoadBalancers"
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