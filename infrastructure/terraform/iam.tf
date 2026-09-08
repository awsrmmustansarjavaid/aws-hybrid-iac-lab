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
# In the current project this role has already been imported
# into Terraform state.
#
# Therefore do NOT import it again unless the state is removed.
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
    Project   = "aws-hybrid-iac-lab"
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
# Existing customer-managed policy:
#
#     github-ci-cd-user-combined-access
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
# Terraform manages the existing policy attachment.
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
      # IAM ROLE MANAGEMENT FOR CLOUDFORMATION
      # ====================================================
      #
      # CloudFormation creates and manages IAM roles used
      # by the nested CloudFormation stacks.
      #
      # The Lambda nested stack creates an AWS::IAM::Role.
      #
      # Because RoleName is not explicitly specified in the
      # CloudFormation template, CloudFormation generates the
      # physical IAM role name.
      #
      # Example:
      #
      # hybridiaclab-dev-MainStack-Lamb-LambdaExecutionRole-XXXXXXX
      #
      #  Therefore IAM permissions use:
      #
      #
      # 
      #       ${local.name_prefix}-*
      #
      # 
      # to cover generated Lambda execution-role names.  
      #
      # CloudFormation therefore needs permission to:
      #
      #     - Create the role
      #     - Read the role
      #     - Read inline policies
      #     - Create/update inline policies
      #     - Delete inline policies
      #     - Attach managed policies
      #     - Detach managed policies
      #     - Delete the role during rollback/cleanup
      #
      # These permissions are intentionally restricted to
      # the Lambda execution role.
      #
      # ====================================================

      {
        Sid    = "ManageLambdaExecutionRole"
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
      # IAM PASSROLE FOR LAMBDA
      # ====================================================
      #
      # CloudFormation must be able to pass the Lambda
      # execution role to the Lambda service.
      #
      # ====================================================

      {
        Sid    = "PassLambdaExecutionRole"
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
      # CloudFormation is running under:
      #
      #     ${local.name_prefix}-CloudFormationExecutionRole
      #
      # The root/nested CloudFormation architecture passes
      # this execution role to nested CloudFormation stacks.
      #
      # Therefore the CloudFormation execution role itself
      # must have permission to pass this role.
      #
      # Without this permission CloudFormation fails with:
      #
      #     iam:PassRole
      #
      # on:
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
#     Git IAM JSON
#
# and:
#
#     AWS IAM policy
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