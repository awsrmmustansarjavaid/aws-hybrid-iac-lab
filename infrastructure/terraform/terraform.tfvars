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
# THIS FILE MUST NOT BE COMMITTED TO GITHUB.
#
# This file may contain:
#
#   - Environment-specific configuration
#   - AWS resource values
#   - Database credentials
#   - IAM naming configuration
#
#
# Recommended .gitignore entries:
#
#   terraform.tfvars
#   *.tfvars
#   *.tfvars.json
#
#
# The real database password must NEVER be committed.
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

github_actions_role_name = "github-actions-oidc-role"



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
# Depending on the backend architecture, this policy may
# provide access to:
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
# The following variables are expected by variables.tf:
#
#
# AWS / PROJECT
#
#   [x] aws_region
#   [x] project_name
#   [x] environment
#
#
# EXTERNAL APPLICATION INPUTS
#
#   [x] ami_id
#
#
# DATABASE
#
#   [x] database_username
#   [x] database_password
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
# VARIABLES INTENTIONALLY REMOVED
# ============================================================
#
# These variables are NOT included because their resources
# are created by CloudFormation:
#
#   [x] vpc_id
#   [x] public_subnet_id
#   [x] public_subnet_1_id
#   [x] public_subnet_2_id
#   [x] private_subnet_1_id
#   [x] private_subnet_2_id
#   [x] application_bucket_name
#   [x] lambda_function_arn
#   [x] ecr_image_uri
#
#
# ============================================================
# IAM VALUES INTENTIONALLY NOT INCLUDED
# ============================================================
#
# These are NOT variables:
#
#   [x] github_actions_role_arn
#   [x] github_actions_policy_arn
#   [x] terraform_backend_policy_arn
#   [x] iam_policy_directory
#
#
# Why?
#
# Terraform can obtain IAM ARNs directly from resources that
# it creates.
#
# The IAM policy directory is part of the fixed repository
# structure and therefore does not need to be an input.
#
#
# ============================================================
# FINAL PRE-PLAN CHECKLIST
# ============================================================
#
# Before running:
#
#   terraform plan
#
# make sure you have replaced:
#
#   [ ] ami_id
#   [ ] database_password
#
#
# IAM names may be left at their defaults unless you want
# different naming.
#
#
# NEVER weaken variables.tf validation just to make invalid
# placeholder values pass.
#
#
# ============================================================
# END OF terraform.tfvars
# ============================================================