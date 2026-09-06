# ============================================================
# Terraform State Backend Bootstrap
# Project: aws-hybrid-iac-lab
#
# Purpose:
#   Creates the dedicated S3 bucket used by Terraform for
#   remote state storage.
#
# IMPORTANT:
#   This configuration is separate from the main Terraform
#   configuration because the main Terraform backend bucket
#   must exist BEFORE terraform init.
#
# The GitHub Actions workflow normally handles this bootstrap
# automatically.
# ============================================================

terraform {

  required_version = ">= 1.6.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


# ------------------------------------------------------------
# AWS Provider
# ------------------------------------------------------------
provider "aws" {

  region = var.aws_region
}


# ============================================================
# Terraform State Bucket
# ============================================================

resource "aws_s3_bucket" "terraform_state" {

  bucket = var.state_bucket_name


  # ----------------------------------------------------------
  # Safety:
  #
  # Never automatically destroy the Terraform state bucket.
  # ----------------------------------------------------------
  lifecycle {
    prevent_destroy = true
  }


  tags = {

    Name        = "aws-hybrid-iac-lab-terraform-state"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Terraform-State"
  }
}


# ============================================================
# Bucket Versioning
# ============================================================

resource "aws_s3_bucket_versioning" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {

    status = "Enabled"
  }
}


# ============================================================
# Block Public Access
# ============================================================

resource "aws_s3_bucket_public_access_block" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ============================================================
# Server-Side Encryption
# ============================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {

    apply_server_side_encryption_by_default {

      sse_algorithm = "AES256"
    }
  }
}

