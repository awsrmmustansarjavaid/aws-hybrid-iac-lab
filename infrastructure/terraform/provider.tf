# ==========================================================
# AWS Provider Configuration
# ==========================================================
#
# This file configures the AWS provider used by Terraform.
#
# The AWS provider allows Terraform to communicate with AWS
# and create, update, and manage AWS infrastructure.
#
# This configuration uses:
#
#   1. Primary AWS provider
#      - Uses the region from var.aws_region
#      - Applies common default tags automatically
#      - Used by normal AWS resources
#
#   2. AWS provider alias: no_default_tags
#      - Uses the same AWS region
#      - Does NOT use default_tags
#      - Used for resources that should not receive the
#        provider-level default tags
#
# The second provider is required for the GitHub Actions
# OIDC provider because the current IAM user does not have
# permission to perform:
#
#     iam:TagOpenIDConnectProvider
#
# The GitHub OIDC provider does not require tags for
# GitHub Actions authentication to work.
# ==========================================================


# ----------------------------------------------------------
# Primary AWS Provider
# ----------------------------------------------------------
#
# This is the default AWS provider used by Terraform.
#
# The region is taken from:
#
#     var.aws_region
#
# Example:
#
#     aws_region = "us-east-1"
#
# Keeping the region in variables.tf makes this Terraform
# configuration reusable across different AWS regions.
# ----------------------------------------------------------

provider "aws" {

  # --------------------------------------------------------
  # AWS Region
  # --------------------------------------------------------
  #
  # The AWS region is controlled through variables.tf.
  #
  # Example:
  #
  #     us-east-1
  #
  # Do NOT write:
  #
  #     region = "var.aws_region"
  #
  # The correct Terraform syntax is:
  #
  #     region = var.aws_region
  # --------------------------------------------------------

  region = var.aws_region


  # --------------------------------------------------------
  # Default Tags
  # --------------------------------------------------------
  #
  # These tags are automatically applied to supported AWS
  # resources managed through this provider.
  #
  # This prevents us from having to repeat the same tags
  # inside every Terraform resource.
  #
  # Default tags are useful for:
  #
  #   - Resource identification
  #   - Cost tracking
  #   - Environment management
  #   - Project organization
  #   - Resource ownership
  #   - Terraform resource management
  #
  # IMPORTANT:
  #
  # These default tags are intentionally kept on the
  # primary provider because they are useful for the rest
  # of the AWS infrastructure.
  #
  # The GitHub OIDC provider will NOT use this provider.
  # It will use the "no_default_tags" provider below.
  # --------------------------------------------------------

  default_tags {

    tags = {

      # ----------------------------------------------------
      # Project
      # ----------------------------------------------------
      #
      # Identifies the AWS project/lab.
      #
      # The value comes from:
      #
      #     var.project_name
      #
      # Example:
      #
      #     HybridIaCLab
      # ----------------------------------------------------

      Project = var.project_name


      # ----------------------------------------------------
      # Environment
      # ----------------------------------------------------
      #
      # Identifies the deployment environment.
      #
      # Examples:
      #
      #     dev
      #     test
      #     staging
      #     production
      #
      # The value comes from:
      #
      #     var.environment
      # ----------------------------------------------------

      Environment = var.environment


      # ----------------------------------------------------
      # ManagedBy
      # ----------------------------------------------------
      #
      # Identifies Terraform as the infrastructure manager.
      # ----------------------------------------------------

      ManagedBy = "Terraform"


      # ----------------------------------------------------
      # Lab
      # ----------------------------------------------------
      #
      # Identifies the Terraform/CloudFormation hybrid lab.
      # ----------------------------------------------------

      Lab = "Terraform-CloudFormation-Hybrid"
    }
  }
}


# ==========================================================
# AWS Provider Without Default Tags
# ==========================================================
#
# This is a second AWS provider configuration.
#
# It uses the same AWS region as the primary provider but
# intentionally does NOT define default_tags.
#
# This provider is used for AWS resources where applying
# the provider-level default tags would cause an unwanted
# IAM tagging API operation.
#
# Current use:
#
#     aws_iam_openid_connect_provider.github_actions
#
# Why?
#
# The primary provider automatically adds:
#
#     Project
#     Environment
#     ManagedBy
#     Lab
#
# to supported resources.
#
# For the GitHub Actions OIDC provider, Terraform can then
# attempt to call:
#
#     iam:TagOpenIDConnectProvider
#
# The current GitHub CI/CD IAM user does not have that
# permission.
#
# The OIDC provider does NOT need these tags for
# authentication.
#
# Therefore, the OIDC provider will use this provider alias
# instead.
# ==========================================================

provider "aws" {

  # --------------------------------------------------------
  # Provider Alias
  # --------------------------------------------------------
  #
  # This creates the provider reference:
  #
  #     aws.no_default_tags
  #
  # Resources can explicitly select this provider using:
  #
  #     provider = aws.no_default_tags
  # --------------------------------------------------------

  alias = "no_default_tags"


  # --------------------------------------------------------
  # AWS Region
  # --------------------------------------------------------
  #
  # Use the same region as the primary AWS provider.
  #
  # The OIDC provider itself is an IAM/global resource, but
  # the AWS provider still requires a region configuration.
  # --------------------------------------------------------

  region = var.aws_region


  # --------------------------------------------------------
  # IMPORTANT: No default_tags block here
  # --------------------------------------------------------
  #
  # Do NOT add:
  #
  #     default_tags {
  #       tags = {
  #         ...
  #       }
  #     }
  #
  # to this provider.
  #
  # The entire purpose of this provider is to prevent
  # Terraform from automatically applying the common
  # project tags to the GitHub Actions OIDC provider.
  # --------------------------------------------------------
}

