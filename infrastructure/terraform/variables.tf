# ==========================================================
# Terraform Input Variables
# ==========================================================
#
# File:
#   variables.tf
#
# Purpose:
#   This file defines all input variables used throughout
#   the Terraform project.
#
# Variables allow us to avoid hard-coding infrastructure
# values directly inside Terraform resource configurations.
#
# Values can be provided through:
#
#   - Default values
#   - terraform.tfvars
#   - *.auto.tfvars
#   - Command-line -var arguments
#   - Environment variables
#
# IMPORTANT:
#   Sensitive values such as database passwords should NOT
#   be committed to GitHub.
#
# ==========================================================



# ==========================================================
# AWS REGION
# ==========================================================
#
# Defines the AWS region where Terraform will create and
# manage infrastructure.
#
# Examples:
#
#   us-east-1
#   us-west-2
#   eu-west-1
#
# The provider.tf file can use this variable:
#
#   region = var.aws_region
#
# ==========================================================

variable "aws_region" {

  description = "AWS region where the lab will be deployed"

  # The AWS region must be a string value.
  type = string

  # Default AWS region for this lab.
  #
  # This value is used when another value is not supplied.
  default = "us-east-1"
}



# ==========================================================
# PROJECT NAME
# ==========================================================
#
# Identifies the project or application.
#
# This value can also be used for:
#
#   - Resource naming
#   - AWS tags
#   - CloudFormation stack names
#   - Logging
#   - Cost tracking
#
# Example:
#
#   Project = "HybridIaCLab"
#
# ==========================================================

variable "project_name" {

  description = "Project name"

  # Project name must be a string.
  type = string

  # Default project name.
  default = "HybridIaCLab"
}



# ==========================================================
# ENVIRONMENT
# ==========================================================
#
# Identifies the deployment environment.
#
# Common environment names include:
#
#   dev
#   test
#   staging
#   prod
#
# This value can also be used for AWS resource tags.
#
# Example:
#
#   Environment = "dev"
#
# ==========================================================

variable "environment" {

  description = "Deployment environment"

  # Environment name must be a string.
  type = string

  # Default environment.
  default = "dev"
}



# ==========================================================
# VPC ID
# ==========================================================
#
# ID of the VPC used by the CloudFormation root stack
# and other infrastructure components.
#
# Example:
#
#   vpc-0123456789abcdef0
#
# This variable allows Terraform to pass an existing VPC
# ID into CloudFormation or other AWS resources.
#
# ==========================================================

variable "vpc_id" {

  description = "VPC ID used by the CloudFormation root stack"

  # VPC ID is represented as a string.
  type = string
}



# ==========================================================
# PUBLIC SUBNET ID
# ==========================================================
#
# Public subnet used by resources such as EC2 instances
# that require placement in a public subnet.
#
# Example:
#
#   subnet-0123456789abcdef0
#
# ==========================================================

variable "public_subnet_id" {

  description = "Public subnet ID used by EC2"

  # Subnet ID must be a string.
  type = string
}



# ==========================================================
# PUBLIC SUBNET 1 ID
# ==========================================================
#
# First public subnet used by services such as ECS.
#
# ECS services that require high availability normally use
# multiple subnets across different Availability Zones.
#
# Example:
#
#   subnet-0123456789abcdef0
#
# ==========================================================

variable "public_subnet_1_id" {

  description = "First public subnet ID used by ECS"

  # Subnet ID must be a string.
  type = string
}



# ==========================================================
# PUBLIC SUBNET 2 ID
# ==========================================================
#
# Second public subnet used by ECS.
#
# Using two public subnets allows ECS resources to be
# distributed across multiple Availability Zones.
#
# Example:
#
#   subnet-0123456789abcdef1
#
# ==========================================================

variable "public_subnet_2_id" {

  description = "Second public subnet ID used by ECS"

  # Subnet ID must be a string.
  type = string
}



# ==========================================================
# PRIVATE SUBNET 1 ID
# ==========================================================
#
# First private subnet used by RDS.
#
# RDS databases should normally be placed in private
# subnets rather than directly on the public internet.
#
# Example:
#
#   subnet-0123456789abcdef2
#
# ==========================================================

variable "private_subnet_1_id" {

  description = "First private subnet ID used by RDS"

  # Subnet ID must be a string.
  type = string
}



# ==========================================================
# PRIVATE SUBNET 2 ID
# ==========================================================
#
# Second private subnet used by RDS.
#
# Using multiple private subnets in different Availability
# Zones supports an RDS DB subnet group and improves
# availability.
#
# Example:
#
#   subnet-0123456789abcdef3
#
# ==========================================================

variable "private_subnet_2_id" {

  description = "Second private subnet ID used by RDS"

  # Subnet ID must be a string.
  type = string
}



# ==========================================================
# AMI ID
# ==========================================================
#
# Amazon Machine Image (AMI) ID used when creating an EC2
# instance.
#
# For this lab, the AMI is expected to be an
# Amazon Linux 2023 image.
#
# Example:
#
#   ami-0123456789abcdef0
#
# IMPORTANT:
#   AMI IDs are region-specific.
#
#   An AMI ID valid in us-east-1 may not be valid in
#   another AWS region.
#
# ==========================================================

variable "ami_id" {

  description = "Amazon Linux 2023 AMI ID"

  # AMI ID must be a string.
  type = string
}



# ==========================================================
# APPLICATION S3 BUCKET NAME
# ==========================================================
#
# Name of the S3 bucket used to store application files
# or application-related objects.
#
# Example:
#
#   hybrid-iac-lab-application-123456
#
# IMPORTANT:
#   S3 bucket names must be globally unique across AWS.
#
# ==========================================================

variable "application_bucket_name" {

  description = "Application S3 bucket name"

  # S3 bucket name must be a string.
  type = string
}



# ==========================================================
# LAMBDA FUNCTION ARN
# ==========================================================
#
# ARN of the Lambda function used by the application or
# CloudFormation resources.
#
# Example:
#
#   arn:aws:lambda:us-east-1:123456789012:function:MyFunction
#
# ARN stands for Amazon Resource Name.
#
# ==========================================================

variable "lambda_function_arn" {

  description = "Lambda function ARN"

  # Lambda ARN must be a string.
  type = string
}



# ==========================================================
# ECR IMAGE URI
# ==========================================================
#
# Full URI of the container image stored in Amazon ECR.
#
# ECS can use this image URI to start containers.
#
# Example:
#
#   123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app:latest
#
# The URI normally contains:
#
#   AWS Account ID
#   ECR registry
#   AWS region
#   Repository name
#   Image tag
#
# ==========================================================

variable "ecr_image_uri" {

  description = "Full ECR container image URI"

  # ECR image URI must be a string.
  type = string
}



# ==========================================================
# DATABASE PASSWORD
# ==========================================================
#
# Password used by the RDS database.
#
# IMPORTANT SECURITY NOTE:
#
#   This variable contains sensitive information.
#
#   Terraform will hide this value from normal CLI output
#   where possible because sensitive = true is configured.
#
#   DO NOT place the real password directly inside:
#
#     - variables.tf
#     - GitHub repository
#     - public documentation
#     - README.md
#
# A better approach is to provide the value through a
# secure mechanism such as:
#
#   - terraform.tfvars (kept out of Git)
#   - Environment variables
#   - AWS Secrets Manager
#   - CI/CD secret variables
#
# ==========================================================

variable "database_password" {

  description = "RDS database password"

  # Database password must be a string.
  type = string

  # Prevent Terraform from displaying the value in normal
  # Terraform CLI output.
  sensitive = true
}

