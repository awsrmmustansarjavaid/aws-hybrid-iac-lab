# ==========================================================
# AWS Hybrid IaC Lab
# GitHub Actions OIDC Verification
# ==========================================================

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " AWS Hybrid IaC Lab" -ForegroundColor Cyan
Write-Host " GitHub Actions OIDC Verification" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ----------------------------------------------------------
# 1. AWS Account
# ----------------------------------------------------------

Write-Host "[1] Checking AWS account..." -ForegroundColor Yellow

$AWS_ACCOUNT_ID = aws sts get-caller-identity `
    --query "Account" `
    --output text

Write-Host "AWS Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Green

# ----------------------------------------------------------
# 2. Role
# ----------------------------------------------------------

$ROLE_NAME = "aws-hybrid-iac-lab-GitHubActions"

Write-Host ""
Write-Host "[2] Checking IAM role..." -ForegroundColor Yellow

$ROLE_ARN = aws iam get-role `
    --role-name $ROLE_NAME `
    --query "Role.Arn" `
    --output text

if ($LASTEXITCODE -eq 0) {

    Write-Host "Role exists." -ForegroundColor Green
    Write-Host "Role Name: $ROLE_NAME"
    Write-Host "Role ARN : $ROLE_ARN"

}
else {

    Write-Host "ERROR: IAM role was not found." -ForegroundColor Red
    exit 1

}

# ----------------------------------------------------------
# 3. OIDC Provider
# ----------------------------------------------------------

Write-Host ""
Write-Host "[3] Checking GitHub OIDC provider..." -ForegroundColor Yellow

$OIDC_PROVIDER_ARN = aws iam list-open-id-connect-providers `
    --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" `
    --output text

if ($OIDC_PROVIDER_ARN) {

    Write-Host "GitHub OIDC provider exists." -ForegroundColor Green
    Write-Host $OIDC_PROVIDER_ARN

}
else {

    Write-Host "ERROR: GitHub OIDC provider not found." -ForegroundColor Red
}

# ----------------------------------------------------------
# 4. Trust Policy
# ----------------------------------------------------------

Write-Host ""
Write-Host "[4] Checking IAM trust policy..." -ForegroundColor Yellow

aws iam get-role `
    --role-name $ROLE_NAME `
    --query "Role.AssumeRolePolicyDocument" `
    --output json

# ----------------------------------------------------------
# 5. Attached Policies
# ----------------------------------------------------------

Write-Host ""
Write-Host "[5] Checking attached IAM policies..." -ForegroundColor Yellow

aws iam list-attached-role-policies `
    --role-name $ROLE_NAME `
    --output table

# ----------------------------------------------------------
# 6. Expected Policy
# ----------------------------------------------------------

$POLICY_NAME = "aws-hybrid-iac-lab-GitHubActionsPolicy"

Write-Host ""
Write-Host "[6] Checking GitHub Actions IAM policy..." -ForegroundColor Yellow

$POLICY_ARN = aws iam list-policies `
    --scope Local `
    --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" `
    --output text

if ($POLICY_ARN) {

    Write-Host "Policy exists." -ForegroundColor Green
    Write-Host "Policy ARN: $POLICY_ARN"

}
else {

    Write-Host "ERROR: Policy not found." -ForegroundColor Red
}

# ----------------------------------------------------------
# 7. Policy Version
# ----------------------------------------------------------

if ($POLICY_ARN) {

    Write-Host ""
    Write-Host "[7] Checking policy permissions..." -ForegroundColor Yellow

    $POLICY_VERSION = aws iam get-policy `
        --policy-arn $POLICY_ARN `
        --query "Policy.DefaultVersionId" `
        --output text

    Write-Host "Policy Version: $POLICY_VERSION"

    aws iam get-policy-version `
        --policy-arn $POLICY_ARN `
        --version-id $POLICY_VERSION `
        --output json
}

# ----------------------------------------------------------
# 8. Final Information
# ----------------------------------------------------------

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " GitHub Secret Value" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "AWS_ROLE_ARN" -ForegroundColor Yellow
Write-Host $ROLE_ARN -ForegroundColor Green

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " GitHub Repository Variable" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "AWS_REGION" -ForegroundColor Yellow
Write-Host "us-east-1" -ForegroundColor Green

Write-Host ""
Write-Host "Verification completed."
Write-Host ""