# ==========================================================
# Terraform Input Variables
# ==========================================================
# This file defines the input variables used throughout the
# Terraform project.
#
# Variables allow us to avoid hard-coding values directly
# inside Terraform resource configurations.
#
# The values can be provided through:
#   - Default values
#   - terraform.tfvars
#   - *.auto.tfvars
#   - Command-line -var arguments
#   - Environment variables
# ==========================================================


# ----------------------------------------------------------
# AWS Region
# ----------------------------------------------------------
# Defines the AWS region where Terraform will create the
# infrastructure.
#
# Example:
#   us-east-1
#   us-west-2
#   eu-west-1
#
# The provider.tf file uses this variable:
#
#   region = var.aws_region
#
# ----------------------------------------------------------

variable "aws_region" {
  description = "AWS region where the lab will be deployed"

  # The value must be a text/string value.
  type = string

  # Default AWS region for this lab.
  # This value is used when no other value is provided.
  default = "us-east-1"
}


# ----------------------------------------------------------
# Project Name
# ----------------------------------------------------------
# Identifies the project/application being deployed.
#
# This variable is also used by provider.tf for the
# Project default tag.
#
# Example:
#   Project = "HybridIaCLab"
# ----------------------------------------------------------

variable "project_name" {
  description = "Project name"

  # The project name must be a string.
  type = string

  # Default project name.
  default = "HybridIaCLab"
}


# ----------------------------------------------------------
# Environment
# ----------------------------------------------------------
# Identifies the environment in which the infrastructure
# is deployed.
#
# Common values include:
#   dev
#   test
#   staging
#   prod
#
# This value is also used by provider.tf for the
# Environment default tag.
# ----------------------------------------------------------

variable "environment" {
  description = "Deployment environment"

  # The environment name must be a string.
  type = string

  # Default environment.
  default = "dev"
}