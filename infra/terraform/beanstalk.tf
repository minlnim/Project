# Elastic Beanstalk - 기존 Seoul 인프라의 Beanstalk 사용

# 기존 Beanstalk 정보는 remote state에서 직접 참조
# data source가 없으므로 outputs에서 가져옴

locals {
  # Seoul remote state의 Beanstalk 정보
  beanstalk_app_name  = data.terraform_remote_state.seoul.outputs.beanstalk_application_name
  beanstalk_env_name  = data.terraform_remote_state.seoul.outputs.beanstalk_environment_name
  beanstalk_cname     = data.terraform_remote_state.seoul.outputs.beanstalk_cname
  beanstalk_env_url   = data.terraform_remote_state.seoul.outputs.beanstalk_environment_url
}

# Outputs
output "beanstalk_environment_name" {
  description = "Beanstalk environment name"
  value       = local.beanstalk_env_name
}

output "beanstalk_environment_url" {
  description = "Beanstalk environment CNAME"
  value       = local.beanstalk_cname
}

output "beanstalk_application_name" {
  description = "Beanstalk application name"
  value       = local.beanstalk_app_name
}
