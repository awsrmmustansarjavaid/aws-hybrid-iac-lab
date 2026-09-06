# ============================================================
# Bootstrap Outputs
# ============================================================


# ------------------------------------------------------------
# Terraform State Bucket Name
# ------------------------------------------------------------
output "terraform_state_bucket_name" {

  description = "Name of the Terraform remote state bucket."

  value = aws_s3_bucket.terraform_state.bucket
}


# ------------------------------------------------------------
# Terraform State Bucket ARN
# ------------------------------------------------------------
output "terraform_state_bucket_arn" {

  description = "ARN of the Terraform remote state bucket."

  value = aws_s3_bucket.terraform_state.arn
}

