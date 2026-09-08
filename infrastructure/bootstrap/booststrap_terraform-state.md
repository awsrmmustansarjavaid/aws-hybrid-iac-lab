1. Create the bootstrap Terraform files

Create:

infrastructure\bootstrap\terraform-state

Then create:

main.tf
variables.tf
outputs.tf
main.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  force_destroy = false

  tags = {
    Name        = var.state_bucket_name
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform-Bootstrap"
    Purpose     = "Terraform Remote State"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
variables.tf
variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used for Terraform remote state."
  type        = string
  default     = "aws-hybrid-iac-lab-terraform-state-123456789"
}

variable "project_name" {
  description = "Project name."
  type        = string
  default     = "HybridIaCLab"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}
outputs.tf
output "terraform_state_bucket_name" {
  description = "Name of the S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform remote state S3 bucket."
  value       = aws_s3_bucket.terraform_state.arn
}
2. Bootstrap it once

From your repository root:

cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"

Then:

terraform -chdir="infrastructure/bootstrap/terraform-state" init

Then:

terraform -chdir="infrastructure/bootstrap/terraform-state" validate

Then:

terraform -chdir="infrastructure/bootstrap/terraform-state" plan

You should see:

Plan: 4 to add, 0 to change, 0 to destroy.

Then:

terraform -chdir="infrastructure/bootstrap/terraform-state" apply

Type:

yes

Now Terraform itself has created the permanent state bucket.

3. Your main Terraform backend.tf

Now create:

infrastructure\terraform\backend.tf

Use:

terraform {
  backend "s3" {
    bucket       = "aws-hybrid-iac-lab-terraform-state-123456789"
    key          = "aws-hybrid-iac-lab/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

Notice something important:

There are no variables in backend.tf.

Don't do:

bucket = var.state_bucket_name

Terraform backend configuration is initialized before normal Terraform variables are available.

4. What about your existing variables.tf?

You do not need to put the backend bucket variable into your main variables.tf.

Your main Terraform variables should continue to contain things such as:

variable "aws_region" {
  ...
}

variable "project_name" {
  ...
}

variable "environment" {
  ...
}

The backend configuration is separate.

So:

bootstrap/terraform-state/variables.tf
        ↓
controls creation of state bucket

infrastructure/terraform/variables.tf
        ↓
controls your actual lab infrastructure

infrastructure/terraform/backend.tf
        ↓
tells Terraform where its state lives

That separation is actually cleaner.

5. Your terraform.yml

Your workflow does not need an S3 bucket creation step.

It needs to authenticate to AWS and then run Terraform normally.

Your current workflow is already close.

I recommend this structure:

name: Terraform Infrastructure

on:
  workflow_call:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    name: Terraform Infrastructure Deployment
    runs-on: ubuntu-latest

    steps:
      # ---------------------------------------------------------
      # 1. Checkout repository
      # ---------------------------------------------------------
      - name: Checkout Repository
        uses: actions/checkout@v4

      # ---------------------------------------------------------
      # 2. Configure AWS credentials using GitHub OIDC
      # ---------------------------------------------------------
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ${{ vars.AWS_REGION }}
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}

      # ---------------------------------------------------------
      # 3. Verify AWS identity
      # ---------------------------------------------------------
      - name: Verify AWS Identity
        shell: bash
        run: |
          aws sts get-caller-identity

      # ---------------------------------------------------------
      # 4. Setup Terraform
      # ---------------------------------------------------------
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      # ---------------------------------------------------------
      # 5. Initialize Terraform
      #
      # This connects Terraform to the persistent S3 backend.
      # The backend bucket must already exist.
      # ---------------------------------------------------------
      - name: Terraform Init
        working-directory: infrastructure/terraform
        run: terraform init

      # ---------------------------------------------------------
      # 6. Check Terraform formatting
      # ---------------------------------------------------------
      - name: Terraform Format Check
        working-directory: infrastructure/terraform
        run: terraform fmt -check -recursive

      # ---------------------------------------------------------
      # 7. Validate Terraform configuration
      # ---------------------------------------------------------
      - name: Terraform Validate
        working-directory: infrastructure/terraform
        run: terraform validate

      # ---------------------------------------------------------
      # 8. Create Terraform execution plan
      # ---------------------------------------------------------
      - name: Terraform Plan
        working-directory: infrastructure/terraform
        run: terraform plan

      # ---------------------------------------------------------
      # 9. Apply Terraform infrastructure
      # ---------------------------------------------------------
      - name: Terraform Apply
        working-directory: infrastructure/terraform
        run: terraform apply -auto-approve
Notice:

There is no:

aws s3api create-bucket

There is no:

terraform -chdir=infrastructure/bootstrap/terraform-state apply

There is no state bucket creation during every deployment.

That's intentional.

6. What about AWS_REGION?

Keep your existing GitHub repository variable:

AWS_REGION

with:

us-east-1

And keep:

AWS_ROLE_ARN

as your GitHub Actions secret.

You don't need another GitHub variable for the Terraform backend bucket because the bucket name is part of the backend configuration.

7. But there is one more important thing

You currently have AWS resources from the failed GitHub Actions run:

HybridIaCLab-dev-CloudFormationExecutionRole
HybridIaCLab-dev-CloudFormationPermissions
hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638

and zero Terraform state.

Creating the backend does not automatically put those resources into Terraform state.

We still need to import them.

The process will be:

                    AWS
                     │
          existing resources
                     │
                     ▼
             terraform import
                     │
                     ▼
             S3 Remote State
                     │
                     ▼
             terraform plan
                     │
                     ▼
               Plan should
              converge cleanly

This is the part we need to do before another GitHub Actions apply.

8. Very important: don't run your main terraform apply yet

Right now, do not run:

terraform -chdir="infrastructure/terraform" apply

because your main Terraform state is still empty.

First:

Create the bootstrap Terraform files.
Create the state bucket.
Add backend.tf.
Initialize the main Terraform backend.
Import the existing IAM/S3 resources.
Import your existing CloudFormation template objects.
Run terraform plan.
Make sure the plan is correct.
Only then run GitHub Actions.
Your final design

This is the design I recommend you keep permanently:

                    GitHub
                       │
                       │ OIDC
                       ▼
              GitHub Actions Role
                       │
                       ▼
              terraform.yml
                       │
                       ▼
             Terraform Init
                       │
                       ▼
       ┌────────────────────────────┐
       │ Dedicated S3 State Bucket  │
       │                            │
       │ aws-hybrid-iac-lab-        │
       │ terraform-state-           │
       │ 123456789               │
       │                            │
       │ Versioning: ON             │
       │ Encryption: ON             │
       │ Public Access: BLOCKED     │
       │ Locking: use_lockfile      │
       └──────────────┬─────────────┘
                      │
                terraform.tfstate
                      │
                      ▼
              Main Terraform
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
       AWS S3               CloudFormation
   Template Bucket            Root Stack
                                  │
                                  ▼
                           Nested CFN Stacks

One-time manual/bootstrap operation: creating the state bucket.

Everything after that: automated through your normal Terraform/GitHub Actions workflow.

And importantly, you don't need to manually create the state bucket with aws s3api anymore if you use the bootstrap Terraform approach above. You run the bootstrap Terraform once, and Terraform becomes responsible for that bucket's configuration.
