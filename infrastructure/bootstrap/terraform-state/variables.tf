# ============================================================
# AWS Region
# ============================================================
# Defines the AWS Region where the Terraform state bucket
# will be created.
#
# You can change this value if you want to use another
# AWS Region.
variable "aws_region" {

  # Explains the purpose of this variable.
  description = "AWS region where the Terraform state bucket is created."

  # This variable must contain text/string data.
  type = string

  # Default AWS Region.
  # If you do not provide another value, Terraform will use
  # us-east-1.
  default = "us-east-1"
}


# ============================================================
# Terraform State Bucket Name
# ============================================================
# Defines the name of the S3 bucket that will store
# Terraform's remote state.
#
# IMPORTANT:
# S3 bucket names must be globally unique across AWS.
variable "state_bucket_name" {

  # Explains what this variable is used for.
  description = "Globally unique S3 bucket name used for Terraform remote state."

  # The bucket name must be a string.
  type = string

  # Default S3 bucket name.
  #
  # You can change this if the name is already taken.
  default = "aws-hybrid-iac-lab-terraform-state-537236558357"
}


# ============================================================
# Project Name
# ============================================================
# Defines the name of your project.
#
# This value is mainly used for resource tagging so that
# you can identify which project a resource belongs to.
variable "project_name" {

  # Explains the purpose of this variable.
  description = "Project name."

  # The project name must be a string.
  type = string

  # Default project name.
  default = "HybridIaCLab"
}


# ============================================================
# Environment
# ============================================================
# Defines which environment this Terraform configuration
# belongs to.
#
# Common examples:
# dev
# test
# staging
# prod
variable "environment" {

  # Explains the purpose of this variable.
  description = "Environment name."

  # The environment name must be a string.
  type = string

  # Default environment.
  default = "dev"
}