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
#   - Terraform manages/uploads the template objects.
#      This aws_cloudformation_stack resource consumes the
#      uploaded root template through template_url.
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
  #   hybridiaclab-dev-MainStack
  #
  # ==========================================================

  name = "${local.name_prefix}-MainStack"


  # ==========================================================
  # ROOT CLOUDFORMATION TEMPLATE
  # ==========================================================
  #
  # main.yaml is stored in the dedicated CloudFormation
  # template S3 bucket.
  #
  # This resource tells CloudFormation to retrieve the
  # root template from that bucket.
  #
  # The root template is responsible for creating and
  # connecting the nested CloudFormation stacks.
  #
  # ==========================================================

  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"

  # ==========================================================
  # CLOUDFORMATION EXECUTION ROLE
  # ==========================================================
  #
  # CloudFormation assumes this IAM role when creating and
  # managing the resources defined by the root and nested
  # CloudFormation templates.
  #
  # This is especially important for services such as
  # CloudFront where the GitHub CI/CD identity does not
  # necessarily have direct service permissions.
  #
  # ==========================================================

  iam_role_arn = aws_iam_role.cloudformation_execution.arn


  # ==========================================================
  # CLOUDFORMATION CAPABILITIES
  # ==========================================================
  # 
  # IAM CAPABILITIES
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
    # Terraform passes the CloudFormation template bucket
    # and the template prefix to the root stack.
    #
    # TemplatePrefix is intentionally empty because the
    # CloudFormation templates are referenced from the
    # bucket root.
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

    AmiId = data.aws_ami.amazon_linux_2023.id


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
  # The root CloudFormation stack depends on:
  #
  #   1. The CloudFormation template S3 object(s)
  #   2. The CloudFormation execution-role permissions
  #
  # This ensures the root template is available and
  # CloudFormation has the required execution permissions
  # before the stack is created.
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

