# ============================================================
# Terraform Remote Backend
# Project: aws-hybrid-iac-lab
#
# Purpose:
#   Store Terraform state remotely in Amazon S3.
#
# IMPORTANT:
#   The S3 bucket must exist before "terraform init".
#
#   GitHub Actions automatically creates/verifies the bucket
#   before running terraform init.
#
# State bucket:
#   aws-hybrid-iac-lab-terraform-state-537236558357
#
# State file:
#   aws-hybrid-iac-lab/dev/terraform.tfstate
#
# State locking:
#   S3 lockfile (.tflock)
#
# ============================================================

terraform {

  backend "s3" {

    # --------------------------------------------------------
    # Dedicated Terraform state bucket.
    #
    # This bucket is DIFFERENT from the CloudFormation
    # template bucket.
    # --------------------------------------------------------
    bucket = "aws-hybrid-iac-lab-terraform-state-537236558357"


    # --------------------------------------------------------
    # Location of the Terraform state file.
    # --------------------------------------------------------
    key = "aws-hybrid-iac-lab/terraform.tfstate"


    # --------------------------------------------------------
    # AWS region containing the state bucket.
    # --------------------------------------------------------
    region = "us-east-1"


    # --------------------------------------------------------
    # Encrypt Terraform state objects.
    #
    # The bucket also has default SSE-S3 encryption configured
    # by the GitHub Actions bootstrap step.
    # --------------------------------------------------------
    encrypt = true


    # --------------------------------------------------------
    # Enable native S3 state locking.
    #
    # Terraform creates:
    #
    #   aws-hybrid-iac-lab/dev/terraform.tfstate.tflock
    #
    # DynamoDB locking is NOT required.
    # --------------------------------------------------------
    use_lockfile = true
  }
}

