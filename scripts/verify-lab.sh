#!/usr/bin/env bash

# ==========================================================
# Charlie Cafe - AWS CloudFormation + Docker Verification
# ==========================================================
#
# File:
#   scripts/verify-lab.sh
#
# Purpose:
#   Verify the important resources created by the lab.
#
# This script checks:
#
#   1. AWS CLI
#   2. AWS authentication
#   3. CloudFormation Template Bucket stack
#   4. Main CloudFormation stack
#   5. CloudFormation resources
#   6. VPC
#   7. Subnets
#   8. EC2
#   9. S3
#  10. RDS
#  11. Secrets Manager
#  12. ECR
#  13. ECS
#  14. ALB
#  15. Docker
#  16. Docker Compose
#  17. Docker image
#  18. Docker container
#  19. HTTP application test
#  20. Docker logs
#
# IMPORTANT:
#
# This script DOES NOT display:
#
#   - RDS passwords
#   - Secrets Manager secret values
#   - AWS access keys
#
# ==========================================================


# ==========================================================
# 1. SCRIPT SAFETY
# ==========================================================

# Exit when a command fails.
#
# We do NOT use "set -e" because this verification script
# needs to continue checking other resources even when one
# verification test fails.
#
set -u


# ==========================================================
# 2. LAB CONFIGURATION
# ==========================================================
#
# Change these values if your lab uses different names.
#
# ==========================================================

AWS_REGION="us-east-1"

# Main CloudFormation stack.
STACK_NAME="Lab01-CloudFormation"

# Template bucket CloudFormation stack.
TEMPLATE_BUCKET_STACK="Lab01-CloudFormation-TemplateBucket"

# Docker image name.
DOCKER_IMAGE="charlie-cafe:latest"

# Docker container name.
DOCKER_CONTAINER="charlie-cafe-container"

# Local application URL.
APPLICATION_URL="http://localhost:8080"


# ==========================================================
# 3. VERIFICATION COUNTERS
# ==========================================================

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0


# ==========================================================
# 4. COLOUR / OUTPUT FUNCTIONS
# ==========================================================
#
# These functions make the verification report easier to
# read.
#
# ==========================================================

pass_test() {

    echo "  [PASS] $1"

    PASS_COUNT=$((PASS_COUNT + 1))
}


fail_test() {

    echo "  [FAIL] $1"

    FAIL_COUNT=$((FAIL_COUNT + 1))
}


skip_test() {

    echo "  [SKIP] $1"

    SKIP_COUNT=$((SKIP_COUNT + 1))
}


section() {

    echo ""
    echo "=========================================================="
    echo "$1"
    echo "=========================================================="
}


# ==========================================================
# 5. START VERIFICATION
# ==========================================================

clear 2>/dev/null || true

echo ""
echo "=========================================================="
echo " Charlie Cafe AWS + Docker Lab Verification"
echo "=========================================================="
echo ""
echo "AWS Region       : $AWS_REGION"
echo "Main Stack       : $STACK_NAME"
echo "Docker Image     : $DOCKER_IMAGE"
echo "Docker Container : $DOCKER_CONTAINER"
echo "Application URL  : $APPLICATION_URL"
echo ""


# ==========================================================
# 6. VERIFY AWS CLI
# ==========================================================

section "1. AWS CLI Verification"

if command -v aws >/dev/null 2>&1; then

    AWS_VERSION=$(aws --version 2>&1)

    echo "AWS CLI:"
    echo "$AWS_VERSION"

    pass_test "AWS CLI is installed."

else

    fail_test "AWS CLI is not installed."

fi


# ==========================================================
# 7. VERIFY AWS AUTHENTICATION
# ==========================================================

section "2. AWS Authentication Verification"

if aws sts get-caller-identity \
    --region "$AWS_REGION" \
    --no-cli-pager >/tmp/charlie-cafe-identity.json 2>/dev/null
then

    echo "AWS Account Information:"

    cat /tmp/charlie-cafe-identity.json

    pass_test "AWS authentication is working."

else

    fail_test "AWS authentication failed."

fi


# ==========================================================
# 8. VERIFY TEMPLATE BUCKET STACK
# ==========================================================

section "3. Template Bucket CloudFormation Stack"

TEMPLATE_BUCKET_STATUS=$(

    aws cloudformation describe-stacks \
        --stack-name "$TEMPLATE_BUCKET_STACK" \
        --region "$AWS_REGION" \
        --query "Stacks[0].StackStatus" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ "$TEMPLATE_BUCKET_STATUS" = "CREATE_COMPLETE" ] ||
   [ "$TEMPLATE_BUCKET_STATUS" = "UPDATE_COMPLETE" ]
then

    echo "Stack Status: $TEMPLATE_BUCKET_STATUS"

    pass_test "Template bucket CloudFormation stack is healthy."

else

    if [ -z "$TEMPLATE_BUCKET_STATUS" ] ||
       [ "$TEMPLATE_BUCKET_STATUS" = "None" ]
    then

        fail_test "Template bucket stack was not found."

    else

        fail_test "Template bucket stack status is $TEMPLATE_BUCKET_STATUS."

    fi

fi


# ==========================================================
# 9. GET TEMPLATE BUCKET NAME
# ==========================================================

section "4. Template S3 Bucket"

TEMPLATE_BUCKET=$(

    aws cloudformation describe-stacks \
        --stack-name "$TEMPLATE_BUCKET_STACK" \
        --region "$AWS_REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='BucketName'].OutputValue" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ -n "$TEMPLATE_BUCKET" ] &&
   [ "$TEMPLATE_BUCKET" != "None" ]
then

    echo "Template Bucket: $TEMPLATE_BUCKET"

    if aws s3api head-bucket \
        --bucket "$TEMPLATE_BUCKET" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
    then

        pass_test "Template S3 bucket exists."

    else

        fail_test "Template S3 bucket cannot be accessed."

    fi

else

    fail_test "Template bucket name could not be retrieved."

fi


# ==========================================================
# 10. VERIFY MAIN CLOUDFORMATION STACK
# ==========================================================

section "5. Main CloudFormation Stack"

MAIN_STACK_STATUS=$(

    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query "Stacks[0].StackStatus" \
        --output text \
        --no-cli-pager 2>/dev/null

)

echo "Stack Status: $MAIN_STACK_STATUS"

case "$MAIN_STACK_STATUS" in

    CREATE_COMPLETE|UPDATE_COMPLETE)

        pass_test "Main CloudFormation stack is healthy."

        ;;

    *)

        fail_test "Main CloudFormation stack is not in a successful state."

        ;;

esac


# ==========================================================
# 11. DISPLAY MAIN STACK RESOURCES
# ==========================================================

section "6. CloudFormation Resources"

if [ "$MAIN_STACK_STATUS" = "CREATE_COMPLETE" ] ||
   [ "$MAIN_STACK_STATUS" = "UPDATE_COMPLETE" ]
then

    echo "Resources created by the main stack:"
    echo ""

    aws cloudformation list-stack-resources \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --no-cli-pager

    pass_test "CloudFormation resources were successfully retrieved."

else

    skip_test "CloudFormation resources because the main stack is unhealthy."

fi


# ==========================================================
# 12. VERIFY VPC
# ==========================================================

section "7. VPC Verification"

VPC_ID=$(

    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='VPCId'].OutputValue" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ -n "$VPC_ID" ] &&
   [ "$VPC_ID" != "None" ]
then

    echo "VPC ID: $VPC_ID"

    VPC_STATE=$(

        aws ec2 describe-vpcs \
            --vpc-ids "$VPC_ID" \
            --region "$AWS_REGION" \
            --query "Vpcs[0].State" \
            --output text \
            --no-cli-pager

    )

    echo "VPC State: $VPC_STATE"

    if [ "$VPC_STATE" = "available" ]; then

        pass_test "VPC is available."

    else

        fail_test "VPC is not available."

    fi

else

    fail_test "VPC ID could not be retrieved."

fi


# ==========================================================
# 13. VERIFY SUBNETS
# ==========================================================

section "8. Subnet Verification"

SUBNET_COUNT=$(

    aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --region "$AWS_REGION" \
        --query "length(Subnets)" \
        --output text \
        --no-cli-pager 2>/dev/null

)

echo "Subnets found: $SUBNET_COUNT"

if [ "$SUBNET_COUNT" -ge 4 ]; then

    pass_test "Expected public/private subnet architecture exists."

else

    fail_test "Expected subnet count was not found."

fi


# ==========================================================
# 14. VERIFY EC2
# ==========================================================

section "9. EC2 Verification"

EC2_ID=$(

    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='EC2InstanceId'].OutputValue" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ -n "$EC2_ID" ] &&
   [ "$EC2_ID" != "None" ]
then

    EC2_STATE=$(

        aws ec2 describe-instances \
            --instance-ids "$EC2_ID" \
            --region "$AWS_REGION" \
            --query "Reservations[0].Instances[0].State.Name" \
            --output text \
            --no-cli-pager

    )

    echo "EC2 Instance: $EC2_ID"
    echo "EC2 State:    $EC2_STATE"

    if [ "$EC2_STATE" = "running" ]; then

        pass_test "EC2 instance is running."

    else

        fail_test "EC2 instance is not running."

    fi

else

    fail_test "EC2 instance ID could not be retrieved."

fi


# ==========================================================
# 15. VERIFY S3
# ==========================================================

section "10. S3 Verification"

if [ -n "${TEMPLATE_BUCKET:-}" ] &&
   [ "$TEMPLATE_BUCKET" != "None" ]
then

    if aws s3 ls "s3://$TEMPLATE_BUCKET/templates/" \
        --region "$AWS_REGION" \
        >/dev/null 2>&1
    then

        echo "CloudFormation templates found in S3."

        aws s3 ls \
            "s3://$TEMPLATE_BUCKET/templates/" \
            --region "$AWS_REGION"

        pass_test "S3 template bucket is accessible."

    else

        fail_test "S3 template directory could not be accessed."

    fi

else

    skip_test "S3 verification because bucket name was unavailable."

fi


# ==========================================================
# 16. VERIFY RDS
# ==========================================================

section "11. RDS Verification"

RDS_ID=$(

    aws rds describe-db-instances \
        --region "$AWS_REGION" \
        --query "DBInstances[0].DBInstanceIdentifier" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ -n "$RDS_ID" ] &&
   [ "$RDS_ID" != "None" ]
then

    RDS_STATUS=$(

        aws rds describe-db-instances \
            --db-instance-identifier "$RDS_ID" \
            --region "$AWS_REGION" \
            --query "DBInstances[0].DBInstanceStatus" \
            --output text \
            --no-cli-pager

    )

    echo "RDS Instance: $RDS_ID"
    echo "RDS Status:   $RDS_STATUS"

    if [ "$RDS_STATUS" = "available" ]; then

        pass_test "RDS database is available."

    else

        fail_test "RDS database is not available."

    fi

else

    fail_test "RDS database was not found."

fi


# ==========================================================
# 17. VERIFY SECRETS MANAGER
# ==========================================================
#
# We ONLY verify that the secret exists.
#
# We NEVER retrieve SecretString.
#
# ==========================================================

section "12. Secrets Manager Verification"

SECRET_COUNT=$(

    aws secretsmanager list-secrets \
        --region "$AWS_REGION" \
        --query "length(SecretList)" \
        --output text \
        --no-cli-pager 2>/dev/null

)

echo "Secrets found: $SECRET_COUNT"

if [ "$SECRET_COUNT" -gt 0 ]; then

    pass_test "Secrets Manager contains secrets."

else

    fail_test "No Secrets Manager secrets were found."

fi


# ==========================================================
# 18. VERIFY ECR
# ==========================================================

section "13. ECR Verification"

ECR_REPOSITORIES=$(

    aws ecr describe-repositories \
        --region "$AWS_REGION" \
        --query "repositories[].repositoryName" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ -n "$ECR_REPOSITORIES" ]; then

    echo "ECR repositories:"
    echo "$ECR_REPOSITORIES"

    pass_test "ECR repository exists."

else

    fail_test "No ECR repository was found."

fi


# ==========================================================
# 19. VERIFY ECS
# ==========================================================

section "14. ECS Verification"

ECS_CLUSTERS=$(

    aws ecs list-clusters \
        --region "$AWS_REGION" \
        --query "clusterArns[]" \
        --output text \
        --no-cli-pager 2>/dev/null

)

if [ -n "$ECS_CLUSTERS" ]; then

    echo "ECS clusters:"
    echo "$ECS_CLUSTERS"

    pass_test "ECS cluster exists."

else

    fail_test "No ECS cluster was found."

fi


# ==========================================================
# 20. VERIFY ALB
# ==========================================================

section "15. Application Load Balancer Verification"

ALB_COUNT=$(

    aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query "length(LoadBalancers)" \
        --output text \
        --no-cli-pager 2>/dev/null

)

echo "ALB count: $ALB_COUNT"

if [ "$ALB_COUNT" -gt 0 ]; then

    pass_test "Application Load Balancer exists."

else

    fail_test "Application Load Balancer was not found."

fi


# ==========================================================
# 21. VERIFY DOCKER
# ==========================================================

section "16. Docker Verification"

if command -v docker >/dev/null 2>&1; then

    docker --version

    pass_test "Docker is installed."

else

    fail_test "Docker is not installed."

fi


# ==========================================================
# 22. VERIFY DOCKER COMPOSE
# ==========================================================

section "17. Docker Compose Verification"

if docker compose version >/dev/null 2>&1; then

    docker compose version

    pass_test "Docker Compose is available."

else

    fail_test "Docker Compose is not available."

fi


# ==========================================================
# 23. VERIFY DOCKER IMAGE
# ==========================================================

section "18. Docker Image Verification"

if docker image inspect "$DOCKER_IMAGE" \
    >/dev/null 2>&1
then

    echo "Docker Image:"
    docker image inspect "$DOCKER_IMAGE" \
        --format='Repository={{.RepoTags}} ImageID={{.Id}}'

    pass_test "Charlie Cafe Docker image exists."

else

    fail_test "Charlie Cafe Docker image does not exist."

fi


# ==========================================================
# 24. VERIFY DOCKER CONTAINER
# ==========================================================

section "19. Docker Container Verification"

if docker inspect "$DOCKER_CONTAINER" \
    >/dev/null 2>&1
then

    CONTAINER_STATUS=$(

        docker inspect \
            --format='{{.State.Status}}' \
            "$DOCKER_CONTAINER"

    )

    echo "Container: $DOCKER_CONTAINER"
    echo "Status:    $CONTAINER_STATUS"

    if [ "$CONTAINER_STATUS" = "running" ]; then

        pass_test "Docker container is running."

    else

        fail_test "Docker container exists but is not running."

    fi

else

    fail_test "Docker container does not exist."

fi


# ==========================================================
# 25. VERIFY HTTP APPLICATION
# ==========================================================

section "20. HTTP Application Verification"

echo "Testing:"
echo "$APPLICATION_URL"
echo ""

if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 10 \
    "$APPLICATION_URL" \
    >/tmp/charlie-cafe-response.html
then

    pass_test "Charlie Cafe application returned HTTP response."

    echo ""
    echo "Application response preview:"
    echo ""

    head -n 20 /tmp/charlie-cafe-response.html

else

    fail_test "Charlie Cafe application did not respond successfully."

fi


# ==========================================================
# 26. VERIFY HTTP STATUS CODE
# ==========================================================

section "21. HTTP Status Code Verification"

HTTP_STATUS=$(

    curl \
        --silent \
        --output /dev/null \
        --write-out "%{http_code}" \
        --max-time 10 \
        "$APPLICATION_URL"

)

echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then

    pass_test "Application returned HTTP 200 OK."

else

    fail_test "Application returned HTTP status $HTTP_STATUS."

fi


# ==========================================================
# 27. DISPLAY DOCKER LOGS
# ==========================================================

section "22. Docker Container Logs"

if docker inspect "$DOCKER_CONTAINER" \
    >/dev/null 2>&1
then

    echo "Recent container logs:"
    echo ""

    docker logs \
        --tail 50 \
        "$DOCKER_CONTAINER" \
        2>&1 || true

    pass_test "Docker container logs retrieved."

else

    skip_test "Docker logs because container does not exist."

fi


# ==========================================================
# 28. FINAL VERIFICATION REPORT
# ==========================================================

section "FINAL VERIFICATION REPORT"

echo ""
echo "PASS : $PASS_COUNT"
echo "FAIL : $FAIL_COUNT"
echo "SKIP : $SKIP_COUNT"
echo ""

echo "=========================================================="

if [ "$FAIL_COUNT" -eq 0 ]; then

    echo "RESULT: VERIFICATION SUCCESSFUL"
    echo "=========================================================="
    echo ""
    echo "Charlie Cafe lab verification completed successfully."
    echo ""
    echo "CloudFormation resources were verified."
    echo "Docker image was verified."
    echo "Docker container was verified."
    echo "Application HTTP endpoint was tested."
    echo ""

else

    echo "RESULT: VERIFICATION FAILED"
    echo "=========================================================="
    echo ""
    echo "One or more verification tests failed."
    echo ""
    echo "Review the [FAIL] messages above."
    echo ""

fi


# ==========================================================
# 29. CLEAN TEMPORARY FILES
# ==========================================================

rm -f /tmp/charlie-cafe-identity.json
rm -f /tmp/charlie-cafe-response.html


# ==========================================================
# 30. EXIT CODE
# ==========================================================
#
# Exit 0 = all tests passed.
#
# Exit 1 = at least one test failed.
#
# This is useful for GitHub Actions because the workflow can
# automatically mark the verification stage as failed.
#
# ==========================================================

if [ "$FAIL_COUNT" -eq 0 ]; then

    exit 0

else

    exit 1

fi