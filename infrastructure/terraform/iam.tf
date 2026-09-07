# ==========================================================
#
# IAM CONFIGURATION
#
# Project: aws-hybrid-iac-lab
# File: iam.tf
#
# ==========================================================
#
# PURPOSE
# ----------------------------------------------------------
#
# This file manages the IAM resources required by the
# aws-hybrid-iac-lab project.
#
#
# IAM resources managed by this file:
#
# 1. GitHub Actions OIDC Provider
#
# 2. GitHub Actions OIDC Trust Policy
#
# 3. GitHub Actions IAM Role
#
# 4. GitHub Actions Customer-Managed IAM Policies
#
# 5. GitHub Actions IAM Policy Attachments
#
# 6. Existing github-ci-cd-user Policy Attachment
#
# 7. CloudFormation Trust Policy
#
# 8. CloudFormation Execution Role
#
# 9. CloudFormation Permissions Policy
#
#
# ==========================================================
# TERRAFORM SOURCE-OF-TRUTH MODEL
# ==========================================================
#
# Terraform is the source of truth for the IAM resources
# defined in this file.
#
#
# The desired architecture is:
#
#
# GitHub Repository
#       |
#       +--> IAM/*.json
#       |
#       v
# Terraform
#       |
#       +--> IAM Policies
#       |
#       +--> IAM Role
#       |
#       +--> Policy Attachments
#       |
#       v
# AWS IAM
#
#
# ==========================================================
# IMPORTANT: EXISTING IAM RESOURCES
# ==========================================================
#
# Some IAM resources in this project were created manually
# before Terraform management was introduced.
#
# Examples:
#
#     aws-hybrid-iac-lab-GitHubActions
#
#     aws-hybrid-iac-lab-GitHubActionsPolicy
#
#     github-actions-terraform-backend-policy
#
#     github-ci-cd-user-combined-access
#
#
# Terraform cannot automatically "adopt" an existing AWS
# resource simply because a resource block has the same name.
#
#
# Therefore the correct migration process is:
#
#
# Existing AWS Resource
#          |
#          v
# terraform import
#          |
#          v
# Terraform State
#          |
#          v
# Terraform manages resource
#
#
# After import:
#
#     terraform plan
#
# will recognize the resource as already managed.
#
#
# Terraform will NOT attempt to create a duplicate resource.
#
#
# ==========================================================
# IMPORTANT: NEW IAM RESOURCES
# ==========================================================
#
# If a new policy is added to the for_each map and that
# policy does NOT already exist in AWS, Terraform will create
# it.
#
#
# Example:
#
#     cloudwatch = {
#       name = "github-actions-cloudwatch-policy"
#       file = "${path.module}/../../IAM/github-actions-cloudwatch-policy.json"
#     }
#
#
# Terraform will:
#
#     1. Create the IAM policy
#
#     2. Store it in Terraform state
#
#     3. Attach it to the GitHub Actions role
#
#
# Therefore the behavior is:
#
#
# EXISTING RESOURCE
#       |
#       v
# Import once
#       |
#       v
# Terraform manages it
#
#
# NEW RESOURCE
#       |
#       v
# Terraform creates it
#       |
#       v
# Terraform manages it
#
#
# ==========================================================
# ARCHITECTURE
# ==========================================================
#
#
# GITHUB ACTIONS AUTHENTICATION
# ----------------------------------------------------------
#
# GitHub Actions
#       |
#       | OIDC JWT
#       v
# GitHub OIDC Provider
#       |
#       | sts:AssumeRoleWithWebIdentity
#       v
# GitHub Actions IAM Role
#       |
#       | temporary AWS credentials
#       v
# AWS Services
#
#
# ==========================================================
# GITHUB ACTIONS AUTHORIZATION
# ==========================================================
#
#
# GitHub Actions IAM Role
#       |
#       +--> GitHub Actions Policy
#       |
#       +--> Terraform Backend Policy
#       |
#       +--> Combined Access Policy
#       |
#       +--> Future Policies
#
#
# ==========================================================
# POLICY MANAGEMENT MODEL
# ==========================================================
#
#
# Git Repository
#       |
#       +--> IAM/*.json
#       |
#       v
# Terraform aws_iam_policy
#       |
#       v
# AWS Customer-Managed IAM Policy
#       |
#       v
# aws_iam_role_policy_attachment
#       |
#       v
# GitHub Actions IAM Role
#
#
# ==========================================================
# IMPORTANT PATH INFORMATION
# ==========================================================
#
# Terraform files:
#
#     infrastructure/terraform/
#
#
# IAM JSON files:
#
#     IAM/
#
#
# Therefore:
#
#     path.module
#
# points to:
#
#     infrastructure/terraform
#
#
# To reach the IAM directory:
#
#     ../../IAM/
#
#
# Correct example:
#
#     ${path.module}/../../IAM/policy.json
#
#
# ==========================================================


# ==========================================================
# 1. GITHUB ACTIONS OIDC PROVIDER
# ==========================================================
#
# GitHub Actions can issue an OpenID Connect token (OIDC).
#
# AWS IAM needs an OIDC provider to establish trust with
# GitHub Actions.
#
#
# GitHub OIDC issuer:
#
#     https://token.actions.githubusercontent.com
#
#
# AWS STS audience:
#
#     sts.amazonaws.com
#
#
# The OIDC provider is account-level and can be reused by
# multiple GitHub Actions IAM roles.
#
#
# ==========================================================
# IMPORTANT: OIDC TAGGING
# ==========================================================
#
# The OIDC provider intentionally does NOT define tags.
#
# This prevents Terraform from attempting:
#
#     iam:TagOpenIDConnectProvider
#
#
# The provider does not require tags to operate.
#
# ==========================================================

resource "aws_iam_openid_connect_provider" "github_actions" {

  # --------------------------------------------------------
  # Use provider without default tags.
  #
  # This avoids IAM OIDC tagging permissions.
  # --------------------------------------------------------

  provider = aws.no_default_tags

  # --------------------------------------------------------
  # GitHub Actions OIDC issuer.
  # --------------------------------------------------------

  url = "https://token.actions.githubusercontent.com"

  # --------------------------------------------------------
  # Audience accepted by AWS STS.
  # --------------------------------------------------------

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # --------------------------------------------------------
  # No tags intentionally.
  # --------------------------------------------------------
}


# ==========================================================
# 2. GITHUB ACTIONS OIDC TRUST POLICY
# ==========================================================
#
# This policy answers:
#
#     "WHO is allowed to assume the GitHub Actions role?"
#
#
# Trusted repository:
#
#     awsrmmustansarjavaid/aws-hybrid-iac-lab
#
#
# Trusted branch:
#
#     main
#
# ==========================================================

data "aws_iam_policy_document" "github_actions_assume_role" {

  statement {

    # ------------------------------------------------------
    # Allow GitHub OIDC identity to assume the role.
    # ------------------------------------------------------

    effect = "Allow"

    # ------------------------------------------------------
    # GitHub Actions OIDC provider.
    # ------------------------------------------------------

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    # ------------------------------------------------------
    # STS action required for GitHub OIDC.
    # ------------------------------------------------------

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    # ------------------------------------------------------
    # OIDC audience.
    #
    # Token must contain:
    #
    #     aud = sts.amazonaws.com
    #
    # ------------------------------------------------------

    condition {
      test = "StringEquals"

      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    # ------------------------------------------------------
    # OIDC subject.
    #
    # Only the main branch of the specified repository is
    # trusted.
    # ------------------------------------------------------

    condition {
      test = "StringEquals"

      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
      ]
    }
  }
}


# ==========================================================
# 3. GITHUB ACTIONS IAM ROLE
# ==========================================================
#
# Existing role:
#
#     aws-hybrid-iac-lab-GitHubActions
#
#
# IMPORTANT
# ----------------------------------------------------------
#
# If this role already exists in AWS, import it into
# Terraform state ONCE.
#
#
# Example:
#
#     terraform import aws_iam_role.github_actions \
#     aws-hybrid-iac-lab-GitHubActions
#
#
# After import Terraform manages the existing role.
#
#
# If the role does not exist, Terraform creates it.
#
# ==========================================================

resource "aws_iam_role" "github_actions" {

  # --------------------------------------------------------
  # Preserve the existing role name.
  # --------------------------------------------------------

  name = "aws-hybrid-iac-lab-GitHubActions"

  # --------------------------------------------------------
  # Role description.
  # --------------------------------------------------------

  description = "aws-hybrid-iac-lab-GitHubActions"

  # --------------------------------------------------------
  # GitHub Actions OIDC trust relationship.
  # --------------------------------------------------------

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  # --------------------------------------------------------
  # Maximum role session duration.
  # --------------------------------------------------------

  max_session_duration = 3600

  # --------------------------------------------------------
  # IAM role tags.
  # --------------------------------------------------------

  tags = {
    Name        = "${local.name_prefix}-GitHubActions"
    Project     = "aws-hybrid-iac-lab"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions CI/CD"
    Environment = var.environment
  }
}


# ==========================================================
# 4. GITHUB ACTIONS CUSTOMER-MANAGED IAM POLICIES
# ==========================================================
#
# Terraform manages the following customer-managed policies:
#
#
# 1. aws-hybrid-iac-lab-GitHubActionsPolicy
#
# 2. github-actions-terraform-backend-policy
#
# 3. github-ci-cd-user-combined-access
#
#
# The policy documents are stored in:
#
#     ../../IAM/
#
#
# ==========================================================
# EXISTING POLICIES
# ==========================================================
#
# If these policies already exist in AWS, import them into
# Terraform state ONCE.
#
#
# After import:
#
#     Terraform manages them.
#
#
# If they do not exist:
#
#     Terraform creates them.
#
#
# ==========================================================

resource "aws_iam_policy" "github_actions" {

  # --------------------------------------------------------
  # One Terraform resource instance is created for every
  # entry in this map.
  #
  # Resource addresses:
  #
  # aws_iam_policy.github_actions["github_actions"]
  #
  # aws_iam_policy.github_actions["terraform_backend"]
  #
  # aws_iam_policy.github_actions["combined_access"]
  #
  # --------------------------------------------------------

  for_each = {

    # ======================================================
    # POLICY 1
    # ======================================================

    github_actions = {

      # Existing AWS IAM policy name.
      name = "aws-hybrid-iac-lab-GitHubActionsPolicy"

      # JSON policy stored in Git.
      file = "${path.module}/../../IAM/aws-hybrid-iac-lab-GitHubActionsPolicy.json"
    }


    # ======================================================
    # POLICY 2
    # ======================================================

    terraform_backend = {

      # Existing AWS IAM policy name.
      name = "github-actions-terraform-backend-policy"

      # JSON policy stored in Git.
      file = "${path.module}/../../IAM/github-actions-terraform-backend-policy.json"
    }


    # ======================================================
    # POLICY 3
    # ======================================================

    combined_access = {

      # Existing AWS IAM policy name.
      name = "github-ci-cd-user-combined-access"

      # JSON policy stored in Git.
      file = "${path.module}/../../IAM/github-ci-cd-user-combined-access.json"
    }
  }

  # --------------------------------------------------------
  # AWS IAM customer-managed policy name.
  # --------------------------------------------------------

  name = each.value.name

  # --------------------------------------------------------
  # Read policy JSON from Git repository.
  #
  # This makes Git the source of truth for the policy
  # document.
  # --------------------------------------------------------

  policy = file(each.value.file)

  # --------------------------------------------------------
  # Terraform management tags.
  # --------------------------------------------------------

  tags = {
    Project   = "aws-hybrid-iac-lab"
    ManagedBy = "Terraform"
  }
}


# ==========================================================
# 5. GITHUB ACTIONS IAM POLICY ATTACHMENTS
# ==========================================================
#
# Automatically attach every policy defined above to the
# GitHub Actions IAM role.
#
#
# Current result:
#
#
# aws-hybrid-iac-lab-GitHubActions
#       |
#       +--> aws-hybrid-iac-lab-GitHubActionsPolicy
#       |
#       +--> github-actions-terraform-backend-policy
#       |
#       +--> github-ci-cd-user-combined-access
#
#
# ==========================================================
# IMPORTANT
# ==========================================================
#
# Existing attachments should also be imported ONCE.
#
# After import Terraform manages the attachment.
#
#
# New policy:
#
#     Terraform creates policy
#              |
#              v
#     Terraform creates attachment
#
#
# Existing policy:
#
#     terraform import
#              |
#              v
#     Terraform manages policy + attachment
#
# ==========================================================

resource "aws_iam_role_policy_attachment" "github_actions" {

  # --------------------------------------------------------
  # Iterate through every Terraform-managed policy.
  # --------------------------------------------------------

  for_each = aws_iam_policy.github_actions

  # --------------------------------------------------------
  # Existing GitHub Actions role.
  # --------------------------------------------------------

  role = aws_iam_role.github_actions.name

  # --------------------------------------------------------
  # ARN of current policy.
  # --------------------------------------------------------

  policy_arn = each.value.arn
}


# ==========================================================
# 6. EXISTING github-ci-cd-user
#    COMBINED ACCESS POLICY ATTACHMENT
# ==========================================================
#
# The IAM user:
#
#     github-ci-cd-user
#
# already has:
#
#     github-ci-cd-user-combined-access
#
# attached.
#
#
# IMPORTANT:
# ----------------------------------------------------------
#
# The same customer-managed IAM policy can safely be
# attached to multiple identities.
#
#
# Therefore:
#
#
# github-ci-cd-user-combined-access
#          |
#          +--> GitHub Actions Role
#          |
#          +--> github-ci-cd-user
#
#
# We are NOT removing the user attachment.
#
# Terraform will manage it as well.
#
# ==========================================================

data "aws_iam_user" "github_ci_cd_user" {

  # --------------------------------------------------------
  # Reference the existing IAM user.
  #
  # This does NOT create the IAM user.
  # --------------------------------------------------------

  user_name = "github-ci-cd-user"
}


# ==========================================================
# USER POLICY ATTACHMENT
# ==========================================================

resource "aws_iam_user_policy_attachment" "combined_access" {

  # --------------------------------------------------------
  # Existing IAM user.
  # --------------------------------------------------------

  user = data.aws_iam_user.github_ci_cd_user.user_name

  # --------------------------------------------------------
  # Terraform-managed combined access policy.
  # --------------------------------------------------------

  policy_arn = aws_iam_policy.github_actions["combined_access"].arn
}


# ==========================================================
# 7. CLOUDFORMATION TRUST POLICY
# ==========================================================
#
# Separate from GitHub Actions.
#
# This trust policy allows AWS CloudFormation to assume the
# CloudFormation execution role.
#
# ==========================================================

data "aws_iam_policy_document" "cloudformation_assume_role" {

  statement {

    # ------------------------------------------------------
    # Allow CloudFormation to assume the role.
    # ------------------------------------------------------

    effect = "Allow"

    # ------------------------------------------------------
    # AWS CloudFormation service principal.
    # ------------------------------------------------------

    principals {
      type = "Service"

      identifiers = [
        "cloudformation.amazonaws.com"
      ]
    }

    # ------------------------------------------------------
    # STS action used by CloudFormation.
    # ------------------------------------------------------

    actions = [
      "sts:AssumeRole"
    ]
  }
}


# ==========================================================
# 8. CLOUDFORMATION EXECUTION ROLE
# ==========================================================
#
# CloudFormation assumes this role to create and manage
# resources defined by the CloudFormation templates.
#
# ==========================================================

resource "aws_iam_role" "cloudformation_execution" {

  # --------------------------------------------------------
  # CloudFormation execution role name.
  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationExecutionRole"

  # --------------------------------------------------------
  # CloudFormation trust policy.
  # --------------------------------------------------------

  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role.json
}


# ==========================================================
# 9. CLOUDFORMATION PERMISSIONS POLICY
# ==========================================================
#
# Broad laboratory permissions.
#
# Production environments should restrict these permissions
# to only the actions and resources actually required.
#
# ==========================================================

resource "aws_iam_role_policy" "cloudformation_lab_permissions" {

  # --------------------------------------------------------
  # Inline policy name.
  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationPermissions"

  # --------------------------------------------------------
  # CloudFormation execution role.
  # --------------------------------------------------------

  role = aws_iam_role.cloudformation_execution.id

  # --------------------------------------------------------
  # Permissions.
  # --------------------------------------------------------

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      # ====================================================
      # EC2 / ELB / Auto Scaling / PassRole
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


# ==========================================================
# ADDING A NEW IAM POLICY
# ==========================================================
#
# Suppose you add:
#
#     IAM/github-actions-cloudwatch-policy.json
#
#
# Add:
#
#
#     cloudwatch = {
#       name = "github-actions-cloudwatch-policy"
#       file = "${path.module}/../../IAM/github-actions-cloudwatch-policy.json"
#     }
#
#
# Terraform automatically:
#
#     1. Creates the policy
#
#     2. Stores it in Terraform state
#
#     3. Attaches it to the GitHub Actions role
#
#
# No new attachment block is required.
#
#
# ==========================================================
# EXISTING POLICY MIGRATION
# ==========================================================
#
# For policies that already exist in AWS:
#
#
# Step 1
#
#     terraform import ...
#
#
# Step 2
#
#     terraform plan
#
#
# Step 3
#
# Review any differences.
#
#
# Step 4
#
#     terraform apply
#
#
# After this migration Terraform becomes the source of
# truth.
#
#
# ==========================================================
# END OF IAM CONFIGURATION
# ==========================================================

