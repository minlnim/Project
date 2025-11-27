# Elastic Beanstalk - Tokyo 리전 독립 Beanstalk 환경

# Tokyo 리전에 독립적인 Beanstalk 환경 생성 필요
# 실제 배포 시 별도의 Beanstalk 리소스를 생성하거나
# 기존 리소스를 참조하도록 구성

# 참고: Tokyo 리전에 별도 Beanstalk 환경을 구성하려면
# 아래 주석을 해제하고 리소스를 정의하세요

# locals {
#   beanstalk_app_name  = "${local.project}-${local.env}-app"
#   beanstalk_env_name  = "${local.project}-${local.env}-env"
# }

# Outputs (Tokyo Beanstalk 배포 후 업데이트 필요)
# output "beanstalk_environment_name" {
#   description = "Beanstalk environment name"
#   value       = "tokyo-beanstalk-env"
# }

# output "beanstalk_environment_url" {
#   description = "Beanstalk environment CNAME"
#   value       = "tokyo-webapp.ap-northeast-1.elasticbeanstalk.com"
# }

# output "beanstalk_application_name" {
#   description = "Beanstalk application name"
#   value       = "tokyo-portal-app"
# }
