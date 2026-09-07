# ==========================================================
#
# TERRAFORM RESOURCE ADOPTION / IMPORTS
#
# Project:
#   aws-hybrid-iac-lab
#
# File:
#   infrastructure/terraform/iam-imports.tf
#
# Purpose:
#   Adopt existing AWS IAM resources into Terraform state.
#
# IMPORTANT:
#
#   These import blocks DO NOT delete AWS resources.
#
#   These import blocks DO NOT recreate AWS resources.
#
#   They tell Terraform that an existing AWS resource should
#   be associated with an existing Terraform resource address.
#
#
# Architecture:
#
#   Existing AWS Resource
#          |
#          v
#   Terraform Import
#          |
#          v
#   Terraform State
#          |
#          v
#   Terraform Management
#
# ==========================================================


# ==========================================================
# AWS ACCOUNT
# ==========================================================
#
# Account ID:
#
#   537236558357
#
# This account ID was verified using the AWS CLI.
#
# ==========================================================


# ==========================================================
# 1. GITHUB ACTIONS OIDC PROVIDER
# ==========================================================
#
# Existing AWS resource:
#
#   arn:aws:iam::537236558357:oidc-provider/
#   token.actions.githubusercontent.com
#
# Terraform resource address:
#
#   aws_iam_openid_connect_provider.github_actions
#
# ==========================================================

import {
  to = aws_iam_openid_connect_provider.github_actions

  id = "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
}


# ==========================================================
# 2. GITHUB ACTIONS IAM POLICY
# ==========================================================
#
# Existing AWS policy:
#
#   aws-hybrid-iac-lab-GitHubActionsPolicy
#
# Terraform resource address:
#
#   aws_iam_policy.github_actions["github_actions"]
#
# ==========================================================

import {
  to = aws_iam_policy.github_actions["github_actions"]

  id = "arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
}


# ==========================================================
# 3. TERRAFORM BACKEND POLICY
# ==========================================================
#
# Existing AWS policy:
#
#   github-actions-terraform-backend-policy
#
# Terraform resource address:
#
#   aws_iam_policy.github_actions["terraform_backend"]
#
# ==========================================================

import {
  to = aws_iam_policy.github_actions["terraform_backend"]

  id = "arn:aws:iam::537236558357:policy/github-actions-terraform-backend-policy"
}


# ==========================================================
# 4. COMBINED ACCESS POLICY
# ==========================================================
#
# Existing AWS policy:
#
#   github-ci-cd-user-combined-access
#
# Terraform resource address:
#
#   aws_iam_policy.github_actions["combined_access"]
#
# ==========================================================

import {
  to = aws_iam_policy.github_actions["combined_access"]

  id = "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ==========================================================
# 5. GITHUB ACTIONS IAM ROLE
# ==========================================================
#
# Existing AWS role:
#
#   aws-hybrid-iac-lab-GitHubActions
#
# Terraform resource address:
#
#   aws_iam_role.github_actions
#
# ==========================================================

import {
  to = aws_iam_role.github_actions

  id = "aws-hybrid-iac-lab-GitHubActions"
}


# ==========================================================
# 6. CLOUDFORMATION EXECUTION ROLE
# ==========================================================
#
# Existing AWS role:
#
#   HybridIaCLab-dev-CloudFormationExecutionRole
#
# Terraform resource address:
#
#   aws_iam_role.cloudformation_execution
#
# ==========================================================

import {
  to = aws_iam_role.cloudformation_execution

  id = "HybridIaCLab-dev-CloudFormationExecutionRole"
}


# ==========================================================
# 7. CLOUDFORMATION INLINE PERMISSIONS POLICY
# ==========================================================
#
# Existing AWS inline policy:
#
#   HybridIaCLab-dev-CloudFormationPermissions
#
# Attached to:
#
#   HybridIaCLab-dev-CloudFormationExecutionRole
#
# Terraform resource address:
#
#   aws_iam_role_policy.cloudformation_lab_permissions
#
# ==========================================================

import {
  to = aws_iam_role_policy.cloudformation_lab_permissions

  id = "HybridIaCLab-dev-CloudFormationExecutionRole:HybridIaCLab-dev-CloudFormationPermissions"
}


# ==========================================================
# 8. EXISTING USER POLICY ATTACHMENT
# ==========================================================
#
# Existing IAM user:
#
#   github-ci-cd-user
#
# Existing customer-managed policy:
#
#   github-ci-cd-user-combined-access
#
# Terraform resource address:
#
#   aws_iam_user_policy_attachment.combined_access
#
# ==========================================================

import {
  to = aws_iam_user_policy_attachment.combined_access

  id = "github-ci-cd-user/arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ==========================================================
# END OF TERRAFORM RESOURCE ADOPTION / IMPORTS
# ==========================================================
#
# IMPORTANT:
#
# After the imports are recognized by Terraform:
#
#   terraform plan
#
# must be reviewed carefully.
#
# We especially need to inspect the existing GitHub Actions
# role trust policy because the AWS trust relationship currently
# differs from the trust relationship defined in iam.tf.
#
# ==========================================================