# ==========================================================
# CloudFormation Template S3 Bucket
# ==========================================================
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
# This bucket is intentionally created by Terraform.
# CloudFormation will use the objects stored in this bucket
# when deploying the CloudFormation portion of the hybrid
# infrastructure.
# ==========================================================


# ----------------------------------------------------------
# S3 Bucket
# ----------------------------------------------------------
# Creates the S3 bucket that will contain the CloudFormation
# templates.
#
# bucket_prefix:
#   Creates a unique bucket name beginning with the supplied
#   prefix. S3 bucket names must be globally unique.
#
# Example prefix:
#
#   HybridIaCLab-dev-cfn-templates-
#
# Terraform will generate the remaining characters.
# ----------------------------------------------------------

resource "aws_s3_bucket" "cloudformation_templates" {

  bucket_prefix = "${local.name_prefix}-cfn-templates-"

  # --------------------------------------------------------
  # Force Destroy
  # --------------------------------------------------------
  # Allows Terraform to delete the bucket even when it
  # contains objects.
  #
  # This is convenient for a learning/lab environment.
  #
  # WARNING:
  # Do NOT normally use force_destroy = true for production
  # buckets containing important data.
  # --------------------------------------------------------

  force_destroy = true
}


# ==========================================================
# S3 Bucket Versioning
# ==========================================================
# Enables versioning on the CloudFormation template bucket.
#
# Why?
#
# If a template is replaced or uploaded again, S3 can keep
# previous versions.
#
# This is useful when:
#   - A CloudFormation template is accidentally overwritten
#   - You need to inspect an older template
#   - You want basic template history
# ==========================================================

resource "aws_s3_bucket_versioning" "cloudformation_templates" {

  # Connect this configuration to the bucket created above.
  bucket = aws_s3_bucket.cloudformation_templates.id

  versioning_configuration {

    # Enable S3 object versioning.
    status = "Enabled"
  }
}


# ==========================================================
# S3 Public Access Block
# ==========================================================
# CloudFormation templates should not be publicly accessible.
#
# This resource enables all four S3 public-access protections.
# ==========================================================

resource "aws_s3_bucket_public_access_block" "cloudformation_templates" {

  # Apply the public-access settings to our template bucket.
  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # Block Public ACLs
  # --------------------------------------------------------
  # Prevents new public access control lists (ACLs).
  # --------------------------------------------------------

  block_public_acls = true


  # --------------------------------------------------------
  # Block Public Bucket Policies
  # --------------------------------------------------------
  # Prevents bucket policies that would make the bucket
  # publicly accessible.
  # --------------------------------------------------------

  block_public_policy = true


  # --------------------------------------------------------
  # Ignore Public ACLs
  # --------------------------------------------------------
  # Causes public ACLs to be ignored.
  # --------------------------------------------------------

  ignore_public_acls = true


  # --------------------------------------------------------
  # Restrict Public Buckets
  # --------------------------------------------------------
  # Restricts access to buckets that could otherwise become
  # publicly accessible.
  # --------------------------------------------------------

  restrict_public_buckets = true
}


# ==========================================================
# S3 Server-Side Encryption
# ==========================================================
# Encrypts CloudFormation template objects when they are
# stored in S3.
#
# AES256 uses Amazon S3 managed server-side encryption (SSE-S3).
#
# This means the templates are encrypted at rest without
# requiring us to create and manage a separate KMS key.
# ==========================================================

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudformation_templates" {

  # Apply encryption configuration to our template bucket.
  bucket = aws_s3_bucket.cloudformation_templates.id


  rule {

    apply_server_side_encryption_by_default {

      # Use S3-managed AES256 encryption.
      sse_algorithm = "AES256"
    }
  }
}