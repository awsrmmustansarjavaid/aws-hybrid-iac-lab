# AWS Hybrid IaC Lab — Architecture & Design Document

**Companion document to `README.md`.**
Where the README explains *how to run* the lab, this document explains *how the lab is built*: every directory, every file, how Terraform and CloudFormation cooperate, how GitHub Actions drives both, and what each script does and why it exists.

---

## Table of Contents

**Part I — The Design**
1. [Design philosophy](#1-design-philosophy)
2. [The four layers](#2-the-four-layers)
3. [Repository architecture map](#3-repository-architecture-map)

**Part II — Directory by Directory**
4. [`infrastructure/` — the IaC core](#4-infrastructure--the-iac-core)
5. [`.github/` — the automation layer](#5-github--the-automation-layer)
6. [`IAM/` — the identity layer](#6-iam--the-identity-layer)
7. [`docker/` — the application artifact](#7-docker--the-application-artifact)
8. [`kubernetes/` — the workload layer](#8-kubernetes--the-workload-layer)
9. [`scripts/` — the operator toolkit](#9-scripts--the-operator-toolkit)
10. [`deployment-monitor-systam/` — the observability layer](#10-deployment-monitor-systam--the-observability-layer)
11. [`report-log/` — the audit evidence layer](#11-report-log--the-audit-evidence-layer)
12. [`docs/` and `logs/` — proposed directories](#12-docs-and-logs--proposed-directories)
13. [Root-level files](#13-root-level-files)

**Part III — How It All Connects**
14. [How Terraform and CloudFormation work together](#14-how-terraform-and-cloudformation-work-together)
15. [How GitHub Actions drives both languages](#15-how-github-actions-drives-both-languages)
16. [The complete parameter and output contract](#16-the-complete-parameter-and-output-contract)
17. [The four handoff points](#17-the-four-handoff-points)
18. [Failure domains and blast radius](#18-failure-domains-and-blast-radius)

**Part IV — Concepts**
19. [Every technical concept in this lab](#19-every-technical-concept-in-this-lab)
20. [Design decisions and their trade-offs](#20-design-decisions-and-their-trade-offs)

---

# PART I — THE DESIGN

## 1. Design philosophy

The lab is built on one organising rule:

> **Each tool does only what it is uniquely good at, and hands off through an explicit, discoverable contract.**

No tool reaches into another tool's domain. There is no Terraform resource creating a VPC subnet here, and no CloudFormation resource building a Docker image. When one layer needs a value from another, it *queries* it rather than duplicating it.

Three principles follow from this:

**1. The boundary is the interface.** Terraform hands CloudFormation a set of *parameters*. CloudFormation hands GitHub Actions a set of *stack outputs*. GitHub Actions hands Kubernetes an *image URI*. Each handoff is a named, inspectable value — never a hardcoded string.

**2. Lifecycle drives ownership.** Things that change rarely and underpin everything (networks, IAM, databases) live in IaC. Things that change on every commit (application images, Kubernetes workloads) live in CI/CD. Mixing the two is the single most common cause of broken pipelines.

**3. Verify before you act.** Every workflow, and nearly every script, begins with validation. Failing in ten seconds on a missing variable is better than failing in fourteen minutes halfway through an EKS node group creation.

---

## 2. The four layers

```
┌──────────────────────────────────────────────────────────────────┐
│ LAYER 0 — BOOTSTRAP                    run once, manually, local │
│ infrastructure/bootstrap/terraform-state/                        │
│ Creates the S3 bucket that will hold Terraform's remote state.   │
│ Uses LOCAL state, because remote state does not exist yet.       │
└──────────────────────────────────────────────────────────────────┘
                              ↓ produces: state bucket name
┌──────────────────────────────────────────────────────────────────┐
│ LAYER 1 — CONTROL PLANE                       Terraform          │
│ infrastructure/terraform/                                        │
│ • S3 template bucket   • uploads 12 CFN templates                │
│ • OIDC provider        • IAM roles and policies                  │
│ • CloudFormation execution role                                  │
│ • aws_cloudformation_stack "main"  ← the bridge to Layer 2       │
└──────────────────────────────────────────────────────────────────┘
                              ↓ produces: a running root stack
┌──────────────────────────────────────────────────────────────────┐
│ LAYER 2 — RESOURCE PLANE                  CloudFormation         │
│ infrastructure/cloudformation/                                   │
│ main.yaml → 10 nested stacks                                     │
│ VPC · S3 · DynamoDB · ECR · Lambda · API GW · CloudFront ·       │
│ EC2 · EKS · RDS        (ECS is deliberately excluded — see §14.4)│
└──────────────────────────────────────────────────────────────────┘
                              ↓ produces: stack outputs
┌──────────────────────────────────────────────────────────────────┐
│ LAYER 3 — APPLICATION PLANE              GitHub Actions          │
│ docker/ + kubernetes/ + .github/workflows/                       │
│ Build image → push to ECR → deploy ECS stack → deploy to EKS     │
└──────────────────────────────────────────────────────────────────┘
```

Each layer can only see the layer directly below it, through a defined contract. That is what makes the system debuggable: when something breaks, you know exactly which layer to inspect.

---

## 3. Repository architecture map

```
aws-hybrid-iac-lab/
│
├── .github/workflows/          ← LAYER 3 automation   (5 files)
├── infrastructure/             ← LAYERS 0, 1, 2       (34 files)
│   ├── bootstrap/                 Layer 0
│   ├── terraform/                 Layer 1
│   └── cloudformation/            Layer 2
├── IAM/                        ← identity policies    (9 JSON files)
├── docker/                     ← application artifact (3 files)
├── kubernetes/                 ← workload manifests   (4 files)
├── scripts/                    ← operator toolkit     (~30 scripts)
├── deployment-monitor-systam/  ← observability        (6 files)
├── report-log/                 ← audit evidence       (4 files)
├── docs/                       ← [proposed]
├── logs/                       ← [proposed]
├── .gitignore  .dockerignore  README.md
```

**File-count-to-importance warning:** `scripts/` has the most files but the least architectural weight — they are tooling, not infrastructure. `infrastructure/terraform/cloudformation.tf` is 20 lines long and is the single most important file in the repository, because it is the bridge between the two IaC languages.

---

# PART II — DIRECTORY BY DIRECTORY

## 4. `infrastructure/` — the IaC core

### 4.1 `infrastructure/bootstrap/terraform-state/` (Layer 0)

Solves the chicken-and-egg problem of remote state: Terraform cannot store its state in an S3 bucket that Terraform has not yet created.

| File | Role |
|---|---|
| `main.tf` | Creates the S3 state bucket with versioning, encryption, and public access blocks |
| `variables.tf` | Bucket name and region inputs |
| `outputs.tf` | Emits the bucket name for use in `backend.tf` |
| `terraform.tfstate` | **Local** state for this layer only — ⚠️ currently committed to git; see §20.6 |
| `.terraform.lock.hcl` | Provider dependency lock |
| `README.md` | 33-section deep dive on state, locking, versioning, and recovery |

**Why it's separate:** this layer uses *local* state by design. It's tiny, it runs once, and it is the only thing in the repository that has no remote backend. Every other Terraform operation depends on its output.

### 4.2 `infrastructure/terraform/` (Layer 1)

Fourteen files, each with a single responsibility. This decomposition is deliberate — Terraform does not care how you split files, but a human reviewer does.

| File | Contents | Why it matters |
|---|---|---|
| `versions.tf` | `required_version = "= 1.15.7"`, AWS provider `~> 6.0` | Exact pin — not `~>`. Guarantees identical behaviour across every machine and CI runner |
| `provider.tf` | Region + `default_tags` block; a second aliased provider `no_default_tags` | Every resource is automatically tagged `Project`, `Environment`, `ManagedBy = Terraform`, `Lab`. The alias exists for resources that reject inherited tags |
| `backend.tf` | S3 backend: bucket, key, region, `encrypt = true`, `use_lockfile = true` | `use_lockfile` is native S3 conditional-write locking — the modern replacement for a DynamoDB lock table |
| `variables.tf` | 8 variables, each with a `validation` block | Region non-empty; project name matches `^[a-z0-9-]+$`; environment ∈ dev/test/staging/prod; DB username matches an RDS-legal pattern. Bad input fails at `plan`, not at AWS |
| `terraform.tfvars.example` | Safe template of real values | Committed. The real `terraform.tfvars` should not be |
| `locals.tf` | `name_prefix = "${project}-${environment}"` and a map of all 12 template paths | Every resource name in the lab derives from `name_prefix`. Change one variable, rename the whole estate |
| `data.tf` | `aws_ami` lookup for Amazon Linux 2023 (owner `137112412989`, five filters) | The AMI ID is *never* hardcoded. Each run resolves the current patched AMI |
| `template_bucket.tf` | S3 bucket with `bucket_prefix`, versioning, AES256 encryption, all four public-access blocks, `force_destroy = true` | `bucket_prefix` avoids global-name collisions. `force_destroy` makes teardown reliable |
| `template_objects.tf` | `for_each` over `local.cloudformation_templates`, uploading each with `etag = filemd5(...)` | Six lines that upload twelve templates. `filemd5` means a changed template re-uploads and triggers a stack update; an unchanged one doesn't |
| `cloudformation.tf` | `aws_cloudformation_stack "main"` — **the bridge** | See §14 |
| `iam.tf` | OIDC provider, GitHub Actions role, three managed policies via `for_each`, role attachments, CFN execution role and its inline policy | The whole identity model in one file |
| `iam-imports.tf` | Eight `import` blocks | Adopts pre-existing IAM into state rather than recreating it. Delete this file on a fresh account |
| `outputs.tf` | Template bucket, stack name, CFN execution role ARN, GitHub Actions role ARN/name, OIDC provider ARN | The contract Layer 1 exposes upward |
| `.terraform.lock.hcl` | Provider hashes | Reproducible provider versions |

Also present: `github-ci-cd-user-combined-access.json`, `oac-test.json` (working artifacts), and `pre-push.tfplan` (⚠️ a committed plan file — see §20.6).

### 4.3 `infrastructure/cloudformation/` (Layer 2)

#### `main.yaml` — the root / parent stack

~1,400 lines, of which the majority are structured explanatory comments. Structure:

- **Parameters** — `ProjectName`, `Environment`, `TemplateBucket`, `TemplatePrefix`, `AmiId`, `DatabaseUsername`
- **Resources** — ten `AWS::CloudFormation::Stack` resources plus `EC2RDSSecretsPolicy`
- **Outputs** — 28 outputs: ten stack IDs plus every value the application layer needs

Each nested stack resource points at `https://<bucket>.s3.../nested/<name>.yaml` and passes down the parameters that child needs, wiring siblings together with `!GetAtt VPCStack.Outputs.VpcId` and similar.

`EC2RDSSecretsPolicy` is a cross-cutting resource defined at root level because it needs values from two different children — the EC2 role name and the RDS secret ARN. This is a useful pattern: **when a resource spans two children, it belongs to the parent.**

#### `nested/` — the ten (plus one) child stacks

| Template | Parameters in | Outputs out | Creates |
|---|---|---|---|
| `vpc.yaml` | ProjectName, Environment | VpcId, 4 subnet IDs, IGW, NAT, EIP, 2 route table IDs | VPC `10.0.0.0/16`, 2 public + 2 private `/24`s across 2 AZs, IGW, NAT Gateway, route tables and associations |
| `s3.yaml` | ProjectName, Environment | BucketName, BucketArn | Application bucket + bucket policy |
| `dynamodb.yaml` | ProjectName, Environment | OrdersTableName, Arn, PartitionKey | Orders table |
| `ecr.yaml` | ProjectName, Environment | **EcrRepositoryUri**, Arn, Name | Container registry — the most-consumed output in the lab |
| `lambda.yaml` | ProjectName, Environment, OrdersTableName, OrdersTableArn | LambdaFunctionName, **LambdaFunctionArn** | Python 3.12 function + execution role scoped to the DynamoDB table |
| `api-gateway.yaml` | ProjectName, Environment, **LambdaFunctionArn** | ApiId, ApiEndpoint, OrdersEndpoint | REST API, `/orders` resource, method, deployment, stage, Lambda invoke permission |
| `cloudfront.yaml` | ProjectName, Environment, **ApplicationBucketName** | DistributionId, DomainName, WebsiteURL, OriginAccessControlId | Distribution + Origin Access Control |
| `ec2.yaml` | ProjectName, Environment, VpcId, PublicSubnetId, **AmiId**, InstanceType | InstanceId, PublicIp, PrivateIp, SecurityGroupId, **EC2RoleName**, InstanceProfileName | `t3.micro` AL2023 instance, SG, IAM role, instance profile |
| `eks.yaml` | ProjectName, Environment, KubernetesVersion (1.33), VpcId, 2 private subnets | ClusterName, ClusterEndpoint, NodeGroupName, ClusterArn, NodeRoleArn | EKS cluster, managed node group (`t3.medium`, AL2023, min 1 / desired 1 / max 2), cluster and node IAM roles |
| `rds.yaml` | ProjectName, Environment, VpcId, **Ec2SecurityGroupId**, 2 private subnets, DatabaseUsername | DatabaseEndpoint, Port, SecurityGroupId, **DatabaseSecretArn** | MySQL 8.0, `db.t3.micro`, 20 GB, encrypted, `PubliclyAccessible: false`, `ManageMasterUserPassword: true`, DB subnet group |
| `ecs.yaml` | ProjectName, Environment, VpcId, all 4 subnets, **EcrImageUri** | 14 outputs incl. ALBDnsName, ApplicationURL, ECSServiceName | ECS cluster, Fargate task definition, service, ALB (internet-facing), target group (`TargetType: ip`), listener, 2 security groups, CloudWatch log group |

**Read the dependency chain in that table.** Bold values are cross-stack: `LambdaFunctionArn` flows into API Gateway; `ApplicationBucketName` flows into CloudFront; `Ec2SecurityGroupId` flows into RDS (so only the EC2 instance can reach the database); `EcrImageUri` flows into ECS from *outside* CloudFormation entirely.

**`ecs.yaml` is the outlier.** It lives in the same folder but is *not* referenced by `main.yaml`. It is deployed as its own stack by `docker.yml`, because its `EcrImageUri` parameter cannot be satisfied until an image exists. This is the architectural centrepiece of the lab — see §14.4.

#### `legacy/iam/cloudformation-execution-role.yaml`

The original CloudFormation-defined execution role, kept for reference after the role moved into Terraform. Useful as a before/after study in migrating ownership between IaC tools.

---

## 5. `.github/` — the automation layer

Five workflow files implementing a reusable-workflow architecture.

```
                    main-deploy.yaml  (orchestrator)
                            │  on: push to main
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
    terraform.yml  →   docker.yml   →   kubernetes.yml
       (16 steps)       (18 steps)        (19 steps)
                                          needs: terraform, docker

                    delete.yml  (24 steps, manual only)
```

### `main-deploy.yaml`
The only workflow with a `push` trigger. Everything else is `workflow_call` or `workflow_dispatch`. It declares `permissions: id-token: write, contents: read` — **without `id-token: write`, no OIDC token is minted and every downstream AWS call fails.** `secrets: inherit` passes credentials to the called workflows. `needs:` enforces ordering.

### `terraform.yml` — 16 steps
```
Checkout → Preflight validation → Diagnose OIDC claims → Display config
→ Configure AWS credentials (OIDC) → Verify AWS identity
→ Bootstrap state bucket → Setup Terraform → Init → Format check
→ Validate → State diagnostic → Discover AL2023 AMI → Plan
→ Apply with live CloudFormation diagnostics → Upload diagnostics
```
Notable design choices:
- **"Diagnose GitHub OIDC Claims"** prints the token's claims before authenticating. When the trust policy rejects you, this shows exactly which `sub` was presented — turning an opaque STS error into a two-second fix.
- **"Verify AWS Identity"** asserts the assumed role matches `AWS_EXPECTED_ROLE_NAME`. Prevents silently deploying with the wrong identity.
- **"Bootstrap Terraform State Bucket"** makes the pipeline self-healing if the bucket is missing.
- **Step 15** is the integration point with `deployment-monitor-systam/` — apply and live CloudFormation diagnosis run together.
- **Step 16** uploads diagnostics as artifacts, so a failed run leaves evidence behind.
- `concurrency: terraform-${{ repo }}-${{ ref }}` with `cancel-in-progress: false` — CI-level state locking.

### `docker.yml` — 18 steps
```
Checkout → Validate config → AWS credentials → Verify identity
→ ECR login → Verify ECR repo + get URI → Build image
→ Verify curl exists in image → Test container HTTP health check
→ Create immutable URI → Tag → Push → Verify image in ECR
→ Get CFN network outputs → Validate network resources
→ Deploy/update ECS → Verify ECS stack → Summary
```
Two steps are worth singling out:
- **"Verify curl Exists in Docker Image"** — the ECS health check is `curl -f http://localhost/`. If curl is missing, the task fails health checks in production with a confusing error. This step catches it at build time.
- **"Test container HTTP health check"** — runs the container in CI and curls it *before* pushing. A broken image never reaches ECR.

### `kubernetes.yml` — 19 steps
```
Checkout → AWS credentials → Verify identity → Get ECR info
→ Verify ECR image exists → Verify EKS cluster → Verify node group
→ Install kubectl → Install envsubst → Configure kubectl
→ Verify connection → Validate manifests
→ Deploy Namespace → ConfigMap → Deployment → Service
→ Verify service → Verify resources → Verify rollout
```
- **`aws ecr describe-images` before deploying** turns a future `ImagePullBackOff` into an immediate, clear failure.
- **`envsubst`** substitutes the ECR image URI into `deployment.yaml` at apply time — the manifest stays generic and environment-agnostic in git.
- Manifests apply in strict dependency order: Namespace must exist before anything can be placed in it; ConfigMap before the Deployment that mounts it.

### `delete.yml` — 24 steps
```
Validate "DESTROY" typed exactly → Validate config → Verify OIDC
→ Credentials → Identity → Terraform init → State list before destroy
→ Check main stack → Determine EKS version → Install kubectl
→ Cleanup Kubernetes resources → Wait for AWS resource cleanup
→ Delete ECS stack → Delete ECR images → Verify ECR cleanup
→ Terraform destroy → Verify state after destroy
→ Verify main stack / ECS stack / ECR / EKS deletion
→ Optionally delete Terraform backend → Final verification
```
Destruction is the mirror image of creation, in reverse dependency order. **"Wait For Kubernetes AWS Resource Cleanup"** is the step most people forget: a Kubernetes `Service` of type `LoadBalancer` creates a real AWS ELB outside CloudFormation's knowledge. Destroying the VPC before that ELB is gone produces a `DependencyViolation` that blocks teardown. Deleting the Kubernetes resources first and *waiting* solves it.

Two independent safety gates: the typed `DESTROY` string, and a separate boolean for the state bucket — because losing state is far worse than losing infrastructure.

---

## 6. `IAM/` — the identity layer

Nine JSON documents defining every permission boundary in the lab.

| File | Statements | Purpose |
|---|---|---|
| `github-actions-trust-policy.json` | `GitHubActionsOIDCTrust` | **The most important file here.** Allows `sts:AssumeRoleWithWebIdentity` from the GitHub OIDC provider, conditioned on `aud = sts.amazonaws.com` and a `sub` matching your repo. This condition is the only thing stopping any other GitHub repo on earth from assuming your role |
| `aws-hybrid-iac-lab-GitHubActionsPolicy.json` | 1 statement, 18 service prefixes | The main deployment permission set: cloudformation, ec2, ecs, ecr, eks, elasticloadbalancing, rds, dynamodb, lambda, apigateway, s3, iam, kms, logs, secretsmanager, ssm, sts, autoscaling |
| `github-actions-terraform-backend-policy.json` | 3 statements | Split by concern: bucket management, object read/write, and lockfile operations. Cleanly illustrates what S3-native state locking actually requires |
| `iam-policiesgithub-ci-cd-cloudformation-passrole-policy.json` | `PassCharlieCafeCloudFormationRole` | `iam:PassRole` only. Lets CI hand the execution role to CloudFormation **without holding that role's permissions itself** — the core of privilege separation |
| `github-ci-cd-hybrid-iac-iam-policy.json` | `ManageHybridIaCCloudFormationExecutionRole` | 5 IAM actions scoped to managing the execution role |
| `github-ci-cd-user-iam-role-management.json` | `ManageGitHubActionsRoleTrustPolicy` | Update the role's own trust policy |
| `github-ci-cd-user-aws-manager-policies.json` | 13 statements | Broad EC2/ELB/CloudWatch/AutoScaling/SSM/S3/CFN access, plus service-linked-role permissions |
| `github-ci-cd-user-combined-access.json` | 23 statements | Everything above, merged, plus CloudFront cleanup permissions |
| `GitHub-Actions.json` | 6 statements | Focused subset: Lambda, EC2/SSM, Secrets Manager, ECR, ECS, PassRole |

### The three-identity model

```
┌─────────────────────────────────────────────────────────────┐
│ IDENTITY 1 — GitHub Actions OIDC role                       │
│ aws-hybrid-iac-lab-GitHubActions                            │
│ Credentials: short-lived STS, minted per job                │
│ Can: run Terraform, call CloudFormation, push to ECR,       │
│      talk to EKS, and iam:PassRole the execution role       │
│ Cannot: act as the execution role                           │
└──────────────────────────┬──────────────────────────────────┘
                           │ iam:PassRole
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ IDENTITY 2 — CloudFormation execution role                  │
│ hybridiaclab-dev-CloudFormationExecutionRole                │
│ Trusted by: cloudformation.amazonaws.com only               │
│ Can: create every AWS resource the nested stacks need       │
│ Cannot: be assumed by a human or by GitHub Actions          │
└──────────────────────────┬──────────────────────────────────┘
                           │ creates
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ IDENTITY 3 — Workload roles                                 │
│ EC2 instance role · Lambda execution role ·                 │
│ ECS task execution role · EKS cluster + node roles          │
│ Each scoped to exactly one workload's needs                 │
└─────────────────────────────────────────────────────────────┘
```

**Why this matters:** if the GitHub Actions role were compromised, the attacker gets CI permissions — not the union of every service permission CloudFormation holds. `iam:PassRole` is the hinge. Understanding it well is a genuine senior-level signal.

---

## 7. `docker/` — the application artifact

| File | Contents |
|---|---|
| `app/Dockerfile` | `FROM nginx:alpine` → `apk add --no-cache curl` → `COPY app/index.html` → `EXPOSE 80` → `CMD ["nginx","-g","daemon off;"]` |
| `app/docker-compose.yml` | Builds from the same Dockerfile, maps `8080:80`, health check `curl -f http://localhost/`, `restart: unless-stopped` |
| `app/src/index.html` | The application page |

### The health-check alignment chain

This is the detail most learners miss, and it's called out explicitly in the Dockerfile comments:

```
Dockerfile      →  RUN apk add --no-cache curl
     │
docker-compose  →  healthcheck: curl -f http://localhost/
     │
docker.yml CI   →  "Verify curl Exists" + "Test container HTTP health check"
     │
ecs.yaml        →  HealthCheck: curl -f http://localhost/ || exit 1
     │
ALB target grp  →  HealthCheckProtocol: HTTP, port 80
```

The *same* test runs at five layers. If it passes on your laptop, it passes on Fargate. If someone removes `apk add curl`, three separate gates catch it before production.

Two other deliberate choices:
- **`daemon off;`** — Docker needs a foreground PID 1. Without it the container exits immediately.
- **`EXPOSE 80` is documentation only** — it publishes nothing. ECS and the ALB configure the actual networking.

---

## 8. `kubernetes/` — the workload layer

Four manifests applied in strict order.

| File | Kind | Key configuration |
|---|---|---|
| `namespace.yaml` | Namespace | `hybridiaclab` — logical isolation boundary |
| `configmap.yaml` | ConfigMap | `hybridiaclab-config`: `APP_ENV`, `APPLICATION_NAME`, `ENVIRONMENT`, `AWS_REGION`. Configuration decoupled from the image |
| `deployment.yaml` | Deployment | 1 replica, `RollingUpdate` with `maxSurge: 1` / `maxUnavailable: 0`, image URI substituted at deploy time |
| `service.yaml` | Service | `type: LoadBalancer`, selector `app: hybridiaclab-app` |

All four carry the standard Kubernetes recommended labels (`app.kubernetes.io/name`, `component`, `part-of`, `environment`, `managed-by`) — this is the convention that makes `kubectl get all -l app.kubernetes.io/part-of=hybridiaclab` work as a real operational tool.

**`maxUnavailable: 0` with `maxSurge: 1`** means: create the new pod, wait for it to be Ready, *then* remove the old one. Genuine zero downtime. The reverse (`maxUnavailable: 1, maxSurge: 0`) would drop capacity to zero on a single-replica deployment.

**`type: LoadBalancer` creates a real AWS ELB** that Kubernetes manages — not CloudFormation. This is the source of the teardown ordering problem handled in `delete.yml`.

**The ECS/EKS duality:** the *same* image runs in both. This is the clearest possible demonstration that the container is the portable unit and the orchestrator is a substitutable platform decision.

---

## 9. `scripts/` — the operator toolkit

Roughly 30 scripts. They fall into six functional families.

### Family 1 — Preflight and validation (run before you deploy)

| Script | What it does |
|---|---|
| `preflight.ps1` | Verifies tool installation, AWS credentials, and configuration are all present and coherent |
| `pre-push-check.ps1` | The local CI gate. Runs the same validation the pipeline will, so you fail on your laptop in 30 seconds rather than in Actions in 10 minutes |
| `validate-cfn.ps1` | `aws cloudformation validate-template` across every template |
| `verify-hybrid-iac-templates.ps1` | Terraform validate + CloudFormation validate together — checks both languages in one pass |
| `audit-cloudformation-lab.ps1` | Full nested-stack preflight audit: parameter/output matching, template references, dependency ordering |
| `cloudformation-validation-diagnostic.ps1` | Deeper CFN diagnostics with structured report output to `report-log/` |

### Family 2 — Identity and CI/CD verification

| Script | What it does |
|---|---|
| `verify-github-aws-oidc.ps1` | Walks the entire OIDC trust chain: provider exists → role exists → trust policy `sub` matches → assume-role succeeds |
| `verify-github-ci-cd.ps1` | Validates workflow configuration, repository variables, and permission wiring |
| `GitHub-Login.ps1` | Browser-based `gh` CLI authentication on Windows |

### Family 3 — Architecture verification (run after you deploy)

| Script | What it does |
|---|---|
| `verify-hybrid-iac-architecture.ps1` | Asserts deployed reality matches intended architecture — subnets in the right AZs, RDS private, security groups chained correctly |
| `aws-hybrid-iac-verification-lab.ps1` | The master suite (4,366 lines). Writes timestamped evidence to `scripts/verification-reports/` |
| `verify-lab.sh` | Bash equivalent — CloudFormation + Docker verification |

**This family is the one that separates a lab from a portfolio piece.** Anyone can deploy infrastructure. Producing timestamped, reproducible evidence that it is correct is an engineering practice.

### Family 4 — Build and deploy helpers

| Script | What it does |
|---|---|
| `terraform-plan.ps1` | Wrapper for a consistent local plan |
| `build-docker.ps1` | Local image build matching CI parameters |
| `ecr-login.sh` | Manual `aws ecr get-login-password` → `docker login` |
| `docker-build-push.sh` | Manual build-and-push, mirroring what `docker.yml` automates |
| `bootstrap-terraform-state.sh` | Bash version of the Layer 0 bootstrap |
| `go-aws-lab.ps1` | The top-level launcher / menu |
| `how to run github.txt` | Operator quick-reference notes |

### Family 5 — EC2 lifecycle (hands-on practice inside the VPC)

| Script | What it does |
|---|---|
| `ec2-userdata.sh` | Launch-time bootstrap for Amazon Linux 2023 |
| `ec2-setup.sh` | Initial post-launch setup |
| `ec2-docker-setup.sh` | Installs Docker and runs the app on EC2 |
| `github-ec2-setup.sh` | Configures SSH keys and clones/updates the repo on the instance |
| `verify-ec2-tools.sh`, `scriptsec2-verify.sh` | Confirm the instance has everything it needs |
| `diagnose-charlie-cafe-ec2.sh` | **Read-only** diagnostics — explicitly non-mutating, the correct design for a debug tool |
| `aws-rds-cafe-lab.sh` | A focused RDS connectivity exercise from EC2 |

### Family 6 — Monitoring and cleanup

| Script | What it does |
|---|---|
| `Monitor-CloudFormation.ps1` | Live stack event tailing |
| `cleanup.sh` | Local Docker cleanup |
| `force-clean-charlie-cafe.sh` | Aggressive EC2 cleanup |
| `aws-full-cleanup.ps1` | Region-wide sweep for orphaned resources — the backstop when the destroy workflow leaves something behind |

### `scripts/verification-reports/`
Timestamped output (`hybrid-iac-verification-20260907-152752.txt` and similar). Committed deliberately: proof the lab ran and passed at a given point in time.

**The PowerShell/Bash split is not arbitrary.** PowerShell scripts run on the *operator's workstation* (Windows-first). Bash scripts run on *Amazon Linux* — EC2 instances and CI runners. Each targets its native environment.

---

## 10. `deployment-monitor-systam/` — the observability layer

The most original component in the repository.

### The problem

The standard IaC failure loop:
```
terraform apply → wait 12 minutes → "Error: creating CloudFormation Stack:
  ... ROLLBACK_COMPLETE" → open the console → find the stack →
  find the nested stack → scroll events → locate the real cause
```
Terraform reports *that* a stack failed. It almost never reports *which nested resource* failed and *why*, because from Terraform's perspective the entire root stack is a single opaque resource.

### The solution

```
                 Start-Deployment.ps1
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
  Monitor-CloudFormation.ps1   terraform apply
  (polls stack + nested          (authoritative)
   stack events every 3s)
            │                         │
            └────────────┬────────────┘
                         ▼
                Generate-Report.ps1
                  matches events against
                  failure-rules.json
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
   deployment-summary.md        diagnosis.json
```

| File | Role |
|---|---|
| `Start-Deployment.ps1` | Orchestrator. Parameters: `TerraformWorkingDirectory`, `StackName`, `Region`, `MonitorDirectory`, `OutputDirectory`, `TerraformPlanFile`, `AutoApprove`, `PollSeconds` (default 3), `MonitorTimeoutMinutes` (default 120). Runs monitoring and apply concurrently; Terraform stays authoritative for the exit code |
| `Monitor-CloudFormation.ps1` | Polls root and nested stack events live, streaming them as they happen |
| `Generate-Report.ps1` | Correlates Terraform output with CloudFormation events, classifies the failure, writes `deployment-summary.md` and `diagnosis.json` |
| `failure-rules.json` | The knowledge base — 12 categories with pattern lists and recommendations |
| `README.md` | 5,252 lines documenting the five-layer design |
| `GitHub Actions Step 15.md` | Documents the integration with `terraform.yml` Step 15 |

### The failure-rules knowledge base

| Priority | Category | Example patterns |
|---|---|---|
| 1 | IAM / PERMISSIONS | `AccessDenied`, `is not authorized to perform`, `UnauthorizedOperation` |
| 1 | IAM / PASSROLE | `iam:PassRole`, `cannot pass role` |
| 1 | EKS / NODE PROVISIONING | `NodeCreationFailure`, `Node group` |
| 1 | NETWORKING | `VPC`, `Subnet`, `RouteTable`, `SecurityGroup`, `NatGateway`, `availability zone` |
| 1 | CLOUDFORMATION TEMPLATE | template syntax and structure errors |
| 1 | S3 / CLOUDFORMATION TEMPLATE | template-bucket access failures |
| 2 | RESOURCE NAMING / EXISTENCE | already-exists and name-collision errors |
| 2 | LAMBDA / API GATEWAY / RDS / DYNAMODB | service-specific failures |
| 3 | ROLLBACK | rollback events — deliberately lowest priority |

**The priority design is the clever part.** A rollback event is a *symptom*; an `AccessDenied` is a *cause*. When both appear, priority ordering surfaces the cause. Priority 3 for ROLLBACK means "this is what you'll see first and it will tell you the least."

**Note:** the directory name contains a typo (`systam` → `system`). Cosmetic, but worth fixing — renaming requires updating the reference in `terraform.yml` Step 15.

---

## 11. `report-log/` — the audit evidence layer

Four structured text reports produced by `audit-cloudformation-lab.ps1` and `cloudformation-validation-diagnostic.ps1`:

| File | Contents |
|---|---|
| `AWS-Hybrid-IaC-Audit-SUMMARY.txt` | Overall verdict and audit date |
| `AWS-Hybrid-IaC-Audit-PASS.txt` | Everything that validated correctly (~955 lines) |
| `AWS-Hybrid-IaC-Audit-WARNING.txt` | Non-blocking issues worth reviewing |
| `AWS-Hybrid-IaC-Audit-ERROR.txt` | Blocking failures |

**The severity-separated design is intentional.** One combined log forces you to read everything. Four files let you open ERROR first, fix, re-run, then read WARNING at leisure. This mirrors how real compliance and audit tooling reports findings.

---

## 12. `docs/` and `logs/` — proposed directories

Neither exists in the current repository. Both are worth adding.

### Proposed `docs/`
```
docs/
├── ARCHITECTURE.md          ← this document
├── OIDC-SETUP.md            ← move the current README's OIDC content here
├── RUNBOOK.md               ← operational procedures: deploy, rollback, recover
├── TROUBLESHOOTING.md       ← expanded failure catalogue
├── COST-ANALYSIS.md         ← per-resource hourly cost breakdown
├── SECURITY.md              ← threat model and known issues
├── DECISIONS/               ← Architecture Decision Records
│   ├── 001-why-hybrid-iac.md
│   ├── 002-why-ecs-outside-root-stack.md
│   ├── 003-why-oidc-over-access-keys.md
│   └── 004-why-sha-tags-over-latest.md
└── diagrams/                ← exported architecture diagrams
```

**Architecture Decision Records are the highest-value addition.** An ADR records *what* was decided, *why*, what alternatives were rejected, and what the consequences are. The four listed above are already implicit in the repository's comments — writing them formally makes your reasoning legible to a reviewer in two minutes instead of twenty.

### Proposed `logs/`
```
logs/
├── terraform/       plan and apply output per run
├── cloudformation/  stack event dumps
├── deployment/      Start-Deployment.ps1 output
└── .gitignore       (ignore *, keep .gitignore)
```

**Critical:** `logs/` should be gitignored except for the `.gitignore` itself. Logs can contain account IDs, ARNs, resource identifiers, and occasionally secrets. `report-log/` and `verification-reports/` are committed because they are curated, reviewed evidence. Raw logs are not.

---

## 13. Root-level files

| File | Role |
|---|---|
| `README.md` | Entry point — purpose, setup, deployment, learning path |
| `.gitignore` | Excludes credentials, Terraform working directories, local settings. ⚠️ Does not currently exclude `*.tfstate` or `*.tfplan` — see §20.6 |
| `.dockerignore` | Keeps build context small and prevents secrets from entering an image layer |

---

# PART III — HOW IT ALL CONNECTS

## 14. How Terraform and CloudFormation work together

### 14.1 The bridge resource

Everything hinges on twenty lines in `cloudformation.tf`:

```hcl
resource "aws_cloudformation_stack" "main" {
  name         = "${local.name_prefix}-MainStack"
  template_url = "https://${aws_s3_bucket.cloudformation_templates
                   .bucket_regional_domain_name}/main.yaml"
  iam_role_arn = aws_iam_role.cloudformation_execution.arn
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"]

  parameters = {
    ProjectName      = var.project_name
    Environment      = var.environment
    TemplateBucket   = aws_s3_bucket.cloudformation_templates.bucket
    TemplatePrefix   = ""
    AmiId            = data.aws_ami.amazon_linux_2023.id
    DatabaseUsername = var.database_username
  }

  depends_on = [
    aws_s3_object.cloudformation_templates,
    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}
```

Five things happen in these lines, each of which is worth understanding:

**`template_url`** — not `template_body`. CloudFormation requires nested-stack templates to be in S3, and inline bodies cap at 51,200 bytes. Using a URL also means Terraform doesn't need to parse or understand the YAML at all.

**`iam_role_arn`** — the privilege-separation hinge. Without it, CloudFormation would execute with *the caller's* permissions, meaning the GitHub Actions role would need the union of every AWS permission the lab touches. With it, CI needs only `cloudformation:*` plus `iam:PassRole`.

**`capabilities`** — an explicit acknowledgement that this stack creates IAM resources, including named ones. AWS forces you to opt in, because a template that silently creates IAM roles is a privilege-escalation vector.

**`parameters`** — the entire Terraform → CloudFormation contract. Six values. Note `AmiId` comes from a *live* data-source lookup, so CloudFormation receives a current patched AMI without ever knowing how it was resolved.

**`depends_on`** — explicit because the dependency is real but invisible to Terraform's dependency graph. CloudFormation will download `nested/vpc.yaml` from S3, but nothing in the `aws_cloudformation_stack` arguments *references* those objects. Without `depends_on`, Terraform might create the stack before the templates finish uploading.

### 14.2 The template upload mechanism

```hcl
resource "aws_s3_object" "cloudformation_templates" {
  for_each = local.cloudformation_templates
  bucket   = aws_s3_bucket.cloudformation_templates.id
  key      = each.key == "main" ? "main.yaml" : "nested/${basename(each.value)}"
  source   = each.value
  etag     = filemd5(each.value)
}
```

Six lines upload twelve templates and maintain them. `filemd5` is the important part: Terraform hashes each file's contents. Edit `vpc.yaml`, and the etag changes, the object updates, the stack's template changes, and CloudFormation performs an update. Leave it alone, and nothing happens. **This is what makes CloudFormation templates behave like Terraform-managed resources — you get change detection on YAML files.**

### 14.3 The directory structure mirrors the S3 structure

```
Local filesystem                       S3 bucket
infrastructure/cloudformation/
├── main.yaml                    →     main.yaml
└── nested/                            nested/
    ├── vpc.yaml                 →       vpc.yaml
    ├── ec2.yaml                 →       ec2.yaml
    └── ...                      →       ...
```

`main.yaml` builds child URLs as `https://${TemplateBucket}.s3.amazonaws.com/${TemplatePrefix}nested/vpc.yaml`. The local layout and the S3 layout are identical by construction — so what you read in the repo is exactly what CloudFormation fetches.

### 14.4 The ECS exclusion — the most important design decision

The naive design:
```
Terraform → CloudFormation → ECR repository
                           → ECS service → needs image
                                             ↑
                                    DOES NOT EXIST YET
```
The ECS task definition requires an image URI. On a first deployment the repository is empty. The stack fails, rolls back, and takes the ECR repository with it. Deadlock.

The lab's design:
```
PHASE 1 — INFRASTRUCTURE (Terraform → CloudFormation)
   VPC · S3 · DynamoDB · ECR(empty) · Lambda · API GW ·
   CloudFront · EC2 · EKS · RDS
                    │
                    ▼  ECR repository now exists
PHASE 2 — APPLICATION (GitHub Actions)
   build image → tag :${GITHUB_SHA} → push to ECR
                    │
                    ▼  image now exists
PHASE 3 — SERVICE (GitHub Actions deploys ecs.yaml)
   ECS stack created with EcrImageUri = <uri>:<sha>
```

`ecs.yaml` sits in the same folder as the other templates and uses the same CloudFormation language — it is simply deployed at a different *time*, by a different *actor*, because its inputs become available at a different *point in the lifecycle*.

**The generalisable lesson:** IaC declares *where artifacts live*; CI/CD *creates the artifacts*; deployment happens *after both exist*. Any time you find yourself blocked by a circular dependency in IaC, look for a lifecycle boundary you've accidentally crossed.

### 14.5 Two state models side by side

| | Terraform | CloudFormation |
|---|---|---|
| State location | S3 bucket you manage | Inside AWS, managed for you |
| Lock mechanism | S3 conditional writes (`use_lockfile`) | Automatic, per-stack |
| Drift detection | `terraform plan` | `detect-stack-drift` |
| Rollback on failure | None — you're left in a partial state | Automatic to the last good state |
| Can lose state? | Yes, if the bucket is deleted | No |
| Multi-cloud | Yes | AWS only |
| Preview changes | `plan` — excellent | Change sets — adequate |

Running both means you experience both models in one deployment. When Terraform errors mid-apply, you deal with a partially-applied state. When CloudFormation errors, you watch an automatic rollback. The contrast is the lesson.

---

## 15. How GitHub Actions drives both languages

### 15.1 The authentication chain

```
GitHub Actions job starts
        │
        │ permissions: id-token: write
        ▼
GitHub mints an OIDC JWT
  claims: iss = token.actions.githubusercontent.com
          aud = sts.amazonaws.com
          sub = repo:<owner>/<repo>:ref:refs/heads/main
        │
        ▼
aws-actions/configure-aws-credentials@v5.1.1
  calls sts:AssumeRoleWithWebIdentity with that JWT
        │
        ▼
AWS validates against the OIDC provider,
  checks the trust policy conditions on aud and sub
        │
        ▼
Temporary credentials (~1 hour) injected into the job env
        │
        ▼
Terraform, AWS CLI, Docker, and kubectl all use them automatically
```

**Nothing is stored.** No secret, no key, no rotation schedule. The credentials expire when the job ends. This is the single most important security property of the lab.

The pipeline then does something most tutorials skip: **it verifies the identity it received.** `aws sts get-caller-identity` is compared against `AWS_EXPECTED_ROLE_NAME`. If they differ, the job stops. Assuming the wrong role and deploying anyway is a failure mode worth designing against.

### 15.2 How Actions drives Terraform

```
hashicorp/setup-terraform (pinned to TF_VERSION = 1.15.7)
        ↓
terraform init   — connects to S3 backend, acquires lock
        ↓
terraform fmt -check   — style gate; fails on unformatted code
        ↓
terraform validate     — syntax and internal consistency
        ↓
terraform plan -out=tfplan
        ↓
terraform apply tfplan   — applies the exact reviewed plan
```

Environment variables shape Terraform's behaviour for automation:
- `TF_IN_AUTOMATION=true` — suppresses interactive suggestions in output
- `TF_INPUT=false` — never prompt; fail instead of hanging on missing input
- `TF_AUTO_APPROVE=true` — no confirmation gate (appropriate for a lab, not for production)

**Applying the saved plan file, not re-planning**, is the correct pattern: it guarantees that what was reviewed is what gets applied, with no drift between plan and apply.

### 15.3 How Actions drives CloudFormation

Two distinct mechanisms, and understanding the difference matters:

**Indirectly, for the main stack** — Actions runs Terraform; Terraform manages `aws_cloudformation_stack.main`. Actions never calls CloudFormation directly for these resources.

**Directly, for ECS** — `docker.yml` calls `aws cloudformation deploy --template-file infrastructure/cloudformation/nested/ecs.yaml` with parameters it has gathered at runtime.

**Directly, to read** — every workflow queries stack outputs:
```bash
aws cloudformation describe-stacks \
  --stack-name "$MAIN_STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri'].OutputValue" \
  --output text
```
**This query is the mechanism that makes the whole lab work without hardcoded values.** The application layer discovers the infrastructure layer at runtime. Change the region, the account, or the project name, and nothing breaks — the values are looked up, not assumed.

### 15.4 How Actions drives Kubernetes

```
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION
```
This one command writes a kubeconfig that authenticates using the *current AWS credentials* — which are the OIDC-derived temporary credentials. So the identity chain runs unbroken:

```
GitHub OIDC token → AWS STS role → EKS cluster authentication → kubectl
```

No kubeconfig file is stored. No service account token is committed. `envsubst` then injects the ECR image URI into `deployment.yaml` before `kubectl apply`, so the manifest in git stays free of account-specific values.

### 15.5 Reusable workflows

`terraform.yml`, `docker.yml`, and `kubernetes.yml` all declare:
```yaml
on:
  workflow_call:      # callable from main-deploy.yaml
  workflow_dispatch:  # runnable manually from the Actions tab
```
This dual trigger is a small design decision with large practical value: the full pipeline runs automatically on push, but any single stage can be re-run in isolation when debugging. Nobody wants to re-run a fourteen-minute Terraform apply to test a Dockerfile change.

### 15.6 Concurrency as distributed locking

```yaml
concurrency:
  group: "hybrid-iac-infrastructure-${{ github.repository }}"
  cancel-in-progress: false
```

Two layers of protection against concurrent mutation:
- **Terraform's S3 lockfile** stops two applies corrupting state
- **GitHub's concurrency group** stops two *workflows* running at all

`cancel-in-progress: false` matters: cancelling a running `terraform apply` leaves a held lock and a partially-created stack. Queuing is correct; cancelling is destructive.

---

## 16. The complete parameter and output contract

Every cross-boundary value in the lab, in one table.

### Terraform → CloudFormation (6 parameters)

| Parameter | Source |
|---|---|
| `ProjectName` | `var.project_name` |
| `Environment` | `var.environment` |
| `TemplateBucket` | `aws_s3_bucket.cloudformation_templates.bucket` |
| `TemplatePrefix` | `""` |
| `AmiId` | `data.aws_ami.amazon_linux_2023.id` (live lookup) |
| `DatabaseUsername` | `var.database_username` |

### Root stack → nested stacks (selected)

| From | Value | To |
|---|---|---|
| VPCStack | `VpcId`, `PublicSubnet1Id`, `PublicSubnet2Id`, `PrivateSubnet1Id`, `PrivateSubnet2Id` | EC2, EKS, RDS, ECS |
| S3Stack | `BucketName` | CloudFrontStack |
| DynamoDBStack | `OrdersTableName`, `OrdersTableArn` | LambdaStack |
| LambdaStack | `LambdaFunctionArn` | APIGatewayStack |
| EC2Stack | `SecurityGroupId` | RDSStack (as `Ec2SecurityGroupId`) |
| EC2Stack | `EC2RoleName` | root `EC2RDSSecretsPolicy` |
| RDSStack | `DatabaseSecretArn` | root `EC2RDSSecretsPolicy` |

### CloudFormation → GitHub Actions (consumed at runtime)

| Output | Consumed by | Used for |
|---|---|---|
| `EcrRepositoryUri` | `docker.yml`, `kubernetes.yml` | Image tagging and push target |
| `EcrRepositoryName` | `kubernetes.yml`, `delete.yml` | Image verification and cleanup |
| `VpcId`, 4 subnet IDs | `docker.yml` | ECS stack parameters |
| `EKSClusterName` | `kubernetes.yml`, `delete.yml` | kubeconfig and teardown |
| `ApiEndpoint`, `CloudFrontDomainName`, `RDSDatabaseEndpoint` | operators | Testing and verification |

### GitHub Actions → ECS / Kubernetes

| Value | Form | Destination |
|---|---|---|
| Image URI + tag | `<uri>:${GITHUB_SHA}` | `ecs.yaml` parameter `EcrImageUri` |
| Image URI + tag | `<uri>:${GITHUB_SHA}` | `deployment.yaml` via `envsubst` |

**Read the whole table top to bottom and you have the complete data flow of the lab.** Every arrow is a named value. There are no hidden couplings.

---

## 17. The four handoff points

If you understand these four moments, you understand the system.

**Handoff 1 — Terraform → CloudFormation**
*Mechanism:* `aws_cloudformation_stack` with a parameter map
*Contract:* 6 named parameters
*Fails when:* a parameter is missing or misspelled, or templates haven't finished uploading
*Debug at:* CloudFormation stack events, root stack

**Handoff 2 — CloudFormation → GitHub Actions**
*Mechanism:* `aws cloudformation describe-stacks --query`
*Contract:* 28 root-stack outputs
*Fails when:* an output name changes, or the stack isn't in a complete state
*Debug at:* run `describe-stacks` manually and compare output keys

**Handoff 3 — GitHub Actions → ECS**
*Mechanism:* `aws cloudformation deploy` with `EcrImageUri`
*Contract:* the image URI + SHA tag, plus VPC and subnet IDs
*Fails when:* the image doesn't exist, or the health check fails
*Debug at:* ECS task stopped-reason, then CloudWatch log group

**Handoff 4 — GitHub Actions → Kubernetes**
*Mechanism:* `envsubst` into `deployment.yaml`, then `kubectl apply`
*Contract:* the image URI + SHA tag
*Fails when:* the node role can't pull from ECR, or the image tag is absent
*Debug at:* `kubectl describe pod`, then `kubectl logs`

---

## 18. Failure domains and blast radius

| If this breaks | Blast radius | Recovery |
|---|---|---|
| State bucket deleted | **Total.** Terraform loses track of everything | Restore from S3 versioning, or rebuild state with `import` |
| State lock stuck | Blocks all Terraform | `terraform force-unlock <ID>` — only when certain nothing is running |
| OIDC trust policy wrong | All pipelines fail at auth | Fix the `sub` condition; the "Diagnose OIDC Claims" step shows the presented value |
| Template bucket deleted | Stack updates fail; existing resources survive | Re-run Terraform; `template_objects.tf` re-uploads |
| VPC stack fails | Everything downstream fails — EC2, EKS, RDS, ECS all need subnets | Fix and redeploy; VPC is the root dependency |
| ECR repository deleted | Docker and Kubernetes workflows fail; running tasks survive until restart | Re-run Terraform, then `docker.yml` |
| ECS stack fails | ECS path only. EKS, Lambda, CloudFront unaffected | Redeploy `ecs.yaml`; this is *why* it's a separate stack |
| EKS node group fails | Kubernetes path only | Check node role, subnets, and quotas |
| Kubernetes LB not cleaned up | **Blocks VPC deletion** during teardown | Delete k8s resources and wait before destroying — `delete.yml` handles this |

**The pattern:** the separation of ECS into its own stack isn't only about the dependency problem — it also contains the blast radius. An application deployment failure cannot roll back your VPC.

---

# PART IV — CONCEPTS

## 19. Every technical concept in this lab

### Infrastructure as Code
Declarative vs imperative · desired-state reconciliation · idempotency · state management · remote state · state locking · drift · plan/apply lifecycle · modularity · variable validation · dependency graphs (implicit vs explicit) · resource importing · provider version pinning · nested stacks · stack parameters and outputs · cross-stack references · change sets · automatic rollback · execution roles · template storage in S3 · `for_each` iteration · content-hash change detection

### CI/CD
Pipeline stages · reusable workflows · orchestration with `needs:` · job dependencies · concurrency control · fail-fast validation · preflight checks · build artifacts · immutable artifacts · artifact promotion · deployment gating · manual approval patterns · workflow inputs · repository variables vs secrets · conditional execution · artifact upload for post-mortems · self-healing pipelines

### Identity and security
OIDC / workload identity federation · JWT claims (`iss`, `aud`, `sub`) · `sts:AssumeRoleWithWebIdentity` · trust policies vs permission policies · `iam:PassRole` · privilege separation · least privilege · service-linked roles · instance profiles · temporary credentials · credential rotation elimination · secrets management · AWS-managed database passwords · encryption at rest · encryption in transit · public access blocking · Origin Access Control · security group chaining · network isolation via private subnets · identity verification after authentication

### Containers
Image layering · base image selection · build context · `.dockerignore` · `EXPOSE` semantics · foreground process / PID 1 · container health checks · multi-layer health-check alignment · image tagging strategy · immutable vs mutable tags · registry authentication · image scanning (roadmap) · local/CI/production parity

### Orchestration — ECS
Task definitions · services · desired count · Fargate vs EC2 launch types · `awsvpc` networking · task execution role vs task role · ALB integration · target groups · `TargetType: ip` vs `instance` · listeners · container health checks · CloudWatch log groups · rolling deployments

### Orchestration — Kubernetes
Clusters and managed node groups · namespaces · ConfigMaps · Deployments · ReplicaSets · Pods · Services · `type: LoadBalancer` · label selectors · recommended label conventions · RollingUpdate strategy · `maxSurge` / `maxUnavailable` · rollout status · declarative apply · manifest ordering · `envsubst` templating · kubeconfig · IAM-to-Kubernetes authentication

### Networking
VPC and CIDR planning · subnetting · public vs private subnets · Availability Zones and multi-AZ design · Internet Gateway vs NAT Gateway · route tables and associations · Elastic IPs · security groups as stateful firewalls · SG-to-SG references · load balancer schemes · DNS via ALB and CloudFront

### Data
Relational vs NoSQL · RDS engine and version selection · DB subnet groups · storage encryption · Multi-AZ vs Single-AZ · public accessibility · managed master passwords · DynamoDB partition keys · Secrets Manager integration

### Serverless and edge
Lambda runtimes · execution roles · resource-based policies (invoke permissions) · API Gateway REST APIs · resources, methods, deployments, stages · CDN distribution · origins · Origin Access Control

### Observability and operations
Deployment monitoring · event polling · log correlation · root-cause analysis · rule-based failure classification · priority-ordered diagnosis · severity-separated reporting · verification as evidence · timestamped audit trails · read-only diagnostic tooling · runbooks

### Engineering practice
Separation of concerns · lifecycle boundaries · contract-driven interfaces · blast-radius containment · reverse-order teardown · cost awareness as a design constraint · guarded destructive operations · self-documenting code · naming conventions via a single prefix · consistent resource tagging · local/CI parity · shift-left validation

---

## 20. Design decisions and their trade-offs

Each of these is a decision visible in the code. Be able to defend it *and* name its cost.

**20.1 Hybrid IaC rather than Terraform-only**
*Gain:* CloudFormation's automatic rollback and AWS-native state; mirrors real brownfield environments; demonstrates both tools.
*Cost:* two languages to maintain; two mental models; Terraform sees the entire stack as one opaque resource.

**20.2 ECS outside the root stack**
*Gain:* breaks the image/service circular dependency; contains blast radius; correctly separates lifecycles.
*Cost:* two-phase deployment; one template in the folder isn't referenced by the parent, which surprises readers.

**20.3 OIDC instead of access keys**
*Gain:* no stored credentials; automatic expiry; per-repo and per-branch scoping.
*Cost:* more setup; failures are harder to diagnose (mitigated by the OIDC claims diagnostic step).

**20.4 SHA tags instead of `latest`**
*Gain:* traceability; reliable rollback; ECS actually pulls the new image.
*Cost:* ECR accumulates images without a lifecycle policy — worth adding.

**20.5 Exact Terraform version pin (`= 1.15.7`)**
*Gain:* identical behaviour everywhere; no surprise provider or core changes.
*Cost:* upgrading is a deliberate, blocking action; contributors must match exactly.

**20.6 Known issues to correct**
| Issue | Why it matters | Fix |
|---|---|---|
| `terraform.tfstate` committed | State can contain sensitive values | Remove, gitignore `*.tfstate*`, purge history |
| `pre-push.tfplan` committed | Plans can contain sensitive values | Remove, gitignore `*.tfplan` |
| Account ID hardcoded in 4+ files | Makes the repo unforkable | Parameterise via variables |
| `TF_AUTO_APPROVE: "true"` | No human gate on infrastructure changes | Add a plan-review step or protected environment |
| `IpProtocol: -1` in security groups | Over-permissive | Narrow to required ports and sources |
| `database_username = "admin"` default | First value any scanner tries | Change the default |
| Directory typo `systam` | Cosmetic, but noticed | Rename; update `terraform.yml` Step 15 |
| No ECR lifecycle policy | Images accumulate and cost money | Add a rule to expire untagged images |

**Being able to enumerate your own project's weaknesses is a stronger signal than claiming it has none.** Present §20.6 as a backlog, not as an apology.

---

*This document describes the architecture of `aws-hybrid-iac-lab` as built. For setup and operation, see `README.md`.*
