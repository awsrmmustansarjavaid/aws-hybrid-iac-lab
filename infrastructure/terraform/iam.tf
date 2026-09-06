# ==========================================================

# IAM CONFIGURATION

# Project: aws-hybrid-iac-lab

# File: iam.tf

# ==========================================================

#

# PURPOSE

# ----------------------------------------------------------

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

# 4. CloudFormation Trust Policy

#

# 5. CloudFormation Execution Role

#

# 6. CloudFormation Permissions Policy

#

#

# ==========================================================

# ARCHITECTURE

# ==========================================================

#

#

# GitHub Actions authentication:

#

# GitHub Actions

# |

# | OIDC JWT

# v

# GitHub OIDC Provider

# |

# | sts:AssumeRoleWithWebIdentity

# v

# GitHub Actions IAM Role

# |

# | temporary AWS credentials

# v

# AWS Services

#

#

# CloudFormation authentication:

#

# Terraform

# |

# | creates / updates

# v

# CloudFormation Stack

# |

# | assumes

# v

# CloudFormation Execution Role

# |

# v

# AWS Resources

#

#

# ==========================================================

# IAM SECURITY MODEL

# ==========================================================

#

# An IAM role contains two important security concepts:

#

#

# TRUST POLICY

# ----------------------------------------------------------

#

# Defines WHO can assume the role.

#

#

# PERMISSIONS POLICY

# ----------------------------------------------------------

#

# Defines WHAT the role can do after it has been assumed.

#

#

# Example:

#

# GitHub OIDC Trust Policy

# |

# v

# Allows GitHub Actions to assume the role

#

# GitHub Actions Permissions

# |

# v

# Allows Terraform to manage AWS resources

#

#

# ==========================================================

# GITHUB ACTIONS IAM DESIGN

# ==========================================================

#

# The existing GitHub Actions role is:

#

# aws-hybrid-iac-lab-GitHubActions

#

#

# This role has already been imported into Terraform state.

#

#

# Existing managed policies attached to the role include:

#

# - aws-hybrid-iac-lab-GitHubActionsPolicy

#

# - github-actions-terraform-backend-policy

#

# - github-ci-cd-user-combined-access

#

#

# IMPORTANT

# ----------------------------------------------------------

#

# This file intentionally does NOT create another broad

# GitHub Actions inline policy containing permissions such as:

#

# ec2:*

# s3:*

# iam:*

# cloudformation:*

# lambda:*

# rds:*

# etc.

#

#

# Creating another broad inline policy would duplicate

# permissions already attached to the existing role.

#

#

# The existing managed policies should therefore remain

# attached to the GitHub Actions role.

#

#

# ==========================================================

# TERRAFORM SOURCE OF TRUTH

# ==========================================================

#

# Terraform is the source of truth for the resources defined

# in this file.

#

# Once Terraform manages these resources:

#

# - Do not manually change the trust policy in AWS Console.

# - Do not manually rename the IAM role.

# - Do not manually remove the OIDC provider.

# - Do not manually change Terraform-managed IAM settings.

#

# Manual changes can cause Terraform drift.

#

# ==========================================================

# ==========================================================

# 1. GITHUB ACTIONS OIDC PROVIDER

# ==========================================================

#

# GitHub Actions can issue an OpenID Connect token (OIDC JWT).

#

# AWS IAM needs an OIDC provider to establish trust with the

# GitHub Actions identity provider.

#

#

# GitHub OIDC issuer:

#

# https://token.actions.githubusercontent.com

#

#

# AWS STS audience:

#

# sts.amazonaws.com

#

#

# The OIDC provider is account-level and can be reused by

# multiple GitHub Actions IAM roles.

#

# ==========================================================

resource "aws_iam_openid_connect_provider" "github_actions" {

  # --------------------------------------------------------

  # GitHub Actions OIDC issuer URL.

  # --------------------------------------------------------

  url = "https://token.actions.githubusercontent.com"

  # --------------------------------------------------------

  # Audience accepted by AWS STS.

  #

  # GitHub requests this audience when the OIDC token is used

  # to obtain temporary AWS credentials.

  # --------------------------------------------------------

  client_id_list = [
    "sts.amazonaws.com"
  ]

  # --------------------------------------------------------

  # Resource tags.

  # --------------------------------------------------------

  tags = {
    Name        = "${local.name_prefix}-GitHubActions-OIDC"
    Project     = "aws-hybrid-iac-lab"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions OIDC Authentication"
    Environment = var.environment
  }
}

# ==========================================================

# 2. GITHUB ACTIONS OIDC TRUST POLICY

# ==========================================================

#

# This data source creates the IAM TRUST POLICY used by the

# GitHub Actions IAM role.

#

#

# The trust policy answers:

#

# "Who is allowed to assume this IAM role?"

#

#

# Trusted identity provider:

#

# GitHub Actions OIDC

#

#

# Trusted repository:

#

# awsrmmustansarjavaid/aws-hybrid-iac-lab

#

#

# Trusted branch:

#

# main

#

#

# Expected subject:

#

# repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main

#

#

# IMPORTANT

# ----------------------------------------------------------

#

# The "sub" claim must match the subject claim generated by

# GitHub for the workflow.

#

# This policy intentionally restricts access to the main

# branch of this repository.

#

# ==========================================================

data "aws_iam_policy_document" "github_actions_assume_role" {

  statement {


    # ------------------------------------------------------
    # Allow the GitHub OIDC identity to assume the role.
    # ------------------------------------------------------

    effect = "Allow"


    # ------------------------------------------------------
    # Identify GitHub as the trusted federated identity
    # provider.
    #
    # The ARN comes from the Terraform-managed OIDC provider.
    # ------------------------------------------------------

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }


    # ------------------------------------------------------
    # AWS STS action required for GitHub OIDC authentication.
    # ------------------------------------------------------

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]


    # ------------------------------------------------------
    # OIDC audience condition.
    #
    # The GitHub token must have:
    #
    #   aud = sts.amazonaws.com
    #
    # This prevents tokens issued for another audience from
    # being used to assume this role.
    # ------------------------------------------------------

    condition {
      test = "StringEquals"

      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }


    # ------------------------------------------------------
    # OIDC subject condition.
    #
    # This restricts role assumption to:
    #
    #   Repository:
    #   awsrmmustansarjavaid/aws-hybrid-iac-lab
    #
    #   Branch:
    #   main
    #
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

# This is the IAM role assumed by GitHub Actions.

#

#

# GitHub does NOT receive permanent AWS access keys.

#

# Instead:

#

# GitHub Actions

# |

# | OIDC token

# v

# AWS STS

# |

# | AssumeRoleWithWebIdentity

# v

# IAM Role

# |

# | temporary credentials

# v

# AWS Services

#

#

# IMPORTANT

# ----------------------------------------------------------

#

# This role already exists in AWS and has been imported into

# Terraform state.

#

#

# Existing role name:

#

# aws-hybrid-iac-lab-GitHubActions

#

#

# The exact existing name is intentionally preserved.

#

# Do NOT change this name unless you intentionally want to

# create a different IAM role.

#

# ==========================================================

resource "aws_iam_role" "github_actions" {

  # --------------------------------------------------------

  # Existing IAM role name.

  # --------------------------------------------------------

  name = "aws-hybrid-iac-lab-GitHubActions"

  # --------------------------------------------------------

  # Existing role description.

  #

  # Keeping this value prevents Terraform from trying to

  # remove the existing description.

  # --------------------------------------------------------

  description = "aws-hybrid-iac-lab-GitHubActions"

  # --------------------------------------------------------

  # GitHub OIDC trust policy.

  #

  # Terraform manages this trust relationship.

  # --------------------------------------------------------

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  # --------------------------------------------------------

  # Maximum session duration.

  #

  # One hour is sufficient for the current CI/CD workflow.

  # --------------------------------------------------------

  max_session_duration = 3600

  # --------------------------------------------------------

  # Resource tags.

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

# 4. GITHUB ACTIONS PERMISSIONS

# ==========================================================

#

# No additional GitHub Actions permissions policy is created

# in this file.

#

#

# The existing GitHub Actions IAM role already has managed

# policies attached to it.

#

#

# Existing managed policies:

#

# 1. aws-hybrid-iac-lab-GitHubActionsPolicy

#

# 2. github-actions-terraform-backend-policy

#

# 3. github-ci-cd-user-combined-access

#

#

# These policies provide the permissions available to the

# GitHub Actions role after successful OIDC authentication.

#

#

# IMPORTANT

# ----------------------------------------------------------

#

# Authentication and authorization are different:

#

#

# Authentication:

#

# GitHub OIDC

# |

# v

# Can GitHub assume the role?

#

#

# Authorization:

#

# IAM permissions

# |

# v

# What can the assumed role do?

#

#

# Therefore, if GitHub receives:

#

# sts:AssumeRoleWithWebIdentity

# AccessDenied

#

# the first thing to investigate is the OIDC provider,

# trust policy, subject, audience, workflow permissions,

# and role ARN.

#

# It is NOT normally fixed by adding more AWS service

# permissions to the role.

#

# ==========================================================

# ==========================================================

# 5. CLOUDFORMATION TRUST POLICY

# ==========================================================

#

# This trust policy is completely separate from the GitHub

# Actions trust policy.

#

#

# It answers:

#

# "Can AWS CloudFormation assume this role?"

#

#

# CloudFormation uses:

#

# sts:AssumeRole

#

#

# This is a standard AWS service-to-IAM-role trust

# relationship.

#

# ==========================================================

data "aws_iam_policy_document" "cloudformation_assume_role" {

  statement {


    # ------------------------------------------------------
    # Allow AWS CloudFormation to assume the role.
    # ------------------------------------------------------

    effect = "Allow"


    # ------------------------------------------------------
    # AWS service trusted to assume the role.
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

# 6. CLOUDFORMATION EXECUTION ROLE

# ==========================================================

#

# CloudFormation uses this IAM role to create and manage

# resources defined by the main and nested CloudFormation

# templates.

#

#

# Architecture:

#

# Terraform

# |

# | creates / updates

# v

# CloudFormation Stack

# |

# | assumes

# v

# CloudFormation Execution Role

# |

# v

# AWS Resources

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

# 7. CLOUDFORMATION PERMISSIONS POLICY

# ==========================================================

#

# This inline policy defines what CloudFormation can do after

# assuming the CloudFormation execution role.

#

#

# IMPORTANT

# ----------------------------------------------------------

#

# The policy is intentionally broad for the initial learning

# and laboratory environment.

#

# It should eventually be reduced according to the actual

# resources deployed by the nested CloudFormation templates.

#

#

# IMPORTANT SECURITY NOTE

# ----------------------------------------------------------

#

# iam:PassRole is required when CloudFormation needs to pass

# another IAM role to an AWS service.

#

# In a production environment, PassRole should preferably be

# restricted to specific role ARNs rather than Resource = "*".

#

# ==========================================================

resource "aws_iam_role_policy" "cloudformation_lab_permissions" {

  # --------------------------------------------------------

  # Inline policy name.

  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationPermissions"

  # --------------------------------------------------------

  # Attach the policy to the CloudFormation execution role.

  # --------------------------------------------------------

  role = aws_iam_role.cloudformation_execution.id

  # --------------------------------------------------------

  # Policy document.

  # --------------------------------------------------------

  policy = jsonencode({


    Version = "2012-10-17"

    Statement = [

      # ====================================================
      # EC2 / ELB / Auto Scaling / IAM PassRole
      # ====================================================
      #
      # Used for networking, compute, load balancing, and
      # Auto Scaling resources.
      #
      # iam:PassRole allows CloudFormation to pass IAM roles
      # to AWS services when required.
      #
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
      #
      # Used for application buckets, template buckets,
      # CloudFront distributions, and related resources.
      #
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
      #
      # Used for serverless functions and API Gateway
      # resources.
      #
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
      #
      # Used for relational database and NoSQL resources.
      #
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
      #
      # Used for container registry, ECS, and EKS resources.
      #
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
      #
      # Used for creating and managing CloudWatch log groups
      # and log streams associated with deployed workloads.
      #
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
