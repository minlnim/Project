# GitOps 배포 설정 가이드

이 문서는 다이어그램에 표시된 GitOps CI/CD 파이프라인을 설정하는 방법을 안내합니다.

## 📋 아키텍처 개요

```
📝 Ops가 K8s Manifest 수정 (Git Push)
   ↓
🔄 GitHub Actions 트리거
   ↓
🐳 Docker Build & ECR Push
   ↓
🔧 Kustomize가 이미지 태그 자동 업데이트 (kustomization.yaml)
   ↓
👀 ArgoCD가 Git 변경 감지
   ↓
🚀 EKS에 자동 롤링 업데이트
```

## 🎯 구성 요소

### 1. **Terraform** (인프라 관리)
- EKS 클러스터
- VPC & 네트워킹
- RDS (Aurora PostgreSQL)
- Cognito
- ArgoCD 설치

### 2. **Kustomize** (Kubernetes 매니페스트 관리)
- `seoul/k8s/base/` - 기본 매니페스트
- `seoul/k8s/overlays/prod/` - 환경별 오버레이
- 이미지 태그 동적 관리

### 3. **GitHub Actions** (CI/CD)
- Docker 빌드 & ECR 푸시
- Kustomize 이미지 태그 자동 업데이트
- Git에 변경사항 커밋

### 4. **ArgoCD** (GitOps 배포)
- Git 저장소 모니터링
- 자동 동기화 (Auto Sync)
- Self-Healing

## 🚀 설정 단계

### Step 1: GitHub Secrets 설정

GitHub 저장소 Settings → Secrets and variables → Actions에서 다음 시크릿 추가:

```yaml
AWS_ACCESS_KEY_ID: <AWS Access Key>
AWS_SECRET_ACCESS_KEY: <AWS Secret Key>
```

**권한 요구사항:**
- ECR: `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`

### Step 2: Terraform 설정 (`terraform.tfvars`)

```hcl
# ArgoCD 활성화
enable_argocd = true

# GitHub Repository 설정
argocd_repo_url    = "https://github.com/minlnim/project.git"
argocd_repo_branch = "main"
argocd_backend_path = "seoul/k8s/base"

# Private Repository인 경우
argocd_repo_username = "your-github-username"
argocd_repo_password = "ghp_xxxxxxxxxxxx"  # GitHub Personal Access Token
```

### Step 3: Terraform 배포

```bash
cd seoul/infra/terraform

# 초기화
terraform init

# 인프라 생성 (EKS, VPC, RDS, ArgoCD)
terraform apply
```

**주의:** ArgoCD는 EKS 클러스터 생성 후 자동으로 설치됩니다.

### Step 4: ArgoCD 접속 확인

```bash
# ArgoCD 서버 주소 확인
kubectl get svc argocd-server -n argocd

# 초기 admin 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

ArgoCD UI 접속: `https://<ARGOCD_LB_DNS>`

### Step 5: Kubernetes 매니페스트 수정 및 배포

#### ConfigMap 업데이트
`seoul/k8s/base/configmap.yaml`:
```yaml
data:
  DB_HOST: "<RDS Endpoint>"  # Terraform output에서 확인
  DB_PORT: "5432"
  DB_NAME: "corpportal"
  COGNITO_USER_POOL_ID: "<User Pool ID>"  # Terraform output
  COGNITO_CLIENT_ID: "<Client ID>"  # Terraform output
```

#### Secret 업데이트
`seoul/k8s/base/secret.yaml`:
```yaml
stringData:
  DB_USER: "portaluser"
  DB_PASSWORD: "your-db-password"
```

**보안 권장사항:** 
- Secret은 AWS Secrets Manager 또는 External Secrets Operator 사용 권장
- Git에 민감정보 커밋하지 않기

#### Git Push
```bash
git add seoul/k8s/
git commit -m "chore: Update K8s manifests for Seoul backend"
git push origin main
```

## 🔄 배포 흐름

### 애플리케이션 코드 변경 시

1. **Backend 코드 수정**
   ```bash
   vi seoul/backend/src/index.js
   git add seoul/backend/
   git commit -m "feat: Add new API endpoint"
   git push origin main
   ```

2. **GitHub Actions 자동 실행**
   - Docker 이미지 빌드
   - ECR에 푸시
   - `seoul/k8s/base/kustomization.yaml`의 이미지 태그 업데이트
   - Git에 자동 커밋 (`[skip ci]`로 무한 루프 방지)

3. **ArgoCD 자동 배포**
   - Git 변경 감지 (3분 주기 또는 수동 Sync)
   - Kustomize 빌드
   - EKS에 롤링 업데이트

### Kubernetes 매니페스트 변경 시

1. **매니페스트 수정**
   ```bash
   vi seoul/k8s/base/deployment.yaml
   # 예: replicas 변경, 환경변수 추가 등
   git add seoul/k8s/
   git commit -m "chore: Increase replicas to 5"
   git push origin main
   ```

2. **ArgoCD 자동 배포**
   - 즉시 변경사항 감지 및 적용

## 🛠️ 트러블슈팅

### ArgoCD Application이 Sync되지 않는 경우

```bash
# ArgoCD CLI 설치
brew install argocd  # macOS
# or
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# 로그인
argocd login <ARGOCD_SERVER>

# Application 상태 확인
argocd app get seoul-portal-backend

# 수동 동기화
argocd app sync seoul-portal-backend
```

### GitHub Actions 실패 시

1. **ECR 권한 확인**
   ```bash
   aws ecr describe-repositories --repository-names seoul-portal-seoul-backend
   ```

2. **Secrets 확인**
   - GitHub Repository → Settings → Secrets and variables → Actions
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 확인

3. **워크플로우 로그 확인**
   - GitHub Repository → Actions 탭
   - 실패한 워크플로우 클릭 → 각 Step 로그 확인

### Kustomize 빌드 오류

```bash
# 로컬에서 Kustomize 빌드 테스트
cd seoul/k8s/base
kustomize build .

# overlays 테스트
cd ../overlays/prod
kustomize build .
```

## 📊 모니터링

### ArgoCD 대시보드
- Application 상태 실시간 확인
- Sync 히스토리
- 리소스 트리 시각화

### Kubernetes 로그
```bash
# Pod 로그 확인
kubectl logs -f deployment/backend -n default

# 이벤트 확인
kubectl get events -n default --sort-by='.lastTimestamp'
```

## 🔐 보안 권장사항

1. **Secret 관리**
   - AWS Secrets Manager 사용
   - External Secrets Operator 도입 검토

2. **IAM 최소 권한 원칙**
   - GitHub Actions용 IAM User는 ECR만 접근 가능하도록 제한
   - EKS Node Role은 필요한 권한만 부여

3. **Git Repository 보호**
   - `main` 브랜치 보호 규칙 설정
   - PR 리뷰 필수화
   - Secrets 파일은 `.gitignore` 추가

4. **Network 보안**
   - ArgoCD는 내부망에서만 접근 (VPN 또는 Bastion)
   - ALB/NLB에 Security Group 적용

## 📚 참고 자료

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Kustomize 공식 문서](https://kustomize.io/)
- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [AWS EKS 모범 사례](https://aws.github.io/aws-eks-best-practices/)

## 🎉 완료!

이제 완전한 GitOps 파이프라인이 구축되었습니다:

✅ **Terraform** → 인프라 관리  
✅ **GitHub Actions** → CI/CD 자동화  
✅ **Kustomize** → K8s 매니페스트 관리  
✅ **ArgoCD** → 자동 배포  

**코드를 수정하고 Git에 Push하면 자동으로 배포됩니다!** 🚀
