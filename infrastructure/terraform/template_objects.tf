# ==========================================================
# CloudFormation Template Objects
# ==========================================================
# This file uploads all CloudFormation templates from the
# local repository into the S3 bucket created by Terraform.
#
# The bucket itself is created in:
#
#   template_bucket.tf
#
# The template file paths are defined in:
#
#   locals.tf
#
# Terraform will automatically create one S3 object for
# every entry in local.cloudformation_templates.
# ==========================================================


# ----------------------------------------------------------
# Upload CloudFormation Templates
# ----------------------------------------------------------
# for_each loops through the cloudformation_templates map
# defined in locals.tf.
#
# Example map entry:
#
#   vpc = "${path.module}/../cloudformation/nested/vpc.yaml"
#
# Terraform creates a separate aws_s3_object for each
# template in the map.
#
# This means we don't have to manually create separate
# resources for:
#
#   - main.yaml
#   - vpc.yaml
#   - ec2.yaml
#   - s3.yaml
#   - cloudfront.yaml
#   - api-gateway.yaml
#   - lambda.yaml
#   - rds.yaml
#   - dynamodb.yaml
#   - ecr.yaml
#   - ecs.yaml
#   - eks.yaml
# ----------------------------------------------------------

resource "aws_s3_object" "cloudformation_templates" {

  # --------------------------------------------------------
  # for_each
  # --------------------------------------------------------
  # Iterate over every CloudFormation template defined in
  # local.cloudformation_templates.
  #
  # Terraform creates one resource instance per map entry.
  #
  # Examples:
  #
  #   aws_s3_object.cloudformation_templates["main"]
  #   aws_s3_object.cloudformation_templates["vpc"]
  #   aws_s3_object.cloudformation_templates["ec2"]
  # --------------------------------------------------------

  for_each = local.cloudformation_templates


  # --------------------------------------------------------
  # Target S3 Bucket
  # --------------------------------------------------------
  # Upload the files into the S3 bucket created by the
  # aws_s3_bucket.cloudformation_templates resource.
  #
  # Using .id creates an implicit dependency:
  #
  #   S3 Bucket
  #       ↓
  #   S3 Objects
  #
  # Terraform therefore knows that the bucket must exist
  # before the objects can be uploaded.
  # --------------------------------------------------------

  bucket = aws_s3_bucket.cloudformation_templates.id


  # --------------------------------------------------------
  # S3 Object Key
  # --------------------------------------------------------
  # Determines where each template will be stored inside
  # the S3 bucket.
  #
  # The "main" template is stored at:
  #
  #   main.yaml
  #
  # All nested templates are stored under:
  #
  #   nested/
  #
  # For example:
  #
  #   vpc       → nested/vpc.yaml
  #   ec2       → nested/ec2.yaml
  #   lambda    → nested/lambda.yaml
  #   eks       → nested/eks.yaml
  #
  # The conditional expression:
  #
  #   condition ? value_if_true : value_if_false
  #
  # is used here.
  # --------------------------------------------------------

  key = each.key == "main" ? "main.yaml" : "nested/${basename(each.value)}"

  # --------------------------------------------------------
  # Source File
  # --------------------------------------------------------
  # each.value contains the local filesystem path to the
  # CloudFormation template.
  #
  # Example:
  #
  #   each.value
  #   ↓
  #   infrastructure/cloudformation/nested/vpc.yaml
  #
  # Terraform reads this local file and uploads it to S3.
  # --------------------------------------------------------

  source = each.value


  # --------------------------------------------------------
  # ETag / File Checksum
  # --------------------------------------------------------
  # filemd5() calculates an MD5 hash of the local template.
  #
  # Terraform uses this value to detect changes to the
  # CloudFormation template.
  #
  # Example:
  #
  # If vpc.yaml changes:
  #
  #   old filemd5 → ABC123
  #   new filemd5 → XYZ789
  #
  # Terraform detects that the file changed and updates the
  # corresponding S3 object.
  #
  # This is particularly useful for this hybrid IaC lab
  # because CloudFormation templates are maintained locally
  # but uploaded by Terraform.
  # --------------------------------------------------------

  etag = filemd5(each.value)
}