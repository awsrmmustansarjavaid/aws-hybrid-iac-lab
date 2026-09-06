#!/usr/bin/env bash

# ============================================================
# Terraform State Bucket Bootstrap
# ============================================================
#
# File:
#   scripts/bootstrap-terraform-state.sh
#
# Purpose:
#   Create and verify the S3 bucket used by Terraform
#   as its remote state backend.
#
# Project:
#   aws-hybrid-iac-lab
#
# ============================================================

# Exit immediately if:
# - a command fails (-e)
# - an undefined variable is used (-u)
# - any command inside a pipeline fails (-o pipefail)
set -euo pipefail


# ============================================================
# Configuration
# ============================================================

# AWS region used by this lab.
AWS_REGION="us-east-1"

# Terraform state bucket.
#
# IMPORTANT:
# This must match the bucket name configured in:
#
# infrastructure/terraform/backend.tf
#
STATE_BUCKET="aws-hybrid-iac-lab-terraform-state-537236558357"

# Root directory of the Git repository.
#
# This assumes this script is located at:
#
# scripts/bootstrap-terraform-state.sh
#
# Therefore:
#
# scripts/
#    bootstrap-terraform-state.sh
#
# The repository root is one directory above scripts/.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Dedicated Terraform bootstrap directory.
BOOTSTRAP_DIR="$REPO_ROOT/infrastructure/bootstrap/terraform-state"


# ============================================================
# Helper functions
# ============================================================

# Print a section heading.
print_header() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo
}


# Print an informational message.
info() {
    echo "[INFO] $1"
}


# Print a success message.
success() {
    echo "[SUCCESS] $1"
}


# Print an error message and stop the script.
error() {
    echo "[ERROR] $1"
    exit 1
}


# ============================================================
# Step 1 — Check required commands
# ============================================================

print_header "Step 1 — Checking required commands"

# Check AWS CLI.
if ! command -v aws >/dev/null 2>&1; then
    error "AWS CLI is not installed or is not available in PATH."
fi

# Check Terraform.
if ! command -v terraform >/dev/null 2>&1; then
    error "Terraform is not installed or is not available in PATH."
fi

success "AWS CLI found."
success "Terraform found."


# ============================================================
# Step 2 — Check AWS authentication
# ============================================================

print_header "Step 2 — Checking AWS credentials"

# Ask AWS who we are.
#
# This confirms that the AWS CLI has valid credentials.
aws sts get-caller-identity >/dev/null

success "AWS authentication is working."


# ============================================================
# Step 3 — Check whether the state bucket already exists
# ============================================================

print_header "Step 3 — Checking Terraform state bucket"

info "Checking bucket:"
echo "$STATE_BUCKET"
echo

# head-bucket returns success if the bucket exists
# and the current AWS identity can access it.
#
# We intentionally do not stop the script if this command
# fails because a missing bucket is expected during the
# initial bootstrap.
if aws s3api head-bucket \
    --bucket "$STATE_BUCKET" \
    --region "$AWS_REGION" \
    >/dev/null 2>&1; then

    success "Terraform state bucket already exists."

    echo
    echo "Bucket:"
    echo "$STATE_BUCKET"

    echo
    echo "The bootstrap bucket does not need to be created again."

    exit 0

else

    info "Terraform state bucket does not currently exist."
    info "This is expected for the first bootstrap."

fi


# ============================================================
# Step 4 — Check bootstrap Terraform directory
# ============================================================

print_header "Step 4 — Checking bootstrap Terraform directory"

if [[ ! -d "$BOOTSTRAP_DIR" ]]; then
    error "Bootstrap Terraform directory was not found:

$BOOTSTRAP_DIR"
fi

success "Bootstrap Terraform directory found."

echo "$BOOTSTRAP_DIR"


# ============================================================
# Step 5 — Initialize bootstrap Terraform
# ============================================================

print_header "Step 5 — Initializing bootstrap Terraform"

# Move into the dedicated bootstrap directory.
cd "$BOOTSTRAP_DIR"

# Initialize Terraform.
#
# This prepares the bootstrap configuration and downloads
# the required Terraform provider(s).
terraform init

success "Bootstrap Terraform initialized."


# ============================================================
# Step 6 — Validate Terraform configuration
# ============================================================

print_header "Step 6 — Validating bootstrap Terraform"

# Validate Terraform syntax and configuration.
terraform validate

success "Terraform configuration is valid."


# ============================================================
# Step 7 — Generate Terraform plan
# ============================================================

print_header "Step 7 — Creating Terraform plan"

# Create the execution plan.
#
# We save the plan to a file so that the exact plan we approve
# can be applied later.
terraform plan -out=tfplan

success "Terraform plan created."

echo
echo "Review the plan above carefully."
echo


# ============================================================
# Step 8 — Ask for confirmation
# ============================================================

print_header "Step 8 — Confirm Terraform apply"

echo "The bootstrap Terraform plan is ready."
echo
echo "Expected resources should be approximately:"
echo
echo "  4 to add"
echo "  0 to change"
echo "  0 to destroy"
echo

read -r -p "Do you want to apply this Terraform plan? Type yes to continue: " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo
    info "Terraform apply cancelled."
    echo
    echo "The plan has NOT been applied."
    exit 0
fi


# ============================================================
# Step 9 — Apply Terraform plan
# ============================================================

print_header "Step 9 — Creating Terraform state bucket"

# Apply the exact plan that was reviewed above.
terraform apply tfplan

success "Terraform bootstrap completed."


# ============================================================
# Step 10 — Verify bucket exists
# ============================================================

print_header "Step 10 — Verifying Terraform state bucket"

aws s3api head-bucket \
    --bucket "$STATE_BUCKET" \
    --region "$AWS_REGION"

success "Terraform state bucket exists."


# ============================================================
# Step 11 — Verify versioning
# ============================================================

print_header "Step 11 — Verifying S3 bucket versioning"

aws s3api get-bucket-versioning \
    --bucket "$STATE_BUCKET" \
    --region "$AWS_REGION"

success "Versioning verification completed."


# ============================================================
# Step 12 — Verify encryption
# ============================================================

print_header "Step 12 — Verifying S3 bucket encryption"

aws s3api get-bucket-encryption \
    --bucket "$STATE_BUCKET" \
    --region "$AWS_REGION"

success "Encryption verification completed."


# ============================================================
# Step 13 — Verify public access block
# ============================================================

print_header "Step 13 — Verifying S3 public access block"

aws s3api get-public-access-block \
    --bucket "$STATE_BUCKET" \
    --region "$AWS_REGION"

success "Public access block verification completed."


# ============================================================
# Step 14 — Final result
# ============================================================

print_header "Terraform State Bootstrap Completed"

echo "Terraform state bucket:"
echo
echo "  $STATE_BUCKET"
echo
echo "AWS Region:"
echo
echo "  $AWS_REGION"
echo
echo "Bootstrap directory:"
echo
echo "  $BOOTSTRAP_DIR"
echo

echo "Next step:"
echo
echo "Initialize your MAIN Terraform configuration:"
echo
echo "  terraform -chdir=\"infrastructure/terraform\" init"
echo

echo "Then check Terraform state:"
echo
echo "  terraform -chdir=\"infrastructure/terraform\" state list"
echo

echo "IMPORTANT:"
echo
echo "Do NOT run GitHub Actions yet."
echo
echo "Existing AWS resources may still need to be imported"
echo "into the new Terraform remote state."
echo

success "Bootstrap process finished successfully."