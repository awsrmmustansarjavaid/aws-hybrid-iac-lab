# ==========================================================
# IAM - CloudFormation Execution Role
# ==========================================================
# This file creates the IAM role that AWS CloudFormation will
# assume when it deploys and manages resources for this lab.
#
# Terraform is responsible for creating:
#
#   1. CloudFormation trust policy
#   2. CloudFormation execution role
#   3. CloudFormation permissions policy
#
#
# IAM CONCEPT
# ----------------------------------------------------------
#
# An IAM role has two important sides:
#
#   TRUST POLICY
#       ↓
#   Who is allowed to assume this role?
#
#   PERMISSIONS POLICY
#       ↓
#   What can the role do after it is assumed?
#
#
# In this lab:
#
#   CloudFormation
#          │
#          │ assumes
#          ▼
#   CloudFormation Execution Role
#          │
#          │ permissions
#          ▼
#   AWS Resources
#
# IMPORTANT:
# The permissions below are intentionally broad for the
# first learning version of the lab.
#
# After the complete lab works, these permissions should be
# reviewed and reduced according to the principle of
# least privilege.
# ==========================================================


# ==========================================================
# 1. CloudFormation Trust Policy
# ==========================================================
# This policy defines WHO is allowed to assume the
# CloudFormation execution role.
#
# The AWS CloudFormation service is the trusted principal.
#
# This is NOT the permissions policy.
#
# It only establishes the trust relationship:
#
#   CloudFormation
#        │
#        │ sts:AssumeRole
#        ▼
#   IAM Role
# ==========================================================

data "aws_iam_policy_document" "cloudformation_assume_role" {

  # --------------------------------------------------------
  # Trust Policy Statement
  # --------------------------------------------------------
  statement {

    # Allow the specified AWS service to assume the role.
    effect = "Allow"


    # ------------------------------------------------------
    # Trusted Principal
    # ------------------------------------------------------
    # Identifies the AWS service that can assume the role.
    #
    # CloudFormation uses this service principal:
    #
    #   cloudformation.amazonaws.com
    # ------------------------------------------------------

    principals {
      type = "Service"

      identifiers = [
        "cloudformation.amazonaws.com"
      ]
    }


    # ------------------------------------------------------
    # Assume Role Action
    # ------------------------------------------------------
    # Allows CloudFormation to request temporary credentials
    # for this IAM role through AWS Security Token Service.
    # ------------------------------------------------------

    actions = [
      "sts:AssumeRole"
    ]
  }
}


# ==========================================================
# 2. CloudFormation Execution Role
# ==========================================================
# Creates the IAM role that CloudFormation will assume while
# deploying the resources defined by the CloudFormation
# templates.
# ==========================================================

resource "aws_iam_role" "cloudformation_execution" {

  # --------------------------------------------------------
  # IAM Role Name
  # --------------------------------------------------------
  # Uses the common name prefix defined in locals.tf.
  #
  # Example:
  #
  #   HybridIaCLab-dev-CloudFormationExecutionRole
  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationExecutionRole"


  # --------------------------------------------------------
  # Trust Policy
  # --------------------------------------------------------
  # Connects this IAM role to the trust policy defined above.
  #
  # The .json attribute converts the Terraform IAM policy
  # document into the JSON format required by AWS IAM.
  # --------------------------------------------------------

  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role.json
}


# ==========================================================
# 3. CloudFormation Permissions Policy
# ==========================================================
# This inline policy defines WHAT CloudFormation is allowed
# to do after it assumes the execution role.
#
# The policy is attached directly to:
#
#   aws_iam_role.cloudformation_execution
#
#
# IMPORTANT:
# This policy is intentionally broad for the first version
# of the learning lab.
#
# Later, after everything is working, we should reduce these
# permissions to the minimum required by the actual
# CloudFormation templates.
# ==========================================================

resource "aws_iam_role_policy" "cloudformation_lab_permissions" {

  # --------------------------------------------------------
  # Policy Name
  # --------------------------------------------------------
  # Creates a predictable policy name.
  #
  # Example:
  #
  #   HybridIaCLab-dev-CloudFormationPermissions
  # --------------------------------------------------------

  name = "${local.name_prefix}-CloudFormationPermissions"


  # --------------------------------------------------------
  # Role
  # --------------------------------------------------------
  # Attaches this inline policy to the CloudFormation
  # execution role created above.
  # --------------------------------------------------------

  role = aws_iam_role.cloudformation_execution.id


  # --------------------------------------------------------
  # IAM Permissions Policy
  # --------------------------------------------------------
  # jsonencode() converts the Terraform object into valid
  # IAM JSON.
  #
  # Using jsonencode() keeps the policy inside Terraform
  # without requiring a separate JSON file.
  # --------------------------------------------------------

  policy = jsonencode({

    # ------------------------------------------------------
    # IAM Policy Language Version
    # ------------------------------------------------------
    Version = "2012-10-17"


    # ======================================================
    # Permission Statements
    # ======================================================
    # Each statement groups permissions for related AWS
    # services.
    # ======================================================

    Statement = [

      # ====================================================
      # EC2 / Load Balancing / Auto Scaling / PassRole
      # ====================================================
      # Supports infrastructure such as:
      #
      #   - VPC resources
      #   - Subnets
      #   - Route tables
      #   - Internet gateways
      #   - NAT gateways
      #   - Security groups
      #   - EC2 instances
      #   - Elastic Load Balancers
      #   - Target groups
      #   - Auto Scaling groups
      #
      # iam:PassRole allows CloudFormation to pass an IAM role
      # to supported AWS services when required.
      #
      # IMPORTANT:
      # iam:PassRole should be restricted later.
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "iam:PassRole"
        ]

        Resource = "*"
      },


      # ====================================================
      # S3 / CloudFront
      # ====================================================
      # Supports:
      #
      #   - S3 buckets
      #   - S3 bucket configuration
      #   - S3 objects
      #   - CloudFront distributions
      #   - CloudFront configuration
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "s3:*",
          "cloudfront:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # Lambda / API Gateway
      # ====================================================
      # Supports serverless resources such as:
      #
      #   - Lambda functions
      #   - Lambda configurations
      #   - API Gateway REST APIs
      #   - API Gateway resources
      #   - API Gateway methods
      #   - API Gateway integrations
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "lambda:*",
          "apigateway:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # RDS / DynamoDB
      # ====================================================
      # Supports database resources such as:
      #
      #   - RDS instances
      #   - RDS subnet groups
      #   - RDS parameter groups
      #   - DynamoDB tables
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "rds:*",
          "dynamodb:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # ECR / ECS / EKS
      # ====================================================
      # Supports container-related resources such as:
      #
      #   - ECR repositories
      #   - ECS clusters
      #   - ECS services
      #   - ECS task-related resources
      #   - EKS clusters
      #
      # IMPORTANT:
      # ECS and EKS deployments can require additional IAM
      # permissions, service-linked roles, networking
      # permissions, and supporting AWS resources.
      #
      # We will handle those requirements when implementing
      # the ECS and EKS CloudFormation stacks.
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "ecr:*",
          "ecs:*",
          "eks:*"
        ]

        Resource = "*"
      },


      # ====================================================
      # CloudWatch Logs
      # ====================================================
      # Supports CloudWatch Logs resources used by services
      # such as Lambda, ECS, and other workloads.
      # ====================================================

      {
        Effect = "Allow"

        Action = [
          "logs:*"
        ]

        Resource = "*"
      }
    ]
  })
}

