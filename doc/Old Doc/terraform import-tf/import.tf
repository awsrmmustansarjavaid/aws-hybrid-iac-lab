# ============================================================
# EXISTING IAM RESOURCES
# ============================================================
#
# These resources already exist in AWS.
#
# These import blocks tell Terraform to adopt the existing
# AWS resources into Terraform state instead of attempting
# to create duplicate resources.
#
# IMPORTANT:
#
# These imports are a ONE-TIME state adoption operation.
#
# After the resources are successfully imported, these blocks
# can be removed from the configuration.
#
# ============================================================


# ============================================================
# 1. GitHub Actions customer-managed IAM policy
# ============================================================

import {
  to = aws_iam_policy.github_actions["github_actions"]

  id = "arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
}


# ============================================================
# 2. Terraform backend IAM policy
# ============================================================

import {
  to = aws_iam_policy.github_actions["terraform_backend"]

  id = "arn:aws:iam::537236558357:policy/github-actions-terraform-backend-policy"
}


# ============================================================
# 3. Combined CI/CD access IAM policy
# ============================================================

import {
  to = aws_iam_policy.github_actions["combined_access"]

  id = "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ============================================================
# 4. GitHub Actions role attachment
# ============================================================

import {
  to = aws_iam_role_policy_attachment.github_actions["github_actions"]

  id = "aws-hybrid-iac-lab-GitHubActions/arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
}


# ============================================================
# 5. Terraform backend role attachment
# ============================================================

import {
  to = aws_iam_role_policy_attachment.github_actions["terraform_backend"]

  id = "aws-hybrid-iac-lab-GitHubActions/arn:aws:iam::537236558357:policy/github-actions-terraform-backend-policy"
}


# ============================================================
# 6. Combined access role attachment
# ============================================================

import {
  to = aws_iam_role_policy_attachment.github_actions["combined_access"]

  id = "aws-hybrid-iac-lab-GitHubActions/arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ============================================================
# 7. Existing IAM user policy attachment
# ============================================================

import {
  to = aws_iam_user_policy_attachment.combined_access

  id = "github-ci-cd-user/arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ============================================================
# END OF IMPORT CONFIGURATION
# ============================================================