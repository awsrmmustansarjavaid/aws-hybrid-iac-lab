# Automating the Terraform S3 Remote Backend for AWS Hybrid IaC Lab

Yes. For your `aws-hybrid-iac-lab`, I recommend this final design:

* **GitHub Actions OIDC** authenticates to AWS.
* A **bootstrap step** automatically creates/verifies the Terraform state bucket.
* The main Terraform configuration uses an **S3 remote backend**.
* S3 **versioning** protects Terraform state.
* S3 backend **lockfile** prevents concurrent Terraform operations.
* No DynamoDB locking table is required; current Terraform documentation treats S3 lockfiles as the preferred mechanism and DynamoDB locking as deprecated. ([HashiCorp Developer][1])
* The state bucket is separate from your CloudFormation template bucket.
* The bootstrap bucket is created automatically by GitHub Actions, so you do **not** manually create it every time.

Your current state bucket name will be:

```text
aws-hybrid-iac-lab-terraform-state-537236558357
```

---

## 1. Final Directory Structure

Your relevant structure should be:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── infrastructure/
│   │
│   ├── terraform/
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── iam.tf
│   │   ├── template_bucket.tf
│   │   ├── template_objects.tf
│   │   ├── cloudformation.tf
│   │   └── ...
│   │
│   └── bootstrap/
│       └── terraform-state/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── README.md
```

**Important:** the bootstrap Terraform files are useful documentation and for manually bootstrapping the backend if necessary, but the GitHub Actions workflow below will automatically create/secure the bucket before `terraform init`.

---

## 2. `.github/workflows/terraform.yml`

Replace your existing workflow with this complete version.

```yaml
# ============================================================
# GitHub Actions - Terraform Infrastructure
# Project: aws-hybrid-iac-lab
#
# Purpose:
#   1. Authenticate GitHub Actions to AWS using OIDC.
#   2. Automatically bootstrap the Terraform state bucket.
#   3. Initialize Terraform with an S3 remote backend.
#   4. Validate Terraform configuration.
#   5. Generate a Terraform plan.
#   6. Apply the Terraform configuration.
#
# IMPORTANT:
#   The S3 backend bucket must exist BEFORE "terraform init".
#   Therefore, the workflow creates/verifies the backend bucket
#   before Terraform initialization.
#
# AWS Authentication:
#   GitHub OIDC -> AWS STS -> GitHub Actions IAM Role
#
# ============================================================

name: Terraform Infrastructure

# ------------------------------------------------------------
# Workflow triggers
# ------------------------------------------------------------
on:

  # Allows this workflow to be called by another workflow.
  workflow_call:

  # Allows manual execution from GitHub Actions.
  workflow_dispatch:


# ------------------------------------------------------------
# Prevent two Terraform deployments from modifying the same
# remote state at the same time.
#
# This is an additional protection at the GitHub Actions level.
# Terraform itself also uses the S3 lockfile.
# ------------------------------------------------------------
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false


# ------------------------------------------------------------
# GitHub Actions permissions
#
# id-token: write
#   Required to request the GitHub OIDC token.
#
# contents: read
#   Required by actions/checkout.
# ------------------------------------------------------------
permissions:
  id-token: write
  contents: read


jobs:

  # ==========================================================
  # Terraform deployment job
  # ==========================================================
  terraform:

    name: Terraform Infrastructure Deployment

    # GitHub-hosted Ubuntu runner.
    runs-on: ubuntu-latest


    steps:

      # --------------------------------------------------------
      # Step 1 - Checkout repository
      # --------------------------------------------------------
      - name: Checkout Repository
        uses: actions/checkout@v4


      # --------------------------------------------------------
      # Step 2 - Configure AWS credentials using GitHub OIDC
      #
      # No long-lived AWS access key is stored in GitHub.
      #
      # GitHub requests an OIDC token and AWS STS exchanges
      # that token for temporary credentials.
      # --------------------------------------------------------
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4

        with:

          # Repository variable:
          # Settings
          #   -> Secrets and variables
          #   -> Actions
          #   -> Variables
          aws-region: ${{ vars.AWS_REGION }}

          # Repository secret:
          # Settings
          #   -> Secrets and variables
          #   -> Actions
          #   -> Secrets
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}


      # --------------------------------------------------------
      # Step 3 - Verify AWS identity
      #
      # This confirms that GitHub Actions successfully assumed
      # the intended IAM role.
      # --------------------------------------------------------
      - name: Verify AWS Identity
        shell: bash

        run: |
          set -euo pipefail

          echo "=============================================="
          echo "AWS Identity"
          echo "=============================================="

          aws sts get-caller-identity

          echo ""
          echo "AWS Region:"
          echo "${AWS_REGION}"


      # ========================================================
      # Step 4 - Bootstrap Terraform State Bucket
      #
      # IMPORTANT:
      #
      # Terraform cannot create its own backend bucket inside
      # the same configuration because Terraform must access
      # the backend during "terraform init".
      #
      # Therefore this preflight step creates/verifies the
      # bucket before terraform init.
      #
      # This step is IDEMPOTENT:
      #
      # - If the bucket does not exist -> create it.
      # - If it already exists -> keep using it.
      #
      # The bucket is configured with:
      #
      # - Versioning
      # - Server-side encryption (SSE-S3)
      # - Block Public Access
      # - Tags
      #
      # The bucket is NOT destroyed by Terraform.
      # ========================================================
      - name: Bootstrap Terraform State Bucket
        shell: bash

        env:

          # Dedicated Terraform state bucket.
          TF_STATE_BUCKET: aws-hybrid-iac-lab-terraform-state-537236558357

          # AWS region comes from the GitHub repository variable.
          TF_STATE_REGION: ${{ vars.AWS_REGION }}

        run: |
          set -euo pipefail

          echo "=============================================="
          echo "Terraform State Backend Bootstrap"
          echo "=============================================="

          echo "State bucket:"
          echo "${TF_STATE_BUCKET}"

          echo "AWS region:"
          echo "${TF_STATE_REGION}"

          echo ""
          echo "Checking whether Terraform state bucket exists..."

          if aws s3api head-bucket \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            2>/dev/null
          then

            echo ""
            echo "Terraform state bucket already exists."
            echo "No bucket creation is required."

          else

            echo ""
            echo "Terraform state bucket does not exist."
            echo "Creating bucket..."

            # us-east-1 requires a slightly different create-bucket
            # command because LocationConstraint is not used there.
            if [ "${TF_STATE_REGION}" = "us-east-1" ]; then

              aws s3api create-bucket \
                --bucket "${TF_STATE_BUCKET}" \
                --region "${TF_STATE_REGION}"

            else

              aws s3api create-bucket \
                --bucket "${TF_STATE_BUCKET}" \
                --region "${TF_STATE_REGION}" \
                --create-bucket-configuration \
                  LocationConstraint="${TF_STATE_REGION}"

            fi

            echo ""
            echo "Terraform state bucket created."

          fi


          # ------------------------------------------------------
          # Enable S3 Versioning
          #
          # Versioning allows previous Terraform state versions
          # to be recovered after accidental modification/deletion.
          # ------------------------------------------------------
          echo ""
          echo "Enabling S3 bucket versioning..."

          aws s3api put-bucket-versioning \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --versioning-configuration Status=Enabled


          # ------------------------------------------------------
          # Enable default server-side encryption.
          #
          # SSE-S3 uses Amazon S3 managed encryption keys.
          # ------------------------------------------------------
          echo ""
          echo "Enabling S3 server-side encryption..."

          aws s3api put-bucket-encryption \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --server-side-encryption-configuration \
            '{
              "Rules": [
                {
                  "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                  }
                }
              ]
            }'


          # ------------------------------------------------------
          # Block all public access.
          #
          # Terraform state can contain sensitive infrastructure
          # information, so the state bucket must never be public.
          # ------------------------------------------------------
          echo ""
          echo "Enabling S3 Block Public Access..."

          aws s3api put-public-access-block \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true


          # ------------------------------------------------------
          # Add bucket tags.
          # ------------------------------------------------------
          echo ""
          echo "Applying Terraform state bucket tags..."

          aws s3api put-bucket-tagging \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --tagging '{
              "TagSet": [
                {
                  "Key": "Name",
                  "Value": "aws-hybrid-iac-lab-terraform-state"
                },
                {
                  "Key": "Project",
                  "Value": "aws-hybrid-iac-lab"
                },
                {
                  "Key": "ManagedBy",
                  "Value": "GitHub-Actions-Bootstrap"
                },
                {
                  "Key": "Purpose",
                  "Value": "Terraform-State"
                },
                {
                  "Key": "Environment",
                  "Value": "dev"
                }
              ]
            }'


          # ------------------------------------------------------
          # Verify the bucket configuration.
          # ------------------------------------------------------
          echo ""
          echo "=============================================="
          echo "Terraform State Bucket Verification"
          echo "=============================================="

          echo ""
          echo "Bucket:"
          aws s3api head-bucket \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"

          echo ""
          echo "Versioning:"
          aws s3api get-bucket-versioning \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"

          echo ""
          echo "Encryption:"
          aws s3api get-bucket-encryption \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"

          echo ""
          echo "Public Access Block:"
          aws s3api get-public-access-block \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"

          echo ""
          echo "Terraform state backend bootstrap completed successfully."


      # --------------------------------------------------------
      # Step 5 - Setup Terraform
      # --------------------------------------------------------
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3


      # --------------------------------------------------------
      # Step 6 - Terraform Init
      #
      # backend.tf tells Terraform to store state remotely in:
      #
      # S3 bucket:
      #   aws-hybrid-iac-lab-terraform-state-537236558357
      #
      # State key:
      #   aws-hybrid-iac-lab/dev/terraform.tfstate
      #
      # use_lockfile=true enables S3 native state locking.
      # --------------------------------------------------------
      - name: Terraform Init
        working-directory: infrastructure/terraform

        run: |
          terraform init -input=false


      # --------------------------------------------------------
      # Step 7 - Terraform Format Check
      # --------------------------------------------------------
      - name: Terraform Format Check
        working-directory: infrastructure/terraform

        run: |
          terraform fmt -check -recursive


      # --------------------------------------------------------
      # Step 8 - Terraform Validate
      # --------------------------------------------------------
      - name: Terraform Validate
        working-directory: infrastructure/terraform

        run: |
          terraform validate


      # --------------------------------------------------------
      # Step 9 - Show Terraform State
      #
      # This helps confirm that Terraform is now using the
      # remote S3 backend.
      # --------------------------------------------------------
      - name: Terraform State Information
        working-directory: infrastructure/terraform

        run: |
          echo "=============================================="
          echo "Terraform State"
          echo "=============================================="

          terraform state list || true


      # --------------------------------------------------------
      # Step 10 - Terraform Plan
      # --------------------------------------------------------
      - name: Terraform Plan
        working-directory: infrastructure/terraform

        run: |
          terraform plan \
            -input=false \
            -out=tfplan


      # --------------------------------------------------------
      # Step 11 - Terraform Apply
      #
      # Only applies the exact plan generated above.
      # --------------------------------------------------------
      - name: Terraform Apply
        working-directory: infrastructure/terraform

        run: |
          terraform apply \
            -input=false \
            -auto-approve \
            tfplan
```

This workflow makes the backend creation automatic while keeping `terraform init` in the correct order.

S3 versioning is particularly appropriate for Terraform state because HashiCorp recommends versioning for recovery from accidental deletion or human error. ([HashiCorp Developer][1])

---

## 3. `infrastructure/terraform/backend.tf`

Create:

```text
infrastructure/terraform/backend.tf
```

Use this:

```hcl
# ============================================================
# Terraform Remote Backend
# Project: aws-hybrid-iac-lab
#
# Purpose:
#   Store Terraform state remotely in Amazon S3.
#
# IMPORTANT:
#   The S3 bucket must exist before "terraform init".
#
#   GitHub Actions automatically creates/verifies the bucket
#   before running terraform init.
#
# State bucket:
#   aws-hybrid-iac-lab-terraform-state-537236558357
#
# State file:
#   aws-hybrid-iac-lab/dev/terraform.tfstate
#
# State locking:
#   S3 lockfile (.tflock)
#
# ============================================================

terraform {

  backend "s3" {

    # --------------------------------------------------------
    # Dedicated Terraform state bucket.
    #
    # This bucket is DIFFERENT from the CloudFormation
    # template bucket.
    # --------------------------------------------------------
    bucket = "aws-hybrid-iac-lab-terraform-state-537236558357"


    # --------------------------------------------------------
    # Location of the Terraform state file.
    # --------------------------------------------------------
    key = "aws-hybrid-iac-lab/dev/terraform.tfstate"


    # --------------------------------------------------------
    # AWS region containing the state bucket.
    # --------------------------------------------------------
    region = "us-east-1"


    # --------------------------------------------------------
    # Encrypt Terraform state objects.
    #
    # The bucket also has default SSE-S3 encryption configured
    # by the GitHub Actions bootstrap step.
    # --------------------------------------------------------
    encrypt = true


    # --------------------------------------------------------
    # Enable native S3 state locking.
    #
    # Terraform creates:
    #
    #   aws-hybrid-iac-lab/dev/terraform.tfstate.tflock
    #
    # DynamoDB locking is NOT required.
    # --------------------------------------------------------
    use_lockfile = true
  }
}
```

The current HashiCorp S3 backend supports `use_lockfile = true`; the required permissions include `GetObject`, `PutObject`, and `DeleteObject` for the lock file. ([HashiCorp Developer][1])

---

## 4. Bootstrap Terraform Files

You asked for the bootstrap files as well.

These are useful because they document the backend infrastructure and give you a manual recovery/bootstrap option.

Create:

```text
infrastructure/bootstrap/terraform-state/
```

### `main.tf`

```hcl
# ============================================================
# Terraform State Backend Bootstrap
# Project: aws-hybrid-iac-lab
#
# Purpose:
#   Creates the dedicated S3 bucket used by Terraform for
#   remote state storage.
#
# IMPORTANT:
#   This configuration is separate from the main Terraform
#   configuration because the main Terraform backend bucket
#   must exist BEFORE terraform init.
#
# The GitHub Actions workflow normally handles this bootstrap
# automatically.
# ============================================================

terraform {

  required_version = ">= 1.6.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


# ------------------------------------------------------------
# AWS Provider
# ------------------------------------------------------------
provider "aws" {

  region = var.aws_region
}


# ============================================================
# Terraform State Bucket
# ============================================================

resource "aws_s3_bucket" "terraform_state" {

  bucket = var.state_bucket_name


  # ----------------------------------------------------------
  # Safety:
  #
  # Never automatically destroy the Terraform state bucket.
  # ----------------------------------------------------------
  lifecycle {
    prevent_destroy = true
  }


  tags = {

    Name        = "aws-hybrid-iac-lab-terraform-state"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Terraform-State"
  }
}


# ============================================================
# Bucket Versioning
# ============================================================

resource "aws_s3_bucket_versioning" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {

    status = "Enabled"
  }
}


# ============================================================
# Block Public Access
# ============================================================

resource "aws_s3_bucket_public_access_block" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# Server-Side Encryption
# ============================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"
    }
  }
}
```

### `variables.tf`

```hcl
# ============================================================
# Bootstrap Variables
# Project: aws-hybrid-iac-lab
# ============================================================


# ------------------------------------------------------------
# AWS Region
# ------------------------------------------------------------
variable "aws_region" {

  description = "AWS region where the Terraform state bucket is created."

  type = string

  default = "us-east-1"
}


# ------------------------------------------------------------
# Terraform State Bucket Name
# ------------------------------------------------------------
variable "state_bucket_name" {

  description = "Globally unique S3 bucket name used for Terraform remote state."

  type = string

  default = "aws-hybrid-iac-lab-terraform-state-537236558357"
}


# ------------------------------------------------------------
# Project Name
# ------------------------------------------------------------
variable "project_name" {

  description = "Project name used for resource tagging."

  type = string

  default = "aws-hybrid-iac-lab"
}


# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
variable "environment" {

  description = "Environment name used for resource tagging."

  type = string

  default = "dev"
}
```

### `outputs.tf`

```hcl
# ============================================================
# Bootstrap Outputs
# ============================================================


# ------------------------------------------------------------
# Terraform State Bucket Name
# ------------------------------------------------------------
output "terraform_state_bucket_name" {

  description = "Name of the Terraform remote state bucket."

  value = aws_s3_bucket.terraform_state.bucket
}


# ------------------------------------------------------------
# Terraform State Bucket ARN
# ------------------------------------------------------------
output "terraform_state_bucket_arn" {

  description = "ARN of the Terraform remote state bucket."

  value = aws_s3_bucket.terraform_state.arn
}
```

---

## 5. IAM Permissions

This part is important.

Your GitHub Actions role:

```text
aws-hybrid-iac-lab-GitHubActions
```

needs permissions for **two different purposes**:

### A. Terraform Backend

It needs to access:

```text
aws-hybrid-iac-lab-terraform-state-537236558357
```

### B. Backend Bootstrap

The workflow needs to create/configure that bucket if it doesn't exist.

Because your main lab already creates S3 infrastructure, your existing GitHub Actions policy may already contain enough S3 permissions. But for the backend specifically, these are the permissions you need.

HashiCorp documents `s3:ListBucket`, `s3:GetObject`, and `s3:PutObject` for state, plus `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the `.tflock` file when S3 locking is enabled. ([HashiCorp Developer][1])

For the automated bootstrap, add these permissions.

---

## 6. Recommended Backend IAM Policy

Create a policy file:

```text
github-actions-terraform-backend-policy.json
```

Use:

```json
{
  "Version": "2012-10-17",
  "Statement": [

    {
      "Sid": "TerraformStateBucketManagement",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging"
      ],
      "Resource": "arn:aws:s3:::aws-hybrid-iac-lab-terraform-state-537236558357"
    },

    {
      "Sid": "TerraformStateObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::aws-hybrid-iac-lab-terraform-state-537236558357/aws-hybrid-iac-lab/dev/terraform.tfstate"
    },

    {
      "Sid": "TerraformStateLockFileAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::aws-hybrid-iac-lab-terraform-state-537236558357/aws-hybrid-iac-lab/dev/terraform.tfstate.tflock"
    }
  ]
}
```

AWS documents `s3:CreateBucket` for bucket creation and `s3:PutBucketPublicAccessBlock` for configuring Block Public Access. ([AWS Documentation][2])

---

## 7. Attach the Policy to Your GitHub Actions Role

Your role is:

```text
aws-hybrid-iac-lab-GitHubActions
```

If you create the managed policy above, attach it to that role.

For example:

```powershell
aws iam create-policy `
  --policy-name "aws-hybrid-iac-lab-TerraformBackendPolicy" `
  --policy-document "file://github-actions-terraform-backend-policy.json"
```

Then:

```powershell
aws iam attach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-TerraformBackendPolicy"
```

Verify:

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"
```

You should see both your existing lab policy and the backend policy.

---

## 8. Important: Don't Put Backend Permissions on `github-ci-cd-user`

This is important given your current architecture.

You have:

```text
github-ci-cd-user
```

and:

```text
aws-hybrid-iac-lab-GitHubActions
```

The GitHub workflow uses:

```text
GitHub OIDC
       ↓
AWS STS
       ↓
aws-hybrid-iac-lab-GitHubActions
       ↓
Terraform
```

Therefore the backend permissions belong to:

```text
aws-hybrid-iac-lab-GitHubActions
```

**not** the IAM user.

---

## 9. GitHub Configuration

You already have the correct values.

### Repository Variable

Go to:

```text
GitHub
→ Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

Create:

```text
Name:
AWS_REGION

Value:
us-east-1
```

### Repository Secret

Go to:

```text
Settings
→ Secrets and variables
→ Actions
→ Secrets
```

Create:

```text
Name:
AWS_ROLE_ARN

Value:
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 10. Very Important: Your Current Existing AWS Resources

You already have resources from the previous failed Terraform run.

For example:

```text
HybridIaCLab-dev-CloudFormationExecutionRole
```

and:

```text
hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638
```

Those resources currently exist in AWS but your new remote Terraform state does **not** know about them.

This means:

```text
S3 backend fixed
        ↓
terraform init works
        ↓
terraform plan
        ↓
Terraform may try to create existing resources
        ↓
EntityAlreadyExists / BucketAlreadyExists
```

So **do not immediately run `terraform apply` after adding the backend** and assume everything is fixed.

You need to migrate/import the resources that were created by the previous failed run.

---

## 11. First Test the Backend

After adding the files:

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"
```

Then:

```powershell
terraform -chdir="infrastructure/terraform" init
```

You should see something similar to:

```text
Initializing the backend...

Successfully configured the backend "s3"!
```

Then:

```powershell
terraform -chdir="infrastructure/terraform" validate
```

Then:

```powershell
terraform -chdir="infrastructure/terraform" state list
```

Initially, it may show:

```text
No resources are currently tracked in the state.
```

That is expected if this is the first remote state.

---

## 12. Test the GitHub Workflow

Commit:

```powershell
git add .
```

Then:

```powershell
git commit -m "Add automated Terraform S3 remote backend"
```

Then:

```powershell
git push origin main
```

GitHub Actions should execute:

```text
Checkout
   ↓
Configure AWS OIDC
   ↓
Verify AWS identity
   ↓
Bootstrap Terraform state bucket
   ↓
Setup Terraform
   ↓
terraform init
   ↓
terraform fmt
   ↓
terraform validate
   ↓
terraform state
   ↓
terraform plan
   ↓
terraform apply
```

---

## 13. What Happens on the Second GitHub Actions Run?

This is the important part.

The first run:

```text
Does bucket exist?
       ↓
NO
       ↓
Create bucket
       ↓
Enable versioning
       ↓
Enable encryption
       ↓
Block public access
       ↓
terraform init
       ↓
Terraform writes state
```

The second run:

```text
Does bucket exist?
       ↓
YES
       ↓
Do NOT create another bucket
       ↓
Verify/configure bucket
       ↓
terraform init
       ↓
Download existing remote state
       ↓
terraform plan
       ↓
terraform apply
```

So you **do not create the state bucket manually every time**.

That is exactly what the bootstrap portion of the workflow is doing.

---

## 14. One Architectural Point I Strongly Recommend

Do **not** put the backend bucket into your normal:

```text
infrastructure/terraform/
```

configuration.

Keep:

```text
infrastructure/terraform/
```

for the actual lab infrastructure:

```text
VPC
EC2
ECS
ECR
EKS
S3
RDS
Lambda
DynamoDB
CloudFormation
IAM
etc.
```

And keep the Terraform backend/bootstrap concept separate.

The reason is fundamental: Terraform needs the backend **before** it can initialize and read/write the state used to manage the rest of the infrastructure. HashiCorp explicitly documents that the S3 backend assumes the bucket already exists. ([HashiCorp Developer][1])

Your final architecture is therefore:

```text
                         GitHub
                           │
                           │ OIDC
                           ▼
              ┌─────────────────────────┐
              │ AWS STS                 │
              │ AssumeRoleWithWebIdentity
              └────────────┬────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │ GitHubActions IAM Role  │
              │                         │
              │ aws-hybrid-iac-lab-     │
              │ GitHubActions           │
              └────────────┬────────────┘
                           │
             ┌─────────────┴──────────────┐
             │                            │
             ▼                            ▼
    Backend Bootstrap              Terraform
             │                            │
             ▼                            │
     ┌───────────────────┐               │
     │ S3 State Bucket   │◄──────────────┘
     │                   │
     │ versioning        │
     │ encryption        │
     │ public blocked    │
     │ .tfstate          │
     │ .tflock           │
     └───────────────────┘
                    │
                    │ Terraform State
                    ▼
          ┌─────────────────────┐
          │ AWS Infrastructure  │
          │                     │
          │ CloudFormation      │
          │ VPC                 │
          │ EC2                 │
          │ S3                  │
          │ ECR                 │
          │ ECS                 │
          │ EKS                 │
          │ RDS                 │
          │ Lambda              │
          │ DynamoDB            │
          │ etc.                │
          └─────────────────────┘
```

### One Thing You Should Do Before the Next `terraform apply`

Because your previous failed run already created AWS resources while leaving Terraform with **no state**, the next step should be **state migration/import**, not blindly applying again. Your existing IAM role and CloudFormation-template bucket need to be brought under the new remote state first; otherwise you'll likely hit the same `EntityAlreadyExists` problem again.

[Terraform S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3)

[1]: https://developer.hashicorp.com/terraform/language/backend/s3 "Backend Type: s3 | Terraform | HashiCorp Developer"
[2]: https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateBucket.html "CreateBucket - Amazon S3"

---

# Part 2 — Choosing the Fully Automated Approach

I went add it on GitHub workflow as it's automation lab do I don't want to do manual each time so I need solutions in this case how can we make a professional way and fix this issues

Yes. Since this is an **automation/DevOps lab**, I agree with your goal: **you should not manually create the backend bucket every time**.

The professional solution is **not** to create the backend bucket inside the same Terraform configuration. Instead, use a **bootstrap stage** in GitHub Actions.

### Recommended Architecture

```text
GitHub Actions
      │
      ├── 1. Bootstrap
      │      └── Create/verify Terraform state S3 bucket
      │
      └── 2. Main Terraform
             │
             ├── terraform init
             ├── terraform plan
             └── terraform apply
                    │
                    ▼
             Persistent S3 State
```

The bootstrap is automated, so **you don't manually run AWS CLI commands**.

### Your Repository

```text
.github/
└── workflows/
    └── terraform.yml
infrastructure/
├── bootstrap/
│   └── terraform-state/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── terraform/
    ├── backend.tf
    ├── variables.tf
    ├── iam.tf
    ├── cloudformation.tf
    └── ...
```

### But There Is One Catch

The bootstrap Terraform itself needs somewhere to store **its own state**.

For a lab, the cleanest approach is:

```text
Bootstrap
   ↓
uses temporary/local state on GitHub runner
   ↓
creates permanent S3 backend bucket
   ↓
Main Terraform
   ↓
uses permanent S3 remote state
```

The bootstrap doesn't need to run on every deployment if the bucket already exists. The workflow can simply:

```text
Check bucket
   ↓
Does it exist?
   ├── YES → continue
   └── NO  → create it
   ↓
terraform init
   ↓
main Terraform
```

That gives you the automation you're looking for.

**One important correction to our previous plan:** I would not use a separate Terraform bootstrap state bucket that itself needs manual bootstrapping. For your lab, we can make the GitHub workflow **idempotently create/verify the state bucket before `terraform init`**, while the main Terraform configuration uses that bucket permanently.

If you want, I can give you the **complete final `terraform.yml` + bootstrap files + `backend.tf` + required IAM permissions**, designed specifically for your current `aws-hybrid-iac-lab`, so you can replace your current setup without manually creating the bucket.

> Give me the complete final terraform.yml, bootstrap files, backend.tf, and required IAM permissions for my aws-hybrid-iac-lab

---

# Part 3 — Diagnosing the "NoSuchBucket" Error After First Run

Your IAM policy attachment is correct, and your Terraform configuration itself is valid.

The only actual problem in this output is that the S3 backend bucket does not exist yet:

```
NoSuchBucket: The specified bucket does not exist
```

That is expected because the bootstrap bucket has not been created yet.

## Do This Next

Because your workflow is designed to create the bucket automatically, do not run `terraform init` locally yet. First push the final `terraform.yml` containing the bootstrap step to GitHub.

From your repo:

```powershell
git status
```

Then:

```powershell
git add .github/workflows/terraform.yml
git commit -m "Add automated Terraform backend bootstrap"
git push origin main
```

Then go to:

```
GitHub → aws-hybrid-iac-lab → Actions → Terraform Infrastructure → Run workflow
```

The workflow should perform:

```text
GitHub OIDC
   ↓
Assume aws-hybrid-iac-lab-GitHubActions
   ↓
Bootstrap Terraform State Bucket
   ↓
Create:
aws-hybrid-iac-lab-terraform-state-537236558357
   ↓
Enable versioning
   ↓
Enable encryption
   ↓
Block public access
   ↓
terraform init
   ↓
terraform validate
   ↓
terraform plan
```

## After the Workflow Creates the Bucket

You can verify it locally:

```powershell
aws s3api head-bucket `
  --bucket "aws-hybrid-iac-lab-terraform-state-537236558357"
```

Then:

```powershell
aws s3api get-bucket-versioning `
  --bucket "aws-hybrid-iac-lab-terraform-state-537236558357"
```

You should get:

```
Status: Enabled
```

Then encryption:

```powershell
aws s3api get-bucket-encryption `
  --bucket "aws-hybrid-iac-lab-terraform-state-537236558357"
```

And public access:

```powershell
aws s3api get-public-access-block `
  --bucket "aws-hybrid-iac-lab-terraform-state-537236558357"
```

## Then Run Locally

Once the bucket exists:

```powershell
terraform -chdir="infrastructure/terraform" init
```

You should now get something like:

```text
Initializing the backend...

Successfully configured the backend "s3"!
```

Then:

```powershell
terraform -chdir="infrastructure/terraform" state list
```

It may initially return no resources. That's okay.

## One Important Warning

Do not run:

```
terraform apply
```

yet.

Your previous GitHub Actions run already created:

```
HybridIaCLab-dev-CloudFormationExecutionRole
```

and:

```
hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638
```

but those resources are currently not recorded in Terraform state.

So our next job after the backend is working is:

```text
S3 backend working
       ↓
terraform init
       ↓
Remote state available
       ↓
Import existing resources
       ↓
terraform plan
       ↓
Confirm 0 unwanted creations
       ↓
terraform apply
```

That will prevent the previous:

```
EntityAlreadyExists:
Role with name HybridIaCLab-dev-CloudFormationExecutionRole already exists
```

error from happening again.

So your current result is good: IAM is attached correctly, validate is successful, and the backend error is simply telling us that the bootstrap bucket hasn't been created yet.
