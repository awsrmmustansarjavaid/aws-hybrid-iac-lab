# ============================================================
# Terraform Outputs
# ============================================================
#
# This file defines the values Terraform should display after
# the infrastructure has been successfully deployed.
#
# These outputs are useful for:
#
# - Verifying the deployment
# - Finding important AWS resource names/ARNs
# - Debugging
# - CI/CD pipelines
# - Passing information to other Terraform configurations
# - Quickly locating CloudFormation resources
#
# ============================================================


# ============================================================
# CloudFormation Template S3 Bucket
# ============================================================
#
# Displays the name of the S3 bucket that stores the
# CloudFormation templates.
#
# The bucket contains files such as:
#
# main.yaml
# nested/vpc.yaml
# nested/s3.yaml
# nested/dynamodb.yaml
# nested/ecr.yaml
#
# This is the bucket Terraform uploads the CloudFormation
# templates into before creating the CloudFormation stack.
#
# ============================================================

output "cloudformation_template_bucket" {

  # Human-readable description shown by Terraform.
  description = "S3 bucket containing CloudFormation templates"

  # Return the actual S3 bucket name.
  #
  # aws_s3_bucket.cloudformation_templates
  #     -> Terraform S3 bucket resource
  #
  # .bucket
  #     -> actual bucket name
  #
  value = aws_s3_bucket.cloudformation_templates.bucket
}


# ============================================================
# Main CloudFormation Stack Name
# ============================================================
#
# Displays the name of the main/root CloudFormation stack
# created by Terraform.
#
# Terraform creates:
#
#     aws_cloudformation_stack.main
#
# That stack then orchestrates the nested CloudFormation
# stacks defined in main.yaml.
#
# ============================================================

output "cloudformation_stack_name" {

  # Human-readable description.
  description = "Main CloudFormation stack"

  # Return the CloudFormation stack name.
  #
  # Example:
  #
  # HybridIaCLab-dev-MainStack
  #
  value = aws_cloudformation_stack.main.name
}


# ============================================================
# CloudFormation Execution Role ARN
# ============================================================
#
# Displays the ARN of the IAM role that CloudFormation uses
# to create and manage AWS resources.
#
# Architecture:
#
# Terraform
#     |
#     v
# CloudFormation
#     |
#     | assumes
#     v
# CloudFormation Execution Role
#     |
#     v
# AWS Resources
#
# The ARN is useful when troubleshooting IAM permission
# problems or verifying which role CloudFormation is using.
#
# ============================================================

output "cloudformation_execution_role_arn" {

  # Human-readable description.
  description = "CloudFormation execution role ARN"

  # Return the IAM role ARN.
  #
  # aws_iam_role.cloudformation_execution
  #     -> Terraform IAM role resource
  #
  # .arn
  #     -> Amazon Resource Name of the role
  #
  value = aws_iam_role.cloudformation_execution.arn
}

# ============================================================
# GitHub Actions IAM Role ARN
# ============================================================

output "github_actions_role_arn" {

  description = "ARN of the IAM role used by GitHub Actions through OIDC."

  value = aws_iam_role.github_actions.arn
}


# ============================================================
# GitHub Actions IAM Role Name
# ============================================================

output "github_actions_role_name" {

  description = "Name of the IAM role used by GitHub Actions."

  value = aws_iam_role.github_actions.name
}


# ============================================================
# GitHub Actions OIDC Provider ARN
# ============================================================

output "github_actions_oidc_provider_arn" {

  description = "ARN of the GitHub Actions OIDC provider."

  value = aws_iam_openid_connect_provider.github_actions.arn
}