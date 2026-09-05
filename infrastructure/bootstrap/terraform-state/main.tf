# ============================================================
# Terraform Configuration
# ============================================================
# This block defines Terraform itself and the providers
# required by this configuration.
terraform {
  # Minimum Terraform version required to run this code.
  required_version = ">= 1.5.0"

  # Define the AWS provider that Terraform will use.
  required_providers {
    aws = {
      # Official AWS provider maintained by HashiCorp.
      source = "hashicorp/aws"

      # Use AWS provider version 6.x.
      # "~> 6.0" allows newer 6.x releases but not 7.x.
      version = "~> 6.0"
    }
  }
}


# ============================================================
# AWS Provider Configuration
# ============================================================
# This tells Terraform which AWS Region to use when creating
# AWS resources.
provider "aws" {
  # The value comes from the Terraform variable:
  # var.aws_region
  #
  # Example:
  # aws_region = "us-east-1"
  region = var.aws_region
}


# ============================================================
# Terraform Remote State S3 Bucket
# ============================================================
# This S3 bucket will store Terraform's remote state.
#
# Terraform state contains information about resources that
# Terraform manages. Keeping the state in S3 allows the state
# to be stored remotely instead of only on your local PC.
#
# IMPORTANT:
# This bucket is a BOOTSTRAP resource.
# It is normally created before configuring Terraform's
# S3 backend to use this bucket.
resource "aws_s3_bucket" "terraform_state" {

  # Name of the S3 bucket.
  #
  # The value comes from:
  # var.state_bucket_name
  #
  # S3 bucket names must be globally unique.
  bucket = var.state_bucket_name

  # Prevent Terraform from automatically deleting objects
  # inside this bucket when destroying the bucket.
  #
  # false = safer for a Terraform state bucket.
  force_destroy = false

  # Tags help identify and organize the AWS resource.
  tags = {
    # Human-readable name of the bucket.
    Name = var.state_bucket_name

    # Project name associated with this bucket.
    Project = var.project_name

    # Environment such as dev, test, staging, or prod.
    Environment = var.environment

    # Shows that Terraform is responsible for managing
    # this bootstrap resource.
    ManagedBy = "Terraform-Bootstrap"

    # Explains why this bucket exists.
    Purpose = "Terraform Remote State"
  }
}


# ============================================================
# S3 Bucket Versioning
# ============================================================
# Enable versioning on the Terraform state bucket.
#
# Versioning keeps previous versions of objects stored in S3.
# This is especially useful for Terraform state because it
# provides a way to recover an earlier version of the state
# if the current state is accidentally changed or deleted.
resource "aws_s3_bucket_versioning" "terraform_state" {

  # Attach versioning to our Terraform state bucket.
  #
  # aws_s3_bucket.terraform_state.id means:
  # "Use the ID/name of the S3 bucket created above."
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {

    # Enable S3 object versioning.
    status = "Enabled"
  }
}


# ============================================================
# S3 Server-Side Encryption
# ============================================================
# Encrypt objects stored inside the Terraform state bucket.
#
# Terraform state can contain sensitive infrastructure
# information, so encryption at rest is an important security
# control.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

  # Apply this encryption configuration to our state bucket.
  bucket = aws_s3_bucket.terraform_state.id

  rule {

    apply_server_side_encryption_by_default {

      # Use Amazon S3 managed encryption keys (SSE-S3).
      #
      # AES256 means AWS manages the encryption keys for you.
      sse_algorithm = "AES256"
    }
  }
}


# ============================================================
# S3 Public Access Block
# ============================================================
# Terraform state should NEVER be publicly accessible.
#
# This resource enables all four S3 public-access blocking
# settings for the state bucket.
resource "aws_s3_bucket_public_access_block" "terraform_state" {

  # Apply the public access restrictions to our
  # Terraform state bucket.
  bucket = aws_s3_bucket.terraform_state.id

  # Prevent public ACLs from granting public access.
  block_public_acls = true

  # Prevent bucket policies from making the bucket public.
  block_public_policy = true

  # Ignore any public ACLs that might exist on objects.
  ignore_public_acls = true

  # Prevent public bucket policies from making the bucket
  # publicly accessible.
  restrict_public_buckets = true
}