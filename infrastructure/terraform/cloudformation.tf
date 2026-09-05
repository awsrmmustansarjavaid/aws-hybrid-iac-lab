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
  #
  # bucket_regional_domain_name provides the regional S3
  # endpoint hostname.
  #
  # Example:
  #
  #   https://my-bucket.s3.us-east-1.amazonaws.com/main.yaml
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
  #
  # CAPABILITY_IAM
  #
  # Allows CloudFormation to create standard IAM resources.
  #
  #
  # CAPABILITY_NAMED_IAM
  #
  # Allows CloudFormation to create IAM resources that use
  # explicitly specified names.
  #
  #
  # If your CloudFormation templates do not create IAM
  # resources, these capabilities may not be necessary.
  #
  # They are retained here because this lab is designed to
  # include IAM-related infrastructure.
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
  # The parameter names MUST match the Parameters section
  # of main.yaml.
  #
  # Expected CloudFormation parameters:
  #
  #   ProjectName
  #   Environment
  #   TemplateBucket
  #   TemplatePrefix
  #
  # ==========================================================

  parameters = {

    # --------------------------------------------------------
    # Project/application name.
    #
    # Terraform variable:
    #
    #   var.project_name
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
    # Terraform variable:
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
    # This bucket is created by Terraform and contains the
    # root and nested CloudFormation templates.
    #
    # Terraform resource:
    #
    #   aws_s3_bucket.cloudformation_templates
    #
    # The bucket name is passed to CloudFormation so that the
    # root template can construct references to nested
    # templates.
    #
    # --------------------------------------------------------

    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket


    # --------------------------------------------------------
    # CloudFormation template prefix.
    #
    # Current S3 layout:
    #
    #   main.yaml
    #   nested/vpc.yaml
    #   nested/s3.yaml
    #   nested/dynamodb.yaml
    #   nested/ecr.yaml
    #
    # Therefore main.yaml is located at the bucket root and
    # no additional prefix is required.
    #
    # --------------------------------------------------------

    TemplatePrefix = ""
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
  # and the parameters also reference that bucket.
  #
  #
  # However, we explicitly declare dependencies for the
  # CloudFormation template objects and execution-role policy.
  #
  #
  # CloudFormation must not start until:
  #
  #   1. The CloudFormation templates have been uploaded.
  #
  #   2. The CloudFormation execution-role policy has been
  #      created.
  #
  #
  # This helps prevent a deployment race condition.
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

