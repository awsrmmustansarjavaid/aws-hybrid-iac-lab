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
# IAM JSON files provide the policy documents for the
# customer-managed IAM policies created by Terraform.
#
#
# Architecture:
#
# Terraform configuration
#       |
#       +--> IAM resources
#       |
#       +--> IAM roles
#       |
#       +--> IAM policy attachments
#       |
#       +--> IAM trust policies
#       |
#       v
# AWS IAM
#
#
# For customer-managed policies:
#
# IAM/*.json
#       |
#       v
# Terraform aws_iam_policy
#       |
#       v
# AWS IAM policy
#
# ==========================================================
# IMPORTANT: EXISTING IAM RESOURCES
# ==========================================================
#
# Some IAM resources in this project were created manually
# before Terraform management was introduced.
#
# Examples of resources that may have existed in AWS
# before Terraform management was introduced:
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
# Terraform cannot automatically adopt an existing AWS
# resource simply because a resource block has the same name.
#
#
# Correct migration process:
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
# Terraform will NOT attempt to create a duplicate resource
# when the existing resource has been correctly imported.
#
#
# ==========================================================
# IMPORTANT: NEW IAM RESOURCES
# ==========================================================
#
# If a new policy is added to the policy map and that policy
# does NOT already exist in AWS, Terraform will create it.
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
#     3. The attachment configuration can attach it to the
#        GitHub Actions role.
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
# To reach the repository-level IAM directory:
#
#     ../../IAM/
#
#
# Correct example:
#
#     ${path.module}/../../IAM/policy.json
#
#
# No iam_policy_directory variable is required.
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
# ==========================================================
# IMPORTANT: OIDC TAGGING
# ==========================================================
#
# This resource intentionally uses the aws.no_default_tags
# provider configuration and does not define explicit tags.
#
# This prevents provider-level default tags from being applied
# to the OIDC provider.
#
# ==========================================================

resource "aws_iam_openid_connect_provider" "github_actions" {

  # --------------------------------------------------------
  # Use the provider without default tags.
  #
  # This avoids requiring IAM OIDC tagging permissions.
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

data "aws_iam_policy_document" "github_actions_assume_role" {

  statement {

    sid    = "GitHubActionsOIDCTrust"
    effect = "Allow"

    principals {
      type = "Federated"

      identifiers = [
        "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
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
# The role must exist in Terraform state before Terraform
# can manage an already-existing AWS role.
#
# Verify the current Terraform state before importing:
#
#     terraform state list
#
# If the role is not in state and already exists in AWS,
# import it once.
#
# Therefore do NOT import it again unless the state is removed.
#
# ==========================================================

resource "aws_iam_role" "github_actions" {

  # --------------------------------------------------------
  # Preserve the existing role name.
  # --------------------------------------------------------

  name = var.github_actions_role_name

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
    Project = var.project_name
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
# These policies may already exist in AWS or may be created
# by Terraform if they do not exist.
#
#
# 1. aws-hybrid-iac-lab-GitHubActionsPolicy
#
# 2. github-actions-terraform-backend-policy
#
# 3. github-ci-cd-user-combined-access
#
#
# Policy JSON documents are stored separately in:
#
#     <repository-root>/IAM/
#
#
# Terraform files are stored in:
#
#     <repository-root>/infrastructure/terraform/
#
#
# Therefore the correct relative path is:
#
#     ${path.module}/../../IAM/<file>.json
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
#     Terraform manages the policies.
#
#
# If a policy does not exist:
#
#     Terraform creates it.
#
# ==========================================================

resource "aws_iam_policy" "github_actions" {

  # --------------------------------------------------------
  # Each map entry represents one customer-managed policy.
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

      # AWS IAM customer-managed policy name.
      name = var.github_actions_policy_name

      # JSON policy stored in Git.
      file = "${path.module}/../../IAM/aws-hybrid-iac-lab-GitHubActionsPolicy.json"
    }


    # ======================================================
    # POLICY 2
    # ======================================================

    terraform_backend = {

      # AWS IAM customer-managed policy name.
      name = var.terraform_backend_policy_name

      # JSON policy stored in Git.
      file = "${path.module}/../../IAM/github-actions-terraform-backend-policy.json"
    }


    # ======================================================
    # POLICY 3
    # ======================================================

    combined_access = {

      # AWS IAM customer-managed policy name.
      name = var.github_ci_cd_combined_policy_name

      # JSON policy stored in Git.
      file = "${path.module}/../../IAM/github-ci-cd-user-combined-access.json"
    }
  }

  # --------------------------------------------------------
  # AWS IAM customer-managed policy name.
  # --------------------------------------------------------

  name = each.value.name

  # --------------------------------------------------------
  # Read the JSON policy document from the repository.
  #
  # Git therefore becomes the source of truth for the policy
  # document.
  # --------------------------------------------------------

  policy = file(each.value.file)

  # --------------------------------------------------------
  # Terraform management tags.
  # --------------------------------------------------------

  tags = {
    Project = var.project_name
    ManagedBy = "Terraform"
  }
}


# ==========================================================
# 5. GITHUB ACTIONS IAM POLICY ATTACHMENTS
# ==========================================================
#
# The three Terraform-managed policies are attached to the
# GitHub Actions IAM role.
#
#
# Desired result:
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
# IMPORTANT: STATIC for_each KEYS
# ==========================================================
#
# DO NOT use:
#
#     for_each = aws_iam_policy.github_actions
#
#
# Why?
#
# Terraform needs to know the complete set of resource
# instance keys during the planning phase.
#
# The ARN values of aws_iam_policy.github_actions are not
# necessarily known until the policies are created or
# refreshed.
#
#
# Therefore we explicitly define the keys:
#
#     github_actions
#     terraform_backend
#     combined_access
#
#
# Terraform can determine the complete set of attachments
# during planning while resolving the ARN values separately.
#
# ==========================================================

resource "aws_iam_role_policy_attachment" "github_actions" {

  # --------------------------------------------------------
  # IMPORTANT:
  #
  # Keep these keys static.
  #
  # Terraform must know exactly which attachment instances
  # exist during the planning phase.
  # --------------------------------------------------------

  for_each = {
    github_actions = aws_iam_policy.github_actions["github_actions"].arn

    terraform_backend = aws_iam_policy.github_actions["terraform_backend"].arn

    combined_access = aws_iam_policy.github_actions["combined_access"].arn
  }

  # --------------------------------------------------------
  # Existing GitHub Actions IAM role.
  # --------------------------------------------------------

  role = aws_iam_role.github_actions.name

  # --------------------------------------------------------
  # ARN of the current customer-managed policy.
  # --------------------------------------------------------

  policy_arn = each.value
}


# ==========================================================
# 6. EXISTING github-ci-cd-user
#    COMBINED ACCESS POLICY ATTACHMENT
# ==========================================================
#
# Existing IAM user:
#
#     github-ci-cd-user
#
#
# Customer-managed policy:
#
#     github-ci-cd-user-combined-access
#
#
#
# The same customer-managed IAM policy can be attached to
# multiple identities.
#
#
# Therefore this policy intentionally has two attachments:
#
#
#     github-ci-cd-user-combined-access
#              |
#              +--> GitHub Actions IAM Role
#              |
#              +--> github-ci-cd-user
#
#
# AWS may therefore correctly show:
#
#     Attached entities = 2
#
#
# We are NOT removing the existing IAM user attachment.
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
#
# Terraform manages the policy attachment between the
# existing IAM user and the customer-managed policy.
#
# The IAM user itself is not managed by this file.
#
# If the attachment already exists in AWS, import it ONCE.
#
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
# This trust relationship is separate from GitHub Actions.
#
# It allows the AWS CloudFormation service to assume the
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
# IMPORTANT:
#
# This policy is intentionally broad for the laboratory.
#
# Production environments should use least-privilege
# permissions restricted to only the actions and resources
# actually required.
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
  # CloudFormation permissions.
  # --------------------------------------------------------

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      # ====================================================
      # EC2 / ELB / Auto Scaling 
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*"
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
      },

      # ====================================================
      # CloudFormation
      #
      # Required because the root CloudFormation stack
      # creates and manages nested CloudFormation stacks.
      #
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "cloudformation:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # IAM ROLE MANAGEMENT FOR CLOUDFORMATION-MANAGED ROLES
      # ====================================================
      #
      # CloudFormation may need to create and manage IAM roles
      # used by resources defined in the CloudFormation templates.
      #
      # The permissions are restricted to roles whose names match:
      #
      #     ${local.name_prefix}-*
      #
      # This allows CloudFormation to manage only the lab's
      # CloudFormation-managed roles following this naming convention.
      #
      # The role ARN pattern:
      #
      #     ${local.name_prefix}-*
      #
      # intentionally covers CloudFormation-managed roles that
      # belong to this lab.
      #
      # CloudFormation therefore needs permission to:
      #
      #     - Create roles
      #     - Read roles
      #     - Read inline policies
      #     - Create/update inline policies
      #     - Delete inline policies
      #     - Attach managed policies
      #     - Detach managed policies
      #     - Delete roles during rollback/cleanup
      #
      # ====================================================

      {
        Sid    = "ManageCloudFormationManagedRoles"
        Effect = "Allow"

        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:TagRole",
          "iam:UntagRole"
        ]

        Resource = [
          "arn:aws:iam::537236558357:role/${local.name_prefix}-*"
        ]
      },

      # ====================================================
      # IAM INSTANCE PROFILE MANAGEMENT FOR EC2
      # ====================================================
      #
      # CloudFormation may need to create and manage an IAM
      # Instance Profile for EC2 resources.
      #
      # This statement grants permission to:
      #
      #     - Read the instance profile
      #     - Add a role to the profile
      #     - Remove a role from the profile
      #     - Delete the instance profile during cleanup
      #
      # The iam:CreateInstanceProfile action is also listed here,
      # but AWS requires this action to use Resource = "*".
      #
      # Therefore a separate statement with Resource = "*"
      # is required to authorize instance-profile creation.
      #
      # The resource pattern below is used for the other
      # instance-profile actions and follows the same lab naming
      # convention used by the CloudFormation-managed roles.
      #
      # ====================================================

      {
        Sid    = "ManageEC2InstanceProfiles"
        Effect = "Allow"

        Action = [
          "iam:CreateInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]

        Resource = [
          "arn:aws:iam::537236558357:instance-profile/${local.name_prefix}-*"
        ]
      },


      # ====================================================
      # IAM PASSROLE FOR CLOUDFORMATION-MANAGED ROLES
      # ====================================================
      #
      # CloudFormation may need to pass IAM roles to AWS
      # services when creating or updating resources.
      #
      # The permission is restricted to roles matching:
      #
      #     ${local.name_prefix}-*
      #
      # ====================================================

      {
        Sid = "PassCloudFormationManagedRoles"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = [
          "arn:aws:iam::537236558357:role/${local.name_prefix}-*"
        ]
      },

      # ====================================================
      # IAM PASSROLE FOR CLOUDFORMATION EXECUTION ROLE
      # ====================================================
      #
      # This allows the CloudFormation execution role to pass
      # the lab's CloudFormation execution role to AWS services
      # when required by the CloudFormation architecture.
      #
      # The permission is restricted to:
      #
      #     ${local.name_prefix}-CloudFormationExecutionRole
      #
      # ====================================================

      {
        Sid    = "PassCloudFormationExecutionRole"
        Effect = "Allow"

        Action = [
          "iam:PassRole"
        ]

        Resource = [
          "arn:aws:iam::537236558357:role/${local.name_prefix}-CloudFormationExecutionRole"
        ]
      }
    ]
  })
}


# ==========================================================
# ADDING A NEW IAM POLICY
# ==========================================================
#
# If you later add:
#
#     IAM/github-actions-cloudwatch-policy.json
#
#
# Add a new entry to the aws_iam_policy.github_actions map:
#
#
#     cloudwatch = {
#       name = "github-actions-cloudwatch-policy"
#       file = "${path.module}/../../IAM/github-actions-cloudwatch-policy.json"
#     }
#
#
# IMPORTANT:
#
# Because the role attachment resource uses explicitly
# defined static keys, a NEW policy also requires a matching
# entry in the role attachment for_each map.
#
#
# Example:
#
#     cloudwatch = aws_iam_policy.github_actions["cloudwatch"].arn
#
#
# Terraform can then:
#
#     1. Create/manage the policy
#
#     2. Store it in Terraform state
#
#     3. Attach it to the GitHub Actions role
#
#        after the matching attachment entry is also added
#        to aws_iam_role_policy_attachment.github_actions.
#
#
# ==========================================================
# EXISTING POLICY MIGRATION
# ==========================================================
#
# For policies that already exist in AWS:
#
#
# Step 1:
#
#     terraform import ...
#
#
# Step 2:
#
#     terraform plan
#
#
# Step 3:
#
# Review any differences between:
#
#     Git IAM JSON policy document
#
# and:
#
#     The IAM policy document currently represented
#     by the AWS policy.
#
#
# Step 4:
#
#     terraform apply
#
#
# After successful migration Terraform becomes the source
# of truth for those resources.
#
#
# ==========================================================
# IMPORTANT TERRAFORM STATE RULE
# ==========================================================
#
# Terraform does not have a generic:
#
#     "create this only if it doesn't already exist"
#
# switch for these IAM resources.
#
#
# The correct Terraform adoption model is:
#
#
# Resource does not exist in AWS
#          |
#          v
# Terraform creates it
#
#
# Resource already exists in AWS
#          |
#          v
# terraform import
#          |
#          v
# Terraform manages it
#
#
# State is therefore critical.
#
#
# ==========================================================
# END OF IAM CONFIGURATION
# ==========================================================