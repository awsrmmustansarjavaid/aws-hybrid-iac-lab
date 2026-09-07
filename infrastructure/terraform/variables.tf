# ==========================================================
# Terraform Input Variables
# ==========================================================
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
#   Defines all input variables used throughout the Terraform
#   project.
#
#
# ==========================================================
# WHY VARIABLES ARE USED
# ==========================================================
#
# Terraform variables prevent infrastructure-specific values
# from being hard-coded directly inside Terraform resources.
#
# Values can be supplied through:
#
#   - terraform.tfvars
#   - *.auto.tfvars
#   - Command-line -var arguments
#   - Environment variables
#   - CI/CD secret/variable systems
#
#
# IMPORTANT:
#
# Environment-specific infrastructure IDs such as:
#
#   - VPC IDs
#   - Subnet IDs
#   - AMI IDs
#   - Lambda ARNs
#   - ECR image URIs
#
# should normally be supplied through terraform.tfvars or
# another secure/dynamic configuration mechanism.
#
#
# SECURITY:
#
# Sensitive values such as database passwords must NOT be
# hard-coded into this file or committed to GitHub.
#
#
# ==========================================================
# VARIABLE ORGANIZATION
# ==========================================================
#
# This file contains variables for:
#
#   1. AWS configuration
#   2. Project configuration
#   3. Environment configuration
#   4. GitHub Actions IAM policies
#   5. Networking
#   6. Compute
#   7. Application infrastructure
#   8. Database configuration
#
# ==========================================================



# ==========================================================
# 1. AWS REGION
# ==========================================================
#
# Defines the AWS region where Terraform manages the lab.
#
# Example:
#
#   us-east-1
#
# The provider.tf file uses:
#
#   region = var.aws_region
#
# ==========================================================

variable "aws_region" {

  description = "AWS region where the hybrid Terraform and CloudFormation lab will be deployed"

  # AWS region is represented as a string.
  type = string

  # Default region for this lab.
  #
  # This can still be overridden by terraform.tfvars.
  default = "us-east-1"

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------
  #
  # Prevent an empty AWS region from being supplied.
  # --------------------------------------------------------

  validation {
    condition = length(
      trimspace(var.aws_region)
    ) > 0

    error_message = "aws_region must not be empty."
  }
}



# ==========================================================
# 2. PROJECT NAME
# ==========================================================
#
# Identifies the project/application.
#
# Used for:
#
#   - Resource naming
#   - AWS tags
#   - CloudFormation stack names
#   - Logging
#   - Cost tracking
#
# Example:
#
#   HybridIaCLab
#
# ==========================================================

variable "project_name" {

  description = "Project name used for resource naming, tagging, and CloudFormation"

  # Project name must be a string.
  type = string

  # Default project name.
  default = "HybridIaCLab"

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------
  #
  # Prevent an empty project name.
  # --------------------------------------------------------

  validation {
    condition = length(
      trimspace(var.project_name)
    ) > 0

    error_message = "project_name must not be empty."
  }
}



# ==========================================================
# 3. ENVIRONMENT
# ==========================================================
#
# Identifies the deployment environment.
#
# Common values:
#
#   dev
#   test
#   staging
#   prod
#
# This value is also used by provider default tags.
#
# ==========================================================

variable "environment" {

  description = "Deployment environment"

  # Environment must be a string.
  type = string

  # Default environment for this lab.
  default = "dev"

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------
  #
  # Only allow the common environment names used by this
  # project.
  #
  # If you later need another environment name, this list
  # can be expanded.
  # --------------------------------------------------------

  validation {
    condition = contains(
      ["dev", "test", "staging", "prod"],
      lower(trimspace(var.environment))
    )

    error_message = "environment must be one of: dev, test, staging, prod."
  }
}



# ==========================================================
# 4. GITHUB ACTIONS IAM ROLE POLICIES
# ==========================================================
#
# Defines the IAM policies that Terraform automatically
# attaches to the GitHub Actions IAM role.
#
#
# IAM ROLE:
#
#   aws-hybrid-iac-lab-GitHubActions
#
#
# Current policies:
#
#   1. aws-hybrid-iac-lab-GitHubActionsPolicy
#
#   2. github-actions-terraform-backend-policy
#
#   3. github-ci-cd-user-combined-access
#
#
# ==========================================================
# HOW THIS WORKS
# ==========================================================
#
# The IAM role is defined in:
#
#   iam.tf
#
#
# The role-policy attachment uses:
#
#   for_each = var.github_actions_role_policy_arns
#
#
# Therefore every policy ARN listed here is automatically
# attached to the GitHub Actions role.
#
#
# ==========================================================
# ADDING FUTURE POLICIES
# ==========================================================
#
# If you create another IAM policy, for example:
#
#   github-actions-cloudwatch-policy
#
# simply add:
#
#   "arn:aws:iam::537236558357:policy/github-actions-cloudwatch-policy"
#
# to this variable.
#
#
# You do NOT need to modify the IAM role resource.
#
# You do NOT need to manually attach the policy in the AWS
# Console.
#
#
# After adding the policy ARN:
#
#   terraform fmt
#   terraform validate
#   terraform plan
#   terraform apply
#
#
# Terraform will automatically create the new attachment.
#
#
# ==========================================================
# WHY set(string) IS USED
# ==========================================================
#
# A set prevents duplicate policy ARNs.
#
# Example:
#
#   policy-a
#   policy-a
#
# becomes one unique policy entry.
#
#
# "for_each" can also track each policy independently.
#
# This is preferable to manually creating one
# aws_iam_role_policy_attachment resource for every policy.
#
# ==========================================================

variable "github_actions_role_policy_arns" {

  description = "Set of IAM policy ARNs automatically attached to the GitHub Actions IAM role."

  # --------------------------------------------------------
  # A set of strings is used because every item is an IAM
  # policy ARN.
  #
  # Using a set:
  #
  #   - Prevents duplicates
  #   - Works naturally with for_each
  #   - Makes adding/removing policies easy
  #   - Allows Terraform to track each attachment
  #     independently
  # --------------------------------------------------------

  type = set(string)

  # --------------------------------------------------------
  # Current customer-managed IAM policies.
  #
  # AWS Account:
  #
  #   537236558357
  #
  # These policies must already exist in AWS if iam.tf is
  # only managing the attachments.
  #
  # --------------------------------------------------------

  default = [

    # ------------------------------------------------------
    # Policy 1
    #
    # Main GitHub Actions project permissions.
    # ------------------------------------------------------

    "arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy",

    # ------------------------------------------------------
    # Policy 2
    #
    # Terraform remote backend permissions.
    # ------------------------------------------------------

    "arn:aws:iam::537236558357:policy/github-actions-terraform-backend-policy",

    # ------------------------------------------------------
    # Policy 3
    #
    # Combined CI/CD AWS permissions.
    # ------------------------------------------------------

    "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
  ]
}



# ==========================================================
# 5. VPC ID
# ==========================================================
#
# ID of the VPC used by the CloudFormation root stack and
# nested infrastructure.
#
# Example:
#
#   vpc-0123456789abcdef0
#
#
# IMPORTANT:
#
# There is intentionally NO default value here.
#
# The real VPC ID must be supplied through terraform.tfvars
# or another Terraform variable source.
#
# ==========================================================

variable "vpc_id" {

  description = "VPC ID used by the CloudFormation root stack"

  # VPC IDs are strings.
  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------
  #
  # Validate the general AWS VPC ID format.
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^vpc-[0-9a-fA-F]{8,}$",
        trimspace(var.vpc_id)
      )
    )

    error_message = "vpc_id must be a valid AWS VPC ID such as vpc-0123456789abcdef0."
  }
}



# ==========================================================
# 6. PUBLIC SUBNET ID
# ==========================================================
#
# Primary public subnet used by resources such as EC2.
#
# Example:
#
#   subnet-0123456789abcdef0
#
# ==========================================================

variable "public_subnet_id" {

  description = "Primary public subnet ID used by EC2 or other public resources"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^subnet-[0-9a-fA-F]{8,}$",
        trimspace(var.public_subnet_id)
      )
    )

    error_message = "public_subnet_id must be a valid AWS subnet ID such as subnet-0123456789abcdef0."
  }
}



# ==========================================================
# 7. PUBLIC SUBNET 1 ID
# ==========================================================
#
# First public subnet used by resources such as ECS.
#
# For a Multi-AZ architecture, this subnet should normally
# exist in one Availability Zone.
#
# Example:
#
#   subnet-0123456789abcdef0
#
# ==========================================================

variable "public_subnet_1_id" {

  description = "First public subnet ID used by the CloudFormation infrastructure"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^subnet-[0-9a-fA-F]{8,}$",
        trimspace(var.public_subnet_1_id)
      )
    )

    error_message = "public_subnet_1_id must be a valid AWS subnet ID such as subnet-0123456789abcdef0."
  }
}



# ==========================================================
# 8. PUBLIC SUBNET 2 ID
# ==========================================================
#
# Second public subnet used by the CloudFormation
# infrastructure.
#
# For Multi-AZ architecture, this subnet should normally be
# located in a different Availability Zone from
# public_subnet_1_id.
#
# Example:
#
#   subnet-0123456789abcdef1
#
# ==========================================================

variable "public_subnet_2_id" {

  description = "Second public subnet ID used by the CloudFormation infrastructure"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^subnet-[0-9a-fA-F]{8,}$",
        trimspace(var.public_subnet_2_id)
      )
    )

    error_message = "public_subnet_2_id must be a valid AWS subnet ID such as subnet-0123456789abcdef0."
  }
}



# ==========================================================
# 9. PRIVATE SUBNET 1 ID
# ==========================================================
#
# First private subnet used by resources such as RDS.
#
# RDS should normally use private subnets rather than
# directly exposing the database to the public internet.
#
# Example:
#
#   subnet-0123456789abcdef2
#
# ==========================================================

variable "private_subnet_1_id" {

  description = "First private subnet ID used by the CloudFormation infrastructure and RDS"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^subnet-[0-9a-fA-F]{8,}$",
        trimspace(var.private_subnet_1_id)
      )
    )

    error_message = "private_subnet_1_id must be a valid AWS subnet ID such as subnet-0123456789abcdef0."
  }
}



# ==========================================================
# 10. PRIVATE SUBNET 2 ID
# ==========================================================
#
# Second private subnet used by resources such as RDS.
#
# For Multi-AZ architecture, this subnet should normally
# exist in a different Availability Zone from
# private_subnet_1_id.
#
# Example:
#
#   subnet-0123456789abcdef3
#
# ==========================================================

variable "private_subnet_2_id" {

  description = "Second private subnet ID used by the CloudFormation infrastructure and RDS"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^subnet-[0-9a-fA-F]{8,}$",
        trimspace(var.private_subnet_2_id)
      )
    )

    error_message = "private_subnet_2_id must be a valid AWS subnet ID such as subnet-0123456789abcdef0."
  }
}



# ==========================================================
# 11. AMAZON LINUX 2023 AMI ID
# ==========================================================
#
# AMI used by the EC2 nested CloudFormation stack.
#
# Example:
#
#   ami-0123456789abcdef0
#
#
# IMPORTANT:
#
# AMI IDs are region-specific.
#
# Because this lab uses:
#
#   us-east-1
#
# the AMI must exist in us-east-1.
#
#
# Recommended command to retrieve the current Amazon Linux
# 2023 x86_64 AMI:
#
# PowerShell:
#
#   aws ssm get-parameter `
#     --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
#     --query "Parameter.Value" `
#     --output text `
#     --region us-east-1
#
#
# The returned value should look similar to:
#
#   ami-0123456789abcdef0
#
# Do NOT use an example AMI ID.
#
# ==========================================================

variable "ami_id" {

  description = "Amazon Linux 2023 AMI ID used by the EC2 CloudFormation stack"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^ami-[0-9a-fA-F]{8,}$",
        trimspace(var.ami_id)
      )
    )

    error_message = "ami_id must be a valid AWS AMI ID such as ami-0123456789abcdef0."
  }
}



# ==========================================================
# 12. APPLICATION S3 BUCKET NAME
# ==========================================================
#
# Name of the S3 bucket used by the application.
#
# IMPORTANT:
#
# This is different from the CloudFormation template bucket
# unless your architecture intentionally uses the same bucket.
#
# Terraform creates/manages the CloudFormation template bucket
# separately through:
#
#   aws_s3_bucket.cloudformation_templates
#
# This variable represents the APPLICATION bucket.
#
# Example:
#
#   hybridiaclab-dev-app
#
# ==========================================================

variable "application_bucket_name" {

  description = "Application S3 bucket name used by the CloudFormation infrastructure"

  type = string

  # --------------------------------------------------------
  # S3 bucket name validation
  # --------------------------------------------------------
  #
  # This performs a basic validation of the bucket-name
  # structure.
  #
  # AWS has additional S3 naming rules, so this validation
  # should not be considered a complete AWS API validation.
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$",
        trimspace(var.application_bucket_name)
      )
    )

    error_message = "application_bucket_name must be a valid S3 bucket-style name."
  }
}



# ==========================================================
# 13. LAMBDA FUNCTION ARN
# ==========================================================
#
# ARN of the Lambda function used by the application or
# CloudFormation resources.
#
# Example:
#
#   arn:aws:lambda:us-east-1:537236558357:function:MyFunction
#
#
# IMPORTANT:
#
# The Lambda function must actually exist if the nested
# CloudFormation templates reference it as an existing
# resource.
#
# ==========================================================

variable "lambda_function_arn" {

  description = "Lambda function ARN used by the CloudFormation infrastructure"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^arn:aws:lambda:[a-z0-9-]+:[0-9]{12}:function:[A-Za-z0-9-_]+$",
        trimspace(var.lambda_function_arn)
      )
    )

    error_message = "lambda_function_arn must be a valid AWS Lambda function ARN."
  }
}



# ==========================================================
# 14. ECR IMAGE URI
# ==========================================================
#
# Full URI of the container image stored in Amazon ECR.
#
# ECS/container-based CloudFormation resources can use this
# value to deploy the application image.
#
# Example:
#
#   537236558357.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
#
#
# Structure:
#
#   AWS Account ID
#        |
#        v
#   ECR Registry
#        |
#        v
#   AWS Region
#        |
#        v
#   Repository
#        |
#        v
#   Image Tag
#
# ==========================================================

variable "ecr_image_uri" {

  description = "Full Amazon ECR container image URI used by ECS or other container resources"

  type = string

  # --------------------------------------------------------
  # Validation
  # --------------------------------------------------------

  validation {
    condition = can(
      regex(
        "^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+$",
        trimspace(var.ecr_image_uri)
      )
    )

    error_message = "ecr_image_uri must be a valid ECR image URI including a repository and image tag."
  }
}



# ==========================================================
# 15. DATABASE PASSWORD
# ==========================================================
#
# Password used by the RDS database.
#
#
# SECURITY WARNING
# ==========================================================
#
# This variable contains sensitive information.
#
# Terraform will treat this value as sensitive because:
#
#     sensitive = true
#
#
# IMPORTANT:
#
# Even though the value is hidden in normal Terraform CLI
# output, it can still exist in Terraform state because
# Terraform passes the value to CloudFormation.
#
#
# NEVER:
#
#   - Commit the real password to GitHub.
#   - Put the real password in variables.tf.
#   - Put the real password in README.md.
#   - Put the real password directly into .tf resources.
#   - Publish the Terraform state.
#
#
# Recommended approaches:
#
#   - Local development:
#       terraform.tfvars
#
#   - CI/CD:
#       GitHub Secrets
#
#   - Production:
#       AWS Secrets Manager
#
# ==========================================================

variable "database_password" {

  description = "Sensitive RDS database password"

  type = string

  # --------------------------------------------------------
  # Hide this variable from normal Terraform CLI output.
  # --------------------------------------------------------

  sensitive = true

  # --------------------------------------------------------
  # Password validation
  # --------------------------------------------------------
  #
  # The current CloudFormation documentation for this lab
  # specifies a minimum length of 8 characters.
  #
  # This validation intentionally does not enforce a specific
  # complexity policy because the final password requirements
  # should match the RDS/CloudFormation template.
  # --------------------------------------------------------

  validation {
    condition = length(
      var.database_password
    ) >= 8

    error_message = "database_password must contain at least 8 characters."
  }
}



# ==========================================================
# END OF variables.tf
# ==========================================================
#
#
# VARIABLE DATA FLOW
# ==========================================================
#
# terraform.tfvars
#       |
#       | supplies actual environment values
#       v
# variables.tf
#       |
#       | exposes var.*
#       v
# Terraform resources
#       |
#       +--> IAM
#       +--> CloudFormation
#       +--> S3
#       +--> Networking
#       +--> Compute
#       +--> Database
#       +--> Application infrastructure
#
#
# ==========================================================
# GITHUB ACTIONS IAM DATA FLOW
# ==========================================================
#
# github_actions_role_policy_arns
#              |
#              v
#          iam.tf
#              |
#              v
# aws_iam_role_policy_attachment
#              |
#              v
# aws-hybrid-iac-lab-GitHubActions
#              |
#       ┌──────┼──────┬───────────┐
#       |      |      |           |
#       v      v      v           v
#     IAM    IAM    IAM        Future
#   Policy  Policy Policy      Policies
#      1      2      3
#
#
# ==========================================================
# ADDING A NEW GITHUB ACTIONS POLICY
# ==========================================================
#
# Example:
#
#   Create:
#
#       github-actions-cloudwatch-policy
#
#
#   Then add its ARN to:
#
#       github_actions_role_policy_arns
#
#
#   Example:
#
#       "arn:aws:iam::537236558357:policy/github-actions-cloudwatch-policy"
#
#
#   Then run:
#
#       terraform fmt
#       terraform validate
#       terraform plan
#       terraform apply
#
#
# Terraform automatically attaches the new policy to:
#
#       aws-hybrid-iac-lab-GitHubActions
#
#
# ==========================================================
# IMPORTANT
# ==========================================================
#
# The following variables intentionally have NO defaults:
#
#   vpc_id
#   public_subnet_id
#   public_subnet_1_id
#   public_subnet_2_id
#   private_subnet_1_id
#   private_subnet_2_id
#   ami_id
#   application_bucket_name
#   lambda_function_arn
#   ecr_image_uri
#   database_password
#
#
# Their actual values must be supplied through:
#
#   terraform.tfvars
#
# or another appropriate Terraform variable mechanism.
#
# ==========================================================