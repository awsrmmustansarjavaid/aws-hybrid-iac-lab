# ============================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS DEVOPS LAB
# ============================================================
#
# File:
#
#   infrastructure/terraform/terraform.tfvars
#
# Purpose:
#
#   Contains the REAL environment-specific values used by
#   Terraform for this AWS lab.
#
#
# ============================================================
# IMPORTANT SECURITY WARNING
# ============================================================
#
# IMPORTANT SECURITY WARNING
#
# This file contains non-secret lab configuration.
# It may be committed if it contains only non-sensitive configuration values.
# NEVER place passwords, access keys, tokens, private keys, or other secrets in this file.
# Sensitive values must be stored using GitHub Secrets, AWS Secrets Manager, or another approved secret store.
#
# This file may contain:
#
#   - Environment-specific configuration
#   - AWS configuration values
#   - IAM naming configuration
#
# The RDS database password is managed by AWS Secrets Manager
# and must NEVER be stored or committed in this file.
#
#
# ============================================================
# ARCHITECTURE
# ============================================================
#
# This project uses a hybrid Terraform + CloudFormation
# architecture.
#
#
# Terraform manages:
#
#   - Terraform backend infrastructure
#   - IAM resources
#   - CloudFormation root stack
#   - CloudFormation template S3 bucket
#   - Other Terraform-specific resources
#
#
# CloudFormation manages the application infrastructure,
# including resources such as:
#
#   - VPC
#   - Subnets
#   - Application S3 bucket
#   - Lambda
#   - ECR repository
#   - DynamoDB
#   - API Gateway
#   - CloudFront
#   - EC2
#   - ECS
#   - EKS
#   - RDS
#
#
# Therefore this file intentionally DOES NOT contain:
#
#   vpc_id
#   public_subnet_id
#   public_subnet_1_id
#   public_subnet_2_id
#   private_subnet_1_id
#   private_subnet_2_id
#   application_bucket_name
#   lambda_function_arn
#
#
# Those values are created by CloudFormation.
#
#
# ============================================================
# IAM ARCHITECTURE
# ============================================================
#
# Terraform manages the IAM resources.
#
# Therefore this file contains IAM RESOURCE NAME variables:
#
#   github_actions_role_name
#   github_actions_policy_name
#   terraform_backend_policy_name
#   github_ci_cd_combined_policy_name
#
#
# These are names only.
#
# Terraform obtains the resulting IAM ARNs directly from the
# IAM resources.
#
#
# DO NOT add:
#
#   github_actions_role_arn
#   github_actions_policy_arn
#   terraform_backend_policy_arn
#
#
# Also DO NOT add:
#
#   iam_policy_directory
#
# IAM policy JSON files are located in a fixed repository
# directory and are referenced directly from iam.tf.
#
#
# ============================================================


# ============================================================
# 1. AWS REGION
# ============================================================
#
# AWS region where this lab is deployed.
#
# Example:
#
#   us-east-1
#
# ============================================================

aws_region = "us-east-1"



# ============================================================
# 2. PROJECT NAME
# ============================================================
#
# Main project/lab name.
#
# Used for:
#
#   - Resource naming
#   - Resource tags
#   - CloudFormation stack naming
#   - IAM resource naming where applicable
#   - Project identification
#
# ============================================================

project_name = "hybridiaclab"



# ============================================================
# 3. ENVIRONMENT
# ============================================================
#
# Deployment environment.
#
# Supported values:
#
#   dev
#   test
#   staging
#   prod
#
# Current lab environment:
#
#   dev
#
# ============================================================

environment = "dev"



# ============================================================
# 4. DATABASE USERNAME
# ============================================================
#
# RDS database administrator username.
#
# This value is not treated as highly sensitive in the same
# way as the database password.
#
# Default:
#
#   admin
#
# ============================================================

database_username = "admin"



# ============================================================
# 5. GITHUB ACTIONS IAM ROLE NAME
# ============================================================
#
# Name of the IAM role assumed by GitHub Actions through
# GitHub OIDC.
#
#
# Terraform creates/manages this IAM role.
#
# Therefore the role NAME can be configured here.
#
#
# The role ARN is NOT required here.
#
# Terraform can obtain it directly from the IAM resource:
#
#   aws_iam_role.<resource_name>.arn
#
# ============================================================

github_actions_role_name = "aws-hybrid-iac-lab-GitHubActions"



# ============================================================
# 6. GITHUB ACTIONS IAM POLICY NAME
# ============================================================
#
# Name of the customer-managed IAM policy attached to the
# GitHub Actions OIDC role.
#
#
# Terraform creates/manages this policy.
#
# The actual policy permissions are stored separately in:
#
#   IAM/aws-hybrid-iac-lab-GitHubActionsPolicy.json
#
#
# IMPORTANT:
#
# The JSON file path is NOT configured here.
#
# iam.tf references the repository path directly.
#
# ============================================================

github_actions_policy_name = "aws-hybrid-iac-lab-GitHubActionsPolicy"



# ============================================================
# 7. TERRAFORM BACKEND IAM POLICY NAME
# ============================================================
#
# Name of the customer-managed IAM policy used for
# Terraform backend access.
#
#
# The policy provides access required for Terraform backend
# operations, including:
#
#   - Terraform state S3 bucket
#   - Terraform state objects
#   - State locking mechanism, if configured
#
#
# The actual permissions remain in the IAM JSON document.
#
# ============================================================

terraform_backend_policy_name = "github-actions-terraform-backend-policy"



# ============================================================
# 8. GITHUB CI/CD COMBINED IAM POLICY NAME
# ============================================================
#
# Name of the customer-managed IAM policy containing the
# combined AWS permissions required by the GitHub CI/CD
# identity.
#
#
# The policy document is stored separately under:
#
#   IAM/github-ci-cd-user-combined-access.json
#
#
# Terraform uses this variable only for the policy NAME.
#
# ============================================================

github_ci_cd_combined_policy_name = "github-ci-cd-user-combined-access"



# ============================================================
# FINAL VARIABLE CHECKLIST
# ============================================================
#
# The following variables are configured in this file:
#
#
# AWS / PROJECT
#
#   [x] aws_region
#   [x] project_name
#   [x] environment
#
#
# DATABASE
#
#   [x] database_username
#
#
# TERRAFORM-MANAGED IAM
#
#   [x] github_actions_role_name
#   [x] github_actions_policy_name
#   [x] terraform_backend_policy_name
#   [x] github_ci_cd_combined_policy_name
#
#
# ============================================================
# VALUES AUTOMATICALLY DISCOVERED OR MANAGED ELSEWHERE
# ============================================================
#
# The following values are intentionally NOT configured in
# terraform.tfvars.
#
#
# EC2 AMI
#
#   ami_id
#
# The AMI ID is dynamically discovered by Terraform using:
#
#   data.aws_ami.amazon_linux_2023.id
#
# defined in:
#
#   infrastructure/terraform/data.tf
#
#
# RDS DATABASE PASSWORD
#
#   database_password
#
# The database password is NOT stored in Terraform variables.
#
# RDS credentials are managed using AWS Secrets Manager through
# the CloudFormation RDS configuration.
#
#
# ============================================================
# CLOUDFORMATION-MANAGED VALUES
# ============================================================
#
# These values are not configured here because their
# corresponding resources are created by CloudFormation:
#
#   vpc_id
#   public_subnet_id
#   public_subnet_1_id
#   public_subnet_2_id
#   private_subnet_1_id
#   private_subnet_2_id
#   application_bucket_name
#   lambda_function_arn
#   ecr_image_uri
#
#
# ============================================================
# IAM VALUES INTENTIONALLY NOT INCLUDED
# ============================================================
#
# These values are not configured as input variables:
#
#   github_actions_role_arn
#   github_actions_policy_arn
#   terraform_backend_policy_arn
#   iam_policy_directory
#
#
# Terraform obtains IAM ARNs directly from the IAM resources
# that it creates.
#
# The IAM policy directory is part of the fixed repository
# structure and therefore does not need to be an input
# variable.
#
#
# ============================================================
# SECURITY CHECK
# ============================================================
#
# Before running:
#
#   terraform plan
#
# verify that this file contains only non-sensitive
# configuration values.
#
# NEVER add:
#
#   - Database passwords
#   - AWS access keys
#   - Secret access keys
#   - API tokens
#   - GitHub tokens
#   - Private keys
#   - Other credentials or secrets
#
# Sensitive values must be stored using GitHub Secrets,
# AWS Secrets Manager, or another approved secret store.
#
#
#
# ============================================================
# END OF terraform.tfvars
# ============================================================