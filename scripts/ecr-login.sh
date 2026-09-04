#!/bin/bash

# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# Amazon ECR Login Script
# ==========================================================

set -e

# ----------------------------------------------------------
# Configuration
# ----------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-1}"


# ----------------------------------------------------------
# Get AWS account ID
# ----------------------------------------------------------

ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text)


# ----------------------------------------------------------
# Build ECR registry URL
# ----------------------------------------------------------

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"


# ----------------------------------------------------------
# Login to ECR
# ----------------------------------------------------------

echo ""
echo ">>> Logging into Amazon ECR..."

aws ecr get-login-password \
    --region "$AWS_REGION" \
    | docker login \
        --username AWS \
        --password-stdin "$ECR_REGISTRY"


echo ""
echo "=================================================="
echo " ECR login successful"
echo "=================================================="

echo ""
echo "Registry:"
echo "$ECR_REGISTRY"