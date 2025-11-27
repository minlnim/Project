# Seoul Portal Project

> GitOps 기반 EKS + ArgoCD 자동 배포 시스템

## 📋 목차

- [아키텍처 개요](#-아키텍처-개요)
- [프로젝트 구조](#-프로젝트-구조)
- [시작하기](#-시작하기)
- [배포 프로세스](#-배포-프로세스)
- [GitOps 워크플로우](#-gitops-워크플로우)
- [인프라 관리](#-인프라-관리)
- [트러블슈팅](#-트러블슈팅)
- [비용 최적화](#-비용-최적화)

---

## 🏗️ 아키텍처 개요

### 전체 시스템 구조

```
                    ┌──────────────────┐
                    │   CloudFront     │  (CDN)
                    │  (Global Edge)   │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Elastic Beanstalk│  Frontend
                    │ (Auto Scaling)   │  (Nginx)
                    └──────────────────┘

┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   GitHub    │────▶│GitHub Actions│────▶│     ECR     │
│ Repository  │     │   (CI/CD)    │     │  (Images)   │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                  │
                     ┌────────────────────────────┘
                     │
       ┌─────────────▼───────────────────────────────────┐
       │              EKS Cluster (1.29)                 │
       │                                                  │
       │  ┌────────────────────────────────────────┐     │
       │  │   AWS Load Balancer Controller         │     │
       │  │   (ALB/NLB Auto Provisioning)          │     │
       │  └─────────────────┬──────────────────────┘     │
       │                    │                            │
       │  ┌─────────────────▼──────────────────────┐     │
       │  │          ArgoCD (GitOps)               │     │
       │  │      Kustomize-based Deployment        │     │
       │  └─────────────────┬──────────────────────┘     │
       │                    │                            │
       │  ┌─────────────────▼──────────────────────┐     │
       │  │      Backend Application               │     │
       │  │  • Dev:  1 replica                     │     │
       │  │  • Prod: 3-10 replicas (HPA)           │     │
       │  │  • Service: ALB Ingress                │     │
       │  └────────────────────────────────────────┘     │
       │                                                  │
       │  ┌──────────────────────────────────────────┐   │
       │  │       Supporting Services                │   │
       │  │  • RDS PostgreSQL 14                     │   │
       │  │  • AWS Cognito                           │   │
       │  │  • Application Load Balancer             │   │
       │  └──────────────────────────────────────────┘   │
       └──────────────────────────────────────────────────┘
```

### 주요 컴포넌트

| 컴포넌트 | 기술 스택 | 용도 |
|---------|---------|------|
| **CDN** | Amazon CloudFront | 글로벌 콘텐츠 배포 |
| **Frontend Hosting** | Elastic Beanstalk (Docker) | 프론트엔드 Auto Scaling 배포 |
| **Frontend** | HTML/CSS/JS + Nginx 1.27 | 정적 파일 서빙 |
| **Backend** | Node.js (Express) | RESTful API |
| **Container Registry** | Amazon ECR | 도커 이미지 저장소 |
| **Orchestration** | Amazon EKS (Kubernetes 1.29) | 컨테이너 오케스트레이션 |
| **Load Balancer** | AWS Load Balancer Controller | ALB/NLB 자동 프로비저닝 |
| **GitOps** | ArgoCD + Kustomize | 자동 배포 및 환경별 설정 |
| **Auto Scaling** | HPA (Horizontal Pod Autoscaler) | Backend 자동 스케일링 |
| **Database** | Amazon RDS PostgreSQL 14 | 관계형 데이터베이스 |
| **Authentication** | AWS Cognito | 사용자 인증/인가 |
| **IaC** | Terraform | 인프라 프로비저닝 |
| **CI/CD** | GitHub Actions | 빌드 및 배포 자동화 |

---

## 📁 프로젝트 구조

```
project/
├── .github/
│   └── workflows/
│       ├── deploy-frontend.yml      # Frontend CI/CD Pipeline
│       └── deploy-backend.yml       # Backend CI/CD Pipeline
│
├── backend/                         # Backend Application
│   ├── src/
│   │   └── index.js                # Express.js 서버
│   ├── Dockerfile                  # 멀티스테이지 빌드
│   └── package.json
│
├── frontend/                        # Frontend Application
│   ├── index.html
│   ├── home.html
│   ├── calendar.html
│   ├── email.html
│   ├── notices.html
│   ├── org.html
│   ├── approvals.html
│   ├── Dockerfile                  # Nginx Docker 이미지
│   ├── nginx.conf                  # Nginx 설정 파일
│   ├── Dockerrun.aws.json          # Beanstalk 배포 설정
│   ├── .ebextensions/              # Beanstalk 확장 설정
│   │   └── 01_docker.config
│   ├── assets/
│   │   ├── app.js
│   │   ├── styles.css
│   │   ├── header.html
│   │   └── header.js
│   └── backend/                    # Frontend용 Lambda 함수
│       └── auth-login/
│
├── infra/
│   └── terraform/                  # Infrastructure as Code
│       ├── main.tf                 # Provider 설정
│       ├── vpc.tf                  # VPC, Subnet, NAT
│       ├── eks.tf                  # EKS Cluster + Node Group
│       ├── argocd.tf               # ArgoCD Helm 배포
│       ├── load-balancer-controller.tf  # AWS LB Controller
│       ├── cloudfront.tf           # CloudFront 배포
│       ├── beanstalk.tf            # Elastic Beanstalk 환경
│       ├── variables.tf            # 변수 정의
│       ├── terraform.tfvars        # 변수 값 (gitignore)
│       └── outputs.tf              # Output 값
│
├── k8s/                            # Kubernetes Manifests (Kustomize)
│   ├── argocd-application.yaml     # ArgoCD App 정의
│   ├── base/                       # Base Manifests
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml         # Backend Deployment
│   │   ├── service.yaml            # ClusterIP Service
│   │   ├── ingress.yaml            # ALB Ingress
│   │   ├── configmap.yaml          # 환경변수 (RDS, Cognito)
│   │   └── secret.yaml             # DB 비밀번호
│   └── overlays/                   # Environment Overlays
│       ├── dev/
│       │   └── kustomization.yaml  # Dev 환경 설정
│       └── prod/
│           ├── kustomization.yaml  # Prod 환경 설정
│           └── hpa.yaml            # Horizontal Pod Autoscaler
│
├── scripts/                        # Automation Scripts
│   ├── setup-env.ps1               # AWS 인증 및 환경 설정
│   ├── deploy-infra.ps1            # Terraform 배포
│   ├── deploy-gitops.ps1           # ArgoCD 설정
│   └── destroy-all.ps1             # 전체 리소스 삭제
│
└── README.md                       # 📖 이 문서
```

---

## 🚀 시작하기

### 사전 준비사항

배포를 시작하기 전에 다음 도구들이 설치되어 있어야 합니다:

| 도구 | 버전 | 설치 확인 |
|-----|------|----------|
| **AWS CLI** | v2.x | `aws --version` |
| **Terraform** | v1.5+ | `terraform version` |
| **kubectl** | v1.29+ | `kubectl version --client` |
| **Git** | v2.x | `git --version` |
| **PowerShell** | 5.1+ | `$PSVersionTable.PSVersion` |

### AWS 자격 증명 설정

```powershell
# AWS CLI 자격 증명 구성
aws configure

# 입력 항목:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: ap-northeast-2
# - Default output format: json
```

### GitHub Secrets 설정

Repository Settings → Secrets and variables → Actions에서 다음을 추가:

| Secret 이름 | 설명 | 예시 |
|------------|------|------|
| `AWS_ACCESS_KEY_ID` | AWS 액세스 키 | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS 시크릿 키 | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

### Terraform 변수 설정

`infra/terraform/terraform.tfvars` 파일을 생성하고 다음 내용을 입력:

```hcl
# 프로젝트 설정
project_name = "seoul-portal"
environment  = "seoul"
region       = "ap-northeast-2"

# 데이터베이스 설정
db_password = "YourSecurePassword123!"  # 변경 필수

# GitOps 설정
enable_argocd = true
github_repo   = "your-username/your-repo-name"  # GitHub 저장소 변경
```

⚠️ **중요**: `terraform.tfvars`는 `.gitignore`에 포함되어 Git에 커밋되지 않습니다.

---

## 📦 배포 프로세스

### 1단계: 환경 초기화

```powershell
# 프로젝트 루트에서 실행
cd c:\Users\soldesk\Desktop\Project\project

# 환경 설정 스크립트 실행
.\scripts\setup-env.ps1
```

이 스크립트는 다음을 수행합니다:
- AWS 자격 증명 확인
- 필요한 AWS 서비스 권한 검증
- Terraform 초기화

### 2단계: 인프라 배포

```powershell
# 인프라 배포 (약 20-25분 소요)
.\scripts\deploy-infra.ps1
```

배포되는 리소스:
- ✅ VPC (10.0.0.0/16) + Public/Private Subnets
- ✅ EKS Cluster (Kubernetes 1.29)
- ✅ EKS Node Group (t3.medium x 2)
- ✅ **AWS Load Balancer Controller** (Helm)
- ✅ **CloudFront Distribution** (CDN)
- ✅ **Elastic Beanstalk Environment** (Frontend)
- ✅ RDS PostgreSQL 14.20 (db.t3.micro)
- ✅ Amazon ECR (2개 리포지토리)
- ✅ AWS Cognito User Pool
- ✅ ArgoCD (Helm Chart)

배포 완료 후 다음 정보가 출력됩니다:
```
argocd_admin_password = "XXXXXXXXXXXX"
cognito_user_pool_id = "ap-northeast-2_XXXXXXXXX"
rds_endpoint = "seoul-portal-seoul-db.XXXXX.ap-northeast-2.rds.amazonaws.com:5432"
cloudfront_domain_name = "dXXXXXXXXXXXX.cloudfront.net"
beanstalk_environment_url = "seoul-portal-seoul-frontend-env.XXXXX.ap-northeast-2.elasticbeanstalk.com"
```

### 3단계: GitOps 설정

```powershell
# ArgoCD 설정 및 애플리케이션 등록
.\scripts\deploy-gitops.ps1
```

이 스크립트는 다음을 수행합니다:
- kubectl 컨텍스트를 EKS 클러스터로 설정
- Kubernetes ConfigMap/Secret 업데이트
- ArgoCD Application 배포
- ArgoCD 초기 동기화

### 4단계: 애플리케이션 배포

코드를 수정하고 Git에 푸시하면 자동으로 배포됩니다:

```powershell
# Backend 수정 예시
code backend/src/index.js
git add backend/
git commit -m "feat: Add new API endpoint"
git push origin main

# Frontend 수정 예시
code frontend/index.html
git add frontend/
git commit -m "feat: Update homepage design"
git push origin main
```

---

## 🔄 GitOps 워크플로우

### Frontend 자동 배포 흐름 (Beanstalk)

```
┌──────────────┐
│ 1. Code Push │
│  (Frontend)  │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 2. GitHub Actions                   │
│   - Docker Build (Nginx)            │
│   - ECR Push (tag: latest, sha)     │
│   - Update Dockerrun.aws.json       │
│   - Create Deployment Package       │
│   - Deploy to Beanstalk             │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 3. Elastic Beanstalk                │
│   - Rolling Update (Zero Downtime)  │
│   - Health Check                    │
│   - Auto Scaling (1-4 instances)    │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 4. CloudFront                       │
│   - Cache Invalidation (Optional)   │
│   - Global CDN Distribution         │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 5. Deployed  │
│   (Live)     │
└──────────────┘
```

### Backend 자동 배포 흐름 (Kustomize + ArgoCD)

```
┌──────────────┐
│ 1. Code Push │
│   (Backend)  │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 2. GitHub Actions                   │
│   - Docker Build                    │
│   - ECR Push (tag: latest, sha)     │
│   - Update k8s/base/deployment.yaml │
│   - Git Commit & Push               │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 3. ArgoCD (30초마다 감지)            │
│   - Git 변경사항 확인                │
│   - Kustomize Build                 │
│   - Manifest Sync (overlays/prod)   │
│   - EKS에 롤링 업데이트              │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 4. AWS Load Balancer Controller     │
│   - ALB Ingress 자동 생성/업데이트   │
│   - Target Group Health Check       │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 5. Deployed  │
│   (Live)     │
└──────────────┘
```

### Kustomize 환경별 배포

| 환경 | Overlay 경로 | Replicas | Resource Limits |
|------|-------------|----------|-----------------|
| **Dev** | `k8s/overlays/dev` | 1 | CPU: 200m, Memory: 256Mi |
| **Prod** | `k8s/overlays/prod` | 3-10 (HPA) | CPU: 1000m, Memory: 1Gi |

**Dev 환경 배포:**
```yaml
# k8s/overlays/dev/kustomization.yaml
replicas:
  - name: backend
    count: 1
```

**Prod 환경 배포:**
```yaml
# k8s/overlays/prod/kustomization.yaml
replicas:
  - name: backend
    count: 3

# HPA 설정
resources:
  - hpa.yaml  # 3-10 replicas, CPU 70%, Memory 80%
```
       │
       ▼
┌─────────────────────────────────────┐
│ 2. GitHub Actions                   │
│   - Docker Build                    │
│   - ECR Push (tag: latest, sha)     │
│   - Update k8s/deployment.yaml      │
│   - Git Commit & Push               │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 3. ArgoCD (30초마다 감지)            │
│   - Git 변경사항 확인                │
│   - Manifest Sync                   │
│   - EKS에 롤링 업데이트              │
└──────┬──────────────────────────────┘
       │
       ▼
┌──────────────┐
│ 4. Deployed  │
│   (Live)     │
└──────────────┘
```

### ArgoCD 특징

- **자동 동기화**: 30초마다 Git 리포지토리를 폴링
- **Self-Healing**: 수동 변경 사항을 자동으로 되돌림
- **Pruning**: Git에서 삭제된 리소스를 자동으로 정리
- **Health Check**: 애플리케이션 상태를 지속적으로 모니터링

### ArgoCD 웹 UI 접속

```powershell
# ArgoCD 포트 포워딩
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 브라우저에서 접속
# URL: https://localhost:8080
# Username: admin
# Password: Terraform output에서 확인
```

### 배포 상태 확인

```powershell
# ArgoCD 애플리케이션 상태
kubectl get application -n argocd

# Backend Pod 상태
kubectl get pods -l app=seoul-backend

# Backend 로그 확인
kubectl logs -l app=seoul-backend -f

# Service 확인
kubectl get svc seoul-backend-service
```

---

## 🛠️ 인프라 관리

### 인프라 수정

```powershell
# terraform.tfvars 또는 *.tf 파일 수정 후
cd infra/terraform
terraform plan     # 변경 사항 확인
terraform apply    # 변경 사항 적용
```

### 일반적인 수정 사항

**노드 수 변경:**
```hcl
# infra/terraform/eks.tf
desired_size = 3  # 2에서 3으로 변경
max_size     = 5
min_size     = 2
```

**인스턴스 타입 변경:**
```hcl
# infra/terraform/eks.tf
instance_types = ["t3.large"]  # t3.medium에서 변경
```

**RDS 스펙 변경:**
```hcl
# infra/terraform/main.tf
instance_class    = "db.t3.small"  # db.t3.micro에서 변경
allocated_storage = 30             # 20에서 30으로 변경
```

### 스케일링

```powershell
# 수동 스케일링 (임시)
kubectl scale deployment seoul-backend --replicas=5

# 영구 변경은 k8s/deployment.yaml 수정 후 Git push
```

### 리소스 정리

```powershell
# 전체 인프라 삭제 (약 10-15분)
.\scripts\destroy-all.ps1
```

⚠️ **주의사항**:
- ECR에 이미지가 있으면 삭제가 실패할 수 있습니다
- 수동으로 ECR 이미지 삭제: `aws ecr delete-repository --repository-name <repo> --force`
- EKS 노드가 남아있으면 AWS 콘솔에서 수동 삭제 필요

---

## 🔧 트러블슈팅

### EKS 클러스터 접근 불가

**증상**: `kubectl get nodes` 실행 시 에러

**해결**:
```powershell
# kubeconfig 업데이트
aws eks update-kubeconfig --region ap-northeast-2 --name seoul-portal-seoul-eks

# 권한 확인
kubectl auth can-i get pods
```

### ArgoCD 애플리케이션이 OutOfSync 상태

**증상**: ArgoCD UI에서 앱이 빨간색 표시

**해결**:
```powershell
# 수동 동기화
kubectl patch application seoul-portal-backend -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# 또는 ArgoCD UI에서 "Sync" 버튼 클릭
```

### Backend Pod가 CrashLoopBackOff

**증상**: `kubectl get pods`에서 재시작 반복

**해결**:
```powershell
# 로그 확인
kubectl logs -l app=seoul-backend --tail=50

# 일반적인 원인:
# 1. 환경변수 누락 → configmap.yaml 확인
# 2. DB 연결 실패 → RDS 보안 그룹 확인
# 3. 이미지 Pull 실패 → ECR 권한 확인
```

### Terraform destroy 타임아웃

**증상**: `terraform destroy` 실행 시 `context deadline exceeded` 에러

**해결**:
```powershell
# 1. Kubernetes 리소스 먼저 삭제
kubectl delete all --all -n default
kubectl delete namespace argocd

# 2. ECR 이미지 삭제
aws ecr delete-repository --repository-name seoul-portal-seoul-backend --force
aws ecr delete-repository --repository-name seoul-portal-seoul-frontend --force

# 3. 다시 destroy 시도
terraform destroy -auto-approve
```

### GitHub Actions 빌드 실패

**증상**: Actions 탭에서 빌드 실패

**해결**:
```yaml
# Secrets 확인
# Repository → Settings → Secrets → Actions
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY

# ECR 권한 확인
aws ecr get-login-password --region ap-northeast-2

# ECR 리포지토리 존재 확인
aws ecr describe-repositories
```

### RDS 연결 실패

**증상**: Backend에서 DB 연결 에러

**해결**:
```powershell
# 1. 보안 그룹 확인
aws ec2 describe-security-groups --group-ids sg-XXXXX

# 2. ConfigMap 확인
kubectl get configmap seoul-backend-config -o yaml

# 3. Secret 확인
kubectl get secret seoul-backend-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# 4. RDS 엔드포인트 연결 테스트
kubectl run -it --rm debug --image=postgres:14 --restart=Never -- \
  psql -h <RDS_ENDPOINT> -U postgres -d seoul_db
```

---

## 💰 비용 최적화

### 예상 월간 비용 (서울 리전)

| 리소스 | 스펙 | 시간당 | 월간 (730시간) |
|--------|------|--------|---------------|
| **CloudFront** | 100GB 데이터 전송 | - | **$8** |
| **Elastic Beanstalk** | t3.micro x 2 (평균) | $0.0104 x 2 | **$15** |
| **EKS Control Plane** | 1개 | $0.10 | **$73** |
| **EC2 (EKS Nodes)** | t3.medium x 2 | $0.0416 x 2 | **$61** |
| **Application Load Balancer** | 1개 | $0.0225 | **$16** |
| **RDS PostgreSQL** | db.t3.micro | $0.017 | **$12** |
| **NAT Gateway** | 1개 | $0.045 | **$33** |
| **ECR Storage** | 10 GB | $0.10/GB | **$1** |
| **Data Transfer** | 추가 100 GB | $0.09/GB | **$9** |
| | | **총계** | **≈ $228/월** |

> **참고**: CloudFront와 Beanstalk 추가로 기존 대비 약 $23/월 증가

### 비용 절감 팁

1. **개발 환경 자동 종료**
   ```powershell
   # 업무 시간 외 EKS 노드 수 0으로 설정
   kubectl scale deployment --all --replicas=0
   ```

2. **Spot 인스턴스 사용**
   ```hcl
   # eks.tf에 추가
   capacity_type = "SPOT"  # 최대 70% 절감
   ```

3. **NAT Gateway 제거** (개발 환경)
   - Private Subnet을 Public으로 변경
   - 보안 그룹으로 접근 제어

4. **RDS Reserved Instance**
   - 1년 선불: 40% 절감
   - 3년 선불: 60% 절감

5. **CloudWatch Logs 보관 기간 설정**
   ```powershell
   aws logs put-retention-policy --log-group-name /aws/eks/seoul-portal-seoul-eks/cluster --retention-in-days 7
   ```

---

## 📚 참고 자료

### 공식 문서
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### 관련 도구
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Helm Charts](https://artifacthub.io/)

### 커뮤니티
- [AWS Korea User Group](https://www.facebook.com/groups/awskr/)
- [Kubernetes Korea](https://www.facebook.com/groups/k8skr/)
- [GitOps Working Group](https://github.com/gitops-working-group)

---

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

---

## 🤝 기여

문제가 발생하거나 개선 사항이 있다면 Issue를 등록해주세요.

---

**마지막 업데이트**: 2024년 1월
| EKS Nodes (2) | t3.medium | $0.0832 |
| RDS | db.t3.micro | $0.017 |
| NAT Gateway (2) | - | $0.090 |
| NLB | - | $0.027 |
| ArgoCD (EKS) | - | $0.03 |
| **총계** | - | **$0.35/시간** (~$8.4/일) |

## 🔐 보안

- RDS는 Private Subnet에 배치
- Security Group으로 접근 제어
- Cognito를 통한 사용자 인증
- Kubernetes Secret으로 민감 정보 관리

## 📊 모니터링

### ArgoCD UI
```powershell
# ArgoCD URL 확인
kubectl get svc -n argocd argocd-server

# 초기 비밀번호
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode
```

### Backend Logs
```powershell
kubectl logs -f deployment/backend
```

### Pod 상태
```powershell
kubectl get pods -l app=backend
```

## 🚨 트러블슈팅

### ArgoCD가 변경사항을 감지하지 못함
```powershell
# 수동 동기화
kubectl patch application seoul-portal-backend -n argocd --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

### Pod가 ImagePullBackOff
```powershell
# ECR 이미지 확인
aws ecr describe-images --repository-name seoul-portal-seoul-backend

# Pod 상세 정보
kubectl describe pod <POD-NAME>
```

### GitHub Actions 실패
- AWS IAM 권한 확인
- GitHub Secrets 확인

---

## 🎯 주요 특징

### 1. **글로벌 CDN 배포**
- CloudFront를 통한 전 세계 엣지 로케이션 배포
- 정적 자산 캐싱 (24시간 ~ 1년)
- HTTPS 리다이렉션 자동 적용

### 2. **완전 자동 스케일링**
- **Frontend**: Elastic Beanstalk Auto Scaling (1-4 인스턴스)
- **Backend**: Kubernetes HPA (3-10 Pods, CPU/Memory 기반)
- 트래픽 급증 시 자동 확장

### 3. **Kustomize 기반 환경 관리**
- **Base**: 공통 매니페스트
- **Dev Overlay**: 최소 리소스, 1 replica
- **Prod Overlay**: 프로덕션 리소스, HPA 활성화
- 환경별 독립적 배포 가능

### 4. **AWS Load Balancer Controller**
- Kubernetes Ingress → ALB 자동 생성
- Target Group 자동 관리
- Health Check 자동 설정
- 수동 ALB 관리 불필요

### 5. **GitOps 완전 자동화**
- **Frontend**: GitHub Actions → Beanstalk
- **Backend**: GitHub Actions → ECR → ArgoCD → EKS
- 코드 푸시 = 자동 배포 (Human Intervention 불필요)

### 6. **무중단 배포**
- Frontend: Beanstalk Rolling Update
- Backend: Kubernetes Rolling Update
- 배포 중에도 서비스 가용성 100% 유지

---

## 📞 연락처

- **Repository**: https://github.com/minlnim/Project
- **Owner**: minlnim

---

## 📄 라이선스

Private Project

---

**마지막 업데이트**: 2025년 1월 - 전체 아키텍처 업그레이드 완료
---

**Built with ❤️ using GitOps**
