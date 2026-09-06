# ============================================================
# CloudFormation Root Stack
# ============================================================
#
# Purpose:
#
# This Terraform resource creates the MAIN CloudFormation
# root stack for the hybrid Infrastructure-as-Code lab.
#
#
# HYBRID IaC ARCHITECTURE
#
# Terraform
#     |
#     | creates/manages
#     v
# CloudFormation Root Stack
#     |
#     +----> VPC Nested Stack
#     |
#     +----> S3 Nested Stack
#     |
#     +----> DynamoDB Nested Stack
#     |
#     +----> ECR Nested Stack
#
#
# Design:
#
# Terraform is responsible for:
#
#   - Creating the CloudFormation template bucket
#   - Uploading CloudFormation templates
#   - Creating the CloudFormation execution IAM role
#   - Creating the CloudFormation root stack
#   - Orchestrating the overall deployment
#
#
# CloudFormation is responsible for:
#
#   - Processing the root CloudFormation template
#   - Creating nested CloudFormation stacks
#   - Creating resources defined by those templates
#
#
# IMPORTANT:
#
# The aws_cloudformation_stack resource in the current AWS
# provider version does NOT accept a "role_arn" argument.
#
# Therefore we intentionally DO NOT use:
#
#   role_arn = aws_iam_role.cloudformation_execution.arn
#
# in this resource.
#
# The CloudFormation execution IAM role can still be created
# and managed by Terraform elsewhere in the configuration.
#
# ============================================================


resource "aws_cloudformation_stack" "main" {

  # ==========================================================
  # 1. CLOUDFORMATION STACK NAME
  # ==========================================================
  #
  # local.name_prefix should be defined in locals.tf.
  #
  # Example:
  #
  #   local.name_prefix = "HybridIaCLab-dev"
  #
  # Result:
  #
  #   HybridIaCLab-dev-MainStack
  #
  # ==========================================================

  name = "${local.name_prefix}-MainStack"


  # ==========================================================
  # 2. ROOT CLOUDFORMATION TEMPLATE
  # ==========================================================
  #
  # CloudFormation needs access to the root template.
  #
  # Terraform uploads main.yaml to the dedicated S3 bucket
  # before this CloudFormation stack is created.
  #
  # Expected S3 structure:
  #
  #   <bucket>/
  #   |
  #   +-- main.yaml
  #   |
  #   +-- nested/
  #       |
  #       +-- vpc.yaml
  #       +-- s3.yaml
  #       +-- dynamodb.yaml
  #       +-- ecr.yaml
  #
  # ==========================================================

  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"


  # ==========================================================
  # 3. CLOUDFORMATION CAPABILITIES
  # ==========================================================
  #
  # These capabilities tell CloudFormation that the template
  # is allowed to create IAM resources.
  #
  # ==========================================================

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM"
  ]


  # ==========================================================
  # 4. CLOUDFORMATION PARAMETERS
  # ==========================================================
  #
  # These values are passed from Terraform into the
  # CloudFormation root template.
  #
  # IMPORTANT:
  #
  # Every parameter name on the LEFT side must exactly match
  # the parameter name defined inside main.yaml.
  #
  # Terraform variable/resource
  #             |
  #             v
  # CloudFormation parameter
  #             |
  #             v
  # Root stack / nested stacks
  #
  # ==========================================================

  parameters = {

    # --------------------------------------------------------
    # Project/application name.
    #
    # Passed from Terraform:
    #
    #   var.project_name
    #
    # CloudFormation parameter:
    #
    #   ProjectName
    #
    # Example:
    #
    #   HybridIaCLab
    #
    # --------------------------------------------------------

    ProjectName = var.project_name


    # --------------------------------------------------------
    # Deployment environment.
    #
    # Passed from Terraform:
    #
    #   var.environment
    #
    # Example:
    #
    #   dev
    #
    # --------------------------------------------------------

    Environment = var.environment


    # --------------------------------------------------------
    # CloudFormation template bucket.
    #
    # This bucket is created and managed by Terraform.
    #
    # It contains:
    #
    #   main.yaml
    #   nested/vpc.yaml
    #   nested/s3.yaml
    #   nested/dynamodb.yaml
    #   nested/ecr.yaml
    #
    # CloudFormation uses this value to locate the nested
    # templates.
    #
    # --------------------------------------------------------

    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket


    # --------------------------------------------------------
    # CloudFormation template prefix.
    #
    # Current S3 structure:
    #
    #   main.yaml
    #   nested/vpc.yaml
    #   nested/s3.yaml
    #   nested/dynamodb.yaml
    #   nested/ecr.yaml
    #
    # main.yaml is located at the bucket root, therefore
    # no prefix is currently required.
    #
    # --------------------------------------------------------

    TemplatePrefix = ""


    # ========================================================
    # ADDITIONAL APPLICATION INFRASTRUCTURE PARAMETERS
    # ========================================================
    #
    # The following parameters allow Terraform to pass
    # existing infrastructure values into CloudFormation.
    #
    # These are useful when Terraform and CloudFormation
    # operate together in the same hybrid IaC architecture.
    #
    # ========================================================


    # --------------------------------------------------------
    # Existing VPC ID.
    #
    # Terraform variable:
    #
    #   var.vpc_id
    #
    # CloudFormation parameter:
    #
    #   VpcId
    #
    # Example:
    #
    #   vpc-0123456789abcdef0
    #
    # This allows CloudFormation resources to reference
    # an existing VPC.
    #
    # --------------------------------------------------------

    VpcId = var.vpc_id


    # --------------------------------------------------------
    # Public subnet ID.
    #
    # Terraform variable:
    #
    #   var.public_subnet_id
    #
    # CloudFormation parameter:
    #
    #   PublicSubnetId
    #
    # Used when a CloudFormation resource needs a specific
    # public subnet.
    #
    # --------------------------------------------------------

    PublicSubnetId = var.public_subnet_id


    # --------------------------------------------------------
    # Public subnet 1 ID.
    #
    # Terraform variable:
    #
    #   var.public_subnet_1_id
    #
    # CloudFormation parameter:
    #
    #   PublicSubnet1Id
    #
    # Typically used for Multi-AZ resources that require
    # more than one public subnet.
    #
    # --------------------------------------------------------

    PublicSubnet1Id = var.public_subnet_1_id


    # --------------------------------------------------------
    # Public subnet 2 ID.
    #
    # Terraform variable:
    #
    #   var.public_subnet_2_id
    #
    # CloudFormation parameter:
    #
    #   PublicSubnet2Id
    #
    # Typically used as the second Availability Zone subnet.
    #
    # --------------------------------------------------------

    PublicSubnet2Id = var.public_subnet_2_id


    # --------------------------------------------------------
    # Private subnet 1 ID.
    #
    # Terraform variable:
    #
    #   var.private_subnet_1_id
    #
    # CloudFormation parameter:
    #
    #   PrivateSubnet1Id
    #
    # Typically used for private application/database
    # resources.
    #
    # --------------------------------------------------------

    PrivateSubnet1Id = var.private_subnet_1_id


    # --------------------------------------------------------
    # Private subnet 2 ID.
    #
    # Terraform variable:
    #
    #   var.private_subnet_2_id
    #
    # CloudFormation parameter:
    #
    #   PrivateSubnet2Id
    #
    # Provides a second private subnet for Multi-AZ
    # architecture.
    #
    # --------------------------------------------------------

    PrivateSubnet2Id = var.private_subnet_2_id


    # --------------------------------------------------------
    # EC2 AMI ID.
    #
    # Terraform variable:
    #
    #   var.ami_id
    #
    # CloudFormation parameter:
    #
    #   AmiId
    #
    # Example:
    #
    #   ami-xxxxxxxxxxxxxxxxx
    #
    # CloudFormation can use this AMI when creating EC2
    # instances.
    #
    # --------------------------------------------------------

    AmiId = var.ami_id


    # --------------------------------------------------------
    # Application S3 bucket name.
    #
    # Terraform variable:
    #
    #   var.application_bucket_name
    #
    # CloudFormation parameter:
    #
    #   ApplicationBucketName
    #
    # This allows CloudFormation resources to reference the
    # application bucket created or managed elsewhere.
    #
    # --------------------------------------------------------

    ApplicationBucketName = var.application_bucket_name


    # --------------------------------------------------------
    # Lambda function ARN.
    #
    # Terraform variable:
    #
    #   var.lambda_function_arn
    #
    # CloudFormation parameter:
    #
    #   LambdaFunctionArn
    #
    # This allows CloudFormation resources to integrate with
    # an existing Lambda function.
    #
    # Example:
    #
    #   arn:aws:lambda:region:account:function:name
    #
    # --------------------------------------------------------

    LambdaFunctionArn = var.lambda_function_arn


    # --------------------------------------------------------
    # ECR container image URI.
    #
    # Terraform variable:
    #
    #   var.ecr_image_uri
    #
    # CloudFormation parameter:
    #
    #   EcrImageUri
    #
    # Used by container-based resources such as ECS when
    # CloudFormation needs to deploy an existing container image.
    #
    # Example:
    #
    #   123456789012.dkr.ecr.us-east-1.amazonaws.com/app:latest
    #
    # --------------------------------------------------------

    EcrImageUri = var.ecr_image_uri


    # --------------------------------------------------------
    # Database password.
    #
    # Terraform variable:
    #
    #   var.database_password
    #
    # CloudFormation parameter:
    #
    #   DatabasePassword
    #
    # This value can be passed to CloudFormation resources
    # that require a database password.
    #
    # SECURITY WARNING:
    #
    # Database passwords are sensitive values.
    #
    # Prefer AWS Secrets Manager rather than passing plaintext
    # passwords through Terraform and CloudFormation whenever
    # possible.
    #
    # If this parameter is used, ensure that:
    #
    #   - var.database_password is marked sensitive
    #   - The password is not hard-coded
    #   - The password is not committed to Git
    #   - Terraform state security is properly configured
    #
    # --------------------------------------------------------

    DatabasePassword = var.database_password
  }


  # ==========================================================
  # 5. EXPLICIT TERRAFORM DEPENDENCIES
  # ==========================================================
  #
  # Terraform already understands dependencies created through
  # resource references.
  #
  # For example:
  #
  #   template_url
  #
  # references:
  #
  #   aws_s3_bucket.cloudformation_templates
  #
  # The parameters also reference the template bucket.
  #
  #
  # We explicitly declare dependencies for the CloudFormation
  # template objects and execution-role policy.
  #
  # CloudFormation must not start until:
  #
  #   1. The CloudFormation templates have been uploaded.
  #
  #   2. The CloudFormation execution-role policy has been
  #      created.
  #
  # ==========================================================

  depends_on = [

    # --------------------------------------------------------
    # Ensure the CloudFormation templates are uploaded before
    # CloudFormation attempts to read main.yaml.
    #
    # This resource is expected to upload:
    #
    #   main.yaml
    #   nested templates
    #
    # --------------------------------------------------------

    aws_s3_object.cloudformation_templates,


    # --------------------------------------------------------
    # Ensure the CloudFormation execution-role permissions
    # exist before the CloudFormation stack is created.
    #
    # IMPORTANT:
    #
    # This dependency does NOT pass role_arn to the
    # aws_cloudformation_stack resource.
    #
    # It only controls Terraform resource creation order.
    #
    # --------------------------------------------------------

    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}


# ============================================================
# END OF CLOUDFORMATION ROOT STACK
# ============================================================
#
# FINAL DEPLOYMENT FLOW
#
# Terraform
#     |
#     +--> S3 Template Bucket
#     |
#     +--> CloudFormation Templates
#     |
#     +--> CloudFormation Execution IAM Role
#     |
#     +--> CloudFormation Root Stack
#              |
#              +--> VPC Nested Stack
#              |
#              +--> S3 Nested Stack
#              |
#              +--> DynamoDB Nested Stack
#              |
#              +--> ECR Nested Stack
#
#
# IMPORTANT:
#
# The GitHub Actions OIDC IAM role is separate from the
# CloudFormation execution role.
#
#
# GitHub OIDC Role:
#
#   aws-hybrid-iac-lab-GitHubActions
#
# is used by GitHub Actions to authenticate to AWS.
#
#
# CloudFormation Execution Role:
#
#   aws_iam_role.cloudformation_execution
#
# is intended for CloudFormation's own resource operations.
#
#
# These two IAM roles should NOT be confused with each other.
#
# ============================================================

