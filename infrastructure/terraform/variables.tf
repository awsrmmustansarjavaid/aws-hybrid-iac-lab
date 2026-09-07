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
# Repository-specific paths, such as the location of IAM JSON
# policy documents, are NOT defined as Terraform variables.
#
# Those paths are part of the repository structure and are
# therefore handled directly by the Terraform configuration
# that consumes them.
#
# Example:
#
#   iam.tf
#      |
#      +--> ${path.module}/../../IAM/*.json
#
# No iam_policy_directory variable is required.
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
#   4. Networking
#   5. Compute
#   6. Application infrastructure
#   7. Database configuration
#
#
# IAM RESOURCES
# ==========================================================
#
# IAM policy resources themselves are NOT controlled through
# variables in this file.
#
# IAM policy definitions are stored separately under:
#
#   <repository-root>/IAM/
#
# IAM Terraform resources are defined in:
#
#   <repository-root>/infrastructure/terraform/iam.tf
#
# Therefore:
#
#   variables.tf
#        |
#        +--> infrastructure inputs
#
#   iam.tf
#        |
#        +--> IAM resources
#        +--> IAM policy JSON files
#        +--> IAM role attachments
#
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

  type = string

  # Default region for this lab.
  #
  # This can still be overridden by terraform.tfvars.
  default = "us-east-1"

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

  type = string

  default = "HybridIaCLab"

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



# ==========================================================
# 4. VPC ID
# ==========================================================
#
# ID of the VPC used by the CloudFormation root stack and
# nested infrastructure.
#
# Example:
#
#   vpc-0123456789abcdef0
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

  type = string

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
# 5. PUBLIC SUBNET ID
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
# 6. PUBLIC SUBNET 1 ID
# ==========================================================
#
# First public subnet used by the CloudFormation
# infrastructure.
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
# 7. PUBLIC SUBNET 2 ID
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
# 8. PRIVATE SUBNET 1 ID
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
# 9. PRIVATE SUBNET 2 ID
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
# 10. AMAZON LINUX 2023 AMI ID
# ==========================================================
#
# AMI used by the EC2 nested CloudFormation stack.
#
# Example:
#
#   ami-0123456789abcdef0
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
# Recommended command:
#
# PowerShell:
#
#   aws ssm get-parameter `
#     --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
#     --query "Parameter.Value" `
#     --output text `
#     --region us-east-1
#
# Do NOT use an example AMI ID.
#
# ==========================================================

variable "ami_id" {

  description = "Amazon Linux 2023 AMI ID used by the EC2 CloudFormation stack"

  type = string

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
# 11. APPLICATION S3 BUCKET NAME
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
# 12. LAMBDA FUNCTION ARN
# ==========================================================
#
# ARN of the Lambda function used by the application or
# CloudFormation resources.
#
# Example:
#
#   arn:aws:lambda:us-east-1:537236558357:function:MyFunction
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
# 13. ECR IMAGE URI
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
# ==========================================================

variable "ecr_image_uri" {

  description = "Full Amazon ECR container image URI used by ECS or other container resources"

  type = string

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
# 14. DATABASE PASSWORD
# ==========================================================
#
# Password used by the RDS database.
#
# SECURITY WARNING
# ==========================================================
#
# This variable contains sensitive information.
#
# Terraform will treat this value as sensitive because:
#
#   sensitive = true
#
# IMPORTANT:
#
# Even though the value is hidden in normal Terraform CLI
# output, it can still exist in Terraform state because
# Terraform passes the value to CloudFormation.
#
# NEVER:
#
#   - Commit the real password to GitHub.
#   - Put the real password in variables.tf.
#   - Put the real password in README.md.
#   - Put the real password directly into .tf resources.
#   - Publish the Terraform state.
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

  sensitive = true

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
#       +--> CloudFormation
#       +--> S3
#       +--> Networking
#       +--> Compute
#       +--> Database
#       +--> Application infrastructure
#
#
# ==========================================================
# IAM DATA FLOW
# ==========================================================
#
# IAM policy JSON documents are stored separately:
#
#   repository-root/
#   |
#   +-- IAM/
#   |    |
#   |    +-- aws-hybrid-iac-lab-GitHubActionsPolicy.json
#   |    +-- github-actions-terraform-backend-policy.json
#   |    +-- github-ci-cd-user-combined-access.json
#   |
#   +-- infrastructure/
#        |
#        +-- terraform/
#             |
#             +-- iam.tf
#             +-- variables.tf
#
#
# iam.tf references the JSON files using:
#
#   ${path.module}/../../IAM/<policy-file>.json
#
#
# IMPORTANT:
#
# There is NO:
#
#   variable "iam_policy_directory"
#
# because the IAM directory is a fixed part of the
# repository structure rather than an environment-specific
# input.
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