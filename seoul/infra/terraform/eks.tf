########################################
# EKS Cluster (Terraform AWS Modules)
########################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.project}-${local.env}-eks"
  cluster_version = var.eks_cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # API 서버 Public/Private 접근
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs

  # 기본 애드온
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Managed Node Group
  eks_managed_node_groups = {
    default = {
      min_size     = var.eks_node_min_size
      max_size     = var.eks_node_max_size
      desired_size = var.eks_node_desired_size

      instance_types = [var.eks_node_instance_type]
      capacity_type  = "ON_DEMAND"

      labels = {
        "role" = "backend"
      }
    }
  }

  enable_irsa = true

  # EKS Access Entry - 현재 사용자에게 관리자 권한 부여
  enable_cluster_creator_admin_permissions = true

  tags = local.tags
}

# Allow NLB to access NodePort range on EKS nodes
resource "aws_security_group_rule" "node_nlb_ingress" {
  description       = "Allow NLB to access NodePort range"
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.node_security_group_id
}
