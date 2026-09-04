# ==========================================================
# AWS Provider Configuration
# ==========================================================
# This file configures Terraform's AWS provider.
#
# The AWS provider is responsible for allowing Terraform to
# communicate with AWS and create/manage AWS resources.
# ==========================================================


# ----------------------------------------------------------
# AWS Provider
# ----------------------------------------------------------
# The region is taken from the aws_region variable defined
# in variables.tf.
#
# Example:
#   aws_region = "us-east-1"
#
# This makes the configuration reusable because we don't
# hard-code an AWS region here.
# ----------------------------------------------------------

provider "aws" {
  region = var.aws_region


  # --------------------------------------------------------
  # Default Tags
  # --------------------------------------------------------
  # These tags are automatically applied to supported AWS
  # resources created through this AWS provider.
  #
  # This is useful for:
  #   - Resource identification
  #   - Cost tracking
  #   - Environment management
  #   - Project organization
  #   - Terraform resource management
  #
  # Instead of adding these tags repeatedly to every
  # resource, we define them once here.
  # --------------------------------------------------------

  default_tags {

    tags = {

      # ----------------------------------------------------
      # Project
      # ----------------------------------------------------
      # Identifies which project the resource belongs to.
      # The value comes from variables.tf.
      # ----------------------------------------------------
      Project = var.project_name


      # ----------------------------------------------------
      # Environment
      # ----------------------------------------------------
      # Identifies the deployment environment.
      #
      # Examples:
      #   dev
      #   test
      #   staging
      #   production
      # ----------------------------------------------------
      Environment = var.environment


      # ----------------------------------------------------
      # ManagedBy
      # ----------------------------------------------------
      # Indicates that Terraform manages this resource.
      # ----------------------------------------------------
      ManagedBy = "Terraform"


      # ----------------------------------------------------
      # Lab
      # ----------------------------------------------------
      # Identifies the specific training/project lab.
      # ----------------------------------------------------
      Lab = "Terraform-CloudFormation-Hybrid"
    }
  }
}