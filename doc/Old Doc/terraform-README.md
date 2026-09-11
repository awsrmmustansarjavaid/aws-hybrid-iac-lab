# Terraform README — Hybrid Terraform + CloudFormation Lab

This document walks through every Terraform file in `infrastructure/terraform/`, what it does, and how the files connect to each other and to the CloudFormation side of the lab.

## Folder overview

```text
infrastructure/
│
├── cloudformation/
│   ├── main.yaml
│   └── nested/
│       ├── vpc.yaml
│       ├── ec2.yaml
│       ├── s3.yaml
│       ├── cloudfront.yaml
│       ├── api-gateway.yaml
│       ├── lambda.yaml
│       ├── rds.yaml
│       ├── dynamodb.yaml
│       ├── ecr.yaml
│       ├── ecs.yaml
│       └── eks.yaml
│
└── terraform/
    ├── versions.tf
    ├── provider.tf
    ├── variables.tf
    ├── locals.tf
    ├── template_bucket.tf
    ├── template_objects.tf
    ├── iam.tf
    ├── outputs.tf (upcoming)
    └── terraform.tfvars (not committed)
```

The dependency chain across these files is:

```text
Terraform
   │
   ├── S3 Template Bucket (template_bucket.tf)
   │       │
   │       └── CloudFormation templates uploaded (template_objects.tf)
   │
   └── IAM Execution Role (iam.tf)
           │
           ├── Trust Policy
           │       └── CloudFormation can assume role
           │
           └── Permissions Policy
                   ├── EC2 / ELB / Auto Scaling
                   ├── S3
                   ├── CloudFront
                   ├── Lambda
                   ├── API Gateway
                   ├── RDS
                   ├── DynamoDB
                   ├── ECR
                   ├── ECS
                   ├── EKS
                   └── CloudWatch Logs
```

Next file up (not yet built): `cloudformation_stack.tf`, which connects the uploaded S3 template, the execution role, and an `aws_cloudformation_stack` resource to actually launch `main.yaml`.

---

## versions.tf

Defines the minimum Terraform version and required providers.

```hcl
# ==========================================================
# Terraform Configuration
# ==========================================================
# This block defines the minimum Terraform version and the
# providers required by this project.
# ==========================================================

terraform {

  # --------------------------------------------------------
  # Minimum Terraform Version
  # --------------------------------------------------------
  # Terraform 1.6.0 or newer is required to run this project.
  # Using a minimum version helps avoid compatibility issues.
  # --------------------------------------------------------
  required_version = ">= 1.6.0"


  # --------------------------------------------------------
  # Required Providers
  # --------------------------------------------------------
  # Providers are plugins that allow Terraform to communicate
  # with external platforms such as AWS.
  # --------------------------------------------------------
  required_providers {

    # ------------------------------------------------------
    # AWS Provider
    # ------------------------------------------------------
    # source:
    #   Official HashiCorp AWS provider.
    #
    # version:
    #   Allows AWS provider versions in the 6.x range.
    #   "~> 6.0" means:
    #       >= 6.0.0
    #       < 7.0.0
    #
    # This prevents Terraform from automatically upgrading
    # to an incompatible future major version.
    # ------------------------------------------------------
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

**What this file does:**

1. Controls the Terraform version — `required_version = ">= 1.6.0"` means the lab requires Terraform 1.6.0 or newer.
2. Defines the AWS provider — Terraform will use the HashiCorp AWS provider 6.x.

> **Note:** Don't put the `provider "aws"` block inside `versions.tf`. Keeping `versions.tf` and `provider.tf` separate is cleaner and better Terraform practice.

---

## provider.tf

Configures the AWS provider itself, including default tags applied to every resource it manages.

```hcl
# ==========================================================
# AWS Provider Configuration
# ==========================================================
# This file configures Terraform's AWS provider.
#
# The AWS provider is responsible for allowing Terraform to
# communicate with AWS and create/manage AWS resources.
# ==========================================================


# ----------------------------------------------------------
# AWS Provider
# ----------------------------------------------------------
# The region is taken from the aws_region variable defined
# in variables.tf.
#
# Example:
#   aws_region = "us-east-1"
#
# This makes the configuration reusable because we don't
# hard-code an AWS region here.
# ----------------------------------------------------------

provider "aws" {
  region = var.aws_region


  # --------------------------------------------------------
  # Default Tags
  # --------------------------------------------------------
  # These tags are automatically applied to supported AWS
  # resources created through this AWS provider.
  #
  # This is useful for:
  #   - Resource identification
  #   - Cost tracking
  #   - Environment management
  #   - Project organization
  #   - Terraform resource management
  #
  # Instead of adding these tags repeatedly to every
  # resource, we define them once here.
  # --------------------------------------------------------

  default_tags {

    tags = {

      # ----------------------------------------------------
      # Project
      # ----------------------------------------------------
      # Identifies which project the resource belongs to.
      # The value comes from variables.tf.
      # ----------------------------------------------------
      Project = var.project_name


      # ----------------------------------------------------
      # Environment
      # ----------------------------------------------------
      # Identifies the deployment environment.
      #
      # Examples:
      #   dev
      #   test
      #   staging
      #   production
      # ----------------------------------------------------
      Environment = var.environment


      # ----------------------------------------------------
      # ManagedBy
      # ----------------------------------------------------
      # Indicates that Terraform manages this resource.
      # ----------------------------------------------------
      ManagedBy = "Terraform"


      # ----------------------------------------------------
      # Lab
      # ----------------------------------------------------
      # Identifies the specific training/project lab.
      # ----------------------------------------------------
      Lab = "Terraform-CloudFormation-Hybrid"
    }
  }
}
```

**Structure:**

```text
provider.tf
│
└── provider "aws"
    │
    ├── region
    │
    └── default_tags
        ├── Project
        ├── Environment
        ├── ManagedBy
        └── Lab
```

This file expects three variables to already be defined:

```text
var.aws_region
var.project_name
var.environment
```

> **Note:** `provider.tf` should configure the provider only. Keep the provider version constraint in `versions.tf` — this separation is good practice.

---

## variables.tf

Declares the input variables consumed by `provider.tf` (and later files).

```hcl
# ==========================================================
# Terraform Input Variables
# ==========================================================
# This file defines the input variables used throughout the
# Terraform project.
#
# Variables allow us to avoid hard-coding values directly
# inside Terraform resource configurations.
#
# The values can be provided through:
#   - Default values
#   - terraform.tfvars
#   - *.auto.tfvars
#   - Command-line -var arguments
#   - Environment variables
# ==========================================================


# ----------------------------------------------------------
# AWS Region
# ----------------------------------------------------------
# Defines the AWS region where Terraform will create the
# infrastructure.
#
# Example:
#   us-east-1
#   us-west-2
#   eu-west-1
#
# The provider.tf file uses this variable:
#
#   region = var.aws_region
#
# ----------------------------------------------------------

variable "aws_region" {
  description = "AWS region where the lab will be deployed"

  # The value must be a text/string value.
  type = string

  # Default AWS region for this lab.
  # This value is used when no other value is provided.
  default = "us-east-1"
}


# ----------------------------------------------------------
# Project Name
# ----------------------------------------------------------
# Identifies the project/application being deployed.
#
# This variable is also used by provider.tf for the
# Project default tag.
#
# Example:
#   Project = "HybridIaCLab"
# ----------------------------------------------------------

variable "project_name" {
  description = "Project name"

  # The project name must be a string.
  type = string

  # Default project name.
  default = "HybridIaCLab"
}


# ----------------------------------------------------------
# Environment
# ----------------------------------------------------------
# Identifies the environment in which the infrastructure
# is deployed.
#
# Common values include:
#   dev
#   test
#   staging
#   prod
#
# This value is also used by provider.tf for the
# Environment default tag.
# ----------------------------------------------------------

variable "environment" {
  description = "Deployment environment"

  # The environment name must be a string.
  type = string

  # Default environment.
  default = "dev"
}
```

**How these three files connect:**

```text
versions.tf
     │
     │ Terraform + AWS provider versions
     ▼
provider.tf
     │
     ├── var.aws_region ──────► variables.tf
     │
     ├── var.project_name ────► variables.tf
     │
     └── var.environment ─────► variables.tf
```

And the values flow like this:

```text
variables.tf
     │
     │ defines variables
     ▼
provider.tf
     │
     │ uses var.*
     ▼
AWS Provider
     │
     └── Default Tags
          ├── Project
          ├── Environment
          ├── ManagedBy
          └── Lab
```

> **Note:** For a learning lab, keeping `default` values is perfectly fine. Later, environment-specific values can move into `terraform.tfvars`.

---

## locals.tf

Defines reusable local values: a common name prefix, and a map of CloudFormation template file paths.

```hcl
# ==========================================================
# Terraform Local Values
# ==========================================================
# Local values allow us to define reusable values once and
# reference them throughout the Terraform configuration.
#
# In this hybrid lab, locals.tf is mainly used for:
#
#   1. Creating a consistent resource name prefix
#   2. Defining paths to CloudFormation templates
#
# Local values are referenced using:
#
#   local.<name>
#
# Example:
#
#   local.name_prefix
#   local.cloudformation_templates.vpc
# ==========================================================


locals {

  # --------------------------------------------------------
  # Common Resource Name Prefix
  # --------------------------------------------------------
  # Creates a consistent prefix using the project name and
  # deployment environment.
  #
  # Example:
  #
  #   project_name = "HybridIaCLab"
  #   environment  = "dev"
  #
  # Result:
  #
  #   HybridIaCLab-dev
  #
  # This can be used when naming AWS resources so that it is
  # easy to identify which project and environment they
  # belong to.
  # --------------------------------------------------------

  name_prefix = "${var.project_name}-${var.environment}"


  # --------------------------------------------------------
  # CloudFormation Template Paths
  # --------------------------------------------------------
  # This map contains the paths to the CloudFormation
  # templates used by the hybrid IaC lab.
  #
  # Terraform can reference these paths later when creating
  # AWS CloudFormation stacks.
  #
  # The paths are based on:
  #
  #   path.module
  #
  # path.module represents the directory containing the
  # current Terraform module.
  #
  # Because the CloudFormation templates are stored outside
  # the Terraform directory, "../" is used to move one level
  # up before entering the cloudformation directory.
  # --------------------------------------------------------

  cloudformation_templates = {

    # ------------------------------------------------------
    # Main CloudFormation Template
    # ------------------------------------------------------
    # Main CloudFormation orchestration template.
    # ------------------------------------------------------

    main = "${path.module}/../cloudformation/main.yaml"


    # ------------------------------------------------------
    # VPC Template
    # ------------------------------------------------------
    # CloudFormation nested template responsible for the
    # VPC/network infrastructure.
    # ------------------------------------------------------

    vpc = "${path.module}/../cloudformation/nested/vpc.yaml"


    # ------------------------------------------------------
    # EC2 Template
    # ------------------------------------------------------
    # CloudFormation nested template for EC2 resources.
    # ------------------------------------------------------

    ec2 = "${path.module}/../cloudformation/nested/ec2.yaml"


    # ------------------------------------------------------
    # S3 Template
    # ------------------------------------------------------
    # CloudFormation nested template for S3 resources.
    # ------------------------------------------------------

    s3 = "${path.module}/../cloudformation/nested/s3.yaml"


    # ------------------------------------------------------
    # CloudFront Template
    # ------------------------------------------------------
    # CloudFormation nested template for CloudFront.
    # ------------------------------------------------------

    cloudfront = "${path.module}/../cloudformation/nested/cloudfront.yaml"


    # ------------------------------------------------------
    # API Gateway Template
    # ------------------------------------------------------
    # CloudFormation nested template for API Gateway.
    # ------------------------------------------------------

    api_gateway = "${path.module}/../cloudformation/nested/api-gateway.yaml"


    # ------------------------------------------------------
    # Lambda Template
    # ------------------------------------------------------
    # CloudFormation nested template for AWS Lambda.
    # ------------------------------------------------------

    lambda = "${path.module}/../cloudformation/nested/lambda.yaml"


    # ------------------------------------------------------
    # RDS Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon RDS.
    # ------------------------------------------------------

    rds = "${path.module}/../cloudformation/nested/rds.yaml"


    # ------------------------------------------------------
    # DynamoDB Template
    # ------------------------------------------------------
    # CloudFormation nested template for DynamoDB.
    # ------------------------------------------------------

    dynamodb = "${path.module}/../cloudformation/nested/dynamodb.yaml"


    # ------------------------------------------------------
    # ECR Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon ECR.
    # ------------------------------------------------------

    ecr = "${path.module}/../cloudformation/nested/ecr.yaml"


    # ------------------------------------------------------
    # ECS Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon ECS.
    # ------------------------------------------------------

    ecs = "${path.module}/../cloudformation/nested/ecs.yaml"


    # ------------------------------------------------------
    # EKS Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon EKS.
    # ------------------------------------------------------

    eks = "${path.module}/../cloudformation/nested/eks.yaml"
  }
}
```

> **Important:** Terraform does not validate or load those CloudFormation files just because they're listed in `locals.tf`. It only creates reusable file-path strings that other Terraform resources (like `aws_s3_object`) reference later.

**How locals.tf works:**

Because `locals.tf` lives inside `infrastructure/terraform/`, `path.module` points to `infrastructure/terraform/`. Therefore:

```text
"${path.module}/../cloudformation/main.yaml"
```

resolves to:

```text
infrastructure/cloudformation/main.yaml
```

**How we'll use it later:**

Instead of repeatedly writing:

```text
"${path.module}/../cloudformation/nested/vpc.yaml"
```

we can simply use:

```text
local.cloudformation_templates.vpc
local.cloudformation_templates.ec2
local.cloudformation_templates.s3
local.cloudformation_templates.eks
```

And the common naming becomes `local.name_prefix`, e.g. `HybridIaCLab-dev`.

This `locals.tf` is a reusable bridge between Terraform and the existing CloudFormation templates.

---

## template_bucket.tf

Creates the Terraform-managed S3 bucket that stores the CloudFormation templates.

```hcl
# ==========================================================
# CloudFormation Template S3 Bucket
# ==========================================================
# Terraform creates and manages this S3 bucket.
#
# Purpose:
#   - Store CloudFormation templates
#   - Provide a central location for nested templates
#   - Allow CloudFormation stacks to retrieve templates
#   - Enable versioning for template history
#   - Prevent public access
#   - Encrypt templates at rest
#
# IMPORTANT:
# This bucket is intentionally created by Terraform.
# CloudFormation will use the objects stored in this bucket
# when deploying the CloudFormation portion of the hybrid
# infrastructure.
# ==========================================================


# ----------------------------------------------------------
# S3 Bucket
# ----------------------------------------------------------
# Creates the S3 bucket that will contain the CloudFormation
# templates.
#
# bucket_prefix:
#   Creates a unique bucket name beginning with the supplied
#   prefix. S3 bucket names must be globally unique.
#
# Example prefix:
#
#   HybridIaCLab-dev-cfn-templates-
#
# Terraform will generate the remaining characters.
# ----------------------------------------------------------

resource "aws_s3_bucket" "cloudformation_templates" {

  bucket_prefix = "${local.name_prefix}-cfn-templates-"

  # --------------------------------------------------------
  # Force Destroy
  # --------------------------------------------------------
  # Allows Terraform to delete the bucket even when it
  # contains objects.
  #
  # This is convenient for a learning/lab environment.
  #
  # WARNING:
  # Do NOT normally use force_destroy = true for production
  # buckets containing important data.
  # --------------------------------------------------------

  force_destroy = true
}


# ==========================================================
# S3 Bucket Versioning
# ==========================================================
# Enables versioning on the CloudFormation template bucket.
#
# Why?
#
# If a template is replaced or uploaded again, S3 can keep
# previous versions.
#
# This is useful when:
#   - A CloudFormation template is accidentally overwritten
#   - You need to inspect an older template
#   - You want basic template history
# ==========================================================

resource "aws_s3_bucket_versioning" "cloudformation_templates" {

  # Connect this configuration to the bucket created above.
  bucket = aws_s3_bucket.cloudformation_templates.id

  versioning_configuration {

    # Enable S3 object versioning.
    status = "Enabled"
  }
}


# ==========================================================
# S3 Public Access Block
# ==========================================================
# CloudFormation templates should not be publicly accessible.
#
# This resource enables all four S3 public-access protections.
# ==========================================================

resource "aws_s3_bucket_public_access_block" "cloudformation_templates" {

  # Apply the public-access settings to our template bucket.
  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # Block Public ACLs
  # --------------------------------------------------------
  # Prevents new public access control lists (ACLs).
  # --------------------------------------------------------

  block_public_acls = true


  # --------------------------------------------------------
  # Block Public Bucket Policies
  # --------------------------------------------------------
  # Prevents bucket policies that would make the bucket
  # publicly accessible.
  # --------------------------------------------------------

  block_public_policy = true


  # --------------------------------------------------------
  # Ignore Public ACLs
  # --------------------------------------------------------
  # Causes public ACLs to be ignored.
  # --------------------------------------------------------

  ignore_public_acls = true


  # --------------------------------------------------------
  # Restrict Public Buckets
  # --------------------------------------------------------
  # Restricts access to buckets that could otherwise become
  # publicly accessible.
  # --------------------------------------------------------

  restrict_public_buckets = true
}


# ==========================================================
# S3 Server-Side Encryption
# ==========================================================
# Encrypts CloudFormation template objects when they are
# stored in S3.
#
# AES256 uses Amazon S3 managed server-side encryption (SSE-S3).
#
# This means the templates are encrypted at rest without
# requiring us to create and manage a separate KMS key.
# ==========================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudformation_templates" {

  # Apply encryption configuration to our template bucket.
  bucket = aws_s3_bucket.cloudformation_templates.id


  rule {

    apply_server_side_encryption_by_default {

      # Use S3-managed AES256 encryption.
      sse_algorithm = "AES256"
    }
  }
}
```

**What Terraform is creating:**

```text
                    Terraform
                        │
                        │ creates
                        ▼
              ┌─────────────────────┐
              │    S3 Bucket        │
              │                     │
              │ CFN Templates       │
              ├─────────────────────┤
              │ Versioning: ON      │
              │ Encryption: AES256  │
              │ Public Access: OFF  │
              │ Force Destroy: ON   │
              └──────────┬──────────┘
                         │
                         │ templates uploaded
                         ▼
              ┌─────────────────────┐
              │ CloudFormation      │
              │                     │
              │ main.yaml           │
              │ nested/*.yaml       │
              └─────────────────────┘
```

> **Important distinction:** This file only creates the bucket. It does not yet upload `main.yaml`, `vpc.yaml`, `ec2.yaml`, etc. That's `template_objects.tf`, below.

---

## template_objects.tf

Uploads every CloudFormation template from the local repo into the S3 bucket, using `for_each` over the map defined in `locals.tf`.

```hcl
# ==========================================================
# CloudFormation Template Objects
# ==========================================================
# This file uploads all CloudFormation templates from the
# local repository into the S3 bucket created by Terraform.
#
# The bucket itself is created in:
#
#   template_bucket.tf
#
# The template file paths are defined in:
#
#   locals.tf
#
# Terraform will automatically create one S3 object for
# every entry in local.cloudformation_templates.
# ==========================================================


# ----------------------------------------------------------
# Upload CloudFormation Templates
# ----------------------------------------------------------
# for_each loops through the cloudformation_templates map
# defined in locals.tf.
#
# Example map entry:
#
#   vpc = "${path.module}/../cloudformation/nested/vpc.yaml"
#
# Terraform creates a separate aws_s3_object for each
# template in the map.
#
# This means we don't have to manually create separate
# resources for:
#
#   - main.yaml
#   - vpc.yaml
#   - ec2.yaml
#   - s3.yaml
#   - cloudfront.yaml
#   - api-gateway.yaml
#   - lambda.yaml
#   - rds.yaml
#   - dynamodb.yaml
#   - ecr.yaml
#   - ecs.yaml
#   - eks.yaml
# ----------------------------------------------------------

resource "aws_s3_object" "cloudformation_templates" {

  # --------------------------------------------------------
  # for_each
  # --------------------------------------------------------
  # Iterate over every CloudFormation template defined in
  # local.cloudformation_templates.
  #
  # Terraform creates one resource instance per map entry.
  #
  # Examples:
  #
  #   aws_s3_object.cloudformation_templates["main"]
  #   aws_s3_object.cloudformation_templates["vpc"]
  #   aws_s3_object.cloudformation_templates["ec2"]
  # --------------------------------------------------------

  for_each = local.cloudformation_templates


  # --------------------------------------------------------
  # Target S3 Bucket
  # --------------------------------------------------------
  # Upload the files into the S3 bucket created by the
  # aws_s3_bucket.cloudformation_templates resource.
  #
  # Using .id creates an implicit dependency:
  #
  #   S3 Bucket
  #       ↓
  #   S3 Objects
  #
  # Terraform therefore knows that the bucket must exist
  # before the objects can be uploaded.
  # --------------------------------------------------------

  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # S3 Object Key
  # --------------------------------------------------------
  # Determines where each template will be stored inside
  # the S3 bucket.
  #
  # The "main" template is stored at:
  #
  #   main.yaml
  #
  # All nested templates are stored under:
  #
  #   nested/
  #
  # For example:
  #
  #   vpc       → nested/vpc.yaml
  #   ec2       → nested/ec2.yaml
  #   lambda    → nested/lambda.yaml
  #   eks       → nested/eks.yaml
  #
  # The conditional expression:
  #
  #   condition ? value_if_true : value_if_false
  #
  # is used here.
  # --------------------------------------------------------

  key = each.key == "main"
    ? "main.yaml"
    : "nested/${each.key}.yaml"


  # --------------------------------------------------------
  # Source File
  # --------------------------------------------------------
  # each.value contains the local filesystem path to the
  # CloudFormation template.
  #
  # Example:
  #
  #   each.value
  #   ↓
  #   infrastructure/cloudformation/nested/vpc.yaml
  #
  # Terraform reads this local file and uploads it to S3.
  # --------------------------------------------------------

  source = each.value


  # --------------------------------------------------------
  # ETag / File Checksum
  # --------------------------------------------------------
  # filemd5() calculates an MD5 hash of the local template.
  #
  # Terraform uses this value to detect changes to the
  # CloudFormation template.
  #
  # Example:
  #
  # If vpc.yaml changes:
  #
  #   old filemd5 → ABC123
  #   new filemd5 → XYZ789
  #
  # Terraform detects that the file changed and updates the
  # corresponding S3 object.
  #
  # This is particularly useful for this hybrid IaC lab
  # because CloudFormation templates are maintained locally
  # but uploaded by Terraform.
  # --------------------------------------------------------

  etag = filemd5(each.value)
}
```

**What `for_each` is doing:**

`locals.tf` contains a map:

```text
cloudformation_templates = {
  main = "..."
  vpc  = "..."
  ec2  = "..."
  s3   = "..."
  ...
}
```

Terraform effectively turns that into:

```text
local.cloudformation_templates
             │
             ├── main
             ├── vpc
             ├── ec2
             ├── s3
             ├── cloudfront
             ├── api_gateway
             ├── lambda
             ├── rds
             ├── dynamodb
             ├── ecr
             ├── ecs
             └── eks
                    │
                    ▼
             for_each
                    │
                    ▼
             S3 Objects
```

**Result inside S3:**

```text
S3: <terraform-generated-bucket>
│
├── main.yaml
│
└── nested/
    ├── vpc.yaml
    ├── ec2.yaml
    ├── s3.yaml
    ├── cloudfront.yaml
    ├── api-gateway.yaml
    ├── lambda.yaml
    ├── rds.yaml
    ├── dynamodb.yaml
    ├── ecr.yaml
    ├── ecs.yaml
    └── eks.yaml
```

**The conditional key expression:**

```text
key = each.key == "main"
  ? "main.yaml"
  : "nested/${each.key}.yaml"
```

means:

```text
Is each.key equal to "main"?
       │
   ┌───┴───┐
  YES      NO
   │        │
   ▼        ▼
main.yaml  nested/<key>.yaml
```

So `main → main.yaml`, `vpc → nested/vpc.yaml`, `ec2 → nested/ec2.yaml`, `eks → nested/eks.yaml`.

This is a good file for practicing `for_each` + maps + conditional expressions + file functions + resource dependencies all in one small file — you're not just creating resources manually, you're learning how Terraform can dynamically manage an entire collection of files with a single resource block.

---

## iam.tf

Creates the IAM role CloudFormation assumes (trust policy), plus the permissions policy attached to it (what it's allowed to do). Both pieces live in the same file — that's a valid and recommended structure, not a mistake.

```hcl
# ==========================================================
# IAM - CloudFormation Execution Role
# ==========================================================
# This file creates the IAM role that AWS CloudFormation will
# assume when it deploys and manages resources for this lab.
#
# Terraform is responsible for creating:
#
#   1. CloudFormation trust policy
#   2. CloudFormation execution role
#   3. CloudFormation permissions policy
#
#
# IAM CONCEPT
# ----------------------------------------------------------
#
# An IAM role has two important sides:
#
#   TRUST POLICY
#       ↓
#   Who is allowed to assume this role?
#
#   PERMISSIONS POLICY
#       ↓
#   What can the role do after it is assumed?
#
#
# In this lab:
#
#   CloudFormation
#          │
#          │ assumes
#          ▼
#   CloudFormation Execution Role
#          │
#          │ permissions
#          ▼
#   AWS Resources
#
# IMPORTANT:
# The permissions below are intentionally broad for the
# first learning version of the lab.
#
# After the complete lab works, these permissions should be
# reviewed and reduced according to the principle of
# least privilege.
# ==========================================================


# ==========================================================
# 1. CloudFormation Trust Policy
# ==========================================================
# This policy defines WHO is allowed to assume the
# CloudFormation execution role.
#
# The AWS CloudFormation service is the trusted principal.
#
# This is NOT the permissions policy.
#
# It only establishes the trust relationship:
#
#   CloudFormation
#        │
#        │ sts:AssumeRole
#        ▼
#   IAM Role
# ==========================================================

data "aws_iam_policy_document" "cloudformation_assume_role" {

  # --------------------------------------------------------
  # Trust Policy Statement
  # --------------------------------------------------------
  statement {

    # Allow the specified AWS service to assume the role.
    effect = "Allow"


    # ------------------------------------------------------
    # Trusted Principal
    # ------------------------------------------------------
    # Identifies the AWS service that can assume the role.
    #
    # CloudFormation uses this service principal:
    #
    #   cloudformation.amazonaws.com
    # ------------------------------------------------------

    principals {
      type = "Service"

      identifiers = [
        "cloudformation.amazonaws.com"
      ]
    }


    # ------------------------------------------------------
    # Assume Role Action
    # ------------------------------------------------------
    # Allows CloudFormation to request temporary credentials
    # for this IAM role through AWS Security Token Service.
    # ------------------------------------------------------

    actions = [
      "sts:AssumeRole"
    ]
  }
}


# ==========================================================
# 2. CloudFormation Execution Role
# ==========================================================
# Creates the IAM role that CloudFormation will assume while
# deploying the resources defined by the CloudFormation
# templates.
# ==========================================================

resource "aws_iam_role" "cloudformation_execution" {

  # --------------------------------------------------------
  # IAM Role Name
  # --------------------------------------------------------
  # Uses the common name prefix defined in locals.tf.
  #
  # Example:
  #
  #   HybridIaCLab-dev-CloudFormationExecutionRole
  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationExecutionRole"


  # --------------------------------------------------------
  # Trust Policy
  # --------------------------------------------------------
  # Connects this IAM role to the trust policy defined above.
  #
  # The .json attribute converts the Terraform IAM policy
  # document into the JSON format required by AWS IAM.
  # --------------------------------------------------------

  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role.json
}


# ==========================================================
# 3. CloudFormation Permissions Policy
# ==========================================================
# This inline policy defines WHAT CloudFormation is allowed
# to do after it assumes the execution role.
#
# The policy is attached directly to:
#
#   aws_iam_role.cloudformation_execution
#
#
# IMPORTANT:
# This policy is intentionally broad for the first version
# of the learning lab.
#
# Later, after everything is working, we should reduce these
# permissions to the minimum required by the actual
# CloudFormation templates.
# ==========================================================

resource "aws_iam_role_policy" "cloudformation_lab_permissions" {

  # --------------------------------------------------------
  # Policy Name
  # --------------------------------------------------------
  # Creates a predictable policy name.
  #
  # Example:
  #
  #   HybridIaCLab-dev-CloudFormationPermissions
  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationPermissions"


  # --------------------------------------------------------
  # Role
  # --------------------------------------------------------
  # Attaches this inline policy to the CloudFormation
  # execution role created above.
  # --------------------------------------------------------

  role = aws_iam_role.cloudformation_execution.id


  # --------------------------------------------------------
  # IAM Permissions Policy
  # --------------------------------------------------------
  # jsonencode() converts the Terraform object into valid
  # IAM JSON.
  #
  # Using jsonencode() keeps the policy inside Terraform
  # without requiring a separate JSON file.
  # --------------------------------------------------------

  policy = jsonencode({

    # ------------------------------------------------------
    # IAM Policy Language Version
    # ------------------------------------------------------
    Version = "2012-10-17"


    # ======================================================
    # Permission Statements
    # ======================================================
    # Each statement groups permissions for related AWS
    # services.
    # ======================================================

    Statement = [

      # ====================================================
      # EC2 / Load Balancing / Auto Scaling / PassRole
      # ====================================================
      # Supports infrastructure such as:
      #
      #   - VPC resources
      #   - Subnets
      #   - Route tables
      #   - Internet gateways
      #   - NAT gateways
      #   - Security groups
      #   - EC2 instances
      #   - Elastic Load Balancers
      #   - Target groups
      #   - Auto Scaling groups
      #
      # iam:PassRole allows CloudFormation to pass an IAM role
      # to supported AWS services when required.
      #
      # IMPORTANT:
      # iam:PassRole should be restricted later.
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "iam:PassRole"
        ]

        Resource = "*"
      },


      # ====================================================
      # S3 / CloudFront
      # ====================================================
      # Supports:
      #
      #   - S3 buckets
      #   - S3 bucket configuration
      #   - S3 objects
      #   - CloudFront distributions
      #   - CloudFront configuration
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "s3:*",
          "cloudfront:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # Lambda / API Gateway
      # ====================================================
      # Supports serverless resources such as:
      #
      #   - Lambda functions
      #   - Lambda configurations
      #   - API Gateway REST APIs
      #   - API Gateway resources
      #   - API Gateway methods
      #   - API Gateway integrations
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "lambda:*",
          "apigateway:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # RDS / DynamoDB
      # ====================================================
      # Supports database resources such as:
      #
      #   - RDS instances
      #   - RDS subnet groups
      #   - RDS parameter groups
      #   - DynamoDB tables
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "rds:*",
          "dynamodb:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # ECR / ECS / EKS
      # ====================================================
      # Supports container-related resources such as:
      #
      #   - ECR repositories
      #   - ECS clusters
      #   - ECS services
      #   - ECS task-related resources
      #   - EKS clusters
      #
      # IMPORTANT:
      # ECS and EKS deployments can require additional IAM
      # permissions, service-linked roles, networking
      # permissions, and supporting AWS resources.
      #
      # We will handle those requirements when implementing
      # the ECS and EKS CloudFormation stacks.
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "ecr:*",
          "ecs:*",
          "eks:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # CloudWatch Logs
      # ====================================================
      # Supports CloudWatch Logs resources used by services
      # such as Lambda, ECS, and other workloads.
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "logs:*"
        ]

        Resource = "*"
      }
    ]
  })
}
```

**What you've built:**

```text
                    Terraform
                        │
                        │ creates
                        ▼
              ┌──────────────────────┐
              │ CloudFormation IAM   │
              │ Execution Role       │
              └──────────┬───────────┘
                         │
              ┌──────────┴───────────┐
              │                      │
              ▼                      ▼
        Trust Policy           Permissions Policy
        "WHO can assume?"      "WHAT can it do?"
              │                      │
              ▼                      ▼
     CloudFormation          AWS Service APIs
                                    │
          ┌─────────┬────────┬──────┼───────┬────────┐
          ▼         ▼        ▼      ▼       ▼        ▼
         EC2       S3      Lambda   RDS    DynamoDB  EKS/ECS
```

`iam.tf` contains three logical pieces:

```text
iam.tf
│
├── data.aws_iam_policy_document
│       │
│       └── Trust Policy
│           CloudFormation can assume role
│
├── aws_iam_role
│       │
│       └── CloudFormationExecutionRole
│
└── aws_iam_role_policy
        │
        └── CloudFormationLabPermissions
            │
            ├── EC2 / ELB / Auto Scaling
            ├── S3
            ├── CloudFront
            ├── Lambda
            ├── API Gateway
            ├── RDS
            ├── DynamoDB
            ├── ECR
            ├── ECS
            ├── EKS
            └── CloudWatch Logs
```

> **Security note:** `Resource = "*"` is acceptable for this learning version, while the goal is to get the hybrid architecture working end to end. It is not production IAM.
>
> Once the lab works, the next security exercise is:
>
> ```text
> Broad permissions
>        ↓
> Get everything working
>        ↓
> Identify actual API calls
>        ↓
> Remove unnecessary actions
>        ↓
> Restrict resources
>        ↓
> Least-privilege IAM
> ```
>
> `iam:PassRole` in particular should be reviewed later and restricted with an appropriate `Resource` and, where applicable, conditions.

You do **not** need to split this into separate `iam-role.tf` / `iam-policy.tf` files — keeping trust policy, role, and permissions policy together in one `iam.tf` is a fine and common structure.

---

## Where things stand / what's next

```text
terraform/
├── versions.tf         ✅ Terraform + provider version constraints
├── provider.tf         ✅ AWS provider + default tags
├── variables.tf        ✅ aws_region, project_name, environment
├── locals.tf           ✅ name_prefix + cloudformation_templates map
├── template_bucket.tf  ✅ S3 bucket for CFN templates
├── template_objects.tf ✅ uploads templates via for_each
└── iam.tf              ✅ trust policy + execution role + permissions
```

**Next logical file:** `cloudformation_stack.tf` — this is where everything comes together: Terraform will use the uploaded S3 template, the CloudFormation execution role, and an `aws_cloudformation_stack` resource to actually launch `main.yaml` and trigger the nested stacks (VPC, EC2, S3, CloudFront, Lambda, RDS, DynamoDB, ECR, ECS, EKS).

---
