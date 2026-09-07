# ============================================================
# AWS HYBRID IaC LAB
# TERRAFORM DATA SOURCES
# ============================================================
#
# File:
#   infrastructure/terraform/data.tf
#
# Purpose:
#   Dynamically retrieve AWS information instead of manually
#   hard-coding AWS resource IDs.
#
# Current use:
#   Automatically find the latest available
#   Amazon Linux 2023 AMI for the configured AWS region.
#
# IMPORTANT:
#   The AMI ID is NOT hard-coded.
#   Terraform asks AWS for the appropriate AMI.
# ============================================================


# ------------------------------------------------------------
# Amazon Linux 2023 AMI
# ------------------------------------------------------------
#
# Terraform searches AWS EC2 images and selects the newest
# matching Amazon Linux 2023 image.
#
# The AWS region comes from the AWS provider configuration.
#
# Therefore:
#
#   us-east-1
#       ↓
#   AWS EC2 AMI search
#       ↓
#   Latest matching Amazon Linux 2023 AMI
#       ↓
#   data.aws_ami.amazon_linux_2023.id
#
# ------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {

  # Select the newest AMI that matches all filters below.
  most_recent = true

  # Official Amazon Linux AMI owner account.
  owners = ["137112412989"]


  # ----------------------------------------------------------
  # AMI name
  # ----------------------------------------------------------
  #
  # Select Amazon Linux 2023 x86_64 images.
  #
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }


  # ----------------------------------------------------------
  # AMI must be available
  # ----------------------------------------------------------

  filter {
    name   = "state"
    values = ["available"]
  }


  # ----------------------------------------------------------
  # CPU architecture
  # ----------------------------------------------------------
  #
  # This is for normal x86_64 EC2 instances.
  #
  # If your EC2 instance uses ARM/Graviton, we would use
  # arm64 instead.
  #

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }


  # ----------------------------------------------------------
  # Root device
  # ----------------------------------------------------------

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }


  # ----------------------------------------------------------
  # Virtualization
  # ----------------------------------------------------------

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}