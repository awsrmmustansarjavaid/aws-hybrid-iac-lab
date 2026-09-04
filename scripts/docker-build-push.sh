#!/bin/bash

# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# Docker Build + ECR Push
# ==========================================================

set -e


# ----------------------------------------------------------
# Configuration
# ----------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-1}"

PROJECT_NAME="${PROJECT_NAME:-HybridIaCLab}"

ENVIRONMENT="${ENVIRONMENT:-dev}"

IMAGE_NAME="hybrid-iac-app"


# ----------------------------------------------------------
# Get AWS account ID
# ----------------------------------------------------------

ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text)


# ----------------------------------------------------------
# ECR repository
# ----------------------------------------------------------

ECR_REPOSITORY="${PROJECT_NAME}-${ENVIRONMENT}-app"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

ECR_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}"


# ----------------------------------------------------------
# Display configuration
# ----------------------------------------------------------

echo ""
echo "=================================================="
echo " Docker Build + ECR Push"
echo "=================================================="

echo ""
echo "AWS Region     : $AWS_REGION"
echo "AWS Account    : $ACCOUNT_ID"
echo "ECR Repository : $ECR_REPOSITORY"
echo "ECR URI        : $ECR_URI"


# ----------------------------------------------------------
# Login to ECR
# ----------------------------------------------------------

echo ""
echo ">>> Logging into ECR..."

aws ecr get-login-password \
    --region "$AWS_REGION" \
    | docker login \
        --username AWS \
        --password-stdin "$ECR_REGISTRY"


# ----------------------------------------------------------
# Create unique image tag
# ----------------------------------------------------------
#
# Using the Git commit SHA is better for CI/CD because
# every image can be traced back to a specific version.
#
# ----------------------------------------------------------

if [ -n "${GITHUB_SHA:-}" ]; then

    IMAGE_TAG="${GITHUB_SHA}"

else

    IMAGE_TAG="$(date +%Y%m%d-%H%M%S)"

fi


# ----------------------------------------------------------
# Build Docker image
# ----------------------------------------------------------

echo ""
echo ">>> Building Docker image..."

cd "$(dirname "$0")/../docker/app"

docker build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    .


# ----------------------------------------------------------
# Tag image for ECR
# ----------------------------------------------------------

echo ""
echo ">>> Tagging image..."

docker tag \
    "${IMAGE_NAME}:${IMAGE_TAG}" \
    "${ECR_URI}:${IMAGE_TAG}"


# ----------------------------------------------------------
# Push image
# ----------------------------------------------------------

echo ""
echo ">>> Pushing image to ECR..."

docker push \
    "${ECR_URI}:${IMAGE_TAG}"


echo ""
echo "=================================================="
echo " Docker image pushed successfully"
echo "=================================================="

echo ""
echo "Image:"
echo "${ECR_URI}:${IMAGE_TAG}"