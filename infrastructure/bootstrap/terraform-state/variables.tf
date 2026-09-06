# ============================================================
# Bootstrap Variables
# Project: aws-hybrid-iac-lab
# ============================================================


# ------------------------------------------------------------
# AWS Region
# ------------------------------------------------------------
variable "aws_region" {

  description = "AWS region where the Terraform state bucket is created."

  type = string

  default = "us-east-1"
}


# ------------------------------------------------------------
# Terraform State Bucket Name
# ------------------------------------------------------------
variable "state_bucket_name" {

  description = "Globally unique S3 bucket name used for Terraform remote state."

  type = string

  default = "aws-hybrid-iac-lab-terraform-state-537236558357"
}


# ------------------------------------------------------------
# Project Name
# ------------------------------------------------------------
variable "project_name" {

  description = "Project name used for resource tagging."

  type = string

  default = "aws-hybrid-iac-lab"
}


# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
variable "environment" {

  description = "Environment name used for resource tagging."

  type = string

  default = "dev"
}

