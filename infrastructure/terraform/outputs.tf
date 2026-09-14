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
# - Making important values available after deployment
# - Quickly identifying the CloudFormation stack and related resources
#
# ============================================================


# ============================================================
# CloudFormation Template S3 Bucket
# ============================================================
#
# Displays the name of the S3 bucket that stores the
# CloudFormation templates.
#
# The bucket is intended to store CloudFormation templates,
# including the main template and nested templates.
#
# This bucket is used to store CloudFormation templates
# required by the CloudFormation deployment.
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
# Displays the name of the CloudFormation stack
# managed by Terraform.
#
# Terraform creates:
#
#     aws_cloudformation_stack.main
#
# The stack is managed through the Terraform
# aws_cloudformation_stack.main resource.
#
# ============================================================

output "cloudformation_stack_name" {

  # Human-readable description.
  description = "Main CloudFormation stack"

  # Return the CloudFormation stack name.
  #
  # Example:
  #
  # hybridiaclab-dev-MainStack
  #
  value = aws_cloudformation_stack.main.name
}


# ============================================================
# CloudFormation Execution Role ARN
# ============================================================
#
# Displays the ARN of the IAM role designated for
# CloudFormation resource management.
#
# Architecture:
#
# Terraform
#     |
#     v
# CloudFormation stack
#     |
#     v
# CloudFormation execution role ARN
#     |
#     v
# IAM role resource
#
# The ARN is useful when troubleshooting IAM permission
# problems or identifying the CloudFormation execution role.
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