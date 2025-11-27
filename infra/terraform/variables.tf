########################################
# Seoul Portal – Variables
########################################

# ===== 기본 설정 =====

variable "aws_region" {
  description = "AWS Region for deployment"
  type        = string
  default     = "ap-northeast-2"
}

# ===== 네트워크 =====

variable "vpc_id" {
  description = "Seoul AWS VPC ID (빈 문자열이면 새로 생성)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "Seoul AWS VPC CIDR (예: 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_ids" {
  description = "Backend/NLB/EKS가 위치한 Private Subnet IDs (VPC를 새로 생성하면 무시됨)"
  type        = list(string)
  default     = []
}

variable "db_subnet_ids" {
  description = "RDS용 Subnet Group에 사용할 Subnet IDs (VPC를 새로 생성하면 무시됨)"
  type        = list(string)
  default     = []
}

# ===== Cognito =====

variable "cognito_domain_prefix" {
  description = "Cognito Hosted UI 도메인 prefix (전 계정 내 유니크, 예: corp-portal-seoul)"
  type        = string
}

variable "cognito_callback_urls" {
  description = "로그인 후 리다이렉트 URL 목록 (예: https://portal.example.com/callback )"
  type        = list(string)
}

variable "cognito_logout_urls" {
  description = "로그아웃 후 이동할 URL 목록"
  type        = list(string)
}

variable "test_users" {
  description = "테스트 사용자 목록 (Cognito 및 조직도 데이터)"
  type = map(object({
    email       = string
    password    = string
    name        = string
    family_name = string
    department  = string
    position    = string
    phone       = string
  }))
  default = {}
}

# ===== Backend / RDS =====

variable "backend_port" {
  description = "EKS Backend Service가 리스닝하는 포트 (예: 8080)"
  type        = number
  default     = 8080
}

variable "db_engine" {
  description = "RDS 엔진 (예: postgres, mysql)"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "RDS 엔진 버전 (예: 14.11)"
  type        = string
  default     = "14.11"
}

variable "db_instance_class" {
  description = "RDS 인스턴스 타입"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS 스토리지(GB)"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "RDS DB 유저 이름"
  type        = string
  default     = "portaluser"
}

variable "db_password" {
  description = "RDS DB 유저 비밀번호"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "RDS DB 이름"
  type        = string
  default     = "corpportal"
}

variable "db_port" {
  description = "RDS DB 포트 (Postgres=5432, MySQL=3306)"
  type        = number
  default     = 5432
}

# ===== ArgoCD =====

variable "enable_argocd" {
  description = "ArgoCD 설치 여부 (EKS 클러스터 생성 후 true로 변경)"
  type        = bool
  default     = false
}

variable "argocd_domain" {
  description = "ArgoCD 접근 도메인 (예: argocd.example.com)"
  type        = string
  default     = ""
}

variable "argocd_repo_url" {
  description = "ArgoCD가 모니터링할 Git Repository URL"
  type        = string
  default     = ""
}

variable "argocd_repo_branch" {
  description = "ArgoCD가 모니터링할 Git Branch"
  type        = string
  default     = "main"
}

variable "argocd_backend_path" {
  description = "Backend Kubernetes 매니페스트가 있는 경로 (예: k8s)"
  type        = string
  default     = "k8s"
}

variable "argocd_repo_username" {
  description = "Private Repository 접근용 Username (Public Repo는 비워두기)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "argocd_repo_password" {
  description = "Private Repository 접근용 Password or Token"
  type        = string
  default     = ""
  sensitive   = true
}

# ===== CloudFront =====

variable "existing_cloudfront_id" {
  description = "기존에 생성된 CloudFront Distribution ID (빈 문자열이면 새로 생성)"
  type        = string
  default     = ""
}
