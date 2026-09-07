# ============================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS DEVOPS LAB
# ============================================================
#
# File:
#   infrastructure/terraform/variables.tf
#
# Purpose:
#   Defines the Terraform input variables for the lab.
#
# ARCHITECTURAL RULE:
#
#   Only values that Terraform genuinely needs from outside
#   the CloudFormation hierarchy should be variables here.
#
# CloudFormation itself creates:
#
#   - VPC
#   - Subnets
#   - Application S3 bucket
#   - Lambda
#   - ECR repository
#   - DynamoDB
#   - API Gateway
#   - CloudFront
#   - EC2
#   - ECS
#   - EKS
#   - RDS
#
# Therefore we DO NOT ask Terraform for:
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
# Those values are produced by CloudFormation.
#
# ============================================================


# ============================================================
# 1. AWS REGION
# ============================================================

variable "aws_region" {

  description = "AWS region where the lab is deployed."

  type = string

  default = "us-east-1"

  validation {

    condition = length(trimspace(var.aws_region)) > 0

    error_message = "aws_region must not be empty."
  }
}


# ============================================================
# 2. PROJECT NAME
# ============================================================

variable "project_name" {

  description = "Main project/lab name."

  type = string

  default = "HybridIaCLab"

  validation {

    condition = can(regex("^[A-Za-z0-9-]+$", var.project_name))

    error_message = "project_name may contain only letters, numbers, and hyphens."
  }
}


# ============================================================
# 3. ENVIRONMENT
# ============================================================

variable "environment" {

  description = "Deployment environment."

  type = string

  default = "dev"

  validation {

    condition = contains(
      ["dev", "test", "staging", "prod"],
      var.environment
    )

    error_message = "environment must be dev, test, staging, or prod."
  }
}


# ============================================================
# 4. AMAZON LINUX 2023 AMI ID
# ============================================================
#
# This remains an external variable because the AMI itself is
# not created by our CloudFormation stack.
#
# Example:
#
#   ami-0123456789abcdef0
#
# ============================================================

variable "ami_id" {

  description = "Amazon Linux 2023 AMI ID used by the EC2 nested stack."

  type = string

  validation {

    condition = can(regex("^ami-[a-zA-Z0-9]+$", var.ami_id))

    error_message = "ami_id must be a valid AMI ID such as ami-0123456789abcdef0."
  }
}


# ============================================================
# 5. ECR IMAGE URI
# ============================================================
#
# Important distinction:
#
# CloudFormation creates:
#
#   ECR Repository
#
# CI/CD creates:
#
#   Docker Image
#
# Therefore the final image URI is still an external input.
#
# Example:
#
#   537236558357.dkr.ecr.us-east-1.amazonaws.com/
#   HybridIaCLab-dev-app:latest
#
# ============================================================

variable "ecr_image_uri" {

  description = "Docker image URI that the ECS service should run."

  type = string

  validation {

    condition = can(regex(
      "^[0-9]{12}\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/[A-Za-z0-9._/-]+:[A-Za-z0-9._-]+$",
      var.ecr_image_uri
    ))

    error_message = "ecr_image_uri must be a valid ECR image URI including an image tag."
  }
}


# ============================================================
# 6. DATABASE USERNAME
# ============================================================
#
# Username is not sensitive in the same way as the password.
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

    condition = can(regex("^[A-Za-z][A-Za-z0-9_]{0,15}$", var.database_username))

    error_message = "database_username must begin with a letter and contain only letters, numbers, and underscores."
  }
}


# ============================================================
# 7. DATABASE PASSWORD
# ============================================================
#
# IMPORTANT:
#
# This is sensitive.
#
# Do not commit the real value to GitHub.
#
# For local development:
#
#   terraform.tfvars
#
# For GitHub Actions:
#
#   TF_VAR_database_password
#
# should be supplied from a GitHub Secret.
#
# ============================================================

variable "database_password" {

  description = "RDS database administrator password."

  type = string

  sensitive = true

  validation {

    condition = length(var.database_password) >= 8

    error_message = "database_password must contain at least 8 characters."
  }
}


# ============================================================
# END OF variables.tf
# ============================================================