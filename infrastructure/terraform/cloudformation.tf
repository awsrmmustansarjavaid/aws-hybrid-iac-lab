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
#     |
#     +----> ECS Nested Stack
#     |
#     +----> EKS Nested Stack
#     |
#     +----> EC2 Nested Stack
#     |
#     +----> RDS Nested Stack
#     |
#     +----> Lambda Nested Stack
#     |
#     +----> API Gateway Nested Stack
#     |
#     +----> CloudFront Nested Stack
#
#
# Terraform is responsible for:
#
#   - Creating the CloudFormation template S3 bucket
#   - Uploading CloudFormation templates
#   - Creating the CloudFormation execution IAM role
#   - Creating the CloudFormation root stack
#   - Passing environment/infrastructure parameters
#   - Orchestrating the overall hybrid deployment
#
#
# CloudFormation is responsible for:
#
#   - Processing the root CloudFormation template
#   - Creating nested CloudFormation stacks
#   - Creating resources defined by those nested templates
#
#
# IMPORTANT:
#
# The aws_cloudformation_stack resource in the current AWS
# provider configuration does NOT use a role_arn argument here.
#
# Therefore we intentionally DO NOT use:
#
#     role_arn = aws_iam_role.cloudformation_execution.arn
#
# The CloudFormation execution IAM role is still created and
# managed separately by Terraform.
#
# ============================================================


resource "aws_cloudformation_stack" "main" {

  # ==========================================================
  # 1. CLOUDFORMATION STACK NAME
  # ==========================================================
  #
  # local.name_prefix is expected to be defined in locals.tf.
  #
  # Example:
  #
  #     local.name_prefix = "HybridIaCLab-dev"
  #
  # Result:
  #
  #     HybridIaCLab-dev-MainStack
  #
  # ==========================================================

  name = "${local.name_prefix}-MainStack"


  # ==========================================================
  # 2. ROOT CLOUDFORMATION TEMPLATE
  # ==========================================================
  #
  # Terraform uploads main.yaml to the dedicated S3 bucket.
  #
  # CloudFormation then downloads the root template from S3.
  #
  # Expected S3 structure:
  #
  #     <bucket>/
  #     |
  #     +-- main.yaml
  #     |
  #     +-- nested/
  #         |
  #         +-- vpc.yaml
  #         +-- s3.yaml
  #         +-- dynamodb.yaml
  #         +-- ecr.yaml
  #         +-- ecs.yaml
  #         +-- eks.yaml
  #         +-- ec2.yaml
  #         +-- rds.yaml
  #         +-- lambda.yaml
  #         +-- api_gateway.yaml
  #         +-- cloudfront.yaml
  #
  # ==========================================================

  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"


  # ==========================================================
  # 3. CLOUDFORMATION CAPABILITIES
  # ==========================================================
  #
  # These capabilities allow CloudFormation to create IAM
  # resources defined inside the CloudFormation templates.
  #
  # CAPABILITY_IAM:
  #
  #   Allows CloudFormation to create IAM resources.
  #
  # CAPABILITY_NAMED_IAM:
  #
  #   Allows CloudFormation to create IAM resources with
  #   custom/named resource names.
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
  # The parameter names on the LEFT side must exactly match
  # the parameter names declared inside main.yaml.
  #
  #
  # Example data flow:
  #
  #     terraform.tfvars
  #          |
  #          v
  #     var.vpc_id
  #          |
  #          v
  #     cloudformation.tf
  #          |
  #          v
  #     VpcId
  #          |
  #          v
  #     main.yaml
  #
  #
  # IMPORTANT:
  #
  # Do NOT put:
  #
  #     VpcId = "vpc-xxxxxxxx"
  #
  # directly in this file.
  #
  # Instead, use:
  #
  #     VpcId = var.vpc_id
  #
  # and provide the actual value through terraform.tfvars
  # or another appropriate Terraform variable source.
  #
  # ==========================================================


  parameters = {

    # ========================================================
    # 4.1 PROJECT NAME
    # ========================================================
    #
    # Terraform variable:
    #
    #     var.project_name
    #
    # CloudFormation parameter:
    #
    #     ProjectName
    #
    # Example:
    #
    #     HybridIaCLab
    #
    # ========================================================

    ProjectName = var.project_name


    # ========================================================
    # 4.2 ENVIRONMENT
    # ========================================================
    #
    # Terraform variable:
    #
    #     var.environment
    #
    # CloudFormation parameter:
    #
    #     Environment
    #
    # Example:
    #
    #     dev
    #
    # ========================================================

    Environment = var.environment


    # ========================================================
    # 4.3 CLOUDFORMATION TEMPLATE BUCKET
    # ========================================================
    #
    # This bucket is created and managed by Terraform.
    #
    # Terraform uploads:
    #
    #     main.yaml
    #     nested/vpc.yaml
    #     nested/s3.yaml
    #     nested/dynamodb.yaml
    #     nested/ecr.yaml
    #     nested/ecs.yaml
    #     nested/eks.yaml
    #     nested/ec2.yaml
    #     nested/rds.yaml
    #     nested/lambda.yaml
    #     nested/api_gateway.yaml
    #     nested/cloudfront.yaml
    #
    # CloudFormation uses this bucket to retrieve the nested
    # templates.
    #
    # ========================================================

    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket


    # ========================================================
    # 4.4 CLOUDFORMATION TEMPLATE PREFIX
    # ========================================================
    #
    # Current S3 structure:
    #
    #     main.yaml
    #     nested/vpc.yaml
    #     nested/s3.yaml
    #     nested/dynamodb.yaml
    #     ...
    #
    # main.yaml is located at the bucket root.
    #
    # Therefore no prefix is currently required.
    #
    # ========================================================

    TemplatePrefix = ""


    # ========================================================
    # 5. NETWORK PARAMETERS
    # ========================================================
    #
    # These parameters pass existing AWS networking values
    # from Terraform into CloudFormation.
    #
    # The actual IDs MUST be supplied through Terraform
    # variables.
    #
    # Example:
    #
    #     vpc-0123456789abcdef0
    #
    #     subnet-0123456789abcdef0
    #
    # ========================================================


    # --------------------------------------------------------
    # 5.1 VPC ID
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.vpc_id
    #
    # CloudFormation parameter:
    #
    #     VpcId
    #
    # Example real value:
    #
    #     vpc-0123456789abcdef0
    #
    # The actual value should come from terraform.tfvars or
    # another Terraform variable source.
    #
    # --------------------------------------------------------

    VpcId = var.vpc_id


    # --------------------------------------------------------
    # 5.2 PUBLIC SUBNET ID
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.public_subnet_id
    #
    # CloudFormation parameter:
    #
    #     PublicSubnetId
    #
    # Example:
    #
    #     subnet-0123456789abcdef0
    #
    # --------------------------------------------------------

    PublicSubnetId = var.public_subnet_id


    # --------------------------------------------------------
    # 5.3 PUBLIC SUBNET 1
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.public_subnet_1_id
    #
    # CloudFormation parameter:
    #
    #     PublicSubnet1Id
    #
    # Used for the first public Availability Zone.
    #
    # --------------------------------------------------------

    PublicSubnet1Id = var.public_subnet_1_id


    # --------------------------------------------------------
    # 5.4 PUBLIC SUBNET 2
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.public_subnet_2_id
    #
    # CloudFormation parameter:
    #
    #     PublicSubnet2Id
    #
    # Used for the second public Availability Zone.
    #
    # --------------------------------------------------------

    PublicSubnet2Id = var.public_subnet_2_id


    # --------------------------------------------------------
    # 5.5 PRIVATE SUBNET 1
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.private_subnet_1_id
    #
    # CloudFormation parameter:
    #
    #     PrivateSubnet1Id
    #
    # Used for private application/database infrastructure.
    #
    # --------------------------------------------------------

    PrivateSubnet1Id = var.private_subnet_1_id


    # --------------------------------------------------------
    # 5.6 PRIVATE SUBNET 2
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.private_subnet_2_id
    #
    # CloudFormation parameter:
    #
    #     PrivateSubnet2Id
    #
    # Provides the second private Availability Zone.
    #
    # --------------------------------------------------------

    PrivateSubnet2Id = var.private_subnet_2_id


    # ========================================================
    # 6. APPLICATION PARAMETERS
    # ========================================================


    # --------------------------------------------------------
    # 6.1 EC2 AMI ID
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.ami_id
    #
    # CloudFormation parameter:
    #
    #     AmiId
    #
    # Example:
    #
    #     ami-0123456789abcdef0
    #
    # IMPORTANT:
    #
    # The actual AMI ID is NOT hard-coded here.
    #
    # It must be supplied through:
    #
    #     var.ami_id
    #
    # --------------------------------------------------------

    AmiId = var.ami_id


    # --------------------------------------------------------
    # 6.2 APPLICATION S3 BUCKET
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.application_bucket_name
    #
    # CloudFormation parameter:
    #
    #     ApplicationBucketName
    #
    # Example:
    #
    #     my-application-bucket
    #
    # IMPORTANT:
    #
    # This must be the actual application bucket name,
    # not the CloudFormation template bucket unless your
    # architecture intentionally uses the same bucket.
    #
    # --------------------------------------------------------

    ApplicationBucketName = var.application_bucket_name


    # --------------------------------------------------------
    # 6.3 LAMBDA FUNCTION ARN
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.lambda_function_arn
    #
    # CloudFormation parameter:
    #
    #     LambdaFunctionArn
    #
    # Example:
    #
    #     arn:aws:lambda:us-east-1:537236558357:function:MyFunction
    #
    # --------------------------------------------------------

    LambdaFunctionArn = var.lambda_function_arn


    # --------------------------------------------------------
    # 6.4 ECR IMAGE URI
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.ecr_image_uri
    #
    # CloudFormation parameter:
    #
    #     EcrImageUri
    #
    # Example:
    #
    #     537236558357.dkr.ecr.us-east-1.amazonaws.com/app:latest
    #
    # IMPORTANT:
    #
    # This must point to an actual ECR image if the nested
    # CloudFormation stack uses it for ECS/container deployment.
    #
    # --------------------------------------------------------

    EcrImageUri = var.ecr_image_uri


    # ========================================================
    # 7. DATABASE PARAMETERS
    # ========================================================


    # --------------------------------------------------------
    # 7.1 DATABASE PASSWORD
    # --------------------------------------------------------
    #
    # Terraform variable:
    #
    #     var.database_password
    #
    # CloudFormation parameter:
    #
    #     DatabasePassword
    #
    # SECURITY:
    #
    # This value is sensitive.
    #
    # It should NOT be hard-coded in this file.
    #
    # Prefer AWS Secrets Manager for production workloads.
    #
    # If this Terraform variable is used:
    #
    #     variable "database_password" {
    #       sensitive = true
    #     }
    #
    # The value should also not be committed to Git.
    #
    # --------------------------------------------------------

    DatabasePassword = var.database_password
  }


  # ==========================================================
  # 8. RESOURCE DEPENDENCIES
  # ==========================================================
  #
  # Terraform normally creates dependencies automatically
  # when one resource references another.
  #
  # However, the CloudFormation root stack must explicitly
  # wait for the template objects and the CloudFormation
  # execution-role policy.
  #
  # CloudFormation should not start until:
  #
  #   1. The S3 template bucket exists.
  #
  #   2. main.yaml and nested templates have been uploaded.
  #
  #   3. The CloudFormation execution-role permissions exist.
  #
  # ==========================================================

  depends_on = [

    # --------------------------------------------------------
    # CloudFormation templates
    # --------------------------------------------------------
    #
    # Ensures that all CloudFormation template objects are
    # uploaded to S3 before the root stack is created.
    #
    # This includes main.yaml and the nested templates.
    #
    # --------------------------------------------------------

    aws_s3_object.cloudformation_templates,


    # --------------------------------------------------------
    # CloudFormation execution-role policy
    # --------------------------------------------------------
    #
    # Ensures that the IAM policy attached to the
    # CloudFormation execution role exists before the
    # CloudFormation root stack is created.
    #
    # IMPORTANT:
    #
    # This dependency controls Terraform resource creation
    # order.
    #
    # It does NOT pass role_arn to the CloudFormation stack.
    #
    # --------------------------------------------------------

    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}


# ============================================================
# END OF CLOUDFORMATION ROOT STACK
# ============================================================
#
#
# FINAL HYBRID IaC DEPLOYMENT FLOW
#
#
# Terraform
#     |
#     +-----------------------------------------+
#     |                                         |
#     v                                         v
# S3 Template Bucket                    IAM Roles/Policies
#     |                                         |
#     |                                         |
#     +-------------------+---------------------+
#                         |
#                         v
#              CloudFormation Root Stack
#                         |
#        +----------------+----------------+
#        |                |                |
#        v                v                v
#      VPC               S3            DynamoDB
#     Stack             Stack             Stack
#        |
#        +--------+---------+----------+
#        |        |         |          |
#        v        v         v          v
#       EC2      ECS       EKS        RDS
#       Stack    Stack     Stack      Stack
#
#        +-----------------------------+
#        |                             |
#        v                             v
#      Lambda                    API Gateway
#       Stack                       Stack
#
#        |
#        v
#    CloudFront
#       Stack
#
#
# ============================================================
# IMPORTANT DESIGN PRINCIPLES
# ============================================================
#
# 1. Terraform manages the orchestration layer.
#
# 2. CloudFormation manages the nested application
#    infrastructure defined by the YAML templates.
#
# 3. Terraform variables provide environment-specific
#    infrastructure values.
#
# 4. AWS resource IDs should NOT be hard-coded inside this
#    CloudFormation Terraform resource.
#
# 5. Actual values should be provided through Terraform
#    variables, preferably using terraform.tfvars or
#    dynamically discovered Terraform data/resources.
#
# 6. Sensitive values should not be committed to Git.
#
# 7. CloudFormation templates are stored in the dedicated
#    S3 template bucket managed by Terraform.
#
# 8. The GitHub Actions OIDC role is separate from the
#    CloudFormation execution role.
#
# GitHub Actions Role:
#
#     aws-hybrid-iac-lab-GitHubActions
#
# CloudFormation Execution Role:
#
#     HybridIaCLab-dev-CloudFormationExecutionRole
#
# These roles have different responsibilities and should
# remain separate.
#
# ============================================================

