# ============================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS DEVOPS LAB
# ============================================================
#
# File:
#
#   infrastructure/terraform/variables.tf
#
# Project:
#
#   aws-hybrid-iac-lab
#
# Purpose:
#
#   Defines Terraform input variables required by the
#   infrastructure layer.
#
#
# ============================================================
# ARCHITECTURE RULE
# ============================================================
#
# This project uses a hybrid infrastructure model:
#
#   Terraform
#       |
#       +--> Terraform-managed infrastructure
#       |
#       +--> CloudFormation root stack
#               |
#               +--> Nested CloudFormation stacks
#
#
# IMPORTANT:
#
# Terraform should only request values that are genuinely
# external inputs.
#
# CloudFormation creates and manages its own resources.
#
#
# Therefore Terraform should NOT require variables for
# resources that CloudFormation itself creates, such as:
#
#   - VPC
#   - Subnets
#   - Application S3 bucket
#   - Lambda functions
#   - ECR repository
#   - DynamoDB
#   - API Gateway
#   - CloudFront
#   - EC2
#   - ECS
#   - EKS
#   - RDS
#
#
# Their IDs, ARNs, and names should flow from the
# CloudFormation hierarchy through stack outputs when
# Terraform needs to consume them.
#
#
# ============================================================
# IAM ARCHITECTURE RULE
# ============================================================
#
# IAM is different from the CloudFormation infrastructure.
#
# Terraform manages the IAM resources defined in:
#
#   infrastructure/terraform/iam.tf
#
#
# Therefore IAM resource NAME variables are allowed.
#
# For example:
#
#   github_actions_role_name
#
#   github_actions_policy_name
#
#   terraform_backend_policy_name
#
#   github_ci_cd_combined_policy_name
#
#
# However, repository-specific IAM JSON file paths are NOT
# variables.
#
# The IAM JSON files live at a fixed repository location:
#
#   repository-root/
#   |
#   +-- IAM/
#       |
#       +-- aws-hybrid-iac-lab-GitHubActionsPolicy.json
#       +-- github-actions-terraform-backend-policy.json
#       +-- github-ci-cd-user-combined-access.json
#
#
# iam.tf references these files directly with:
#
#   ${path.module}/../../IAM/<file>.json
#
#
# There is intentionally NO:
#
#   variable "iam_policy_directory"
#
#
# ============================================================
# VARIABLE ORGANIZATION
# ============================================================
#
# This file contains variables for:
#
#   1. AWS configuration
#   2. Project configuration
#   3. Environment configuration
#   4. External compute/application inputs
#   5. Database credentials
#   6. Terraform-managed IAM resource names
#
#
# ============================================================
# 1. AWS REGION
# ============================================================
#
# AWS region where Terraform manages the lab.
#
# Example:
#
#   us-east-1
#
# provider.tf uses:
#
#   region = var.aws_region
#
# ============================================================

variable "aws_region" {

  description = "AWS region where the hybrid Terraform and CloudFormation lab is deployed."

  type = string

  # Default region for this lab.
  #
  # This can be overridden through terraform.tfvars,
  # *.auto.tfvars, CLI arguments, or environment variables.

  default = "us-east-1"

  validation {

    condition = length(
      trimspace(var.aws_region)
    ) > 0

    error_message = "aws_region must not be empty."
  }
}



# ============================================================
# 2. PROJECT NAME
# ============================================================
#
# Main project/lab name.
#
# Used for:
#
#   - Resource naming
#   - Resource tags
#   - CloudFormation stack naming
#   - Logging
#   - Cost identification
#
# Example:
#
#   HybridIaCLab
#
# ============================================================

variable "project_name" {

  description = "Main project/lab name used for resource naming, tagging, and CloudFormation."

  type = string

  default = "HybridIaCLab"

  validation {

    condition = can(
      regex(
        "^[A-Za-z0-9-]+$",
        trimspace(var.project_name)
      )
    )

    error_message = "project_name may contain only letters, numbers, and hyphens."
  }
}



# ============================================================
# 3. ENVIRONMENT
# ============================================================
#
# Deployment environment.
#
# Supported values:
#
#   dev
#   test
#   staging
#   prod
#
# Example:
#
#   dev
#
# ============================================================

variable "environment" {

  description = "Deployment environment."

  type = string

  default = "dev"

  validation {

    condition = contains(
      ["dev", "test", "staging", "prod"],
      lower(trimspace(var.environment))
    )

    error_message = "environment must be one of: dev, test, staging, prod."
  }
}


# ============================================================
# 5. DATABASE USERNAME
# ============================================================
#
# Database administrator username.
#
# This is not considered highly sensitive in the same way as
# the database password.
#
# Default:
#
#   admin
#
# ============================================================

variable "database_username" {

  description = "RDS database administrator username."

  type = string

  default = "admin"

  validation {

    condition = can(
      regex(
        "^[A-Za-z][A-Za-z0-9_]{0,15}$",
        trimspace(var.database_username)
      )
    )

    error_message = "database_username must begin with a letter and contain only letters, numbers, and underscores."
  }
}



# ============================================================
# 6. GITHUB ACTIONS IAM ROLE NAME
# ============================================================
#
# Name of the IAM role assumed by GitHub Actions through
# GitHub OIDC.
#
# IMPORTANT:
#
# Terraform creates/manages this IAM role.
#
# Therefore a variable for the ROLE NAME is appropriate.
#
# The role ARN is NOT an input variable.
#
# Terraform can obtain the ARN from:
#
#   aws_iam_role.github_actions.arn
#
# or the corresponding Terraform resource.
#
# Example:
#
#   github-actions-oidc-role
#
# ============================================================

variable "github_actions_role_name" {

  description = "Name of the IAM role assumed by GitHub Actions through OIDC."

  type = string

  default = "github-actions-oidc-role"

  validation {

    condition = can(
      regex(
        "^[A-Za-z0-9+=,.@_-]{1,64}$",
        trimspace(var.github_actions_role_name)
      )
    )

    error_message = "github_actions_role_name must be a valid IAM role name with 1-64 characters."
  }
}



# ============================================================
# 7. GITHUB ACTIONS IAM POLICY NAME
# ============================================================
#
# Name of the customer-managed IAM policy used by the
# GitHub Actions OIDC role.
#
# Terraform creates the policy.
#
# The policy DOCUMENT itself is stored as JSON under:
#
#   repository-root/IAM/
#
# Therefore:
#
#   policy name --> variable
#
#   policy JSON path --> fixed in iam.tf
#
# ============================================================

variable "github_actions_policy_name" {

  description = "Name of the customer-managed IAM policy attached to the GitHub Actions OIDC role."

  type = string

  default = "aws-hybrid-iac-lab-GitHubActionsPolicy"

  validation {

    condition = can(
      regex(
        "^[A-Za-z0-9+=,.@_-]{1,128}$",
        trimspace(var.github_actions_policy_name)
      )
    )

    error_message = "github_actions_policy_name must be a valid IAM policy name with 1-128 characters."
  }
}



# ============================================================
# 8. TERRAFORM BACKEND IAM POLICY NAME
# ============================================================
#
# Name of the customer-managed IAM policy used for the
# Terraform backend.
#
# Example responsibilities may include:
#
#   - S3 state bucket access
#   - Terraform state object access
#   - DynamoDB locking, if used
#
# The actual permissions remain in the IAM JSON policy file.
#
# ============================================================

variable "terraform_backend_policy_name" {

  description = "Name of the customer-managed IAM policy used by the Terraform backend."

  type = string

  default = "github-actions-terraform-backend-policy"

  validation {

    condition = can(
      regex(
        "^[A-Za-z0-9+=,.@_-]{1,128}$",
        trimspace(var.terraform_backend_policy_name)
      )
    )

    error_message = "terraform_backend_policy_name must be a valid IAM policy name with 1-128 characters."
  }
}



# ============================================================
# 9. GITHUB CI/CD COMBINED POLICY NAME
# ============================================================
#
# Name of the customer-managed IAM policy containing the
# combined AWS permissions required by the CI/CD identity.
#
# The policy document is stored separately in:
#
#   IAM/github-ci-cd-user-combined-access.json
#
# IMPORTANT:
#
# The JSON file path is NOT a Terraform variable.
#
# The policy name is a variable because it is an actual
# Terraform-managed IAM resource attribute.
#
# ============================================================

variable "github_ci_cd_combined_policy_name" {

  description = "Name of the customer-managed IAM policy containing the combined GitHub CI/CD AWS permissions."

  type = string

  default = "github-ci-cd-user-combined-access"

  validation {

    condition = can(
      regex(
        "^[A-Za-z0-9+=,.@_-]{1,128}$",
        trimspace(var.github_ci_cd_combined_policy_name)
      )
    )

    error_message = "github_ci_cd_combined_policy_name must be a valid IAM policy name with 1-128 characters."
  }
}



# ============================================================
# 10. IAM POLICY PATHS
# ============================================================
#
# NO IAM POLICY DIRECTORY VARIABLE IS REQUIRED.
#
# Do NOT add:
#
#   variable "iam_policy_directory"
#
#
# The repository structure is fixed:
#
#   repository-root/
#   |
#   +-- IAM/
#       |
#       +-- aws-hybrid-iac-lab-GitHubActionsPolicy.json
#       +-- github-actions-terraform-backend-policy.json
#       +-- github-ci-cd-user-combined-access.json
#
#
# iam.tf should reference these files directly using:
#
#   ${path.module}/../../IAM/<policy-file>.json
#
#
# This makes the repository structure explicit and avoids
# unnecessary environment variables.
#
# ============================================================



# ============================================================
# 11. IAM ROLE ARN / POLICY ARN
# ============================================================
#
# NO IAM ROLE ARN VARIABLE IS REQUIRED.
#
# NO IAM POLICY ARN VARIABLE IS REQUIRED.
#
# Because Terraform creates the IAM resources, their ARNs
# are available directly from Terraform resource attributes.
#
# Example:
#
#   aws_iam_role.github_actions.arn
#
#   aws_iam_policy.github_actions.arn
#
#
# Do NOT create variables such as:
#
#   variable "github_actions_role_arn"
#
#   variable "github_actions_policy_arn"
#
# unless an IAM resource is genuinely created outside this
# Terraform configuration.
#
# ============================================================



# ============================================================
# END OF variables.tf
# ============================================================
#
#
# FINAL VARIABLE DATA FLOW
# ============================================================
#
# terraform.tfvars
#       |
#       | external values
#       v
# variables.tf
#       |
#       +--> AWS configuration
#       |
#       +--> Project configuration
#       |
#       +--> Environment
#       |
#       +--> AMI
#       |
#       +--> Database credentials
#       |
#       +--> IAM resource names
#       |
#       v
# Terraform resources
#
#
# ============================================================
# CLOUDFORMATION DATA FLOW
# ============================================================
#
# Terraform
#     |
#     | creates/updates CloudFormation root stack
#     v
# CloudFormation Root Stack
#     |
#     +--> VPC
#     +--> Subnets
#     +--> Application S3
#     +--> Lambda
#     +--> ECR repository
#     +--> DynamoDB
#     +--> API Gateway
#     +--> CloudFront
#     +--> EC2
#     +--> ECS
#     +--> EKS
#     +--> RDS
#     |
#     v
# CloudFormation Outputs
#     |
#     v
# Terraform / dependent resources
#
#
# ============================================================
# IAM DATA FLOW
# ============================================================
#
# Terraform
#     |
#     +--> IAM role
#     |
#     +--> IAM policies
#     |
#     +--> IAM attachments
#     |
#     v
# AWS IAM
#
#
# IAM POLICY DOCUMENT DATA FLOW
# ============================================================
#
# repository-root/
#
#     IAM/
#       |
#       +-- aws-hybrid-iac-lab-GitHubActionsPolicy.json
#       |
#       +-- github-actions-terraform-backend-policy.json
#       |
#       +-- github-ci-cd-user-combined-access.json
#                     |
#                     v
#                    iam.tf
#                     |
#                     v
#              aws_iam_policy
#
#
# ============================================================
# VARIABLES THAT SHOULD NOT BE HERE
# ============================================================
#
# The following are intentionally NOT Terraform input
# variables under the new CloudFormation architecture:
#
#   vpc_id
#   public_subnet_id
#   public_subnet_1_id
#   public_subnet_2_id
#   private_subnet_1_id
#   private_subnet_2_id
#   application_bucket_name
#   lambda_function_arn
#
#
# These resources are created by CloudFormation.
#
#
# Similarly, do NOT add:
#
#   iam_policy_directory
#   github_actions_role_arn
#   github_actions_policy_arn
#
# because those values are either fixed repository paths or
# values Terraform can obtain directly from its own resources.
#
#
# ============================================================
# IMPORTANT
# ============================================================
#
# Variables WITHOUT defaults:
#
#   ami_id
#   database_password
#
#
# These values should normally be supplied through:
#
#   terraform.tfvars
#
# or:
#
#   TF_VAR_*
#
# environment variables / CI/CD secret mechanisms.
#
#
# IAM NAME VARIABLES WITH DEFAULTS:
#
#   github_actions_role_name
#   github_actions_policy_name
#   terraform_backend_policy_name
#   github_ci_cd_combined_policy_name
#
# These defaults are naming conventions and can be overridden
# when a different environment or naming strategy is required.
#
# ============================================================