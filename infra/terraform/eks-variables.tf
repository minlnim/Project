########################################
# EKS Variables
########################################

variable "eks_cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS managed node group"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in EKS managed node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in EKS managed node group"
  type        = number
  default     = 4
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in EKS managed node group"
  type        = number
  default     = 2
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks that can access the EKS public endpoint"
  type        = list(string)
  # NOTE: 학습/테스트 환경 기본값입니다. 운영 환경에서는 회사 VPN/사설망 IP만 허용하는 것을 권장합니다.
  default = ["0.0.0.0/0"]
}

# ===== Project Settings =====

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "seoul-portal"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "seoul"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

# ===== Elastic Beanstalk Variables =====

variable "beanstalk_instance_type" {
  description = "Instance type for Beanstalk frontend"
  type        = string
  default     = "t3.micro"
}

variable "beanstalk_min_instances" {
  description = "Minimum number of instances for Beanstalk Auto Scaling"
  type        = number
  default     = 1
}

variable "beanstalk_max_instances" {
  description = "Maximum number of instances for Beanstalk Auto Scaling"
  type        = number
  default     = 4
}

