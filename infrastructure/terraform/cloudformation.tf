# ============================================================
# CloudFormation Root Stack
# ============================================================
#
# This Terraform resource creates the MAIN CloudFormation stack.
#
# Architecture:
#
# Terraform
#    |
#    | creates
#    v
# CloudFormation Root Stack
#    |
#    +----> VPC Nested Stack
#    |
#    +----> S3 Nested Stack
#    |
#    +----> DynamoDB Nested Stack
#    |
#    +----> ECR Nested Stack
#
# This demonstrates a real-world HYBRID IaC approach:
#
# - Terraform manages the overall deployment/orchestration.
# - CloudFormation manages AWS resources inside the CloudFormation
#   stack hierarchy.
#
# ============================================================


resource "aws_cloudformation_stack" "main" {

  # ----------------------------------------------------------
  # CloudFormation Stack Name
  # ----------------------------------------------------------
  #
  # local.name_prefix is expected to be defined in locals.tf.
  #
  # Example:
  #
  # ProjectName = HybridIaCLab
  # Environment = dev
  #
  # Result:
  #
  # HybridIaCLab-dev-MainStack
  #
  name = "${local.name_prefix}-MainStack"


  # ----------------------------------------------------------
  # CloudFormation Root Template
  # ----------------------------------------------------------
  #
  # CloudFormation needs access to the root template.
  #
  # The main.yaml file is uploaded to the dedicated
  # CloudFormation template S3 bucket by Terraform.
  #
  # Example URL:
  #
  # https://bucket-name.s3.us-east-1.amazonaws.com/main.yaml
  #
  # bucket_regional_domain_name automatically provides the
  # regional S3 DNS name.
  #
  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"


  # ----------------------------------------------------------
  # CloudFormation Capabilities
  # ----------------------------------------------------------
  #
  # These capabilities tell CloudFormation that the template
  # may create IAM resources.
  #
  # CAPABILITY_IAM
  #     Allows CloudFormation to create standard IAM resources.
  #
  # CAPABILITY_NAMED_IAM
  #     Allows CloudFormation to create IAM resources that use
  #     explicitly specified names.
  #
  # We include both because this lab may grow to contain
  # IAM-related CloudFormation resources.
  #
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM"
  ]


  # ----------------------------------------------------------
  # Parameters Passed to CloudFormation
  # ----------------------------------------------------------
  #
  # These values correspond to the Parameters section of the
  # CloudFormation root template:
  #
  # main.yaml
  #
  # Parameters:
  #   ProjectName
  #   Environment
  #   TemplateBucket
  #   TemplatePrefix
  #
  # Terraform supplies the actual values here.
  #
  parameters = {

    # Project/application name.
    #
    # Comes from Terraform:
    # var.project_name
    #
    ProjectName = var.project_name


    # Deployment environment.
    #
    # Example:
    # dev
    # staging
    # prod
    #
    Environment = var.environment


    # --------------------------------------------------------
    # CloudFormation Template Bucket
    # --------------------------------------------------------
    #
    # This is the S3 bucket containing:
    #
    # main.yaml
    # nested/vpc.yaml
    # nested/s3.yaml
    # nested/dynamodb.yaml
    # nested/ecr.yaml
    #
    # Terraform creates this bucket.
    #
    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket


    # --------------------------------------------------------
    # CloudFormation Template Prefix
    # --------------------------------------------------------
    #
    # Our current S3 layout places main.yaml at the bucket
    # root and nested templates under:
    #
    # nested/
    #
    # Therefore no additional prefix is required.
    #
    # Result:
    #
    # main.yaml
    # nested/vpc.yaml
    #
    TemplatePrefix = ""
  }


  # ----------------------------------------------------------
  # CloudFormation Execution Role
  # ----------------------------------------------------------
  #
  # CloudFormation will assume this IAM role while creating
  # and managing resources defined inside the CloudFormation
  # templates.
  #
  # This is an important real-world security pattern:
  #
  # Terraform
  #     |
  #     | creates stack
  #     v
  # CloudFormation
  #     |
  #     | assumes
  #     v
  # Execution IAM Role
  #     |
  #     v
  # AWS Resources
  #
  # The role must have permissions required by the CloudFormation
  # templates.
  #
  role_arn = aws_iam_role.cloudformation_execution.arn


  # ----------------------------------------------------------
  # Terraform Dependency Control
  # ----------------------------------------------------------
  #
  # Terraform normally creates resources based on references.
  #
  # However, we explicitly declare dependencies here because
  # CloudFormation must NOT start until:
  #
  # 1. All CloudFormation templates have been uploaded to S3.
  #
  # 2. The CloudFormation execution role has its required
  #    permissions.
  #
  # This prevents a race condition where CloudFormation starts
  # before the templates or IAM permissions are ready.
  #
  depends_on = [

    # Ensures main.yaml and nested CloudFormation templates
    # have been uploaded to S3.
    aws_s3_object.cloudformation_templates,


    # Ensures the CloudFormation execution role has the required
    # IAM policy before the stack is created.
    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}
