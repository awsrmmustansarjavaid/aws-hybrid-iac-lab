# ==========================================================
# Terraform Local Values
# ==========================================================
# Local values allow us to define reusable values once and
# reference them throughout the Terraform configuration.
#
# In this hybrid lab, locals.tf is mainly used for:
#
#   1. Creating a consistent resource name prefix
#   2. Defining paths to CloudFormation templates
#
# Local values are referenced using:
#
#   local.<name>
#
# Example:
#
#   local.name_prefix
#   local.cloudformation_templates.vpc
# ==========================================================


locals {

  # --------------------------------------------------------
  # Common Resource Name Prefix
  # --------------------------------------------------------
  # Creates a consistent prefix using the project name and
  # deployment environment.
  #
  # Example:
  #
  #   project_name = "HybridIaCLab"
  #   environment  = "dev"
  #
  # Result:
  #
  #   HybridIaCLab-dev
  #
  # This can be used when naming AWS resources so that it is
  # easy to identify which project and environment they
  # belong to.
  # --------------------------------------------------------

  name_prefix = "${var.project_name}-${var.environment}"


  # --------------------------------------------------------
  # CloudFormation Template Paths
  # --------------------------------------------------------
  # This map contains the paths to the CloudFormation
  # templates used by the hybrid IaC lab.
  #
  # Terraform can reference these paths later when creating
  # AWS CloudFormation stacks.
  #
  # The paths are based on:
  #
  #   path.module
  #
  # path.module represents the directory containing the
  # current Terraform module.
  #
  # Because the CloudFormation templates are stored outside
  # the Terraform directory, "../" is used to move one level
  # up before entering the cloudformation directory.
  # --------------------------------------------------------

  cloudformation_templates = {

    # ------------------------------------------------------
    # Main CloudFormation Template
    # ------------------------------------------------------
    # Main CloudFormation orchestration template.
    # ------------------------------------------------------

    main = "${path.module}/../cloudformation/main.yaml"


    # ------------------------------------------------------
    # VPC Template
    # ------------------------------------------------------
    # CloudFormation nested template responsible for the
    # VPC/network infrastructure.
    # ------------------------------------------------------

    vpc = "${path.module}/../cloudformation/nested/vpc.yaml"


    # ------------------------------------------------------
    # EC2 Template
    # ------------------------------------------------------
    # CloudFormation nested template for EC2 resources.
    # ------------------------------------------------------

    ec2 = "${path.module}/../cloudformation/nested/ec2.yaml"


    # ------------------------------------------------------
    # S3 Template
    # ------------------------------------------------------
    # CloudFormation nested template for S3 resources.
    # ------------------------------------------------------

    s3 = "${path.module}/../cloudformation/nested/s3.yaml"


    # ------------------------------------------------------
    # CloudFront Template
    # ------------------------------------------------------
    # CloudFormation nested template for CloudFront.
    # ------------------------------------------------------

    cloudfront = "${path.module}/../cloudformation/nested/cloudfront.yaml"


    # ------------------------------------------------------
    # API Gateway Template
    # ------------------------------------------------------
    # CloudFormation nested template for API Gateway.
    # ------------------------------------------------------

    api_gateway = "${path.module}/../cloudformation/nested/api-gateway.yaml"


    # ------------------------------------------------------
    # Lambda Template
    # ------------------------------------------------------
    # CloudFormation nested template for AWS Lambda.
    # ------------------------------------------------------

    lambda = "${path.module}/../cloudformation/nested/lambda.yaml"


    # ------------------------------------------------------
    # RDS Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon RDS.
    # ------------------------------------------------------

    rds = "${path.module}/../cloudformation/nested/rds.yaml"


    # ------------------------------------------------------
    # DynamoDB Template
    # ------------------------------------------------------
    # CloudFormation nested template for DynamoDB.
    # ------------------------------------------------------

    dynamodb = "${path.module}/../cloudformation/nested/dynamodb.yaml"


    # ------------------------------------------------------
    # ECR Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon ECR.
    # ------------------------------------------------------

    ecr = "${path.module}/../cloudformation/nested/ecr.yaml"


    # ------------------------------------------------------
    # ECS Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon ECS.
    # ------------------------------------------------------

    ecs = "${path.module}/../cloudformation/nested/ecs.yaml"


    # ------------------------------------------------------
    # EKS Template
    # ------------------------------------------------------
    # CloudFormation nested template for Amazon EKS.
    # ------------------------------------------------------

    eks = "${path.module}/../cloudformation/nested/eks.yaml"
  }
}