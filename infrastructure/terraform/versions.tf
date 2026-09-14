# ==========================================================
# Terraform Configuration
# ==========================================================
# This block defines the minimum Terraform version and the
# providers required by this project.
# ==========================================================

terraform {

  # --------------------------------------------------------
  # Minimum Terraform Version
  # --------------------------------------------------------
  # Terraform 1.15.7 is required to run this project.
  # The exact version is enforced to ensure consistent
  # Terraform behavior across environments.
  # --------------------------------------------------------
  required_version = "= 1.15.7"


  # --------------------------------------------------------
  # Required Providers
  # --------------------------------------------------------
  # Providers are plugins that allow Terraform to communicate
  # with external platforms such as AWS.
  # --------------------------------------------------------
  required_providers {

    # ------------------------------------------------------
    # AWS Provider
    # ------------------------------------------------------
    # source:
    #   Official HashiCorp AWS provider.
    #
    # version:
    #   Allows AWS provider versions in the 6.x range.
    #   "~> 6.0" means:
    #       >= 6.0.0
    #       < 7.0.0
    #
    # This prevents Terraform from automatically upgrading
    # to an incompatible future major version.
    # ------------------------------------------------------
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

