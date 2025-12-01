# 시스템 배포 가이드

## 📋 배포 순서 개요

```
1. 사전 준비 (Prerequisites)
   ↓
2. Seoul Region 인프라 배포 (Terraform)
   ↓
3. Seoul Region 애플리케이션 배포 (GitOps)
   ↓
4. Tokyo Region 인프라 배포 (Terraform)
   ↓
5. Tokyo Region 애플리케이션 배포 (GitOps)
   ↓
6. 검증 및 모니터링
```

---

## 1️⃣ 사전 준비 (Prerequisites)

### 1.1 필수 도구 설치
```powershell
# AWS CLI
winget install Amazon.AWSCLI

# Terraform
winget install Hashicorp.Terraform

# kubectl
winget install Kubernetes.kubectl

# Docker Desktop
winget install Docker.DockerDesktop

# Helm
winget install Helm.Helm

# ArgoCD CLI (선택사항)
choco install argocd-cli
```

### 1.2 AWS 계정 설정
```powershell
# AWS 자격 증명 구성
aws configure

# 입력 필요 정보:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: ap-northeast-2 (Seoul)
# - Default output format: json
```

### 1.3 GitHub 설정
```powershell
# GitHub Personal Access Token 생성 (필요한 권한: repo, workflow)
# Settings → Developer settings → Personal access tokens → Generate new token

# 환경 변수 설정
$env:GITHUB_TOKEN = "your-github-token"
```

---

## 2️⃣ Seoul Region 인프라 배포

### 2.1 Terraform 변수 설정
```powershell
cd seoul\infra\terraform

# terraform.tfvars 파일 수정
notepad terraform.tfvars
```

**필수 변경 사항:**
```hcl
# terraform.tfvars
aws_region          = "ap-northeast-2"
vpc_cidr            = "20.0.0.0/16"
project_name        = "portal-seoul"
environment         = "production"

# RDS 설정
db_username         = "admin"
db_password         = "your-secure-password"  # 실제 비밀번호로 변경

# Cognito 설정
cognito_domain      = "your-unique-domain"    # 고유한 도메인으로 변경

# 도메인 설정
domain_name         = "your-domain.com"       # 실제 도메인으로 변경
```

### 2.2 Terraform 초기화 및 검증
```powershell
# Terraform 초기화
terraform init

# Terraform 플랜 확인
terraform plan

# 예상 리소스 확인:
# - VPC, Subnets, Route Tables
# - EKS Cluster (1.29)
# - RDS Aurora PostgreSQL
# - Elastic Beanstalk
# - Cognito UserPool
# - Lambda (DB Init)
# - ECR Repositories
# - ArgoCD (Helm Release)
```

### 2.3 인프라 배포 실행
```powershell
# Terraform 적용 (약 20-30분 소요)
terraform apply

# 확인 후 'yes' 입력
```

### 2.4 AWS 계정 ID 확인 및 ECR 로그인
```powershell
# AWS 계정 ID 확인
aws sts get-caller-identity --query Account --output text
# 출력 예: 123456789012

# ECR 로그인 (Seoul) - Terraform으로 ECR이 생성된 후 실행
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 성공 시 출력: Login Succeeded
```

> **⚠️ 중요**: ECR 레포지토리가 Terraform으로 생성된 후에만 로그인이 가능합니다!

### 2.5 EKS 클러스터 접근 설정
```powershell
# kubeconfig 업데이트
aws eks update-kubeconfig --region ap-northeast-2 --name portal-seoul-eks

# 클러스터 연결 확인
kubectl get nodes

# 네임스페이스 확인
kubectl get namespaces

# ArgoCD 설치 확인
kubectl get pods -n argocd
```

### 2.6 ArgoCD 초기 비밀번호 확인
```powershell
# ArgoCD admin 비밀번호 가져오기
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# ArgoCD UI 접근 (포트 포워딩)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 브라우저에서 https://localhost:8080 접속
# Username: admin
# Password: 위에서 가져온 비밀번호
```

### 2.7 Lambda DB 초기화 확인
```powershell
# Lambda 함수 실행 로그 확인
aws logs tail /aws/lambda/portal-seoul-db-init --region ap-northeast-2 --follow
```

---

## 3️⃣ Seoul Region 애플리케이션 배포

### 3.1 Docker 이미지 빌드 (Backend)
```powershell
cd seoul\backend

# 이미지 빌드
docker build -t portal-backend:v1.0.0 .

# ECR에 태그 (2.4단계에서 확인한 account-id 사용)
docker tag portal-backend:v1.0.0 <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/portal-backend:v1.0.0

# ECR에 푸시
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/portal-backend:v1.0.0
```

> **💡 참고**: 2.4단계에서 이미 ECR 로그인을 완료했으므로 바로 push 가능합니다.

### 3.2 Kustomize 매니페스트 업데이트
```powershell
cd seoul\k8s\overlays\prod

# Kustomize로 이미지 태그 업데이트
kustomize edit set image backend-app=<account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/portal-backend:v1.0.0

# 변경사항 커밋
git add kustomization.yaml
git commit -m "chore: Update backend image tag to v1.0.0 [skip ci]"
git push origin main
```

### 3.3 ArgoCD 애플리케이션 동기화 확인
```powershell
# ArgoCD 애플리케이션 상태 확인
kubectl get applications -n argocd

# 자동 동기화 대기 (약 3분) 또는 수동 동기화
argocd app sync portal-backend --port-forward

# 배포된 리소스 확인
kubectl get all -n production
```

### 3.4 Frontend (Elastic Beanstalk) 배포
```powershell
cd seoul\frontend

# Elastic Beanstalk CLI 설치 (필요시)
pip install awsebcli

# EB 초기화
eb init

# 환경 선택: portal-seoul-beanstalk-env

# 애플리케이션 배포
eb deploy

# 상태 확인
eb status
```

### 3.5 CloudFront 배포 확인
```powershell
# CloudFront 배포 상태 확인
aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='Portal Seoul'].{Id:Id,DomainName:DomainName,Status:Status}" --region ap-northeast-2
```

---

## 4️⃣ Tokyo Region 인프라 배포

### 4.1 Terraform 변수 설정
```powershell
cd tokyo\infra\terraform

# terraform.tfvars 파일 수정
notepad terraform.tfvars
```

**필수 변경 사항:**
```hcl
# terraform.tfvars
aws_region          = "ap-northeast-1"
vpc_cidr            = "30.0.0.0/16"
project_name        = "portal-tokyo"
environment         = "production"

# RDS 설정 (Seoul과 동일하거나 다른 비밀번호)
db_username         = "admin"
db_password         = "your-secure-password"

# Cognito 설정
cognito_domain      = "your-unique-domain-tokyo"

# 도메인 설정
domain_name         = "tokyo.your-domain.com"
```

### 4.2 Terraform 배포
```powershell
# Terraform 초기화
terraform init

# Terraform 플랜 확인
terraform plan

# Terraform 적용 (약 20-30분 소요)
terraform apply
```

### 4.3 AWS 계정 ID 확인 및 ECR 로그인 (Tokyo)
```powershell
# ECR 로그인 (Tokyo) - Terraform으로 ECR이 생성된 후 실행
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com

# 성공 시 출력: Login Succeeded
```

### 4.4 EKS 클러스터 접근 설정
```powershell
# kubeconfig 업데이트 (Tokyo)
aws eks update-kubeconfig --region ap-northeast-1 --name portal-tokyo-eks

# 클러스터 연결 확인
kubectl get nodes

# ArgoCD 설치 확인
kubectl get pods -n argocd
```

### 4.5 ArgoCD 초기 설정 (Tokyo)
```powershell
# ArgoCD admin 비밀번호 가져오기
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# ArgoCD UI 접근
kubectl port-forward svc/argocd-server -n argocd 8081:443

# 브라우저에서 https://localhost:8081 접속
```

---

## 5️⃣ Tokyo Region 애플리케이션 배포

### 5.1 Docker 이미지 빌드 (Backend)
```powershell
cd tokyo\backend

# 이미지 빌드
docker build -t portal-backend-tokyo:v1.0.0 .

# ECR에 태그 (Tokyo)
docker tag portal-backend-tokyo:v1.0.0 <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/portal-backend:v1.0.0

# ECR에 푸시
docker push <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/portal-backend:v1.0.0
```

### 5.2 Kustomize 매니페스트 업데이트 (Tokyo)
```powershell
cd tokyo\k8s\overlays\prod

# Kustomize로 이미지 태그 업데이트
kustomize edit set image backend-app=<account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/portal-backend:v1.0.0

# 변경사항 커밋
git add kustomization.yaml
git commit -m "chore: Update Tokyo backend image tag to v1.0.0 [skip ci]"
git push origin main
```

### 5.3 ArgoCD 애플리케이션 동기화 (Tokyo)
```powershell
# Tokyo EKS 컨텍스트로 전환
kubectl config use-context arn:aws:eks:ap-northeast-1:<account-id>:cluster/portal-tokyo-eks

# ArgoCD 애플리케이션 확인
kubectl get applications -n argocd

# 동기화 확인
kubectl get all -n production
```

### 5.4 Frontend 배포 (Tokyo)
```powershell
cd tokyo\frontend

# EB 초기화
eb init

# 애플리케이션 배포
eb deploy

# 상태 확인
eb status
```

---

## 6️⃣ 검증 및 모니터링

### 6.1 전체 시스템 헬스 체크

#### Seoul Region
```powershell
# EKS 클러스터
kubectl config use-context arn:aws:eks:ap-northeast-2:<account-id>:cluster/portal-seoul-eks
kubectl get nodes
kubectl get pods -n production
kubectl top nodes
kubectl top pods -n production

# RDS Aurora
aws rds describe-db-clusters --db-cluster-identifier portal-seoul-aurora --region ap-northeast-2 --query "DBClusters[0].Status"

# Elastic Beanstalk
aws elasticbeanstalk describe-environment-health --environment-name portal-seoul-beanstalk-env --attribute-names All --region ap-northeast-2

# Lambda
aws lambda get-function --function-name portal-seoul-db-init --region ap-northeast-2

# ArgoCD 애플리케이션 상태
kubectl get applications -n argocd
```

#### Tokyo Region
```powershell
# EKS 클러스터
kubectl config use-context arn:aws:eks:ap-northeast-1:<account-id>:cluster/portal-tokyo-eks
kubectl get nodes
kubectl get pods -n production

# RDS Aurora
aws rds describe-db-clusters --db-cluster-identifier portal-tokyo-aurora --region ap-northeast-1 --query "DBClusters[0].Status"

# Elastic Beanstalk
aws elasticbeanstalk describe-environment-health --environment-name portal-tokyo-beanstalk-env --attribute-names All --region ap-northeast-1
```

### 6.2 엔드포인트 테스트

#### Seoul
```powershell
# CloudFront 엔드포인트
curl https://<cloudfront-domain>.cloudfront.net

# API Gateway 엔드포인트
curl https://<api-gateway-id>.execute-api.ap-northeast-2.amazonaws.com/prod/health

# Beanstalk 엔드포인트
curl http://<beanstalk-env>.ap-northeast-2.elasticbeanstalk.com
```

#### Tokyo
```powershell
# CloudFront 엔드포인트
curl https://<cloudfront-domain-tokyo>.cloudfront.net

# API Gateway 엔드포인트
curl https://<api-gateway-id-tokyo>.execute-api.ap-northeast-1.amazonaws.com/prod/health
```

### 6.3 로그 모니터링

#### CloudWatch Logs
```powershell
# Lambda 로그 (Seoul)
aws logs tail /aws/lambda/portal-seoul-db-init --region ap-northeast-2 --follow

# Beanstalk 로그 (Seoul)
eb logs --region ap-northeast-2

# EKS 로그 (Seoul - kubectl 사용)
kubectl logs -f deployment/backend -n production
```

#### ArgoCD 로그
```powershell
# ArgoCD 애플리케이션 로그
kubectl logs -f deployment/argocd-application-controller -n argocd
kubectl logs -f deployment/argocd-server -n argocd
```

### 6.4 GitHub Actions 워크플로우 확인
```powershell
# GitHub Actions 상태 확인
# 브라우저에서 접속: https://github.com/<username>/<repo>/actions

# 최근 워크플로우 실행 확인
# - Seoul Backend CD
# - Tokyo Backend CD
# - 모든 워크플로우가 성공 상태인지 확인
```

---

## 🔄 지속적 배포 (CI/CD)

### 자동 배포 프로세스

#### 1. 코드 변경 및 푸시
```powershell
# 코드 수정 후
git add .
git commit -m "feat: Add new feature"
git push origin main
```

#### 2. GitHub Actions 자동 실행
- Docker 이미지 빌드
- ECR에 이미지 푸시
- Kustomize 매니페스트 업데이트
- Git 커밋 (이미지 태그 업데이트)

#### 3. ArgoCD 자동 동기화 (3분 이내)
- Git 레포지토리 변경 감지
- Kustomize 빌드
- Kubernetes 리소스 업데이트
- 롤링 업데이트 실행

#### 4. 배포 확인
```powershell
# ArgoCD UI에서 확인
# 또는 kubectl로 확인
kubectl rollout status deployment/backend -n production
```

---

## 🚨 롤백 절차

### ArgoCD를 통한 롤백
```powershell
# 이전 버전으로 롤백
argocd app rollback portal-backend <revision-number>

# 또는 kubectl로 롤백
kubectl rollout undo deployment/backend -n production

# 롤백 상태 확인
kubectl rollout status deployment/backend -n production
```

### Terraform 리소스 롤백
```powershell
cd seoul\infra\terraform

# 이전 상태로 복원
terraform state pull > backup.tfstate
terraform apply -state=backup.tfstate
```

---

## 📊 모니터링 대시보드

### ArgoCD UI
- URL: `https://localhost:8080` (포트 포워딩)
- Username: `admin`
- 애플리케이션 상태, 동기화 이력, 리소스 트리 확인

### Kubernetes Dashboard (선택사항)
```powershell
# Dashboard 설치
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# 토큰 생성
kubectl -n kubernetes-dashboard create token admin-user

# 포트 포워딩
kubectl proxy

# 브라우저 접속: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### CloudWatch Dashboards
- AWS Console → CloudWatch → Dashboards
- EKS, RDS, Lambda, Beanstalk 메트릭 확인

---

## 🛠️ 트러블슈팅

### EKS 클러스터 접근 불가
```powershell
# kubeconfig 재설정
aws eks update-kubeconfig --region ap-northeast-2 --name portal-seoul-eks --kubeconfig ~/.kube/config

# IAM 권한 확인
aws sts get-caller-identity
```

### ArgoCD 동기화 실패
```powershell
# ArgoCD 로그 확인
kubectl logs -f deployment/argocd-application-controller -n argocd

# 수동 동기화 시도
argocd app sync portal-backend --force

# Git 레포지토리 연결 확인
argocd repo list
```

### Docker 이미지 푸시 실패
```powershell
# ECR 로그인 재시도
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# ECR 레포지토리 확인
aws ecr describe-repositories --region ap-northeast-2
```

### RDS 연결 실패
```powershell
# Security Group 확인
aws ec2 describe-security-groups --filters "Name=group-name,Values=portal-seoul-rds-sg" --region ap-northeast-2

# RDS 엔드포인트 확인
aws rds describe-db-clusters --db-cluster-identifier portal-seoul-aurora --region ap-northeast-2 --query "DBClusters[0].Endpoint"
```

---

## 🔐 보안 체크리스트

- [ ] AWS IAM 최소 권한 원칙 적용
- [ ] RDS 비밀번호 안전하게 관리 (AWS Secrets Manager 사용 권장)
- [ ] Cognito UserPool MFA 활성화
- [ ] Security Group 규칙 최소화
- [ ] CloudFront HTTPS 강제
- [ ] WAF 규칙 설정
- [ ] VPC Flow Logs 활성화
- [ ] CloudTrail 로깅 활성화
- [ ] ECR 이미지 스캔 활성화
- [ ] Kubernetes RBAC 설정

---

## 📝 배포 후 확인사항

### Seoul Region
- [ ] EKS 클러스터 정상 작동 (노드 Ready)
- [ ] ArgoCD 설치 및 애플리케이션 동기화 완료
- [ ] Backend Pods 실행 중 (HPA 작동)
- [ ] RDS Aurora 연결 가능
- [ ] Lambda DB 초기화 완료
- [ ] Elastic Beanstalk 환경 정상
- [ ] CloudFront 배포 완료
- [ ] Route 53 DNS 설정 완료
- [ ] Cognito UserPool 생성 완료

### Tokyo Region
- [ ] 위와 동일한 체크리스트 확인

### CI/CD
- [ ] GitHub Actions 워크플로우 성공
- [ ] ArgoCD 자동 동기화 작동
- [ ] Docker 이미지 ECR 푸시 성공
- [ ] Kustomize 매니페스트 업데이트 자동화

---

## 📞 지원 및 문서

- **AWS 문서**: https://docs.aws.amazon.com/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **ArgoCD 문서**: https://argo-cd.readthedocs.io/
- **Kustomize 문서**: https://kustomize.io/
- **Kubernetes 문서**: https://kubernetes.io/docs/

---

## ⏱️ 예상 배포 시간

| 단계 | 예상 시간 |
|------|----------|
| 사전 준비 | 30분 |
| Seoul 인프라 배포 | 25-30분 |
| Seoul 애플리케이션 배포 | 10-15분 |
| Tokyo 인프라 배포 | 25-30분 |
| Tokyo 애플리케이션 배포 | 10-15분 |
| 검증 및 테스트 | 20분 |
| **전체 배포 시간** | **약 2-3시간** |

---

## 🎯 배포 완료 후 다음 단계

1. **부하 테스트**: Apache JMeter, Locust 등으로 부하 테스트
2. **모니터링 설정**: Prometheus + Grafana 설치
3. **알림 설정**: CloudWatch Alarms, SNS 토픽 구성
4. **백업 전략**: RDS 자동 백업, EBS 스냅샷 정책
5. **DR 계획**: 재해 복구 시나리오 수립
6. **보안 감사**: AWS Security Hub, GuardDuty 활성화
7. **비용 최적화**: Cost Explorer, Trusted Advisor 검토

---

**작성일**: 2025-12-01  
**버전**: 1.0.0  
**Region**: Seoul (ap-northeast-2), Tokyo (ap-northeast-1)
