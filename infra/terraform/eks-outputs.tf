########################################
# EKS Outputs
########################################

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_cluster_oidc_issuer" {
  description = "EKS cluster OIDC issuer URL (for IRSA)"
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_node_group_role_arn" {
  description = "Default EKS managed node group IAM role ARN"
  value       = try(module.eks.eks_managed_node_groups["default"].iam_role_arn, null)
}
