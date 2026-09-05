#requires -Version 5.1

<#
=======================================================================
 AWS Hybrid IaC Lab
 GitHub Actions OIDC + IAM + Terraform Verification Script
=======================================================================

File:
    scripts\verify-github-aws-oidc.ps1

Repository:
    awsrmmustansarjavaid/aws-hybrid-iac-lab

Purpose:
    Automatically verify the AWS and Terraform configuration required
    by GitHub Actions using AWS OIDC.

Checks:
    1. AWS CLI installation
    2. AWS account
    3. AWS caller identity
    4. AWS region
    5. GitHub OIDC provider
    6. OIDC provider URL
    7. OIDC audience
    8. IAM role
    9. IAM role ARN
   10. IAM trust policy
   11. GitHub repository restriction
   12. GitHub branch restriction
   13. GitHub Actions IAM policy
   14. IAM policy attachment
   15. IAM policy default version
   16. IAM policy document
   17. iam:PassRole
   18. CloudFormation permissions
   19. S3 permissions
   20. EC2 permissions
   21. IAM permissions
   22. ECR permissions
   23. EKS permissions
   24. RDS permissions
   25. Lambda permissions
   26. Terraform installation
   27. Terraform directory
   28. Terraform files
   29. Terraform AWS provider
   30. Terraform region configuration
   31. Terraform formatting
   32. Terraform initialization
   33. Terraform validation
   34. main-deploy.yaml
   35. terraform.yml
   36. workflow_call
   37. GitHub OIDC id-token permission
   38. AWS_REGION
   39. AWS_ROLE_ARN
   40. Final PASS / FAIL / WARNING summary

IMPORTANT:
    This script does NOT attempt to assume the GitHub OIDC role.

    GitHub's OIDC token exists only inside GitHub Actions.

    This script verifies that the AWS-side configuration and local
    Terraform configuration are ready for GitHub Actions OIDC.

PowerShell:
    Windows PowerShell 5.1+

=======================================================================
#>

# =====================================================================
# POWERSHELL SAFETY SETTINGS
# =====================================================================

Set-StrictMode -Version Latest

# Continue after individual AWS/Terraform verification failures so
# that the complete report can be displayed.
$ErrorActionPreference = "Continue"


# =====================================================================
# CONFIGURATION
# =====================================================================

# ---------------------------------------------------------------------
# IAM role created for GitHub Actions OIDC
# ---------------------------------------------------------------------

$ExpectedRoleName = "aws-hybrid-iac-lab-GitHubActions"


# ---------------------------------------------------------------------
# Customer-managed IAM policy attached to the GitHub Actions role
# ---------------------------------------------------------------------

$ExpectedPolicyName = "aws-hybrid-iac-lab-GitHubActionsPolicy"


# ---------------------------------------------------------------------
# GitHub repository
# Format:
#     OWNER/REPOSITORY
# ---------------------------------------------------------------------

$ExpectedGitHubRepository = "awsrmmustansarjavaid/aws-hybrid-iac-lab"


# ---------------------------------------------------------------------
# GitHub branch allowed to assume the IAM role
# ---------------------------------------------------------------------

$ExpectedGitHubBranch = "main"


# ---------------------------------------------------------------------
# AWS region used by the lab
# ---------------------------------------------------------------------

$ExpectedAwsRegion = "us-east-1"


# ---------------------------------------------------------------------
# GitHub Actions OIDC provider URL
# ---------------------------------------------------------------------

$ExpectedOidcUrl = "https://token.actions.githubusercontent.com"


# ---------------------------------------------------------------------
# OIDC audience used by AWS STS
# ---------------------------------------------------------------------

$ExpectedOidcAudience = "sts.amazonaws.com"


# =====================================================================
# REPOSITORY PATHS
# =====================================================================

# PSScriptRoot points to:
#
#     aws-hybrid-iac-lab\scripts
#
# Therefore ".." points to:
#
#     aws-hybrid-iac-lab
# ---------------------------------------------------------------------

$TerraformDirectory = Join-Path $PSScriptRoot "..\infrastructure\terraform"

$MainWorkflow = Join-Path $PSScriptRoot "..\.github\workflows\main-deploy.yaml"

$TerraformWorkflow = Join-Path $PSScriptRoot "..\.github\workflows\terraform.yml"


# =====================================================================
# NORMALIZE PATHS
# =====================================================================

# Convert relative paths into absolute paths.
# This also makes the output easier to understand.

$TerraformDirectoryFull = [System.IO.Path]::GetFullPath($TerraformDirectory)

$MainWorkflowFull = [System.IO.Path]::GetFullPath($MainWorkflow)

$TerraformWorkflowFull = [System.IO.Path]::GetFullPath($TerraformWorkflow)


# =====================================================================
# RESULT STORAGE
# =====================================================================

$Passed = 0

$Failed = 0

$Warnings = 0

$Results = @()


# =====================================================================
# VARIABLE INITIALIZATION
# =====================================================================
#
# These variables are initialized because Set-StrictMode -Version Latest
# causes an error if a variable is referenced before it exists.
# =====================================================================

$AWSAccountId = $null

$CallerArn = $null

$OidcProviderArn = $null

$OidcProvider = $null

$Role = $null

$RoleArn = $null

$Policy = $null

$PolicyArn = $null

$PolicyVersion = $null

$PolicyDocument = $null

$PolicyJson = $null

$MainWorkflowText = $null

$TerraformWorkflowText = $null

$TerraformText = ""

$TerraformFiles = @()


# =====================================================================
# HELPER FUNCTIONS
# =====================================================================

function Write-Section {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "=======================================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=======================================================================" -ForegroundColor Cyan
}


function Write-Check {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "[CHECK] $Name" -ForegroundColor Yellow
}


function Write-Pass {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:Passed++

    $script:Results += [PSCustomObject]@{
        Status = "PASS"
        Check  = $Message
    }

    Write-Host "[PASS] $Message" -ForegroundColor Green
}


function Write-Fail {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:Failed++

    $script:Results += [PSCustomObject]@{
        Status = "FAIL"
        Check  = $Message
    }

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}


function Write-Warn {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:Warnings++

    $script:Results += [PSCustomObject]@{
        Status = "WARN"
        Check  = $Message
    }

    Write-Host "[WARN] $Message" -ForegroundColor DarkYellow
}


function Test-CommandExists {

    param (
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    return $null -ne (
        Get-Command $CommandName -ErrorAction SilentlyContinue
    )
}


# =====================================================================
# HEADER
# =====================================================================

Clear-Host

Write-Host ""
Write-Host "#######################################################################" -ForegroundColor Cyan
Write-Host "#                                                                     #" -ForegroundColor Cyan
Write-Host "#       AWS HYBRID IaC LAB - GITHUB ACTIONS OIDC CHECK               #" -ForegroundColor Cyan
Write-Host "#                                                                     #" -ForegroundColor Cyan
Write-Host "#######################################################################" -ForegroundColor Cyan

Write-Host ""

Write-Host "Repository : $ExpectedGitHubRepository"
Write-Host "Branch     : $ExpectedGitHubBranch"
Write-Host "AWS Region : $ExpectedAwsRegion"
Write-Host "IAM Role   : $ExpectedRoleName"
Write-Host "IAM Policy : $ExpectedPolicyName"

Write-Host ""

Write-Host "Terraform Directory:" -ForegroundColor Cyan
Write-Host "    $TerraformDirectoryFull"

Write-Host ""

Write-Host "Main Workflow:" -ForegroundColor Cyan
Write-Host "    $MainWorkflowFull"

Write-Host ""

Write-Host "Terraform Workflow:" -ForegroundColor Cyan
Write-Host "    $TerraformWorkflowFull"


# =====================================================================
# 1. CHECK AWS CLI
# =====================================================================

Write-Section "1. AWS CLI"

Write-Check "AWS CLI installation"

if (Test-CommandExists "aws") {

    $AwsVersion = aws --version 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "AWS CLI is installed."

        Write-Host "        $AwsVersion"

    }
    else {

        Write-Fail "AWS CLI exists but could not execute."

    }

}
else {

    Write-Fail "AWS CLI is not installed or not available in PATH."

    Write-Host ""
    Write-Host "Install AWS CLI before continuing." -ForegroundColor Yellow
}


# =====================================================================
# 2. AWS CALLER IDENTITY
# =====================================================================

Write-Section "2. AWS Account and Caller Identity"

if (Test-CommandExists "aws") {

    Write-Check "AWS caller identity"

    $CallerIdentityRaw = aws sts get-caller-identity --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        try {

            $CallerIdentity = $CallerIdentityRaw | ConvertFrom-Json

            $AWSAccountId = $CallerIdentity.Account

            $CallerArn = $CallerIdentity.Arn

            Write-Pass "AWS authentication is working."

            Write-Host "        Account : $AWSAccountId"

            Write-Host "        ARN     : $CallerArn"

        }
        catch {

            Write-Fail "AWS returned an unexpected caller identity response."

            Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        }

    }
    else {

        Write-Fail "AWS CLI cannot authenticate with AWS."

        Write-Host ""
        Write-Host "AWS response:" -ForegroundColor Red
        Write-Host "$CallerIdentityRaw" -ForegroundColor Red

    }

}
else {

    Write-Fail "Cannot check AWS identity because AWS CLI is unavailable."

}


# =====================================================================
# 3. AWS REGION
# =====================================================================

Write-Section "3. AWS Region"

Write-Check "Expected AWS region"

Write-Host "        Expected region: $ExpectedAwsRegion"

$AwsRegionEnvironment = $env:AWS_REGION

if ([string]::IsNullOrWhiteSpace($AwsRegionEnvironment)) {

    Write-Warn "Local AWS_REGION environment variable is not set."

    Write-Host ""
    Write-Host "This is not automatically a failure." -ForegroundColor Yellow
    Write-Host "AWS CLI can still use the region from AWS configuration."

}
elseif ($AwsRegionEnvironment -eq $ExpectedAwsRegion) {

    Write-Pass "Local AWS_REGION matches expected region."

}
else {

    Write-Warn "Local AWS_REGION is '$AwsRegionEnvironment', expected '$ExpectedAwsRegion'."

}


# =====================================================================
# 4. GITHUB OIDC PROVIDER
# =====================================================================

Write-Section "4. GitHub OIDC Provider"

if (-not [string]::IsNullOrWhiteSpace($AWSAccountId)) {

    $OidcProviderArn = "arn:aws:iam::$AWSAccountId`:oidc-provider/token.actions.githubusercontent.com"

    Write-Check "GitHub OIDC provider"

    Write-Host "        Expected ARN:"
    Write-Host "        $OidcProviderArn"

    $OidcProviderRaw = aws iam get-open-id-connect-provider `
        --open-id-connect-provider-arn $OidcProviderArn `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        try {

            $OidcProvider = $OidcProviderRaw | ConvertFrom-Json

            Write-Pass "GitHub OIDC provider exists."

            Write-Host "        ARN: $OidcProviderArn"

        }
        catch {

            Write-Fail "OIDC provider exists but could not be parsed."

            Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        }

    }
    else {

        Write-Fail "GitHub OIDC provider was not found."

        Write-Host ""
        Write-Host "Expected:" -ForegroundColor Yellow
        Write-Host "$OidcProviderArn" -ForegroundColor Yellow

        Write-Host ""
        Write-Host "AWS response:" -ForegroundColor Red
        Write-Host "$OidcProviderRaw" -ForegroundColor Red
    }

}
else {

    Write-Fail "Cannot check OIDC provider because AWS account ID is unavailable."

}


# =====================================================================
# 5. OIDC URL AND AUDIENCE
# =====================================================================

if ($null -ne $OidcProvider) {

    Write-Section "5. OIDC Provider Configuration"


    # -----------------------------------------------------------------
    # OIDC URL
    # -----------------------------------------------------------------

    Write-Check "OIDC provider URL"

    $OidcUrl = $OidcProvider.Url

    if ($OidcUrl -eq $ExpectedOidcUrl) {

        Write-Pass "OIDC provider URL is correct."

        Write-Host "        $OidcUrl"

    }
    else {

        Write-Fail "OIDC provider URL is incorrect."

        Write-Host "        Found   : $OidcUrl"
        Write-Host "        Expected: $ExpectedOidcUrl"

    }


    # -----------------------------------------------------------------
    # OIDC AUDIENCE
    # -----------------------------------------------------------------

    Write-Check "OIDC audience"

    $AudienceFound = $false

    if ($null -ne $OidcProvider.ClientIDList) {

        foreach ($ClientId in $OidcProvider.ClientIDList) {

            if ($ClientId -eq $ExpectedOidcAudience) {

                $AudienceFound = $true

                break
            }
        }
    }

    if ($AudienceFound) {

        Write-Pass "OIDC audience contains sts.amazonaws.com."

    }
    else {

        Write-Fail "OIDC audience does not contain sts.amazonaws.com."

        Write-Host ""
        Write-Host "Expected audience:" -ForegroundColor Yellow
        Write-Host "$ExpectedOidcAudience" -ForegroundColor Yellow
    }

}


# =====================================================================
# 6. IAM ROLE
# =====================================================================

Write-Section "6. GitHub Actions IAM Role"

Write-Check "IAM role exists"

$RoleRaw = aws iam get-role `
    --role-name $ExpectedRoleName `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    try {

        $Role = $RoleRaw | ConvertFrom-Json

        $RoleArn = $Role.Role.Arn

        Write-Pass "IAM role exists."

        Write-Host "        Name: $ExpectedRoleName"

        Write-Host "        ARN : $RoleArn"

    }
    catch {

        Write-Fail "IAM role was found but could not be parsed."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }

}
else {

    Write-Fail "IAM role '$ExpectedRoleName' does not exist."

    Write-Host ""
    Write-Host "AWS response:" -ForegroundColor Red
    Write-Host "$RoleRaw" -ForegroundColor Red
}


# =====================================================================
# 7. IAM TRUST POLICY
# =====================================================================

if ($null -ne $Role) {

    Write-Section "7. IAM Trust Policy"

    $TrustPolicy = $Role.Role.AssumeRolePolicyDocument

    $TrustJson = $TrustPolicy | ConvertTo-Json -Depth 30


    # -----------------------------------------------------------------
    # STS WEB IDENTITY
    # -----------------------------------------------------------------

    Write-Check "OIDC AssumeRoleWithWebIdentity"

    if ($TrustJson -match "AssumeRoleWithWebIdentity") {

        Write-Pass "Trust policy allows AssumeRoleWithWebIdentity."

    }
    else {

        Write-Fail "Trust policy does not contain AssumeRoleWithWebIdentity."

    }


    # -----------------------------------------------------------------
    # GITHUB OIDC PROVIDER
    # -----------------------------------------------------------------

    Write-Check "GitHub OIDC provider in trust policy"

    if ($TrustJson -match "token.actions.githubusercontent.com") {

        Write-Pass "Trust policy references GitHub OIDC."

    }
    else {

        Write-Fail "Trust policy does not reference GitHub OIDC."

    }


    # -----------------------------------------------------------------
    # OIDC AUDIENCE
    # -----------------------------------------------------------------

    Write-Check "OIDC audience condition"

    if ($TrustJson -match [regex]::Escape($ExpectedOidcAudience)) {

        Write-Pass "Trust policy contains sts.amazonaws.com audience."

    }
    else {

        Write-Fail "Trust policy does not contain sts.amazonaws.com."

    }


    # -----------------------------------------------------------------
    # GITHUB REPOSITORY
    # -----------------------------------------------------------------

    Write-Check "GitHub repository restriction"

    if ($TrustJson -match [regex]::Escape($ExpectedGitHubRepository)) {

        Write-Pass "Trust policy references the correct GitHub repository."

    }
    else {

        Write-Fail "Trust policy does not reference the expected repository."

        Write-Host ""
        Write-Host "Expected repository:" -ForegroundColor Yellow
        Write-Host "$ExpectedGitHubRepository" -ForegroundColor Yellow
    }


    # -----------------------------------------------------------------
    # GITHUB BRANCH
    # -----------------------------------------------------------------

    Write-Check "GitHub main branch restriction"

    $ExpectedSubject = "repo:$ExpectedGitHubRepository`:ref:refs/heads/$ExpectedGitHubBranch"

    if ($TrustJson -match [regex]::Escape($ExpectedSubject)) {

        Write-Pass "Trust policy restricts access to the main branch."

    }
    else {

        Write-Warn "Could not confirm exact main branch restriction."

        Write-Host ""
        Write-Host "Expected subject:" -ForegroundColor Yellow
        Write-Host "$ExpectedSubject" -ForegroundColor Yellow
    }

}


# =====================================================================
# 8. IAM POLICY
# =====================================================================

Write-Section "8. GitHub Actions IAM Policy"

Write-Check "IAM customer-managed policy"

$PolicyRaw = aws iam list-policies `
    --scope Local `
    --query "Policies[?PolicyName=='$ExpectedPolicyName']" `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    try {

        $Policies = $PolicyRaw | ConvertFrom-Json

        if ($null -ne $Policies -and $Policies.Count -gt 0) {

            $Policy = $Policies[0]

            $PolicyArn = $Policy.Arn

            Write-Pass "IAM policy exists."

            Write-Host "        Name: $ExpectedPolicyName"

            Write-Host "        ARN : $PolicyArn"

        }
        else {

            Write-Fail "IAM policy '$ExpectedPolicyName' does not exist."

        }

    }
    catch {

        Write-Fail "Could not parse IAM policy response."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }

}
else {

    Write-Fail "Unable to query IAM policies."

    Write-Host ""
    Write-Host "AWS response:" -ForegroundColor Red
    Write-Host "$PolicyRaw" -ForegroundColor Red
}


# =====================================================================
# 9. POLICY ATTACHMENT
# =====================================================================

if ($null -ne $Role) {

    Write-Section "9. IAM Policy Attachment"

    Write-Check "Policy attached to GitHub Actions role"

    $AttachedPoliciesRaw = aws iam list-attached-role-policies `
        --role-name $ExpectedRoleName `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        try {

            $AttachedPolicies = $AttachedPoliciesRaw | ConvertFrom-Json

            $Attached = $false

            if ($null -ne $AttachedPolicies.AttachedPolicies) {

                foreach ($AttachedPolicy in $AttachedPolicies.AttachedPolicies) {

                    if ($AttachedPolicy.PolicyName -eq $ExpectedPolicyName) {

                        $Attached = $true

                        break
                    }
                }
            }

            if ($Attached) {

                Write-Pass "GitHub Actions IAM policy is attached to the role."

            }
            else {

                Write-Fail "GitHub Actions IAM policy is NOT attached to the role."

            }

        }
        catch {

            Write-Fail "Could not parse attached policy response."

            Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        }

    }
    else {

        Write-Fail "Could not retrieve attached policies."

        Write-Host ""
        Write-Host "$AttachedPoliciesRaw" -ForegroundColor Red
    }

}


# =====================================================================
# 10. IAM POLICY VERSION
# =====================================================================

if (-not [string]::IsNullOrWhiteSpace($PolicyArn)) {

    Write-Section "10. IAM Policy Permissions"

    Write-Check "IAM policy default version"

    $PolicyVersion = aws iam get-policy `
        --policy-arn $PolicyArn `
        --query "Policy.DefaultVersionId" `
        --output text 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "IAM policy default version: $PolicyVersion"

    }
    else {

        Write-Fail "Could not retrieve IAM policy version."

        Write-Host "$PolicyVersion" -ForegroundColor Red
    }


    # ================================================================
    # POLICY DOCUMENT
    # ================================================================

    if (-not [string]::IsNullOrWhiteSpace($PolicyVersion)) {

        Write-Check "IAM policy document"

        $PolicyDocumentRaw = aws iam get-policy-version `
            --policy-arn $PolicyArn `
            --version-id $PolicyVersion `
            --query "PolicyVersion.Document" `
            --output json 2>&1

        if ($LASTEXITCODE -eq 0) {

            try {

                $PolicyDocument = $PolicyDocumentRaw | ConvertFrom-Json

                # AWS CLI normally returns the policy document as JSON.
                # Convert it again to create a searchable JSON string.

                $PolicyJson = $PolicyDocument | ConvertTo-Json -Depth 50

                Write-Pass "IAM policy document can be read."

            }
            catch {

                Write-Fail "Could not parse IAM policy document."

                Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
            }

        }
        else {

            Write-Fail "Could not retrieve IAM policy document."

            Write-Host "$PolicyDocumentRaw" -ForegroundColor Red
        }

    }


    # ================================================================
    # IAM PASSROLE
    # ================================================================

    if (-not [string]::IsNullOrWhiteSpace($PolicyJson)) {

        Write-Check "iam:PassRole"

        if (
            ($PolicyJson -match "iam:PassRole") -or
            ($PolicyJson -match "iam:\*")
        ) {

            Write-Pass "Policy contains iam:PassRole capability."

        }
        else {

            Write-Fail "Policy does not contain iam:PassRole."

        }


        # ============================================================
        # CLOUDFORMATION
        # ============================================================

        Write-Check "CloudFormation permissions"

        if (
            ($PolicyJson -match "cloudformation:\*") -or
            ($PolicyJson -match "cloudformation:")
        ) {

            Write-Pass "CloudFormation permissions detected."

        }
        else {

            Write-Warn "CloudFormation permissions were not detected."

        }


        # ============================================================
        # S3
        # ============================================================

        Write-Check "S3 permissions"

        if (
            ($PolicyJson -match "s3:\*") -or
            ($PolicyJson -match "s3:")
        ) {

            Write-Pass "S3 permissions detected."

        }
        else {

            Write-Warn "S3 permissions were not detected."

        }


        # ============================================================
        # EC2
        # ============================================================

        Write-Check "EC2 permissions"

        if (
            ($PolicyJson -match "ec2:\*") -or
            ($PolicyJson -match "ec2:")
        ) {

            Write-Pass "EC2 permissions detected."

        }
        else {

            Write-Warn "EC2 permissions were not detected."

        }


        # ============================================================
        # IAM
        # ============================================================

        Write-Check "IAM permissions"

        if (
            ($PolicyJson -match "iam:\*") -or
            ($PolicyJson -match "iam:")
        ) {

            Write-Pass "IAM permissions detected."

        }
        else {

            Write-Warn "IAM permissions were not detected."

        }


        # ============================================================
        # ECR
        # ============================================================

        Write-Check "ECR permissions"

        if (
            ($PolicyJson -match "ecr:\*") -or
            ($PolicyJson -match "ecr:")
        ) {

            Write-Pass "ECR permissions detected."

        }
        else {

            Write-Warn "ECR permissions were not detected."

        }


        # ============================================================
        # EKS
        # ============================================================

        Write-Check "EKS permissions"

        if (
            ($PolicyJson -match "eks:\*") -or
            ($PolicyJson -match "eks:")
        ) {

            Write-Pass "EKS permissions detected."

        }
        else {

            Write-Warn "EKS permissions were not detected."

        }


        # ============================================================
        # RDS
        # ============================================================

        Write-Check "RDS permissions"

        if (
            ($PolicyJson -match "rds:\*") -or
            ($PolicyJson -match "rds:")
        ) {

            Write-Pass "RDS permissions detected."

        }
        else {

            Write-Warn "RDS permissions were not detected."

        }


        # ============================================================
        # LAMBDA
        # ============================================================

        Write-Check "Lambda permissions"

        if (
            ($PolicyJson -match "lambda:\*") -or
            ($PolicyJson -match "lambda:")
        ) {

            Write-Pass "Lambda permissions detected."

        }
        else {

            Write-Warn "Lambda permissions were not detected."

        }

    }

}


# =====================================================================
# 11. TERRAFORM INSTALLATION
# =====================================================================

Write-Section "11. Terraform"

Write-Check "Terraform installation"

if (Test-CommandExists "terraform") {

    $TerraformVersion = terraform version 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "Terraform is installed."

        Write-Host ""

        foreach ($VersionLine in $TerraformVersion) {

            Write-Host "        $VersionLine"
        }

    }
    else {

        Write-Fail "Terraform command exists but could not execute."

        Write-Host "$TerraformVersion" -ForegroundColor Red
    }

}
else {

    Write-Fail "Terraform is not installed or not available in PATH."

}


# =====================================================================
# 12. TERRAFORM DIRECTORY
# =====================================================================

Write-Check "Terraform directory"

if (
    Test-Path $TerraformDirectoryFull -PathType Container
) {

    Write-Pass "Terraform directory exists."

    Write-Host "        $TerraformDirectoryFull"

}
else {

    Write-Fail "Terraform directory does not exist."

    Write-Host ""
    Write-Host "Expected:" -ForegroundColor Yellow
    Write-Host "$TerraformDirectoryFull" -ForegroundColor Yellow
}


# =====================================================================
# 13. TERRAFORM FILES
# =====================================================================

if (
    Test-Path $TerraformDirectoryFull -PathType Container
) {

    Write-Check "Terraform files"

    $TerraformFiles = @(
        Get-ChildItem `
            -Path $TerraformDirectoryFull `
            -Filter "*.tf" `
            -File `
            -ErrorAction SilentlyContinue
    )

    if ($TerraformFiles.Count -gt 0) {

        Write-Pass "Terraform files found: $($TerraformFiles.Count)"

        foreach ($File in $TerraformFiles) {

            Write-Host "        $($File.Name)"
        }

    }
    else {

        Write-Fail "No Terraform .tf files were found."

    }

}


# =====================================================================
# 14. TERRAFORM PROVIDER
# =====================================================================

if (
    Test-Path $TerraformDirectoryFull -PathType Container
) {

    Write-Section "12. Terraform AWS Provider"

    $TerraformFiles = @(
        Get-ChildItem `
            -Path $TerraformDirectoryFull `
            -Filter "*.tf" `
            -File `
            -ErrorAction SilentlyContinue
    )

    $TerraformText = ""

    foreach ($File in $TerraformFiles) {

        try {

            $TerraformText += Get-Content `
                -Path $File.FullName `
                -Raw `
                -ErrorAction Stop

            $TerraformText += "`n"

        }
        catch {

            Write-Warn "Could not read Terraform file: $($File.Name)"

        }

    }


    # -----------------------------------------------------------------
    # AWS PROVIDER
    # -----------------------------------------------------------------

    Write-Check "AWS provider configuration"

    if ($TerraformText -match 'provider\s+"aws"') {

        Write-Pass "AWS provider block detected."

    }
    else {

        Write-Fail "AWS provider block was not detected."

    }


    # -----------------------------------------------------------------
    # AWS REGION
    # -----------------------------------------------------------------

    Write-Check "AWS region configuration"

    if (
        ($TerraformText -match 'region\s*=\s*var\.aws_region') -or
        ($TerraformText -match 'region\s*=\s*["''][^"'']+["'']')
    ) {

        Write-Pass "Terraform AWS region configuration detected."

    }
    else {

        Write-Warn "Could not automatically detect Terraform AWS region configuration."

    }

}


# =====================================================================
# 15. TERRAFORM FORMAT
# =====================================================================

$TerraformInstalled = Test-CommandExists "terraform"

$TerraformDirectoryExists = Test-Path `
    $TerraformDirectoryFull `
    -PathType Container

if (
    $TerraformInstalled -and
    $TerraformDirectoryExists
) {

    Write-Check "Terraform format"

    Push-Location $TerraformDirectoryFull

    try {

        terraform fmt -check -recursive

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Terraform formatting check passed."

        }
        else {

            Write-Warn "Terraform formatting check failed."

            Write-Host ""
            Write-Host "Recommended command:" -ForegroundColor Yellow
            Write-Host "terraform fmt -recursive" -ForegroundColor Yellow

        }

    }
    catch {

        Write-Fail "Terraform fmt check encountered an error."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red

    }
    finally {

        Pop-Location

    }

}


# =====================================================================
# 16. TERRAFORM INIT
# =====================================================================

if (
    $TerraformInstalled -and
    $TerraformDirectoryExists
) {

    Write-Check "Terraform init"

    Push-Location $TerraformDirectoryFull

    try {

        terraform init -input=false

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Terraform initialization succeeded."

        }
        else {

            Write-Fail "Terraform initialization failed."

        }

    }
    catch {

        Write-Fail "Terraform init encountered an error."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red

    }
    finally {

        Pop-Location

    }

}


# =====================================================================
# 17. TERRAFORM VALIDATE
# =====================================================================

if (
    $TerraformInstalled -and
    $TerraformDirectoryExists
) {

    Write-Check "Terraform validate"

    Push-Location $TerraformDirectoryFull

    try {

        terraform validate

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Terraform validation succeeded."

        }
        else {

            Write-Fail "Terraform validation failed."

        }

    }
    catch {

        Write-Fail "Terraform validate encountered an error."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red

    }
    finally {

        Pop-Location

    }

}


# =====================================================================
# 18. MAIN WORKFLOW
# =====================================================================

Write-Section "13. GitHub Actions Workflows"

Write-Check "main-deploy.yaml"

if (
    Test-Path $MainWorkflowFull -PathType Leaf
) {

    Write-Pass "main-deploy.yaml exists."

    try {

        $MainWorkflowText = Get-Content `
            -Path $MainWorkflowFull `
            -Raw `
            -ErrorAction Stop

        # -------------------------------------------------------------
        # Check whether the main workflow references terraform.yml.
        # -------------------------------------------------------------

        if ($MainWorkflowText -match 'terraform\.yml') {

            Write-Pass "main-deploy.yaml references terraform.yml."

        }
        else {

            Write-Warn "main-deploy.yaml does not appear to reference terraform.yml."

        }

    }
    catch {

        Write-Fail "Could not read main-deploy.yaml."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }

}
else {

    Write-Fail "main-deploy.yaml was not found."

    Write-Host ""
    Write-Host "Expected:" -ForegroundColor Yellow
    Write-Host "$MainWorkflowFull" -ForegroundColor Yellow
}


# =====================================================================
# 19. TERRAFORM WORKFLOW
# =====================================================================

Write-Check "terraform.yml"

if (
    Test-Path $TerraformWorkflowFull -PathType Leaf
) {

    Write-Pass "terraform.yml exists."

    try {

        $TerraformWorkflowText = Get-Content `
            -Path $TerraformWorkflowFull `
            -Raw `
            -ErrorAction Stop


        # =============================================================
        # WORKFLOW_CALL
        # =============================================================

        Write-Check "workflow_call"

        if ($TerraformWorkflowText -match "workflow_call") {

            Write-Pass "terraform.yml supports workflow_call."

        }
        else {

            Write-Fail "terraform.yml does not contain workflow_call."

        }


        # =============================================================
        # OIDC PERMISSION
        # =============================================================

        Write-Check "GitHub OIDC permission"

        if (
            $TerraformWorkflowText -match "id-token:\s*write"
        ) {

            Write-Pass "terraform.yml has id-token: write."

        }
        else {

            Write-Fail "terraform.yml is missing id-token: write."

        }


        # =============================================================
        # AWS REGION
        # =============================================================

        Write-Check "AWS_REGION"

        if (
            $TerraformWorkflowText -match `
                'aws-region:\s*\$\{\{\s*vars\.AWS_REGION\s*\}\}'
        ) {

            Write-Pass "terraform.yml uses vars.AWS_REGION."

        }
        else {

            Write-Fail "terraform.yml does not use vars.AWS_REGION for aws-region."

        }


        # =============================================================
        # AWS ROLE ARN
        # =============================================================

        Write-Check "AWS_ROLE_ARN"

        if (
            $TerraformWorkflowText -match `
                'role-to-assume:\s*\$\{\{\s*secrets\.AWS_ROLE_ARN\s*\}\}'
        ) {

            Write-Pass "terraform.yml uses secrets.AWS_ROLE_ARN."

        }
        else {

            Write-Fail "terraform.yml does not use secrets.AWS_ROLE_ARN."

        }


        # =============================================================
        # CONFIGURE AWS CREDENTIALS
        # =============================================================

        Write-Check "configure-aws-credentials"

        if (
            $TerraformWorkflowText -match `
                "aws-actions/configure-aws-credentials@v4"
        ) {

            Write-Pass "terraform.yml uses configure-aws-credentials@v4."

        }
        else {

            Write-Fail "terraform.yml does not use configure-aws-credentials@v4."

        }

    }
    catch {

        Write-Fail "Could not read terraform.yml."

        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }

}
else {

    Write-Fail "terraform.yml was not found."

    Write-Host ""
    Write-Host "Expected:" -ForegroundColor Yellow
    Write-Host "$TerraformWorkflowFull" -ForegroundColor Yellow
}


# =====================================================================
# 20. GITHUB CONFIGURATION REMINDER
# =====================================================================

Write-Section "14. GitHub Repository Configuration"

Write-Host ""
Write-Host "The following values MUST exist in GitHub:" -ForegroundColor Yellow


# ---------------------------------------------------------------------
# GITHUB VARIABLE
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Repository Variable:" -ForegroundColor Cyan

Write-Host "    AWS_REGION = $ExpectedAwsRegion"


# ---------------------------------------------------------------------
# GITHUB SECRET
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "Repository Secret:" -ForegroundColor Cyan

if (-not [string]::IsNullOrWhiteSpace($RoleArn)) {

    Write-Host "    AWS_ROLE_ARN = $RoleArn"

}
else {

    Write-Host "    AWS_ROLE_ARN = <ROLE ARN COULD NOT BE DETECTED>" -ForegroundColor Yellow

}


# ---------------------------------------------------------------------
# GITHUB REPOSITORY
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "GitHub Repository:" -ForegroundColor Cyan

Write-Host "    $ExpectedGitHubRepository"


# ---------------------------------------------------------------------
# GITHUB BRANCH
# ---------------------------------------------------------------------

Write-Host ""
Write-Host "GitHub Branch:" -ForegroundColor Cyan

Write-Host "    $ExpectedGitHubBranch"


# ---------------------------------------------------------------------
# IMPORTANT NOTE
# ---------------------------------------------------------------------

Write-Host ""

Write-Warn "GitHub Actions variables/secrets cannot be read directly using AWS CLI."

Write-Warn "Verify AWS_REGION and AWS_ROLE_ARN manually in GitHub Settings."


# =====================================================================
# 21. FINAL SUMMARY
# =====================================================================

Write-Section "FINAL VERIFICATION SUMMARY"

Write-Host ""

Write-Host "PASS    : $Passed" -ForegroundColor Green

Write-Host "FAIL    : $Failed" -ForegroundColor Red

Write-Host "WARNING : $Warnings" -ForegroundColor Yellow

Write-Host ""


# =====================================================================
# DISPLAY RESULT
# =====================================================================

if ($Failed -eq 0) {

    Write-Host "=======================================================================" -ForegroundColor Green

    Write-Host " RESULT: AWS/GitHub OIDC verification PASSED" -ForegroundColor Green

    Write-Host "=======================================================================" -ForegroundColor Green

    Write-Host ""

    Write-Host "AWS-side configuration looks ready for GitHub Actions OIDC." -ForegroundColor Green

    Write-Host ""

    Write-Host "NEXT STEP:" -ForegroundColor Cyan

    Write-Host ""

    Write-Host "1. Verify AWS_REGION in GitHub:"
    Write-Host "   Settings -> Secrets and variables -> Actions -> Variables"

    Write-Host ""

    Write-Host "2. Verify AWS_ROLE_ARN in GitHub:"
    Write-Host "   Settings -> Secrets and variables -> Actions -> Secrets"

    Write-Host ""

    Write-Host "3. Run the main deployment workflow again."

}
else {

    Write-Host "=======================================================================" -ForegroundColor Red

    Write-Host " RESULT: VERIFICATION FAILED" -ForegroundColor Red

    Write-Host "=======================================================================" -ForegroundColor Red

    Write-Host ""

    Write-Host "Fix the FAIL items above before running Main Deployment again." -ForegroundColor Yellow

}


# =====================================================================
# FINAL EXPECTED CONFIGURATION
# =====================================================================

Write-Section "EXPECTED FINAL CONFIGURATION"

Write-Host ""

Write-Host "IAM ROLE"
Write-Host "    $ExpectedRoleName"

Write-Host ""

Write-Host "IAM POLICY"
Write-Host "    $ExpectedPolicyName"

Write-Host ""

Write-Host "GITHUB OIDC"
Write-Host "    $ExpectedOidcUrl"

Write-Host ""

Write-Host "OIDC AUDIENCE"
Write-Host "    $ExpectedOidcAudience"

Write-Host ""

Write-Host "GITHUB REPOSITORY"
Write-Host "    $ExpectedGitHubRepository"

Write-Host ""

Write-Host "GITHUB BRANCH"
Write-Host "    $ExpectedGitHubBranch"

Write-Host ""

Write-Host "AWS REGION"
Write-Host "    $ExpectedAwsRegion"

Write-Host ""

Write-Host "GITHUB SECRET"
Write-Host "    AWS_ROLE_ARN"

Write-Host ""

Write-Host "GITHUB VARIABLE"
Write-Host "    AWS_REGION"

Write-Host ""

Write-Host "======================================================================="

Write-Host " Verification script finished."

Write-Host "======================================================================="

Write-Host ""