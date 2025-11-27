# Tokyo Region 배포 가이드

이 문서는 Tokyo 폴더의 코드를 AWS 도쿄 리전(ap-northeast-1)에 배포하기 위한 가이드입니다.

## 주요 변경 사항

### 1. 리전 설정
- **AWS Region**: `ap-northeast-2` (Seoul) → `ap-northeast-1` (Tokyo)
- **VPC CIDR**: `20.0.0.0/16` → `30.0.0.0/16` (Seoul과 충돌 방지)

### 2. Terraform 설정 변경

#### variables.tf
- 기본 리전: `ap-northeast-1`
- 프로젝트 이름: `tokyo-portal`
- 환경: `tokyo`

#### terraform.tfvars
- `vpc_cidr`: `30.0.0.0/16`
- `cognito_domain_prefix`: `corp-portal-tokyo-demo`
- `existing_rds_instance_identifier`: `aurora-global-tokyo-writer`

#### main.tf
- Backend S3 key: `tokyo/portal/terraform.tfstate`
- Backend region: `ap-northeast-1`
- 프로젝트 로컬 변수: `tokyo-portal`
- Cognito 리소스 이름: `aws_cognito_user_pool.tokyo`

### 3. Kubernetes 설정 변경

#### k8s/base/configmap.yaml
```yaml
DB_HOST: "aurora-global-tokyo-writer.cluster-xxxxxxxx.ap-northeast-1.rds.amazonaws.com"
COGNITO_REGION: "ap-northeast-1"
COGNITO_USER_POOL_ID: "ap-northeast-1_XXXXXXXXX"
COGNITO_CLIENT_ID: "XXXXXXXXXXXXXXXXXXXXXXXXXX"
```

#### k8s/base/deployment.yaml
```yaml
image: 299145660695.dkr.ecr.ap-northeast-1.amazonaws.com/tokyo-portal-tokyo-backend:latest
```

#### k8s/base/targetgroupbinding.yaml
```yaml
targetGroupARN: arn:aws:elasticloadbalancing:ap-northeast-1:299145660695:targetgroup/tokyo-portal-tokyo-tg/XXXXXXXXXXXXXXXX
```

### 4. Frontend 설정 변경

#### config.js
```javascript
API_BASE: window.ENV?.API_BASE || "https://your-api-id.execute-api.ap-northeast-1.amazonaws.com"
```

#### env.sh
- API Gateway URL: `ap-northeast-1` 리전으로 변경
- Cognito 설정: `ap-northeast-1` 리전으로 변경

#### Dockerrun.aws.json
```json
"Name": "299145660695.dkr.ecr.ap-northeast-1.amazonaws.com/tokyo-portal-tokyo-frontend:latest"
```

### 5. Backend 설정 변경

#### .env.example & .env.production
```env
AWS_REGION=ap-northeast-1
COGNITO_USER_POOL_ID=ap-northeast-1_XXXXXXXXX
DB_HOST=tokyo-portal-tokyo-db.xxxxxxxx.ap-northeast-1.rds.amazonaws.com
```

## 배포 전 필수 작업

### 1. Aurora Global Database 설정
Tokyo 리전에 Aurora Global Database의 세컨더리 클러스터를 생성하거나, 독립적인 Aurora 클러스터를 생성해야 합니다.

```bash
# Aurora Global Tokyo Writer 엔드포인트 확인 후
# terraform.tfvars의 existing_rds_instance_identifier 업데이트
existing_rds_instance_identifier = "aurora-global-tokyo-writer"
```

### 2. ECR Repository 생성
Tokyo 리전에 ECR 리포지토리를 생성합니다.

```bash
aws ecr create-repository \
  --repository-name tokyo-portal-tokyo-backend \
  --region ap-northeast-1

aws ecr create-repository \
  --repository-name tokyo-portal-tokyo-frontend \
  --region ap-northeast-1
```

### 3. Terraform Backend 설정
S3 버킷과 DynamoDB 테이블이 Tokyo 리전에 있는지 확인하거나, main.tf의 backend 설정을 적절히 수정합니다.

```terraform
# main.tf에서 주석 해제 후 설정
backend "s3" {
  bucket = "your-tfstate-bucket"
  key    = "tokyo/portal/terraform.tfstate"
  region = "ap-northeast-1"
}
```

### 4. VPC 및 네트워크 설정
새로운 VPC를 생성하거나 기존 VPC를 사용하도록 terraform.tfvars를 수정합니다.

```hcl
# 새 VPC 생성
vpc_id = ""
vpc_cidr = "30.0.0.0/16"

# 또는 기존 VPC 사용
vpc_id = "vpc-xxxxxxxxx"
private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
db_subnet_ids = ["subnet-aaaaa", "subnet-bbbbb"]
```

## 배포 순서

### 1. Terraform으로 인프라 배포

```bash
cd tokyo/infra/terraform

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 2. 배포 후 값 업데이트

Terraform 배포가 완료되면 다음 값들을 업데이트해야 합니다:

#### ConfigMap (k8s/base/configmap.yaml)
```bash
# Terraform output에서 값 가져오기
DB_HOST=$(terraform output -raw db_endpoint)
COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
COGNITO_CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)
```

#### TargetGroupBinding (k8s/base/targetgroupbinding.yaml)
```bash
# NLB Target Group ARN 업데이트
terraform output -raw nlb_target_group_arn
```

#### Frontend Config
```bash
# API Gateway URL 업데이트
terraform output -raw api_gateway_http_api_endpoint
```

### 3. Docker 이미지 빌드 및 푸시

```bash
# Backend
cd tokyo/backend
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin 299145660695.dkr.ecr.ap-northeast-1.amazonaws.com
docker build -t tokyo-portal-tokyo-backend .
docker tag tokyo-portal-tokyo-backend:latest 299145660695.dkr.ecr.ap-northeast-1.amazonaws.com/tokyo-portal-tokyo-backend:latest
docker push 299145660695.dkr.ecr.ap-northeast-1.amazonaws.com/tokyo-portal-tokyo-backend:latest

# Frontend
cd tokyo/frontend
docker build -t tokyo-portal-tokyo-frontend .
docker tag tokyo-portal-tokyo-frontend:latest 299145660695.dkr.ecr.ap-northeast-1.amazonaws.com/tokyo-portal-tokyo-frontend:latest
docker push 299145660695.dkr.ecr.ap-northeast-1.amazonaws.com/tokyo-portal-tokyo-frontend:latest
```

### 4. Kubernetes 배포

```bash
# EKS 클러스터 접근 설정
aws eks update-kubeconfig --name tokyo-portal-tokyo-cluster --region ap-northeast-1

# Kustomize로 배포
cd tokyo/k8s/overlays/prod
kubectl apply -k .

# 배포 확인
kubectl get pods
kubectl get svc
kubectl get targetgroupbindings
```

### 5. 데이터베이스 초기화

```bash
cd tokyo/scripts
.\init-database.ps1
```

## 검증 사항

### 1. 인프라 검증
- [ ] VPC 및 서브넷 생성 확인
- [ ] EKS 클러스터 정상 작동
- [ ] RDS 엔드포인트 접근 가능
- [ ] Cognito User Pool 생성 확인
- [ ] ECR 리포지토리 생성 확인

### 2. 애플리케이션 검증
- [ ] Backend Pod 정상 실행
- [ ] NLB Target Group 헬스 체크 통과
- [ ] API Gateway 엔드포인트 응답
- [ ] Frontend 배포 및 접근 가능
- [ ] Cognito 인증 정상 작동

### 3. 네트워크 검증
- [ ] EKS → RDS 연결
- [ ] API Gateway → NLB → EKS Backend 연결
- [ ] Frontend → API Gateway 연결
- [ ] Cognito 로그인/로그아웃 플로우

## 주의사항

1. **리전별 서비스 가용성**: Tokyo 리전에서 사용하려는 AWS 서비스들이 모두 지원되는지 확인하세요.

2. **비용**: 리전 간 데이터 전송 비용과 Global Database 비용을 고려하세요.

3. **레이턴시**: Tokyo 리전 사용자를 위한 최적화를 고려하세요.

4. **Aurora Global Database**: Seoul과 Tokyo 간 복제 지연을 모니터링하세요.

5. **Cognito 도메인**: Cognito 도메인 prefix는 AWS 계정 전체에서 유니크해야 합니다.

6. **ECR 리포지토리**: 각 리전마다 독립적인 ECR 리포지토리가 필요합니다.

## 트러블슈팅

### Terraform 배포 실패
- AWS 자격 증명 확인
- 리전별 서비스 쿼터 확인
- VPC CIDR 충돌 확인

### EKS Pod 시작 실패
- ECR 이미지 pull 권한 확인
- ConfigMap/Secret 값 확인
- RDS 보안 그룹 규칙 확인

### API 연결 실패
- NLB Target Group 헬스 체크 상태
- 보안 그룹 인바운드/아웃바운드 규칙
- API Gateway VPC Link 상태

## 추가 리소스

- [AWS Tokyo Region Services](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/)
- [Aurora Global Database Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [EKS Multi-Region Architecture](https://aws.amazon.com/blogs/containers/multi-region-amazon-eks/)
