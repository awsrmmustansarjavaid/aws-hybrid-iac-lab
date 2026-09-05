# ============================================================
# Terraform State Bucket Name
# ============================================================
# This output displays the name of the S3 bucket that Terraform
# created for storing remote Terraform state.
#
# You can see this value after running:
#
# terraform apply
#
# Or later with:
#
# terraform output terraform_state_bucket_name
output "terraform_state_bucket_name" {

  # Explains what this output represents.
  description = "Name of the S3 bucket used for Terraform remote state."

  # Get the bucket name from the S3 bucket resource.
  #
  # aws_s3_bucket.terraform_state
  #     -> The S3 bucket resource defined in main.tf
  #
  # .bucket
  #     -> The actual S3 bucket name
  value = aws_s3_bucket.terraform_state.bucket
}


# ============================================================
# Terraform State Bucket ARN
# ============================================================
# This output displays the Amazon Resource Name (ARN) of the
# Terraform state S3 bucket.
#
# An ARN uniquely identifies an AWS resource.
#
# Example format:
# arn:aws:s3:::your-terraform-state-bucket
output "terraform_state_bucket_arn" {

  # Explains what this output represents.
  description = "ARN of the Terraform remote state S3 bucket."

  # Get the ARN from the S3 bucket resource.
  #
  # aws_s3_bucket.terraform_state
  #     -> The S3 bucket resource defined in main.tf
  #
  # .arn
  #     -> The bucket's Amazon Resource Name
  value = aws_s3_bucket.terraform_state.arn
}