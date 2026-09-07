# ============================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS DEVOPS LAB
# ============================================================
#
# File:
#
#   infrastructure/terraform/cloudformation.tf
#
# Purpose:
#
#   Terraform creates and manages the ROOT CloudFormation stack.
#
#
# Architecture:
#
#   Terraform
#      |
#      +-- CloudFormation Template S3 Bucket
#      |
#      +-- IAM
#      |
#      +-- Root CloudFormation Stack
#              |
#              +-- VPC
#              +-- S3
#              +-- DynamoDB
#              +-- ECR
#              +-- Lambda
#              +-- API Gateway
#              +-- CloudFront
#              +-- EC2
#              +-- EKS
#              +-- RDS
#
# ============================================================
# IMPORTANT DEPLOYMENT ARCHITECTURE
# ============================================================
#
# This Terraform resource is responsible for the
# INFRASTRUCTURE / BOOTSTRAP phase.
#
# The root CloudFormation stack creates the infrastructure
# resources through nested CloudFormation stacks.
#
# The ECR repository is created during this phase.
#
# The Docker image is NOT created during this phase.
#
# The Docker image is built and pushed later by GitHub Actions.
#
#
# Deployment flow:
#
#   Terraform
#      |
#      +--> CloudFormation template bucket
#      |
#      +--> Root CloudFormation stack
#              |
#              +--> VPC
#              +--> S3
#              +--> DynamoDB
#              +--> ECR repository
#              +--> Lambda
#              +--> API Gateway
#              +--> CloudFront
#              +--> EC2
#              +--> EKS
#              +--> RDS
#
#
# Then:
#
#   GitHub Actions Docker workflow
#      |
#      +--> Build Docker image
#      |
#      +--> Login to ECR
#      |
#      +--> Push image:${GITHUB_SHA}
#      |
#      +--> Deploy/update ECS
#
# ============================================================
# IMPORTANT ECR / ECS RULE
# ============================================================
#
# ECR repository creation and ECS application deployment are
# intentionally separated.
#
# ECR:
#
#   CloudFormation creates the repository.
#
# ECS:
#
#   GitHub Actions deploys ECS after the Docker image exists.
#
#
# This prevents Terraform from requiring an application image
# before the Docker workflow has built and pushed that image.
#
#
# Therefore this file MUST NOT contain:
#
#   EcrImageUri = var.ecr_image_uri
#
#
# The root main.yaml no longer accepts EcrImageUri either.
#
# ============================================================
# RESOURCE OWNERSHIP RULE
# ============================================================
#
# Terraform owns:
#
#   - The CloudFormation template bucket
#   - CloudFormation template objects
#   - IAM resources
#   - The root CloudFormation stack
#
#
# CloudFormation owns:
#
#   - VPC
#   - Application S3 bucket
#   - DynamoDB
#   - ECR repository
#   - Lambda
#   - API Gateway
#   - CloudFront
#   - EC2
#   - EKS
#   - RDS
#
#
# GitHub Actions application deployment owns:
#
#   - Docker image build
#   - Docker image push
#   - ECS application deployment/update
#
#
# This separation keeps infrastructure provisioning and
# application deployment as two different lifecycle stages.
#
# ============================================================


resource "aws_cloudformation_stack" "main" {

  # ==========================================================
  # STACK NAME
  # ==========================================================
  #
  # Terraform creates a predictable root CloudFormation
  # stack name.
  #
  # Example:
  #
  #   HybridIaCLab-dev-MainStack
  #
  # ==========================================================

  name = "${local.name_prefix}-MainStack"


  # ==========================================================
  # ROOT CLOUDFORMATION TEMPLATE
  # ==========================================================
  #
  # Terraform uploads main.yaml into the dedicated
  # CloudFormation template S3 bucket.
  #
  # CloudFormation then retrieves main.yaml from that bucket.
  #
  # The root template is responsible for creating and
  # connecting the nested CloudFormation stacks.
  #
  # ==========================================================

  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"


  # ==========================================================
  # CLOUDFORMATION CAPABILITIES
  # ==========================================================
  #
  # Some nested CloudFormation stacks create IAM resources.
  #
  # CAPABILITY_IAM:
  #
  #   Allows CloudFormation to create IAM resources.
  #
  #
  # CAPABILITY_NAMED_IAM:
  #
  #   Allows CloudFormation to create IAM resources with
  #   explicitly specified names.
  #
  # ==========================================================

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM"
  ]


  # ==========================================================
  # ROOT STACK PARAMETERS
  # ==========================================================
  #
  # Only genuine external inputs are supplied here.
  #
  #
  # Resources created inside nested CloudFormation stacks
  # should NOT be passed through Terraform.
  #
  #
  # For example, Terraform does NOT provide:
  #
  #   VpcId
  #   PublicSubnetId
  #   PrivateSubnetId
  #   ApplicationBucketName
  #   LambdaFunctionArn
  #   EcrImageUri
  #
  #
  # Those values are handled by the CloudFormation hierarchy
  # or by the later application deployment pipeline.
  #
  # ==========================================================

  parameters = {

    # ========================================================
    # BASIC PROJECT CONFIGURATION
    # ========================================================
    #
    # These values are genuine configuration inputs.
    #
    # They are consumed by the root CloudFormation template
    # and passed to nested stacks.
    #
    # ========================================================

    ProjectName = var.project_name
    Environment = var.environment


    # ========================================================
    # CLOUDFORMATION TEMPLATE LOCATION
    # ========================================================
    #
    # Terraform owns the CloudFormation template bucket.
    #
    # The root CloudFormation stack receives the bucket name
    # so that it can locate main.yaml and all nested templates.
    #
    # ========================================================

    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket
    TemplatePrefix = ""


    # ========================================================
    # EC2 AMI
    # ========================================================
    #
    # The AMI is not created by this CloudFormation hierarchy.
    #
    # Therefore the AMI ID remains a legitimate external input.
    #
    # Terraform supplies the AMI ID to the root CloudFormation
    # stack.
    #
    # main.yaml then passes the value to EC2Stack.
    #
    # ========================================================

    AmiId = var.ami_id


    # ========================================================
    # EC2 INSTANCE TYPE
    # ========================================================
    #
    # The current main.yaml defines:
    #
    #   InstanceType:
    #     Default: t3.micro
    #
    # We intentionally do not pass InstanceType here.
    #
    # CloudFormation therefore uses its own default:
    #
    #   t3.micro
    #
    # If you later create a Terraform variable for the EC2
    # instance type, this parameter can be supplied here.
    #
    # ========================================================


    # ========================================================
    # ECR DOCKER IMAGE
    # ========================================================
    #
    # IMPORTANT:
    #
    # There is intentionally NO:
    #
    #   EcrImageUri = var.ecr_image_uri
    #
    #
    # Reason:
    #
    # The ECR repository is created during the infrastructure
    # bootstrap phase.
    #
    # The Docker image does not exist yet at this point.
    #
    #
    # The Docker image lifecycle is handled later by GitHub
    # Actions:
    #
    #   1. Build Docker image.
    #   2. Login to ECR.
    #   3. Tag image with GITHUB_SHA.
    #   4. Push image to ECR.
    #   5. Deploy/update ECS.
    #
    #
    # Therefore Terraform does not need an ECR image URI during
    # infrastructure provisioning.
    #
    # ========================================================


    # ========================================================
    # DATABASE USERNAME
    # ========================================================
    #
    # Passed to the RDS nested stack through main.yaml.
    #
    # ========================================================

    DatabaseUsername = var.database_username
  }


  # ==========================================================
  # DEPENDENCIES
  # ==========================================================
  #
  # The root CloudFormation stack must only be created after:
  #
  #   1. All CloudFormation templates have been uploaded.
  #
  #   2. The CloudFormation execution role permissions exist.
  #
  #
  # This ensures CloudFormation can:
  #
  #   - Download main.yaml
  #   - Download nested templates
  #   - Create the required nested resources
  #
  # ==========================================================

  depends_on = [
    aws_s3_object.cloudformation_templates,
    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}


# ============================================================
# END OF cloudformation.tf
# ============================================================

