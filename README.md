# AWS Hybrid IaC Lab

**A production-style DevOps lab where Terraform and AWS CloudFormation work together as one deployment pipeline, driven end-to-end by GitHub Actions with OIDC (no long-lived AWS keys).**

Terraform owns the *control plane* (state backend, IAM, OIDC, the template bucket, and the root stack resource).
CloudFormation owns the *AWS resource plane* (VPC, S3, DynamoDB, ECR, Lambda, API Gateway, CloudFront, EC2, EKS, RDS, ECS).
GitHub Actions owns the *application plane* (Docker build → ECR push → ECS Fargate deploy → EKS deploy).

---

## Table of Contents

1. [What this lab is](#1-what-this-lab-is)
2. [Why "hybrid" IaC](#2-why-hybrid-iac)
3. [What you will learn](#3-what-you-will-learn)
4. [Technology stack](#4-technology-stack)
5. [Architecture](#5-architecture)
6. [End-to-end data flow](#6-end-to-end-data-flow)
7. [Repository structure](#7-repository-structure)
8. [Prerequisites — tools to install](#8-prerequisites--tools-to-install)
9. [Preparing your system](#9-preparing-your-system)
10. [AWS account preparation](#10-aws-account-preparation)
11. [GitHub repository configuration](#11-github-repository-configuration)
12. [Deployment — step by step](#12-deployment--step-by-step)
13. [The CI/CD workflows explained](#13-the-cicd-workflows-explained)
14. [Scripts reference](#14-scripts-reference)
15. [Deployment monitoring system](#15-deployment-monitoring-system)
16. [Verification — how to prove it works](#16-verification--how-to-prove-it-works)
17. [Lab tasks and exercises](#17-lab-tasks-and-exercises)
18. [Core DevOps concepts this lab teaches](#18-core-devops-concepts-this-lab-teaches)
19. [Interview questions you should be able to answer](#19-interview-questions-you-should-be-able-to-answer)
20. [Troubleshooting](#20-troubleshooting)
21. [Cost awareness and cleanup](#21-cost-awareness-and-cleanup)
22. [Security notes](#22-security-notes)
23. [Roadmap / improvements](#23-roadmap--improvements)

---

## 1. What this lab is

Most AWS learning repos pick one IaC tool and stop there. Real companies rarely look like that. They inherit CloudFormation stacks, adopt Terraform later, and end up running both. This lab is a deliberate, working model of that reality.

The lab deploys a full application platform into a single AWS region:

- A custom VPC with public and private subnets across two Availability Zones, an Internet Gateway, and a NAT Gateway
- A containerised Nginx web application, built as a Docker image and pushed to Amazon ECR
- The same image deployed twice — once to **ECS Fargate** behind an Application Load Balancer, and once to **Amazon EKS** behind a Kubernetes `LoadBalancer` Service
- A serverless path: **Lambda** (Python 3.12) fronted by **API Gateway**
- A static/edge path: **S3** origin behind **CloudFront** with Origin Access Control
- Data stores: **RDS MySQL 8.0** in private subnets with credentials in Secrets Manager, plus a **DynamoDB** table
- An **EC2** instance for manual, hands-on practice inside the same VPC

Everything is destroyable with a single confirmed workflow run.

**Who it's for:** DevOps / Cloud / Platform engineering learners who already know AWS basics and want to see how the pieces are wired together in a real pipeline, not in isolation.

---

## 2. Why "hybrid" IaC

The obvious question a reviewer will ask: *why not just use Terraform for everything?*

The answer this lab demonstrates:

| Concern | Owned by | Reason |
|---|---|---|
| Remote state backend (S3) | Terraform (bootstrap layer) | Must exist before anything else can be managed remotely |
| IAM roles, policies, OIDC provider | Terraform | Terraform's `import` blocks let pre-existing IAM be adopted cleanly |
| CloudFormation template bucket | Terraform | Nested stacks require templates to live in S3 |
| The root stack itself | Terraform (`aws_cloudformation_stack`) | Terraform triggers and tracks CloudFormation as a single resource |
| VPC, S3, DynamoDB, ECR, Lambda, API GW, CloudFront, EC2, EKS, RDS | CloudFormation nested stacks | Native AWS service coverage, automatic rollback, drift detection |
| Docker image build + push | GitHub Actions | IaC declares repositories; it does not build artifacts |
| ECS service deployment | GitHub Actions (CloudFormation `ecs.yaml`) | Must run *after* an image exists in ECR |
| Kubernetes workloads | GitHub Actions (`kubectl`) | Kubernetes manifests are their own declarative layer |

The key architectural insight — written into `main.yaml` as a comment and worth understanding deeply — is the **chicken-and-egg problem**:

```
Terraform → CloudFormation → ECR repository → ECS service → needs a Docker image
                                                              ↑
                                              …which does not exist yet
```

ECS is therefore **deliberately excluded** from the root bootstrap stack. It is deployed later, by the Docker workflow, once a real image tag exists. This separation of *infrastructure lifecycle* from *application lifecycle* is one of the most important lessons in the lab.

---

## 3. What you will learn

**Infrastructure as Code**
- Writing modular Terraform: `provider.tf`, `versions.tf`, `variables.tf` with validation blocks, `locals.tf`, `data.tf`, `outputs.tf`
- Remote state on S3 with `use_lockfile = true` (native S3 locking — the modern replacement for a DynamoDB lock table)
- The bootstrap pattern: a separate mini-configuration that creates the state bucket before the main config can use it
- Terraform `import` blocks for adopting resources that already exist in an account
- CloudFormation nested stacks, parameters, outputs, `!GetAtt`, cross-stack wiring, and `CAPABILITY_NAMED_IAM`
- Using a **CloudFormation execution role** so the stack's permissions are separate from the caller's permissions

**CI/CD**
- GitHub Actions reusable workflows (`workflow_call`) and a parent orchestrator with `needs:` dependencies
- `concurrency` groups to prevent two pipelines mutating the same infrastructure
- Manual-approval-style gating via `workflow_dispatch` inputs (the destroy workflow requires typing `DESTROY`)
- Preflight validation steps that fail fast on missing configuration instead of failing halfway through an apply

**Security**
- **GitHub OIDC federation to AWS** — short-lived STS credentials, zero stored access keys
- Trust policies scoped to a specific repository and branch
- Least-privilege IAM policy design (see the nine policy documents in `IAM/`)
- Secrets Manager–managed RDS master passwords (`ManageMasterUserPassword: true`) — the password never appears in a template or state file
- S3 public access blocks, bucket encryption, CloudFront Origin Access Control instead of public buckets

**Containers and orchestration**
- Dockerfile authoring, health-check alignment between Dockerfile, Compose, ECS, and Kubernetes
- Immutable image tagging with `${GITHUB_SHA}` instead of `latest`
- ECS Fargate: task definitions, services, ALB target groups with `TargetType: ip`
- EKS: cluster, managed node group, namespace, ConfigMap, Deployment with RollingUpdate strategy, Service of type LoadBalancer
- `aws eks update-kubeconfig` and authenticating `kubectl` from CI

**Networking**
- VPC CIDR planning (`10.0.0.0/16`), public `/24`s for the ALB and NAT, private `/24`s for RDS and EKS nodes
- Route tables, Internet Gateway vs NAT Gateway, security group chaining (ALB SG → ECS SG)

**Operations**
- Real-time CloudFormation event monitoring while Terraform is still applying
- Automated root-cause diagnosis from stack events
- Verification scripts that assert reality matches intent
- Cost control and complete teardown

---

## 4. Technology stack

| Layer | Technology | Version / Detail |
|---|---|---|
| IaC (control) | Terraform | pinned `= 1.15.7`, AWS provider `~> 6.0` |
| IaC (resources) | AWS CloudFormation | 10 nested stacks + ECS deployed separately |
| CI/CD | GitHub Actions | 5 workflows, OIDC auth via `aws-actions/configure-aws-credentials@v5.1.1` |
| Containers | Docker / Docker Compose | `nginx:alpine` base, curl added for health checks |
| Registry | Amazon ECR | `hybridiaclab-dev-app` |
| Container orchestration | Amazon ECS Fargate | `LaunchType: FARGATE`, behind an internet-facing ALB |
| Kubernetes | Amazon EKS | version `1.33`, managed node group, `t3.medium`, AL2023 AMI |
| Compute | Amazon EC2 | `t3.micro`, Amazon Linux 2023 (AMI resolved dynamically by Terraform `data` source) |
| Serverless | AWS Lambda + API Gateway | Python 3.12, REST API |
| Edge / CDN | Amazon CloudFront + S3 | Origin Access Control |
| Relational DB | Amazon RDS MySQL | `8.0`, `db.t3.micro`, 20 GB, encrypted, private, not publicly accessible |
| NoSQL | Amazon DynamoDB | on-demand table |
| Secrets | AWS Secrets Manager | RDS master credentials |
| State | Amazon S3 | versioned, encrypted, native lockfile |
| Scripting | PowerShell 7 + Bash | ~30 scripts for setup, validation, diagnosis, cleanup |

---

## 5. Architecture

### 5.1 Control flow (who creates what)

```
                    Developer / GitHub push to main
                                 │
                                 ▼
                 ┌───────────────────────────────┐
                 │  GitHub Actions (OIDC → STS)  │
                 └───────────────┬───────────────┘
                                 │
      ┌──────────────────────────┼──────────────────────────┐
      ▼                          ▼                          ▼
  terraform.yml              docker.yml              kubernetes.yml
      │                          │                          │
      ▼                          ▼                          ▼
  Terraform                Build image →            aws eks update-kubeconfig
      │                    push to ECR →                     │
      │                    deploy ECS stack           kubectl apply -f kubernetes/
      │                                                      │
      ├─► S3 template bucket (versioned, encrypted)          ▼
      ├─► Upload 12 CFN templates                    Namespace / ConfigMap
      ├─► IAM: GitHubActions role, OIDC provider,    Deployment / Service (LB)
      │        CloudFormationExecutionRole
      └─► aws_cloudformation_stack "main"
                     │
                     ▼
        hybridiaclab-dev-MainStack  (root stack)
                     │
   ┌─────┬─────┬─────┼─────┬─────┬─────┬─────┬─────┬─────┐
   ▼     ▼     ▼     ▼     ▼     ▼     ▼     ▼     ▼     ▼
  VPC   S3   Dynamo  ECR  Lambda  API   Cloud  EC2   EKS   RDS
                                  GW    Front
```

### 5.2 Runtime architecture (what users hit)

```
                          Internet
                             │
        ┌────────────────┬───┴────┬──────────────┬──────────────┐
        ▼                ▼        ▼              ▼              ▼
   CloudFront        API Gateway  ALB      EKS LoadBalancer   EC2 (SSH/HTTP)
        │                │         │              │              │
        ▼                ▼         ▼              ▼              │
    S3 bucket         Lambda   ECS Fargate   EKS pods            │
     (OAC)           (py3.12)    task          (nginx)           │
                         │         │              │              │
                         └─────────┴──────┬───────┴──────────────┘
                                          ▼
                              ┌───────────────────────┐
                              │  Private subnets      │
                              │  RDS MySQL  DynamoDB  │
                              │  (Secrets Manager)    │
                              └───────────────────────┘
```

### 5.3 Network layout

| Component | CIDR | AZ | Purpose |
|---|---|---|---|
| VPC | `10.0.0.0/16` | — | Lab network boundary |
| Public subnet 1 | `10.0.1.0/24` | AZ-a | ALB, NAT Gateway, EC2 |
| Public subnet 2 | `10.0.2.0/24` | AZ-b | ALB (multi-AZ requirement) |
| Private subnet 1 | `10.0.11.0/24` | AZ-a | EKS nodes, RDS |
| Private subnet 2 | `10.0.12.0/24` | AZ-b | EKS nodes, RDS subnet group |

Public subnets route `0.0.0.0/0` to the Internet Gateway. Private subnets route `0.0.0.0/0` to the NAT Gateway.

---

## 6. End-to-end data flow

**Phase 0 — Bootstrap (once per account, run locally)**
1. `infrastructure/bootstrap/terraform-state/` creates the S3 state bucket with versioning and encryption.
2. The main Terraform config points its backend at that bucket.

**Phase 1 — Terraform (`terraform.yml`)**
3. GitHub Actions requests an OIDC token; AWS STS exchanges it for temporary credentials against the `aws-hybrid-iac-lab-GitHubActions` role.
4. `terraform init` connects to the S3 backend and acquires a lock.
5. Terraform creates the CFN template bucket and uploads all 12 YAML templates (`aws_s3_object` with `filemd5` etags, so changed templates re-upload).
6. Terraform creates/imports the IAM roles, policies, and the OIDC provider.
7. Terraform creates `aws_cloudformation_stack.main`, passing `ProjectName`, `Environment`, `TemplateBucket`, `AmiId` (resolved from a live AMI lookup), and `DatabaseUsername`, and executing as the CloudFormation execution role.

**Phase 2 — CloudFormation (triggered by Terraform)**
8. The root stack downloads each nested template from S3 and creates the stacks in dependency order: VPC first, then everything that needs subnets.
9. Nested stacks return outputs upward — `VpcId`, `PublicSubnet1Id`, `ApplicationBucketName`, `LambdaFunctionArn`, `EcrRepositoryUri`, `RDSDatabaseSecretArn`, `EKSClusterName`, and more — which the root stack re-exports.

**Phase 3 — Application build (`docker.yml`)**
10. The workflow queries the root stack: `aws cloudformation describe-stacks --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri']"`. This is the contract between IaC and CI/CD — no hardcoded URIs.
11. Docker builds from `docker/app/`, tags with `${GITHUB_SHA}`, logs into ECR, pushes.
12. The workflow then deploys `ecs.yaml` as its own stack, passing the immutable image tag.

**Phase 4 — Kubernetes (`kubernetes.yml`)**
13. `aws ecr describe-images` verifies the tag actually exists before proceeding.
14. `aws eks update-kubeconfig` authenticates `kubectl`.
15. Namespace → ConfigMap → Deployment → Service are applied in order; the Deployment image is substituted with the ECR URI + SHA; a RollingUpdate (`maxUnavailable: 0`) replaces pods with zero downtime.

**Phase 5 — Traffic**
16. Users reach the app through the ALB (ECS path), the Kubernetes LoadBalancer (EKS path), CloudFront (static path), or API Gateway (serverless path).

---

## 7. Repository structure

```
aws-hybrid-iac-lab/
│
├── .github/workflows/
│   ├── main-deploy.yaml          Orchestrator: terraform → docker → kubernetes
│   ├── terraform.yml             Reusable: init / validate / plan / apply
│   ├── docker.yml                Reusable: build → ECR push → ECS deploy
│   ├── kubernetes.yml            Reusable: EKS auth → kubectl apply → rollout
│   └── delete.yml                Guarded full teardown (type DESTROY)
│
├── infrastructure/
│   ├── bootstrap/terraform-state/    Layer 0 — creates the S3 state backend
│   ├── terraform/                    Layer 1 — control plane
│   │   ├── backend.tf                S3 remote state + native lockfile
│   │   ├── versions.tf               Terraform 1.15.7, AWS provider ~> 6.0
│   │   ├── provider.tf               Region + default_tags
│   │   ├── variables.tf              Validated input variables
│   │   ├── locals.tf                 name_prefix + template path map
│   │   ├── data.tf                   Dynamic Amazon Linux 2023 AMI lookup
│   │   ├── template_bucket.tf        Versioned, encrypted, private S3 bucket
│   │   ├── template_objects.tf       for_each upload of all CFN templates
│   │   ├── cloudformation.tf         aws_cloudformation_stack "main"
│   │   ├── iam.tf                    OIDC provider, roles, policies
│   │   ├── iam-imports.tf            import blocks for pre-existing IAM
│   │   └── outputs.tf                Role ARNs, bucket name, stack name
│   └── cloudformation/
│       ├── main.yaml                 Layer 2 — root / parent stack
│       ├── nested/                   vpc, s3, dynamodb, ecr, lambda,
│       │                             api-gateway, cloudfront, ec2, eks,
│       │                             rds, ecs
│       └── legacy/iam/               Original CFN execution role template
│
├── docker/app/
│   ├── Dockerfile                    nginx:alpine + curl + index.html
│   ├── docker-compose.yml            Local run on :8080 with health check
│   └── src/index.html                The application page
│
├── kubernetes/
│   ├── namespace.yaml   configmap.yaml   deployment.yaml   service.yaml
│
├── IAM/                              9 JSON policy documents (trust + permissions)
│
├── scripts/                          ~30 PowerShell and Bash helpers
│   └── verification-reports/         Timestamped verification output
│
├── deployment-monitor-systam/        Real-time CFN monitoring + RCA system
└── report-log/                       Audit output: PASS / WARNING / ERROR / SUMMARY
```

---

## 8. Prerequisites — tools to install

### Required on your PC

| Tool | Minimum version | Why | Install |
|---|---|---|---|
| **AWS CLI** | v2 | All AWS interaction, ECR login, EKS kubeconfig | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| **Terraform** | **exactly 1.15.7** (pinned) | `versions.tf` uses `required_version = "= 1.15.7"` | [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform/downloads) |
| **Git** | 2.30+ | Clone, branch, push | [git-scm.com](https://git-scm.com/) |
| **Docker Desktop** | 24+ | Build and test the image locally | [docker.com](https://www.docker.com/products/docker-desktop/) |
| **kubectl** | within one minor of 1.33 | Talk to EKS | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |
| **PowerShell** | 7.x | Most helper scripts are `.ps1` | [github.com/PowerShell/PowerShell](https://github.com/PowerShell/PowerShell) |
| **GitHub CLI** (`gh`) | 2.x | Used by `GitHub-Login.ps1`, handy for triggering workflows | [cli.github.com](https://cli.github.com/) |

> **Terraform version pin.** Because `required_version` uses `=` rather than `~>`, any other version fails immediately. Use [tfenv](https://github.com/tfutils/tfenv) (macOS/Linux) or [tfswitch](https://tfswitch.warrensbox.com/) to manage this cleanly.

### Optional but recommended

| Tool | Why |
|---|---|
| **eksctl** | Easier EKS inspection and debugging |
| **jq** | Parsing AWS CLI JSON in Bash |
| **VS Code** + HashiCorp Terraform, YAML, Docker, Kubernetes extensions | Syntax, validation, and linting while editing |
| **cfn-lint** | `pip install cfn-lint` — catches CloudFormation errors before AWS does |
| **tflint / tfsec / checkov** | Terraform linting and security scanning |
| **Windows Terminal + WSL2** | Run the Bash scripts on Windows |

### Verify your installation

```bash
aws --version          # aws-cli/2.x
terraform version      # Terraform v1.15.7
docker --version       # Docker version 24+
kubectl version --client
git --version
pwsh --version         # PowerShell 7.x
```

---

## 9. Preparing your system

### Windows

```powershell
# Install core tools with winget
winget install Amazon.AWSCLI
winget install Hashicorp.Terraform
winget install Git.Git
winget install Docker.DockerDesktop
winget install Kubernetes.kubectl
winget install Microsoft.PowerShell
winget install GitHub.cli

# Allow the lab's local scripts to run in this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Clone and enter
git clone https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git
cd aws-hybrid-iac-lab
```

### macOS

```bash
brew install awscli terraform git kubectl powershell/tap/powershell gh jq
brew install --cask docker
git clone https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git
cd aws-hybrid-iac-lab
```

### Linux (Ubuntu/Debian)

```bash
sudo apt update && sudo apt install -y git curl unzip jq
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
# Terraform (HashiCorp apt repo), kubectl, docker, pwsh — see vendor docs
git clone https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git
cd aws-hybrid-iac-lab
```

### Configure AWS credentials locally

```bash
aws configure
# Access key, secret, region us-east-1, output json

aws sts get-caller-identity     # must return your account ID
```

> Local credentials are only needed for the **bootstrap** step and for running verification scripts. The pipeline itself never uses them — it uses OIDC.

---

## 10. AWS account preparation

You need an AWS account with administrative access for the initial setup.

**Checklist before deploying:**

- [ ] Region decided (the lab defaults to `us-east-1`; CloudFront + ACM work best there)
- [ ] Service quotas checked: VPCs per region (default 5), Elastic IPs (default 5 — the NAT Gateway needs one), EKS clusters
- [ ] A billing alarm / AWS Budget configured — **this lab costs real money while running** (see §21)
- [ ] MFA enabled on the root account; day-to-day work done as an IAM user or SSO identity

**Fork-specific values you must change.** The repo currently contains hardcoded references to the original author's account (`537236558357`). Update these before deploying to your own account:

| File | What to change |
|---|---|
| `infrastructure/terraform/backend.tf` | `bucket = "aws-hybrid-iac-lab-terraform-state-<YOUR_ACCOUNT_ID>"` |
| `infrastructure/terraform/iam-imports.tf` | All `import` block ARNs — or **delete this file entirely** on a fresh account, since nothing exists to import |
| `.github/workflows/terraform.yml`, `delete.yml` | `TF_STATE_BUCKET` |
| `infrastructure/terraform/terraform.tfvars` | Copy from `terraform.tfvars.example` and adjust |

---

## 11. GitHub repository configuration

### 11.1 Create the OIDC identity provider in AWS

One per account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 11.2 Create the role GitHub Actions assumes

Role name used throughout the lab: **`aws-hybrid-iac-lab-GitHubActions`**

Trust policy (see `IAM/github-actions-trust-policy.json`):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<YOUR_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:<YOUR_GH_USER>/aws-hybrid-iac-lab:*"
      }
    }
  }]
}
```

> **Understand this trust policy.** The `sub` condition is what stops *any other* GitHub repository in the world from assuming your role. Scope it as tightly as you can — to a branch (`:ref:refs/heads/main`) or an environment if you want it stricter.

Attach the permission policies from `IAM/`:
- `aws-hybrid-iac-lab-GitHubActionsPolicy.json` — service permissions
- `github-actions-terraform-backend-policy.json` — S3 state access
- `github-ci-cd-user-combined-access.json` — combined CI/CD access
- `iam-policiesgithub-ci-cd-cloudformation-passrole-policy.json` — `iam:PassRole` for the CFN execution role

### 11.3 Set repository variables

`Settings → Secrets and variables → Actions → Variables`

| Name | Example value |
|---|---|
| `AWS_ACCOUNT_ID` | `123456789012` |
| `AWS_ROLE_ARN` | `arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions` |
| `AWS_REGION` | `us-east-1` |

The workflows validate these on every run — `AWS_ACCOUNT_ID` must be exactly 12 digits, and both must be non-empty, or the job fails in the preflight step before touching AWS.

---

## 12. Deployment — step by step

### Step 1 — Bootstrap the Terraform state backend (local, once)

```bash
cd infrastructure/bootstrap/terraform-state
terraform init
terraform plan
terraform apply
terraform output      # note the bucket name
```

Then put that bucket name into `infrastructure/terraform/backend.tf` and the workflow `TF_STATE_BUCKET` variables.

The dedicated [`bootstrap README`](infrastructure/bootstrap/terraform-state/README.md) covers this layer in depth — why it exists, state locking, versioning, and recovery.

### Step 2 — Validate locally before pushing

```powershell
./scripts/preflight.ps1              # environment + credential checks
./scripts/verify-hybrid-iac-templates.ps1   # terraform validate + cfn validate
./scripts/pre-push-check.ps1         # full local gate before git push
```

### Step 3 — Local Docker test

```bash
cd docker/app
docker compose build
docker compose up -d
curl http://localhost:8080
docker inspect --format="{{.State.Health.Status}}" hybrid-iac-app   # → healthy
docker compose down
```

This matters: the Compose health check (`curl -f http://localhost/`) is intentionally identical to the ECS health check. If it's unhealthy locally, it will be unhealthy on Fargate.

### Step 4 — Deploy via the pipeline

```bash
git add .
git commit -m "Deploy hybrid IaC lab"
git push origin main
```

`main-deploy.yaml` fires automatically and runs, in order:

```
terraform  →  docker  →  kubernetes
```

You can also run each reusable workflow manually from the Actions tab (`workflow_dispatch`).

### Step 5 — Optional local Terraform run

```powershell
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 6 — Retrieve your endpoints

```bash
aws cloudformation describe-stacks \
  --stack-name hybridiaclab-dev-MainStack \
  --query "Stacks[0].Outputs" --output table
```

```bash
kubectl get svc -n hybridiaclab
# EXTERNAL-IP column = your EKS load balancer hostname
```

---

## 13. The CI/CD workflows explained

### `main-deploy.yaml` — orchestrator
Triggered on push to `main` and on manual dispatch. It calls the three reusable workflows and enforces ordering with `needs:`. `secrets: inherit` passes credentials down. `permissions: id-token: write` is what makes OIDC possible — without it, no token is minted.

### `terraform.yml`
Preflight validation → OIDC auth → verify the assumed role is actually the expected one → `terraform init` with backend config → `fmt -check` → `validate` → `plan` → `apply`. Guarded by a `concurrency` group keyed on repo + ref so two applies can never race the same state file.

### `docker.yml`
Validates that the build context, Dockerfile, ECS template, and `GITHUB_SHA` all exist before anything runs. Reads `EcrRepositoryUri` from stack outputs. Builds, tags with the commit SHA, pushes, then deploys the ECS CloudFormation stack pointing at that exact tag.

**Why the SHA and not `latest`:** `latest` is mutable. Two deployments can produce different running code from the same tag, rollbacks become guesswork, and ECS may not even pull a new image because the tag didn't change. An immutable tag makes every deployment traceable to one commit.

### `kubernetes.yml`
Reads ECR outputs, **verifies the image tag exists** with `aws ecr describe-images` (fail fast rather than watch pods crash-loop on ImagePullBackOff), configures kubeconfig, applies manifests in dependency order, and waits for the rollout.

### `delete.yml`
Requires typing `DESTROY` exactly, plus a separate boolean for whether to delete the state bucket. Deletes in reverse dependency order: Kubernetes resources → ECS stack → EKS → main stack → Terraform destroy → optionally the state bucket.

---

## 14. Scripts reference

### PowerShell (Windows-first)

| Script | Purpose |
|---|---|
| `go-aws-lab.ps1` | Main launcher / menu for lab operations |
| `preflight.ps1` | Verifies tools, credentials, and configuration before deploying |
| `pre-push-check.ps1` | Local gate: validate everything before `git push` |
| `validate-cfn.ps1` | `aws cloudformation validate-template` across all templates |
| `verify-hybrid-iac-templates.ps1` | Terraform + CloudFormation validation together |
| `verify-hybrid-iac-architecture.ps1` | Asserts deployed resources match the intended architecture |
| `audit-cloudformation-lab.ps1` | Full nested-stack preflight audit |
| `cloudformation-validation-diagnostic.ps1` | Deep CFN diagnostics with report output |
| `verify-github-aws-oidc.ps1` | Confirms the OIDC trust chain works end to end |
| `verify-github-ci-cd.ps1` | Validates the CI/CD configuration |
| `aws-hybrid-iac-verification-lab.ps1` | Master verification suite → `verification-reports/` |
| `Monitor-CloudFormation.ps1` | Live stack event tailing |
| `terraform-plan.ps1`, `build-docker.ps1` | Convenience wrappers |
| `GitHub-Login.ps1` | Browser-based GitHub CLI authentication |
| `aws-full-cleanup.ps1` | Region-wide cleanup sweep |

### Bash (Linux / EC2 / WSL)

| Script | Purpose |
|---|---|
| `bootstrap-terraform-state.sh` | Bash equivalent of the state bootstrap |
| `ec2-setup.sh`, `ec2-docker-setup.sh`, `ec2-userdata.sh` | Prepare an Amazon Linux 2023 EC2 host |
| `github-ec2-setup.sh` | Configure SSH + repo clone on EC2 |
| `verify-ec2-tools.sh`, `scriptsec2-verify.sh`, `verify-lab.sh` | Verify EC2 environment and lab state |
| `ecr-login.sh`, `docker-build-push.sh` | Manual ECR login and image push |
| `aws-rds-cafe-lab.sh` | RDS-focused practice exercise |
| `diagnose-charlie-cafe-ec2.sh` | Read-only EC2 diagnostics |
| `cleanup.sh`, `force-clean-charlie-cafe.sh` | Docker and EC2 cleanup |

---

## 15. Deployment monitoring system

`deployment-monitor-systam/` is a genuinely unusual piece of this lab and worth highlighting when you present it.

**The problem it solves.** The normal failure loop is: `terraform apply` → wait → fail → read an opaque error → open the console → hunt through CloudFormation events → find the *real* cause. Terraform reports that a stack failed; it rarely tells you *which nested resource* failed and *why*.

**What it does instead.** `Start-Deployment.ps1` runs the Terraform apply and a CloudFormation event monitor **in parallel**. The monitor tails stack and nested-stack events live, matches them against rules in `failure-rules.json`, and correlates them with the Terraform output. `Generate-Report.ps1` then produces `deployment-summary.md` and `diagnosis.json` with a root-cause verdict.

```
GitHub Actions / local
        │
        ▼
Start-Deployment.ps1
        ├──────────────┬──────────────┐
        ▼              ▼              ▼
  CFN Monitor    Terraform Apply   Nested-stack watch
        └──────────────┴──────────────┘
                       ▼
             Generate-Report.ps1
                       ▼
        deployment-summary.md + diagnosis.json
```

**The concept to take away:** this is *observability applied to infrastructure deployment*, not just to running applications. Failures become diagnosable in real time rather than archaeologically.

---

## 16. Verification — how to prove it works

```bash
# Terraform state and outputs
cd infrastructure/terraform && terraform output

# Stack health
aws cloudformation describe-stacks --stack-name hybridiaclab-dev-MainStack \
  --query "Stacks[0].StackStatus"
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --output table

# Networking
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=hybridiaclab" --output table

# Container image
aws ecr describe-images --repository-name hybridiaclab-dev-app --output table

# ECS
aws ecs list-clusters
aws ecs describe-services --cluster hybridiaclab-dev-cluster \
  --services hybridiaclab-dev-service --query "services[0].{Running:runningCount,Desired:desiredCount}"

# EKS
aws eks update-kubeconfig --name hybridiaclab-dev-EKS --region us-east-1
kubectl get nodes
kubectl get all -n hybridiaclab
kubectl logs -n hybridiaclab -l app=hybridiaclab-app --tail=50

# RDS (should be private, encrypted, not publicly accessible)
aws rds describe-db-instances \
  --query "DBInstances[0].{Status:DBInstanceStatus,Public:PubliclyAccessible,Encrypted:StorageEncrypted}"
```

Or run the bundled suite:

```powershell
./scripts/aws-hybrid-iac-verification-lab.ps1
```

Output lands in `scripts/verification-reports/` and `report-log/` as PASS / WARNING / ERROR / SUMMARY files.

---

## 17. Lab tasks and exercises

### Level 1 — Foundation
1. Bootstrap the state backend; inspect the created bucket's versioning and encryption settings.
2. Deploy the full stack via `main-deploy.yaml` and watch each job's logs.
3. Find every stack output and reach each of the four public endpoints.
4. Trace one value — `EcrRepositoryUri` — from `ecr.yaml` → `main.yaml` outputs → `docker.yml` → the running ECS task.

### Level 2 — Modification
5. Change `ProjectName` or `Environment` in `terraform.tfvars` and observe how every resource name changes through `local.name_prefix`.
6. Edit `docker/app/src/index.html`, push, and watch the new SHA-tagged image roll out to both ECS and EKS.
7. Scale the Kubernetes Deployment from 1 to 3 replicas and observe the RollingUpdate with `maxUnavailable: 0`.
8. Add a third private subnet in a third AZ and wire it into the RDS subnet group.

### Level 3 — Extension
9. Add a new nested stack — for example SNS or SQS — and wire its output into the root stack.
10. Add a Terraform-managed CloudWatch alarm on the ALB's 5xx count.
11. Add a `terraform plan` job that comments the plan on pull requests instead of auto-applying.
12. Add HTTPS: request an ACM certificate and add a 443 listener to the ALB.
13. Add an EKS Ingress with the AWS Load Balancer Controller instead of a `LoadBalancer` Service.
14. Replace the EKS node group with Fargate profiles and compare cost and cold-start behaviour.

### Level 4 — Break it and fix it (the most valuable ones)
15. Delete a nested stack manually, then re-run Terraform. What happens, and why?
16. Push an image tagged `latest` only, then deploy. Watch ECS fail to pick it up. Explain why.
17. Change the OIDC trust policy `sub` to a different repo and watch the pipeline fail. Read the STS error carefully.
18. Corrupt the Terraform state lock and practise recovery.
19. Make the ECS health check fail (remove `curl` from the Dockerfile) and diagnose it from task logs alone.
20. Remove an IAM permission and identify the failure from the CloudFormation event stream rather than from the Terraform error.

### Level 5 — Production thinking
21. Add `dev`, `staging`, and `prod` via Terraform workspaces or separate tfvars files.
22. Add drift detection: a scheduled workflow running `terraform plan -detailed-exitcode`.
23. Add `checkov` or `tfsec` as a blocking security gate in CI.
24. Document the RTO/RPO of the RDS instance and add automated snapshots before destroy.

---

## 18. Core DevOps concepts this lab teaches

These are the concepts a reviewer will probe. Be able to explain each in your own words.

**Infrastructure as Code**
Infrastructure defined in version-controlled files rather than console clicks. Benefits: repeatability, review, audit trail, disaster recovery, and the ability to diff intended state against actual state.

**Declarative vs imperative**
Both Terraform and CloudFormation are declarative — you describe the desired end state, the engine computes the path. The Bash scripts in this repo are imperative — a sequence of steps. Know which problems suit which.

**State management**
Terraform's state is its map from configuration to real resources. Remote state on S3 makes it shared; locking stops concurrent applies from corrupting it. CloudFormation, by contrast, keeps state inside AWS — a genuine advantage this lab lets you feel directly.

**Idempotency**
Running the same apply twice produces no changes. This is what makes automated pipelines safe to retry.

**Immutable infrastructure**
Don't patch running servers — replace them. The SHA-tagged image is immutable infrastructure applied to containers.

**Separation of concerns**
Infrastructure lifecycle ≠ application lifecycle. This lab's whole ECR/ECS split is a demonstration of that boundary.

**Least privilege**
Every identity gets only the permissions it needs. Note the layering here: the GitHub Actions role can *start* CloudFormation, but CloudFormation runs as a *separate* execution role. The CI identity never needs the union of every service permission.

**Secretless CI/CD (OIDC / workload identity federation)**
Long-lived access keys are the single most common cloud breach vector. OIDC replaces them with short-lived, cryptographically scoped tokens. Explaining this well is one of the strongest signals in an interview.

**Secrets management**
`ManageMasterUserPassword: true` means AWS generates the RDS password, stores it in Secrets Manager, and rotates it. The password appears nowhere in the repo, the templates, or the state file.

**Pipeline design: fail fast**
Every workflow validates configuration before touching AWS. Cheap checks run first; expensive ones run last.

**Dependency ordering**
`needs:` in GitHub Actions, `DependsOn` and `!GetAtt` in CloudFormation, `depends_on` in Terraform. Implicit dependencies (via references) are preferable to explicit ones.

**Concurrency control**
`concurrency` groups prevent two pipelines mutating shared infrastructure simultaneously — the CI-level equivalent of a state lock.

**Health checks and readiness**
Docker `HEALTHCHECK`, ECS container health checks, ALB target group health checks, and Kubernetes probes all answer "is this thing actually serving traffic?" — at different layers.

**Zero-downtime deployment**
RollingUpdate with `maxUnavailable: 0` and `maxSurge: 1` means a new pod becomes ready before an old one is removed.

**Observability**
Logs, events, and metrics. This lab's monitoring system extends that idea backwards into the deployment itself.

**Cost as an engineering constraint**
NAT Gateways, EKS control planes, ALBs, and RDS instances bill hourly. A destroy workflow isn't an afterthought — it's part of responsible infrastructure design.

**Blast radius and guarded destruction**
The typed `DESTROY` confirmation is a deliberate friction point. Know why irreversible operations deserve friction.

---

## 19. Interview questions you should be able to answer

Practise these out loud. They're drawn directly from decisions visible in this repo.

**Architecture**
1. Why use Terraform and CloudFormation together instead of one tool?
2. What specifically does Terraform manage here, and what does CloudFormation manage?
3. Why is ECS excluded from the root bootstrap stack?
4. How do values move from a nested stack to the GitHub Actions workflow?
5. What would break if you deleted `template_objects.tf`?

**Terraform**
6. What is the bootstrap problem with remote state, and how does this repo solve it?
7. What does `use_lockfile = true` do, and what did it replace?
8. What are `import` blocks for, and when would you use them?
9. Why is `filemd5` used as the S3 object etag?
10. What is the difference between `depends_on` and an implicit reference dependency?

**CloudFormation**
11. What is a nested stack, and why use one instead of one giant template?
12. Why does the stack need `CAPABILITY_NAMED_IAM`?
13. What is a CloudFormation execution role and why is it more secure than using the caller's permissions?
14. What happens when a nested stack fails mid-create?

**CI/CD and security**
15. Explain GitHub OIDC to AWS. What exactly is exchanged, and why is it safer than access keys?
16. What does the `sub` condition in the trust policy protect against?
17. Why `id-token: write` in workflow permissions?
18. What is a reusable workflow and why use one here?
19. Why does the pipeline verify the assumed role name after authenticating?

**Containers and Kubernetes**
20. Why tag with the commit SHA instead of `latest`?
21. Why is `curl` explicitly installed in the Dockerfile?
22. Why `daemon off;` in the Nginx CMD?
23. What does `TargetType: ip` mean for an ECS Fargate target group, and why not `instance`?
24. Explain `maxSurge: 1` / `maxUnavailable: 0`.
25. How does `kubectl` in CI authenticate to EKS?

**Networking and data**
26. Why do EKS nodes and RDS live in private subnets?
27. What does the NAT Gateway do, and what does it cost?
28. How does CloudFront Origin Access Control keep the S3 bucket private?
29. Where is the RDS password stored, and who can read it?

---

## 20. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error: Unsupported Terraform Core version` | Wrong Terraform version | Install exactly 1.15.7, or relax `versions.tf` |
| `Error acquiring the state lock` | A previous run died holding the lock | Wait, then `terraform force-unlock <ID>` — only if you're certain no apply is running |
| `NoSuchBucket` on `terraform init` | State bucket not bootstrapped, or wrong name | Run the bootstrap layer; check `backend.tf` |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy `sub` doesn't match repo/branch | Fix the trust policy; check the OIDC provider exists |
| `Credentials could not be loaded` in Actions | Missing `id-token: write` or empty `AWS_ROLE_ARN` | Add the permission; set the repository variable |
| CloudFormation `ROLLBACK_COMPLETE` | A nested resource failed | Read the *nested* stack's events, not just the root's |
| `Resource already exists` | Prior partial run left resources behind | Delete manually or use `import` blocks |
| ECS task cycles / never healthy | Health check failing | Confirm curl is in the image; check CloudWatch task logs |
| `ImagePullBackOff` in EKS | Image tag missing or node IAM lacks ECR read | `aws ecr describe-images`; check the node role policy |
| `kubectl` "Unauthorized" | kubeconfig not refreshed, or identity not in cluster auth | Re-run `aws eks update-kubeconfig`; check access entries |
| CloudFront returns 403 | OAC/bucket policy mismatch | Verify the bucket policy allows the distribution |
| EIP quota exceeded | NAT Gateway needs an Elastic IP | Release unused EIPs or request a quota increase |

**General debugging order:** GitHub Actions log → Terraform error → **root CloudFormation stack events** → **nested stack events** → the individual service's logs (CloudWatch / `kubectl logs`). The real cause is almost always one layer deeper than the first error you see.

---

## 21. Cost awareness and cleanup

**This lab is not free-tier.** Rough `us-east-1` on-demand estimates while running:

| Resource | Approx. cost |
|---|---|
| EKS control plane | ~$0.10 / hour (~$73/month) |
| EKS node group (1 × t3.medium) | ~$0.042 / hour |
| NAT Gateway | ~$0.045 / hour + data processing |
| Application Load Balancer | ~$0.023 / hour + LCU |
| RDS `db.t3.micro` | ~$0.017 / hour |
| EC2 `t3.micro` | ~$0.0104 / hour |
| ECS Fargate task | ~$0.02 / hour at 0.25 vCPU / 0.5 GB |
| S3, DynamoDB, Lambda, CloudFront, ECR | cents at lab volume |

**Running everything is roughly $0.25–0.30 per hour — about $5–7 per day.** Deploy, learn, destroy the same day.

### Teardown

**Preferred — the guarded workflow:**
`Actions → Delete Infrastructure → Run workflow → type DESTROY`

**Manual, in reverse dependency order:**

```bash
kubectl delete -f kubernetes/ --ignore-not-found
aws cloudformation delete-stack --stack-name hybridiaclab-dev-ECSStack
aws cloudformation wait stack-delete-complete --stack-name hybridiaclab-dev-ECSStack
cd infrastructure/terraform && terraform destroy
```

**Verify nothing is left billing you:**

```bash
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
aws elbv2 describe-load-balancers
aws eks list-clusters
aws rds describe-db-instances
aws ec2 describe-addresses          # orphaned Elastic IPs still bill
```

NAT Gateways, ALBs, orphaned EBS volumes, and unattached Elastic IPs are the usual suspects for a surprise bill.

---

## 22. Security notes

**What this lab does well**
- No long-lived AWS credentials anywhere — OIDC only
- RDS master password generated and stored by Secrets Manager, never in code or state
- S3 buckets: public access blocked, encryption at rest, versioning on the state bucket
- RDS: private subnets, encrypted storage, `PubliclyAccessible: false`
- CloudFront OAC rather than a public S3 bucket
- A separate CloudFormation execution role, so CI never holds the full permission set
- Destruction gated behind an explicit typed confirmation

**Known issues in the current repo — fix these before reusing the pattern anywhere real**

1. **`infrastructure/bootstrap/terraform-state/terraform.tfstate` is committed to git.** Terraform state can contain sensitive values and should never be in version control. Remove it, add `*.tfstate*` to `.gitignore`, and purge it from history if the repo is public.
2. **`pre-push.tfplan` is committed.** Plan files can also contain sensitive data. Remove it.
3. **The AWS account ID `537236558357` is hardcoded** in `backend.tf`, `iam-imports.tf`, and several workflows. Account IDs aren't secrets, but hardcoding them makes the repo unusable by anyone else. Parameterise them.
4. **`TF_AUTO_APPROVE: "true"`** means every push to `main` applies without review. Fine for a personal lab; unacceptable for shared environments. Add a plan-review gate or a GitHub environment with required reviewers.
5. **Security groups allowing `IpProtocol: -1`** should be narrowed to the specific ports and sources actually needed.
6. **Default `database_username = "admin"`** — change it; `admin` is the first thing scanners try.
7. **Single-AZ RDS with `MultiAZ: false`** and no automated backup/snapshot policy — correct for cost in a lab, but call it out as a deliberate lab trade-off, not an oversight.

Being able to list your own project's weaknesses is a stronger signal than pretending it has none.

---

## 23. Roadmap / improvements

- [ ] Remove committed state and plan files; parameterise the account ID
- [ ] Add `terraform plan` on pull requests with the plan posted as a PR comment
- [ ] Add `tflint`, `tfsec`/`checkov`, and `cfn-lint` as blocking CI gates
- [ ] Add Trivy image scanning before the ECR push
- [ ] Add HTTPS via ACM on the ALB and CloudFront
- [ ] Multi-environment support (dev / staging / prod)
- [ ] Refactor the Terraform layer into reusable modules
- [ ] Scheduled drift detection with `terraform plan -detailed-exitcode`
- [ ] CloudWatch dashboards and alarms for ALB 5xx, ECS task failures, and RDS CPU
- [ ] Replace the EKS `LoadBalancer` Service with the AWS Load Balancer Controller + Ingress
- [ ] Add automated tests (Terratest or `terraform test`)

---

## License

Add a license file if you intend others to reuse this. MIT or Apache-2.0 are the usual choices for teaching repositories.

## Author

**Mustansar Javaid** — [github.com/awsrmmustansarjavaid](https://github.com/awsrmmustansarjavaid)

---

*Built to learn how Terraform, CloudFormation, Docker, Kubernetes, and GitHub Actions actually fit together — not as separate tutorials, but as one system.*