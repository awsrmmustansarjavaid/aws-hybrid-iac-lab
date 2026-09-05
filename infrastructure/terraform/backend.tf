terraform {
  backend "s3" {
    # S3 bucket where Terraform stores the remote state file.
    # This bucket should already exist before running Terraform init.
    bucket = "aws-hybrid-iac-lab-terraform-state-537236558357"

    # Path and filename of the Terraform state file inside the S3 bucket.
    # "dev" keeps the state organized for the development environment.
    key = "aws-hybrid-iac-lab/dev/terraform.tfstate"

    # AWS Region where the S3 state bucket is located.
    region = "us-east-1"

    # Encrypts the Terraform state file while it is stored in S3.
    # This helps protect sensitive information contained in the state.
    encrypt = true

    # Enables Terraform's native S3 state locking mechanism.
    # This prevents multiple Terraform operations from modifying
    # the same state at the same time.
    use_lockfile = true
  }
}