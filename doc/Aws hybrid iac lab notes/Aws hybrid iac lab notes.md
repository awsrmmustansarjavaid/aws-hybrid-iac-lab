# AWS Hybrid IaC Lab — Notes

Pipeline flow: **Terraform → Docker/ECR → Kubernetes/EKS**, with CloudFormation provisioning ECR and ECS separately.

---

## 1. CloudFormation

### 1.1 ECR Repository (`nested/ecr.yaml`)
- Creates repo named `${ProjectName}-${Environment}-app`
- **ScanOnPush: true** — auto vulnerability scanning
- **ImageTagMutability: IMMUTABLE** — tags can't be overwritten
- **Encryption: AES256**
- Outputs: `RepositoryUri`, `RepositoryArn`, `RepositoryName`

### 1.2 ECS Fargate (`ecs.yaml`)
- Resources: Cluster, Security Group, Task Execution Role, CloudWatch Log Group, Task Definition, Service
- **Lab-only setup:** `AssignPublicIp: ENABLED`, port 80 open to `0.0.0.0/0` (no ALB — prod should use one with private tasks)
- Task: Fargate, 256 CPU / 512 MiB, container port 80
- Logs → `/ecs/${ProjectName}-${Environment}` (7-day retention)
- Requires an image already pushed to ECR (`EcrImageUri` param)
- Key CLI: `aws cloudformation deploy`, `aws ecs update-service --force-new-deployment`, `aws ecs describe-tasks` (get public IP via network interface)

---

## 2. GitHub Actions Workflows

### 2.1 Main Deployment (`main-deploy.yaml`)
- Triggers: `push` to `main`, or manual `workflow_dispatch`
- Orchestrates 3 reusable workflows in order:
  1. `terraform` (no deps)
  2. `docker` (needs: terraform)
  3. `kubernetes` (needs: terraform, docker)
- Uses `secrets: inherit` to pass secrets down

### 2.2 Terraform Infra (`terraform.yml`)
- Auth: **GitHub OIDC → AWS IAM role** (no static AWS keys)
- Key env vars: `AWS_ROLE_ARN`, `AWS_OIDC_AUDIENCE=sts.amazonaws.com`, `TF_STATE_BUCKET`, `TF_STATE_KEY`
- Steps: preflight validation → OIDC claim diagnostic (decodes JWT, checks `iss`/`aud`/`sub`) → `configure-aws-credentials` → `sts get-caller-identity` check → **bootstrap S3 state bucket** (versioning + AES256 + block public access) → `terraform init/fmt/validate/plan/apply`
- Note: pinned to `aws-actions/configure-aws-credentials@v5.1.1` (v6 has an OIDC bug in reusable workflows)
- Concurrency group prevents parallel state writes

### 2.3 Docker Build & ECR (`docker.yml`)
- Steps: checkout → configure AWS creds → `amazon-ecr-login` → get account ID → `docker build` → look up ECR URI (`HybridIaCLab-dev-app`) → tag with `${GITHUB_SHA}` and `latest` → push both tags

### 2.4 Kubernetes Deployment (`kubernetes.yml`)
- Steps: checkout → configure AWS creds → install `kubectl` → `aws eks update-kubeconfig --name HybridIaCLab-dev-eks` → verify nodes → apply `namespace.yaml` → `configmap.yaml` → `deployment.yaml` → `service.yaml` → verify with `kubectl get pods/services -n hybrid-iac`

---

## Key Things to Remember
- **Security note:** this lab exposes ECS tasks directly to the internet (no ALB) — fine for learning, not for prod.
- **Auth model:** everything uses OIDC role assumption, not long-lived AWS keys.
- **State separation:** Terraform state (S3 bucket) is separate from any CloudFormation-managed resources.
- **Order matters:** Terraform → Docker/ECR → Kubernetes, enforced via `needs:` in the main workflow.
---
