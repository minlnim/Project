terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # backend "s3" {
  #   bucket = "your-tfstate-bucket"
  #   key    = "seoul/portal/terraform.tfstate"
  #   region = "ap-northeast-2"
  # }
}

provider "aws" {
  region = var.aws_region
}

# Import CloudFront state
data "terraform_remote_state" "cloudfront" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/global-cloudfront/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Import Seoul state
data "terraform_remote_state" "seoul" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/seoul/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Import Tokyo state
data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = "terraform-s3-cheonsangyeon"
    key    = "terraform/tokyo/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project = "seoul-portal"
  env     = "seoul"

  tags = {
    Project = local.project
    Env     = local.env
  }

  # 기존 Seoul 인프라에서 VPC 및 서브넷 정보 가져오기
  vpc_id             = data.terraform_remote_state.seoul.outputs.seoul_vpc_id
  private_subnet_ids = data.terraform_remote_state.seoul.outputs.seoul_beanstalk_subnet_ids
  db_subnet_ids      = data.terraform_remote_state.seoul.outputs.seoul_beanstalk_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.seoul.outputs.seoul_beanstalk_subnet_ids  # ELB용
  
  # CloudFront 정보
  cloudfront_domain = try(data.terraform_remote_state.cloudfront.outputs.cloudfront_domain_name, "")
}

########################################
# 1. Cognito User Pool (Auth)
########################################

resource "aws_cognito_user_pool" "seoul" {
  name = "${local.project}-${local.env}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_uppercase = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = local.tags
}

resource "aws_cognito_user_pool_client" "seoul_spa" {
  name         = "${local.project}-${local.env}-spa-client"
  user_pool_id = aws_cognito_user_pool.seoul.id

  generate_secret = false

  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  supported_identity_providers = ["COGNITO"]

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]
}

resource "aws_cognito_user_pool_domain" "seoul" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.seoul.id
}

# Test users for development
resource "aws_cognito_user" "test_users" {
  for_each = var.test_users

  user_pool_id = aws_cognito_user_pool.seoul.id
  username     = each.value.email

  attributes = {
    email          = each.value.email
    email_verified = "true"
    name           = each.value.name
    family_name    = each.value.family_name
  }

  password = each.value.password

  lifecycle {
    ignore_changes = [
      password,
      attributes
    ]
  }
}

########################################
# 3. RDS (직원/공지/조직/결재 데이터)
########################################

resource "aws_db_subnet_group" "this" {
  name       = "${local.project}-${local.env}-db-subnet"
  subnet_ids = local.db_subnet_ids

  tags = local.tags
}

resource "aws_security_group" "rds" {
  name        = "${local.project}-${local.env}-rds-sg"
  description = "RDS security group for VPC internal access only"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_db_instance" "this" {
  identifier             = "${local.project}-${local.env}-db"
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  # NOTE: 학습/테스트 기본값입니다.
  # 운영 환경에서는 skip_final_snapshot = false, deletion_protection = true 설정을 권장합니다.
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true
  deletion_protection        = false

  tags = local.tags
}

########################################
# 4. ECR (백엔드 컨테이너 이미지)
########################################

resource "aws_ecr_repository" "backend" {
  name                 = "${local.project}-${local.env}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_repository" "frontend" {
  name                 = "${local.project}-${local.env}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = local.tags
}

########################################
# 5. NLB (Backend Entry for API GW → EKS)
########################################

resource "aws_security_group" "vpc_link" {
  name        = "${local.project}-${local.env}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = var.backend_port
    to_port     = var.backend_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "seoul-vpc-link-sg"
  })
}

resource "aws_lb" "nlb" {
  name               = "${local.project}-${local.env}-nlb"
  load_balancer_type = "network"
  internal           = true
  subnets            = local.private_subnet_ids

  tags = local.tags
}

resource "aws_lb_target_group" "backend" {
  name        = "${local.project}-${local.env}-tg"
  port        = var.backend_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }

  tags = local.tags
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.backend_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

########################################
# 6. API Gateway HTTP API + VPC Link + JWT Authorizer
########################################

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${local.project}-${local.env}-vpc-link"
  subnet_ids         = local.private_subnet_ids
  security_group_ids = [aws_security_group.vpc_link.id]

  tags = local.tags
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.project}-${local.env}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "http://localhost:3000",
      "http://seoul-webapp-env.eba-ccpra5ej.ap-northeast-2.elasticbeanstalk.com",
      "http://seoul-portal-seoul-frontend-env.eba-npadbvru.ap-northeast-2.elasticbeanstalk.com",
      "https://d28e0o760kyoll.cloudfront.net",
      "https://dj5k42sej4rz6.cloudfront.net"
    ]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
    expose_headers = ["*"]
    max_age = 300
  }

  tags = local.tags
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id          = aws_apigatewayv2_api.http_api.id
  authorizer_type = "JWT"
  name            = "cognito-jwt-authorizer"

  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer = "https://cognito-idp.ap-northeast-2.amazonaws.com/${aws_cognito_user_pool.seoul.id}"
    audience = [
      aws_cognito_user_pool_client.seoul_spa.id
    ]
  }
}

resource "aws_apigatewayv2_integration" "backend" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"

  # NLB Listener ARN 사용 (VPC Link 연결)
  integration_uri = aws_lb_listener.backend.arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.this.id

  payload_format_version = "1.0"
}

# 1) 로그인 엔드포인트: POST /auth/login (무인증)
resource "aws_apigatewayv2_route" "auth_login" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /auth/login"

  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "NONE"
}

# 2) 보호된 API: ANY /api/{proxy+} (JWT 필요)
resource "aws_apigatewayv2_route" "api_proxy" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /api/{proxy+}"

  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = local.tags
}
