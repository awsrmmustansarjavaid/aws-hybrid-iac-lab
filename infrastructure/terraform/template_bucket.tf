# ==========================================================
# CloudFormation Template S3 Bucket
# ==========================================================
#
# Terraform creates and manages this S3 bucket.
#
# Purpose:
#   - Store CloudFormation templates
#   - Provide a central location for nested templates
#   - Allow CloudFormation stacks to retrieve templates
#   - Enable versioning for template history
#   - Prevent public access
#   - Encrypt templates at rest
#
# IMPORTANT:
#
# S3 bucket names have stricter naming rules than normal AWS
# resource names.
#
# S3 bucket names must:
#   - Be lowercase
#   - Use only letters, numbers, periods, and hyphens
#   - Be globally unique
#   - Start and end with a letter or number
#
# Our global local.name_prefix may contain uppercase letters:
#
#   HybridIaCLab-dev
#
# Therefore we convert the prefix to lowercase specifically
# for the S3 bucket.
#
# ==========================================================


# ----------------------------------------------------------
# S3 Bucket
# ----------------------------------------------------------
#
# Creates the S3 bucket that stores the CloudFormation
# templates.
#
# We use bucket_prefix instead of bucket so Terraform can
# generate a globally unique suffix automatically.
#
# IMPORTANT:
#
# Do NOT use:
#
#   bucket_prefix = "${local.name_prefix}-cfn-templates-"
#
# because local.name_prefix may contain uppercase characters.
#
# Instead we use:
#
#   lower(local.name_prefix)
#
# which converts:
#
#   HybridIaCLab-dev
#
# into:
#
#   hybridiaclab-dev
#
# The resulting prefix becomes:
#
#   hybridiaclab-dev-cfn-templates-
#
# Terraform then adds a unique suffix.
#
# Example generated bucket name:
#
#   hybridiaclab-dev-cfn-templates-759b325cae3783edb2b018c38d
#
# ==========================================================

resource "aws_s3_bucket" "cloudformation_templates" {

  # --------------------------------------------------------
  # Globally Unique S3 Bucket Name
  # --------------------------------------------------------
  #
  # lower() is important because S3 bucket names must be
  # lowercase.
  #
  # local.name_prefix:
  #
  #   HybridIaCLab-dev
  #
  # becomes:
  #
  #   hybridiaclab-dev
  #
  # Terraform automatically appends a unique suffix because
  # bucket_prefix is being used.
  # --------------------------------------------------------

  bucket_prefix = "${lower(local.name_prefix)}-cfn-templates-"


  # --------------------------------------------------------
  # Force Destroy
  # --------------------------------------------------------
  #
  # Allows Terraform to delete the bucket even when it
  # contains objects.
  #
  # This is convenient for a learning/lab environment.
  #
  # WARNING:
  #
  # Do NOT normally use force_destroy = true for production
  # buckets containing important data.
  # --------------------------------------------------------

  force_destroy = true
}


# ==========================================================
# S3 Bucket Versioning
# ==========================================================
#
# Enables versioning on the CloudFormation template bucket.
#
# Why?
#
# If a template is replaced or uploaded again, S3 can keep
# previous versions.
#
# This is useful when:
#
#   - A template is accidentally overwritten
#   - You need to inspect an older template
#   - You want basic template history
#
# ==========================================================

resource "aws_s3_bucket_versioning" "cloudformation_templates" {

  # --------------------------------------------------------
  # Connect Versioning to the CloudFormation Template Bucket
  # --------------------------------------------------------

  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # Versioning Configuration
  # --------------------------------------------------------

  versioning_configuration {

    # Enable S3 object versioning.
    status = "Enabled"
  }
}


# ==========================================================
# S3 Public Access Block
# ==========================================================
#
# CloudFormation templates should not be publicly accessible.
#
# This resource enables all four S3 public-access protections.
#
# The four protections are:
#
#   1. block_public_acls
#   2. block_public_policy
#   3. ignore_public_acls
#   4. restrict_public_buckets
#
# ==========================================================

resource "aws_s3_bucket_public_access_block" "cloudformation_templates" {

  # --------------------------------------------------------
  # Apply Public Access Protection to the Template Bucket
  # --------------------------------------------------------

  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # Block Public ACLs
  # --------------------------------------------------------
  #
  # Prevents public access through newly created ACLs.
  # --------------------------------------------------------

  block_public_acls = true


  # --------------------------------------------------------
  # Block Public Bucket Policies
  # --------------------------------------------------------
  #
  # Prevents bucket policies that would make the bucket
  # publicly accessible.
  # --------------------------------------------------------

  block_public_policy = true


  # --------------------------------------------------------
  # Ignore Public ACLs
  # --------------------------------------------------------
  #
  # Causes any public ACLs to be ignored.
  # --------------------------------------------------------

  ignore_public_acls = true


  # --------------------------------------------------------
  # Restrict Public Buckets
  # --------------------------------------------------------
  #
  # Restricts access when a bucket could otherwise become
  # publicly accessible.
  # --------------------------------------------------------

  restrict_public_buckets = true
}


# ==========================================================
# S3 Server-Side Encryption
# ==========================================================
#
# Encrypts CloudFormation template objects when they are
# stored in S3.
#
# AES256 uses Amazon S3 managed server-side encryption
# (SSE-S3).
#
# This means:
#
#   - Templates are encrypted at rest
#   - AWS manages the encryption keys
#   - We do not need to create a separate KMS key
#
# ==========================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudformation_templates" {

  # --------------------------------------------------------
  # Apply Encryption Configuration to the Template Bucket
  # --------------------------------------------------------

  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # Encryption Rule
  # --------------------------------------------------------

  rule {

    # ------------------------------------------------------
    # Default Server-Side Encryption
    # ------------------------------------------------------

    apply_server_side_encryption_by_default {

      # ----------------------------------------------------
      # Use S3-managed AES256 encryption (SSE-S3).
      # ----------------------------------------------------

      sse_algorithm = "AES256"
    }
  }
}

