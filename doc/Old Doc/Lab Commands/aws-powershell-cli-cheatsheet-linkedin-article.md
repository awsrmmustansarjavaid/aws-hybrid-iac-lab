# From Chaos to Clarity: 60+ PowerShell & AWS CLI Commands Every Hybrid IaC Engineer Should Know

> A field-tested cheat sheet from real Terraform + CloudFormation + GitHub Actions troubleshooting sessions.

---

## LinkedIn Post (Intro Paragraph)

Over the past few weeks I've been building a **Hybrid Infrastructure-as-Code lab** on AWS — Terraform provisioning the backend, CloudFormation deploying nested stacks (VPC, S3, ECR, ECS, EKS, RDS, Lambda, API Gateway, CloudFront), and GitHub Actions handling CI/CD via OIDC (no long-lived AWS keys!). 🚀

Along the way, I hit almost every real-world failure mode you can imagine: drifted Terraform state, orphaned IAM roles, immutable ECR tag conflicts, GitHub's new immutable OIDC subject format, missing S3 backend buckets, and CloudFormation rollback loops.

Instead of losing that knowledge in a terminal history, I turned it into a **categorized command reference** — what each command does, when to reach for it, and why it matters. Whether you're debugging Terraform state drift, auditing IAM permissions, or verifying CloudFormation templates in bulk, this list should save you hours.

Bookmark it. Share it. Add your own favorites in the comments. 👇

`#AWS #Terraform #CloudFormation #DevOps #IaC #PowerShell #GitHubActions #CloudEngineering #SRE`

---

## Table of Contents

1. [PowerShell Navigation & File Discovery](#1-powershell-navigation--file-discovery)
2. [Terraform — State, Validation & Planning](#2-terraform--state-validation--planning)
3. [Terraform — Importing Existing AWS Resources](#3-terraform--importing-existing-aws-resources)
4. [AWS IAM — Identity, Roles & Policy Auditing](#4-aws-iam--identity-roles--policy-auditing)
5. [AWS S3 — Buckets & Terraform Backend Management](#5-aws-s3--buckets--terraform-backend-management)
6. [AWS CloudFormation — Stacks, Events & Validation](#6-aws-cloudformation--stacks-events--validation)
7. [AWS ECR — Container Registry Management](#7-aws-ecr--container-registry-management)
8. [AWS Networking, Compute & Other Services](#8-aws-networking-compute--other-services)
9. [GitHub CLI — OIDC & Repository Metadata](#9-github-cli--oidc--repository-metadata)
10. [Bulk Automation — Validate Everything in One Shot](#10-bulk-automation--validate-everything-in-one-shot)
11. [Job Roles & When You'd Reach for Each Category](#11-job-roles--when-youd-reach-for-each-category)

---

## 1. PowerShell Navigation & File Discovery

**Use case:** The very first thing you do in any troubleshooting session — figuring out *where you are* and *what actually exists* on disk before touching Terraform or AWS.

### `Get-Location`
**What it does:** Prints your current working directory.
**When to use:** Before running any `terraform` command — Terraform is directory-sensitive, and running it from the wrong folder is one of the most common "No configuration files" errors.
```powershell
Get-Location
```

### `Get-ChildItem`
**What it does:** Lists files/folders (PowerShell's equivalent of `ls`/`dir`).
**When to use:** To confirm `.tf`, `.yaml`, or `.json` files exist where you expect them.
```powershell
Get-ChildItem -Filter "*.tf"
Get-ChildItem -Path . -Filter *.tf -Recurse | Select-Object FullName
Get-ChildItem -Force
```

### `Test-Path`
**What it does:** Returns `True`/`False` for whether a file or folder exists.
**When to use:** Quick existence checks before importing, deleting, or referencing a file (e.g., confirming a Terraform state file or IAM JSON policy is really there).
```powershell
Test-Path ".\infrastructure\terraform\terraform.tfstate"
Test-Path ..\..\IAM\github-ci-cd-user-combined-access.json
```

### `Select-String`
**What it does:** PowerShell's `grep` — searches file contents for a pattern.
**When to use:** Hunting for a specific configuration value (a backend block, a hardcoded secret, an old project name) across dozens of files at once.
```powershell
Get-ChildItem ".\infrastructure\terraform" -Filter "*.tf" |
    Select-String -Pattern 'backend'

Get-ChildItem -Recurse -File |
    Select-String -Pattern 'vars\.AWS_REGION|secrets\.AWS_ROLE_ARN'
```

### `Resolve-Path`
**What it does:** Converts a relative path into its full, absolute path.
**When to use:** Verifying Terraform's relative file references (e.g., `../../IAM/policy.json`) actually resolve to the folder you think they do.
```powershell
Resolve-Path ..\..\IAM
```

### `ConvertFrom-Json`
**What it does:** Parses JSON content and validates its syntax.
**When to use:** Sanity-checking an IAM policy JSON file before Terraform tries to load it — catches syntax errors early.
```powershell
Get-Content .\IAM\github-ci-cd-user-combined-access.json | ConvertFrom-Json
```

---

## 2. Terraform — State, Validation & Planning

**Use case:** The core day-to-day loop of working safely with Terraform without accidentally destroying or duplicating infrastructure.

### `terraform fmt`
**What it does:** Auto-formats `.tf` files to canonical style; `-check` reports issues without modifying files.
**When to use:** Before every commit, and in CI, to enforce consistent formatting.
```powershell
terraform fmt
terraform fmt -check -recursive
```

### `terraform validate`
**What it does:** Checks configuration syntax and internal consistency (not against real AWS resources).
**When to use:** Immediately after `terraform init`, and before every `plan`.
```powershell
terraform validate
```

### `terraform init`
**What it does:** Downloads providers/modules and configures the backend.
**When to use:** After cloning a repo, changing backend config, or adding new providers. Use `-reconfigure` when the backend definition itself has changed.
```powershell
terraform init -input=false
terraform init -reconfigure
terraform init -backend=false -input=false   # syntax-only check, skips backend
```

### `terraform plan`
**What it does:** Shows what Terraform *would* change — without changing anything.
**When to use:** Always, before `apply`. Non-negotiable in production and in any recovery scenario.
```powershell
terraform plan
terraform plan -out=tfplan
```

### `terraform apply`
**What it does:** Executes the plan and creates/updates/destroys real infrastructure.
**When to use:** Only after reviewing a clean plan. Applying an exact saved plan file avoids drift between plan and apply.
```powershell
terraform apply -auto-approve
terraform apply "tfplan"
```

### `terraform state list`
**What it does:** Lists every resource Terraform currently tracks.
**When to use:** The single most important diagnostic command when state and reality (AWS) might be out of sync.
```powershell
terraform -chdir="infrastructure/terraform" state list
terraform state list | Select-String "iam_role"
```

### `terraform state show <resource>`
**What it does:** Prints the full attributes Terraform has recorded for one resource.
**When to use:** Confirming an import brought in the correct resource with the correct attributes.
```powershell
terraform state show aws_cloudformation_stack.main
```

### `terraform state pull`
**What it does:** Downloads and prints the raw remote state (JSON).
**When to use:** Deep debugging of backend/state issues — use sparingly and never paste the full output publicly (it can contain sensitive values).

### `terraform console`
**What it does:** Opens an interactive REPL to evaluate variables, locals, and expressions.
**When to use:** Verifying computed values (like a `local.name_prefix`) actually resolve the way you expect, without running a full plan.
```powershell
terraform console
> var.project_name
> local.name_prefix
> exit
```

### `terraform providers`
**What it does:** Shows the provider requirements/tree for the current configuration.
**When to use:** Debugging version conflicts or confirming which providers a module actually pulls in.

### `terraform show`
**What it does:** Renders a saved plan or state file in human-readable form.
**When to use:** Reviewing a saved plan file offline, or converting it to text for sharing/review.
```powershell
terraform show -no-color tfplan > terraform-plan.txt
```

---

## 3. Terraform — Importing Existing AWS Resources

**Use case:** The resource already exists in AWS (created manually, by a previous run, or by CloudFormation) but Terraform doesn't know about it yet. Importing prevents Terraform from trying to recreate — and clobber — it.

### `terraform import`
**What it does:** Binds an existing AWS resource to a resource address in your Terraform configuration/state.
**When to use:** After confirming (via `state list` + AWS CLI) that a resource exists in AWS but not in Terraform's state.
```powershell
terraform import aws_iam_role.cloudformation_execution `
  "HybridIaCLab-dev-CloudFormationExecutionRole"

terraform import aws_iam_role_policy.cloudformation_lab_permissions `
  "HybridIaCLab-dev-CloudFormationExecutionRole:HybridIaCLab-dev-CloudFormationPermissions"

terraform import aws_cloudformation_stack.main hybridiaclab-dev-MainStack
```

> **Golden rule:** Never import blindly. Always run `terraform state list` and the equivalent `aws` describe/get command first to confirm what's missing and what already matches.

---

## 4. AWS IAM — Identity, Roles & Policy Auditing

**Use case:** Debugging "AccessDenied" errors, verifying OIDC trust policies, and auditing exactly what permissions a user or role has before changing anything.

### `aws sts get-caller-identity`
**What it does:** Shows the AWS account, ARN, and user/role you're currently authenticated as.
**When to use:** The first command to run in *any* AWS troubleshooting session — confirms you're not accidentally using the wrong profile or an overly-restricted CI/CD identity.
```powershell
aws sts get-caller-identity
aws sts get-caller-identity --query "{Account:Account,Arn:Arn,UserId:UserId}" --output table
```

### `aws iam get-role`
**What it does:** Returns full role metadata, including its trust (assume-role) policy.
**When to use:** Diagnosing OIDC federation issues — comparing the actual trust policy against what your GitHub Actions workflow is sending.
```powershell
aws iam get-role --role-name "aws-hybrid-iac-lab-GitHubActions"
aws iam get-role --role-name "..." --query "Role.AssumeRolePolicyDocument" --output json
```

### `aws iam get-role-policy`
**What it does:** Returns the JSON document of a specific inline policy attached to a role.
**When to use:** Confirming an inline policy (like a CloudFormation execution role's permissions) actually matches what Terraform says it deployed.
```powershell
aws iam get-role-policy `
  --role-name "HybridIaCLab-dev-CloudFormationExecutionRole" `
  --policy-name "HybridIaCLab-dev-CloudFormationPermissions"
```

### `aws iam list-role-policies` / `list-attached-role-policies`
**What it does:** Lists inline policies (former) vs. managed policies (latter) attached to a role.
**When to use:** Auditing everything a role can do — inline and managed policies are easy to conflate but behave differently.
```powershell
aws iam list-role-policies --role-name "..." --output table
aws iam list-attached-role-policies --role-name "..." --output table
```

### `aws iam list-attached-user-policies` / `list-user-policies`
**What it does:** Same distinction as above, but for an IAM user instead of a role.
**When to use:** Auditing a CI/CD service user's permission footprint.
```powershell
aws iam list-attached-user-policies --user-name "github-ci-cd-user" --output table
aws iam list-user-policies --user-name "github-ci-cd-user" --output table
```

### `aws iam list-policies --scope Local`
**What it does:** Lists customer-managed (account-specific) policies, excluding AWS-managed ones.
**When to use:** Finding the exact ARN of a custom policy you created via Terraform.
```powershell
aws iam list-policies --scope Local `
  --query "Policies[].{PolicyName:PolicyName,PolicyArn:Arn}" `
  --output table
```

### `aws iam list-entities-for-policy`
**What it does:** Shows every user, group, and role a given policy is attached to.
**When to use:** Answering "what would break if I change/delete this policy?"
```powershell
aws iam list-entities-for-policy --policy-arn "arn:aws:iam::...:policy/..." --output table
```

### `aws iam get-policy`
**What it does:** Confirms whether a managed policy exists and returns its metadata.
**When to use:** Sanity check before referencing a policy ARN elsewhere.
```powershell
aws iam get-policy --policy-arn "arn:aws:iam::...:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
```

---

## 5. AWS S3 — Buckets & Terraform Backend Management

**Use case:** Terraform state lives in S3. If the bucket is missing, misconfigured, or unversioned, you risk losing your entire infrastructure's source of truth.

### `aws s3api list-buckets`
**What it does:** Lists every S3 bucket in the account.
**When to use:** Confirming a Terraform state or CloudFormation template bucket actually exists.
```powershell
aws s3api list-buckets --query "Buckets[].Name" --output table
```

### `aws s3api head-bucket`
**What it does:** Checks bucket existence and your access to it (no output = success).
**When to use:** Scripting a bootstrap step — "does the state bucket exist yet, or do I need to create it?"
```powershell
aws s3api head-bucket --bucket "aws-hybrid-iac-lab-terraform-state-537236558357" --region us-east-1
```

### `aws s3api create-bucket`
**What it does:** Creates a new S3 bucket.
**When to use:** Bootstrapping a Terraform backend bucket for the first time — **only** after confirming via `head-bucket`/`list-buckets` that it doesn't already exist (recreating a bucket does not restore lost state).
```powershell
aws s3api create-bucket --bucket "my-terraform-state-bucket" --region us-east-1
```

### `aws s3api put-bucket-versioning` / `get-bucket-versioning`
**What it does:** Enables (or checks) object versioning — critical for state buckets so a bad `apply` doesn't permanently destroy your last-known-good state.
```powershell
aws s3api put-bucket-versioning --bucket "..." --versioning-configuration Status=Enabled
aws s3api get-bucket-versioning --bucket "..."
```

### `aws s3api put-bucket-encryption` / `get-bucket-encryption`
**What it does:** Enforces (or checks) server-side encryption at rest.
```powershell
aws s3api get-bucket-encryption --bucket "..."
```

### `aws s3api put-public-access-block` / `get-public-access-block`
**What it does:** Blocks (or verifies blocking of) public access to a bucket — essential for state buckets that may contain sensitive values.
```powershell
aws s3api get-public-access-block --bucket "..."
```

### `aws s3api head-object`
**What it does:** Checks whether a specific object (e.g., the actual `terraform.tfstate` key) exists inside a bucket.
**When to use:** Distinguishing "the bucket exists but is empty" from "the bucket has my real state file."
```powershell
aws s3api head-object --bucket "..." --key "aws-hybrid-iac-lab/terraform.tfstate"
```

### `aws s3 ls`
**What it does:** Lists objects in a bucket (simpler, human-friendly output vs. the `s3api` JSON commands).
```powershell
aws s3 ls s3://aws-hybrid-iac-lab-terraform-state-537236558357/ --recursive
```

---

## 6. AWS CloudFormation — Stacks, Events & Validation

**Use case:** Diagnosing *why* a nested stack rolled back, and confirming templates are syntactically valid before deploying.

### `aws cloudformation validate-template`
**What it does:** Validates a template's syntax against the CloudFormation schema (does not check runtime permissions).
```powershell
aws cloudformation validate-template --template-body file://main.yaml --region us-east-1
```

### `aws cloudformation describe-stacks`
**What it does:** Returns a stack's current status, reason, and metadata.
**When to use:** First command to run when a deployment "fails" — tells you if it's `ROLLBACK_COMPLETE`, `CREATE_FAILED`, `UPDATE_ROLLBACK_COMPLETE`, etc.
```powershell
aws cloudformation describe-stacks `
  --stack-name "HybridIaCLab-dev-MainStack" `
  --query "Stacks[0].[StackName,StackStatus,StackStatusReason]" `
  --output table
```

### `aws cloudformation describe-stack-events`
**What it does:** Returns the full timeline of resource-level events for a stack.
**When to use:** Finding the *exact* resource and reason a nested stack failed — filter aggressively, this list can be huge.
```powershell
aws cloudformation describe-stack-events `
  --stack-name "HybridIaCLab-dev-MainStack" `
  --query "StackEvents[?contains(ResourceStatus,'FAILED')].[Timestamp,LogicalResourceId,ResourceType,ResourceStatusReason]" `
  --output table
```

### `aws cloudformation delete-stack`
**What it does:** Deletes a stack and its resources.
**When to use:** Cleaning up a `ROLLBACK_COMPLETE` stack that must be removed before Terraform (or CloudFormation) can recreate one with the same name.
```powershell
aws cloudformation delete-stack --stack-name "HybridIaCLab-ECS" --region us-east-1
```

---

## 7. AWS ECR — Container Registry Management

**Use case:** Confirming repositories exist, inspecting pushed images, and understanding immutable-tag constraints before your CI/CD pipeline pushes a new build.

### `aws ecr describe-repositories`
**What it does:** Lists repositories and their URIs.
```powershell
aws ecr describe-repositories --repository-names "HybridIaCLab-dev-app" --output table
```

### `aws ecr list-images`
**What it does:** Lists image tags/digests inside a repository.
**When to use:** Confirming a specific commit-SHA-tagged image was actually pushed successfully.
```powershell
aws ecr list-images --repository-name "HybridIaCLab-dev-app" --output table
```

### `aws ecr delete-repository`
**What it does:** Deletes a repository — `--force` also deletes all images inside it.
**When to use:** Lab cleanup only. Treat as destructive and irreversible.
```powershell
aws ecr delete-repository --repository-name "hybrid-iac-lab" --force --region us-east-1
```

> **Immutable tags tip:** If your repository uses `ImageTagMutability: IMMUTABLE`, repeatedly pushing `:latest` will eventually fail. Tag builds with the Git commit SHA (`${GITHUB_SHA}`) instead, and treat `:latest` as optional/best-effort.

---

## 8. AWS Networking, Compute & Other Services

**Use case:** Gathering the real-world values (VPC IDs, subnet IDs, AMIs) that CloudFormation parameters and `terraform.tfvars` need — never guess these.

### VPCs and Subnets
```powershell
aws ec2 describe-vpcs `
  --query "Vpcs[].{VpcId:VpcId,Cidr:CidrBlock}" --output table

aws ec2 describe-subnets `
  --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,Cidr:CidrBlock}" `
  --output table
```

### Latest Amazon Linux 2023 AMI (via SSM Parameter Store)
**What it does:** Fetches the current, region-specific AMI ID without hardcoding a stale one.
```powershell
aws ssm get-parameter `
  --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
  --query "Parameter.Value" --output text --region us-east-1
```

### DynamoDB Tables
```powershell
aws dynamodb list-tables --output table
```

### Lambda Functions
```powershell
aws lambda list-functions --query "Functions[].{Name:FunctionName,Arn:FunctionArn}" --output table
```

---

## 9. GitHub CLI — OIDC & Repository Metadata

**Use case:** GitHub Actions authenticates to AWS via OIDC. Getting the trust policy's `sub` condition wrong (especially with GitHub's newer *immutable subject* format) is one of the most common causes of `AssumeRoleWithWebIdentity: not authorized`.

### `gh api .../actions/oidc/customization/sub`
**What it does:** Shows whether your repository uses the classic or immutable OIDC subject format.
```powershell
gh api repos/OWNER/REPO/actions/oidc/customization/sub
```

### `gh api repos/OWNER/REPO`
**What it does:** Retrieves the repository's and owner's numeric IDs — required to build the immutable subject string (`repo:OWNER@OWNER_ID/REPO@REPO_ID:ref:...`).
```powershell
gh api repos/OWNER/REPO --jq '{owner_login: .owner.login, owner_id: .owner.id, repo_name: .name, repo_id: .id}'
```

### `git grep`
**What it does:** Searches tracked files in a Git repository for a pattern (faster than `Select-String -Recurse` on large repos).
**When to use:** Auditing every workflow file for OIDC-related configuration in one pass.
```powershell
git grep -n -E "environment:|role-to-assume|id-token:"
```

---

## 10. Bulk Automation — Validate Everything in One Shot

**Use case:** Once you have more than 2–3 templates or `.tf` files, validating them one at a time is a waste of time. These one-liners loop through an entire directory tree.

### Validate every CloudFormation template and print a clean PASS/FAIL table
```powershell
Get-ChildItem -Path . -Recurse -Filter "*.yaml" | ForEach-Object {
    $file = $_.FullName
    aws cloudformation validate-template --template-body "file://$file" --region us-east-1 *> $null
    [PSCustomObject]@{
        Template = $file
        Status   = if ($LASTEXITCODE -eq 0) { "VALID" } else { "FAILED" }
    }
} | Format-Table -AutoSize
```

### Full Terraform validation pipeline (fmt → init → validate) in one command
```powershell
terraform fmt -check; if ($LASTEXITCODE -ne 0) { Write-Host "fmt FAILED" -ForegroundColor Red; exit 1 }
terraform init -backend=false -input=false; if ($LASTEXITCODE -ne 0) { Write-Host "init FAILED" -ForegroundColor Red; exit 1 }
terraform validate
if ($LASTEXITCODE -eq 0) { Write-Host "ALL CHECKS PASSED" -ForegroundColor Green } else { Write-Host "VALIDATION FAILED" -ForegroundColor Red }
```

### A reusable, read-only architecture verification script
For a full CI-style audit — checking required files exist, scanning for leftover deprecated config, confirming Terraform ↔ CloudFormation ↔ GitHub Actions ordering, and producing a timestamped PASS/FAIL report — wrap the checks above into a PowerShell script (e.g., `scripts/verify-hybrid-iac-architecture.ps1`) that:
- Never runs `terraform apply` or `terraform destroy`
- Never creates or deletes AWS resources
- Only reads files and calls read-only AWS/Terraform commands
- Exits with code `0` on pass and `1` on fail, so it can gate a CI pipeline

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-hybrid-iac-architecture.ps1
```

---

## 11. Job Roles & When You'd Reach for Each Category

| Role | Commands You'll Use Most |
|---|---|
| **DevOps / Platform Engineer** | Terraform state/import commands, S3 backend management, bulk validation scripts |
| **Cloud Security Engineer** | IAM auditing commands (`list-*-policies`, `get-role-policy`, permissions boundary checks) |
| **Site Reliability Engineer (SRE)** | CloudFormation stack/event diagnostics, ECS/ECR troubleshooting |
| **CI/CD / Release Engineer** | GitHub CLI OIDC commands, `configure-aws-credentials` debugging, immutable-tag ECR workflows |
| **Solutions Architect** | VPC/subnet discovery, AMI lookups, service inventory commands (Lambda, DynamoDB, ECR) |
| **Junior Cloud Engineer / Learner** | PowerShell navigation & file discovery — the foundation everything else builds on |

---

## Closing Thought

None of these commands are exotic — the value is in the **sequence**: always identify where you are and what exists (`Get-Location`, `state list`, `describe-stacks`) *before* you change anything (`apply`, `import`, `create-bucket`). That discipline is what turns a stressful 2 a.m. rollback into a 10-minute fix.

If this was useful, save it, share it with your team, and let me know in the comments which command has saved *you* the most time. 🔧

`#AWS #Terraform #CloudFormation #IaC #PowerShell #DevOps #CloudComputing #GitHubActions #InfrastructureAsCode`
