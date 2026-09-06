# ==========================================================
# verify-github-ci-cd.ps1
# ==========================================================
#
# Purpose:
# Complete READ/VERIFY-oriented verification of:
#
# - AWS account
# - AWS region
# - Combined IAM policy
# - GitHub Actions IAM role
# - IAM policy attachment
# - GitHub OIDC provider
# - GitHub Actions role trust policy
# - IAM PassRole
# - EC2
# - S3
# - SSM
# - Lambda
# - ECR
# - ECS
# - CloudFormation
# - Secrets Manager
# - Terraform
# - Git repository
# - GitHub Actions workflow files
#
# IMPORTANT:
# This script DOES NOT:
#
# - Create AWS resources
# - Delete AWS resources
# - Modify IAM roles
# - Modify IAM policies
# - Detach IAM policies
# - Run terraform apply
# - Deploy applications
# - Push to GitHub
#
# The script creates:
#
# github-ci-cd-verification-report-YYYYMMDD-HHmmss.txt
#
# in the current directory.
#
# ==========================================================


# ==========================================================
# 1. CONFIGURATION
# ==========================================================

$ErrorActionPreference = "Continue"

# Expected AWS account
$ExpectedAccountId = "537236558357"

# Expected AWS region
$AwsRegion = "us-east-1"

# Combined IAM policy
$CombinedPolicyName = "github-ci-cd-user-combined-access"

$CombinedPolicyArn = `
    "arn:aws:iam::$ExpectedAccountId`:policy/$CombinedPolicyName"

# GitHub Actions IAM role
$GitHubRoleName = "aws-hybrid-iac-lab-GitHubActions"

$GitHubRoleArn = `
    "arn:aws:iam::$ExpectedAccountId`:role/$GitHubRoleName"

# CloudFormation service role
$CloudFormationRoleName = "CharlieCafe-CloudFormation-ServiceRole"

$CloudFormationRoleArn = `
    "arn:aws:iam::$ExpectedAccountId`:role/$CloudFormationRoleName"

# Terraform directory
$TerraformDirectory = (Get-Location).Path

# Optional Secrets Manager secret
$SecretName = "CafeDevDBSM"


# ==========================================================
# 2. REPORT VARIABLES
# ==========================================================

$Passed = @()
$Warnings = @()
$Errors = @()

$StartTime = Get-Date

$ReportFile = Join-Path `
    $TerraformDirectory `
    (
        "github-ci-cd-verification-report-" +
        $StartTime.ToString("yyyyMMdd-HHmmss") +
        ".txt"
    )


# ==========================================================
# 3. REPORT HEADER
# ==========================================================

$ReportHeader = @"
============================================================
 GitHub Actions + AWS + Terraform Verification Report
============================================================

Started:
$StartTime

Expected AWS Account:
$ExpectedAccountId

Expected AWS Region:
$AwsRegion

Combined IAM Policy:
$CombinedPolicyName

GitHub Actions Role:
$GitHubRoleName

CloudFormation Service Role:
$CloudFormationRoleName

Terraform Directory:
$TerraformDirectory

============================================================

"@

$ReportHeader | Out-File `
    -FilePath $ReportFile `
    -Encoding utf8


# ==========================================================
# 4. OUTPUT FUNCTIONS
# ==========================================================

function Write-Test {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host "TEST: $Name" `
        -ForegroundColor Cyan

    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Add-Content `
        -Path $ReportFile `
        -Value ""

    Add-Content `
        -Path $ReportFile `
        -Value "=========================================================="

    Add-Content `
        -Path $ReportFile `
        -Value "TEST: $Name"

    Add-Content `
        -Path $ReportFile `
        -Value "=========================================================="
}


function Write-Pass {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:Passed += $Message

    Write-Host "[PASS] $Message" `
        -ForegroundColor Green

    Add-Content `
        -Path $ReportFile `
        -Value "[PASS] $Message"
}


function Write-WarningResult {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:Warnings += $Message

    Write-Host "[WARN] $Message" `
        -ForegroundColor Yellow

    Add-Content `
        -Path $ReportFile `
        -Value "[WARN] $Message"
}


function Write-Fail {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:Errors += $Message

    Write-Host "[FAIL] $Message" `
        -ForegroundColor Red

    Add-Content `
        -Path $ReportFile `
        -Value "[FAIL] $Message"
}


function Write-Info {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" `
        -ForegroundColor Gray

    Add-Content `
        -Path $ReportFile `
        -Value "[INFO] $Message"
}


# ==========================================================
# 5. AWS CLI AVAILABILITY
# ==========================================================

Write-Test "AWS CLI Availability"

try {

    $AwsVersion = aws --version 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "AWS CLI is installed."
        Write-Info "AWS CLI version: $AwsVersion"

    }
    else {

        Write-Fail "AWS CLI is not available."

    }

}
catch {

    Write-Fail `
        "AWS CLI check failed: $($_.Exception.Message)"
}


# ==========================================================
# 6. TERRAFORM AVAILABILITY
# ==========================================================

Write-Test "Terraform Availability"

try {

    $TerraformVersion = terraform version 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "Terraform is installed."
        Write-Info "Terraform version:"
        Write-Info "$TerraformVersion"

    }
    else {

        Write-Fail "Terraform is not available."

    }

}
catch {

    Write-Fail `
        "Terraform check failed: $($_.Exception.Message)"
}


# ==========================================================
# 7. AWS ACCOUNT IDENTITY
# ==========================================================

Write-Test "AWS Account Identity"

try {

    $IdentityJson = aws sts get-caller-identity `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $Identity = $IdentityJson | ConvertFrom-Json

        Write-Info "AWS Account: $($Identity.Account)"
        Write-Info "AWS ARN: $($Identity.Arn)"
        Write-Info "AWS User ID: $($Identity.UserId)"

        if ($Identity.Account -eq $ExpectedAccountId) {

            Write-Pass `
                "AWS account matches expected account $ExpectedAccountId."

        }
        else {

            Write-Fail `
                "AWS account mismatch. Expected $ExpectedAccountId but found $($Identity.Account)."

        }

    }
    else {

        Write-Fail `
            "Unable to authenticate to AWS."

        Write-Info "$IdentityJson"
    }

}
catch {

    Write-Fail `
        "AWS identity check failed: $($_.Exception.Message)"
}


# ==========================================================
# 8. AWS REGION
# ==========================================================

Write-Test "AWS Region"

try {

    $ConfiguredRegion = aws configure get region 2>&1

    if ($ConfiguredRegion -eq $AwsRegion) {

        Write-Pass `
            "AWS CLI region is $AwsRegion."

    }
    else {

        Write-WarningResult `
            "Configured AWS region is '$ConfiguredRegion'. Expected '$AwsRegion'."

    }

}
catch {

    Write-WarningResult `
        "Unable to determine AWS CLI region."
}


# ==========================================================
# 9. COMBINED IAM POLICY EXISTS
# ==========================================================

$DefaultVersionId = $null

Write-Test "Combined IAM Policy Exists"

try {

    $PolicyJson = aws iam get-policy `
        --policy-arn $CombinedPolicyArn `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $Policy = $PolicyJson | ConvertFrom-Json

        Write-Pass `
            "Combined IAM policy exists: $CombinedPolicyName"

        Write-Info `
            "Policy ARN: $($Policy.Policy.Arn)"

        Write-Info `
            "Policy ID: $($Policy.Policy.PolicyId)"

        $DefaultVersionId = `
            $Policy.Policy.DefaultVersionId

        Write-Info `
            "Default policy version: $DefaultVersionId"

    }
    else {

        Write-Fail `
            "Combined IAM policy was not found: $CombinedPolicyArn"

    }

}
catch {

    Write-Fail `
        "Combined IAM policy check failed: $($_.Exception.Message)"
}


# ==========================================================
# 10. READ COMBINED POLICY DOCUMENT
# ==========================================================

$PolicyVersionJson = $null
$PolicyText = ""

Write-Test "Combined IAM Policy Document"

try {

    if ($DefaultVersionId) {

        $PolicyVersionJson = aws iam get-policy-version `
            --policy-arn $CombinedPolicyArn `
            --version-id $DefaultVersionId `
            --output json 2>&1

        if ($LASTEXITCODE -eq 0) {

            $PolicyVersion = `
                $PolicyVersionJson | ConvertFrom-Json

            Write-Pass `
                "Combined IAM policy document can be read."

            $Statements = `
                @($PolicyVersion.PolicyVersion.Document.Statement)

            Write-Info `
                "Policy statement count: $($Statements.Count)"

            $PolicyText = $PolicyVersionJson.ToString()

        }
        else {

            Write-Fail `
                "Unable to read combined IAM policy version."

        }

    }
    else {

        Write-WarningResult `
            "Policy version cannot be checked because the policy was not found."

    }

}
catch {

    Write-Fail `
        "Policy document check failed: $($_.Exception.Message)"
}


# ==========================================================
# 11. CHECK REQUIRED IAM PERMISSIONS
# ==========================================================

Write-Test "Required IAM Policy Permissions"

$RequiredActions = @(
    "lambda:UpdateFunctionCode",
    "lambda:UpdateFunctionConfiguration",
    "lambda:PublishLayerVersion",
    "ssm:SendCommand",
    "secretsmanager:GetSecretValue",
    "ecr:PutImage",
    "ecs:UpdateService",
    "iam:PassRole",
    "ec2:*",
    "s3:*",
    "cloudformation:*",
    "ssm:*"
)

if ([string]::IsNullOrWhiteSpace($PolicyText)) {

    Write-WarningResult `
        "Combined policy document is unavailable; required action checks were skipped."

}
else {

    foreach ($Action in $RequiredActions) {

        if ($PolicyText -match [regex]::Escape($Action)) {

            Write-Pass `
                "Policy contains required permission: $Action"

        }
        else {

            Write-Fail `
                "Policy is missing expected permission: $Action"

        }
    }
}


# ==========================================================
# 12. GITHUB ACTIONS IAM ROLE
# ==========================================================

Write-Test "GitHub Actions IAM Role"

try {

    $RoleJson = aws iam get-role `
        --role-name $GitHubRoleName `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $Role = $RoleJson | ConvertFrom-Json

        Write-Pass `
            "GitHub Actions role exists: $GitHubRoleName"

        Write-Info `
            "Role ARN: $($Role.Role.Arn)"

        Write-Info `
            "Role ID: $($Role.Role.RoleId)"

    }
    else {

        Write-Fail `
            "GitHub Actions role does not exist."

    }

}
catch {

    Write-Fail `
        "GitHub Actions role check failed: $($_.Exception.Message)"
}


# ==========================================================
# 13. CHECK ATTACHED POLICIES
# ==========================================================

Write-Test "IAM Policies Attached to GitHub Actions Role"

try {

    $AttachedJson = aws iam list-attached-role-policies `
        --role-name $GitHubRoleName `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $Attached = `
            $AttachedJson | ConvertFrom-Json

        $PolicyNames = @(
            $Attached.AttachedPolicies |
            ForEach-Object {
                $_.PolicyName
            }
        )

        if ($PolicyNames -contains $CombinedPolicyName) {

            Write-Pass `
                "Combined policy is attached to GitHub Actions role."

        }
        else {

            Write-Fail `
                "Combined policy is NOT attached to GitHub Actions role."

        }

        Write-Info "Currently attached policies:"

        foreach ($PolicyName in $PolicyNames) {

            Write-Info "  - $PolicyName"

        }

    }
    else {

        Write-Fail `
            "Unable to retrieve attached IAM policies."

    }

}
catch {

    Write-Fail `
        "Attached policy check failed: $($_.Exception.Message)"
}


# ==========================================================
# 14. CHECK GITHUB OIDC PROVIDER
# ==========================================================

Write-Test "GitHub OIDC Provider"

try {

    $OidcArn = `
        "arn:aws:iam::$ExpectedAccountId`:oidc-provider/token.actions.githubusercontent.com"

    $OidcJson = aws iam get-open-id-connect-provider `
        --open-id-connect-provider-arn $OidcArn `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $OidcProvider = $OidcJson | ConvertFrom-Json

        Write-Pass `
            "GitHub Actions OIDC provider exists."

        Write-Info `
            "OIDC URL: https://token.actions.githubusercontent.com"

        if ($OidcProvider.ClientIDList) {

            Write-Info `
                "OIDC client IDs: $($OidcProvider.ClientIDList -join ', ')"
        }

    }
    else {

        Write-Fail `
            "GitHub Actions OIDC provider was not found."

    }

}
catch {

    Write-Fail `
        "OIDC provider check failed: $($_.Exception.Message)"
}


# ==========================================================
# 15. CHECK GITHUB ACTIONS TRUST POLICY
# ==========================================================

Write-Test "GitHub Actions Trust Policy"

try {

    $TrustJson = aws iam get-role `
        --role-name $GitHubRoleName `
        --query "Role.AssumeRolePolicyDocument" `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $TrustText = $TrustJson.ToString()

        if ($TrustText -match `
            "token.actions.githubusercontent.com") {

            Write-Pass `
                "GitHub OIDC provider is referenced in role trust policy."

        }
        else {

            Write-Fail `
                "GitHub OIDC provider is not referenced in trust policy."

        }

        if ($TrustText -match `
            "sts:AssumeRoleWithWebIdentity") {

            Write-Pass `
                "sts:AssumeRoleWithWebIdentity exists in trust policy."

        }
        else {

            Write-Fail `
                "sts:AssumeRoleWithWebIdentity is missing."

        }

        if ($TrustText -match `
            "token.actions.githubusercontent.com:sub") {

            Write-Pass `
                "GitHub OIDC subject condition exists."

        }
        else {

            Write-WarningResult `
                "GitHub OIDC subject condition was not detected."

        }

        if ($TrustText -match `
            "token.actions.githubusercontent.com:aud") {

            Write-Pass `
                "GitHub OIDC audience condition exists."

        }
        else {

            Write-WarningResult `
                "GitHub OIDC audience condition was not detected."

        }

    }
    else {

        Write-Fail `
            "Unable to retrieve GitHub Actions trust policy."

    }

}
catch {

    Write-Fail `
        "Trust policy check failed: $($_.Exception.Message)"
}


# ==========================================================
# 16. CLOUDFORMATION SERVICE ROLE
# ==========================================================

Write-Test "CloudFormation Service Role"

try {

    $CFRoleJson = aws iam get-role `
        --role-name $CloudFormationRoleName `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $CFRole = $CFRoleJson | ConvertFrom-Json

        Write-Pass `
            "CloudFormation service role exists."

        Write-Info `
            "CloudFormation Role ARN: $($CFRole.Role.Arn)"

    }
    else {

        Write-Fail `
            "CloudFormation service role was not found."

    }

}
catch {

    Write-Fail `
        "CloudFormation role check failed: $($_.Exception.Message)"
}


# ==========================================================
# 17. TEST IAM PASSROLE SIMULATION
# ==========================================================

Write-Test "IAM PassRole Simulation"

try {

    $SimulationJson = aws iam simulate-principal-policy `
        --policy-source-arn $GitHubRoleArn `
        --action-names "iam:PassRole" `
        --resource-arns $CloudFormationRoleArn `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $Simulation = `
            $SimulationJson | ConvertFrom-Json

        $Decision = `
            $Simulation.EvaluationResults[0].EvalDecision

        Write-Info `
            "PassRole simulation decision: $Decision"

        if ($Decision -eq "allowed") {

            Write-Pass `
                "iam:PassRole is allowed for the CloudFormation service role."

        }
        else {

            Write-Fail `
                "iam:PassRole simulation result: $Decision"

        }

    }
    else {

        Write-WarningResult `
            "IAM PassRole simulation could not be completed."

        Write-Info "$SimulationJson"
    }

}
catch {

    Write-WarningResult `
        "PassRole simulation failed: $($_.Exception.Message)"
}


# ==========================================================
# 18. TEST S3
# ==========================================================

Write-Test "S3 Access"

try {

    $S3Result = aws s3api list-buckets `
        --query "Buckets[].Name" `
        --output text 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "S3 access is working."

        if ($S3Result) {

            Write-Info "S3 buckets:"
            Write-Info "$S3Result"

        }

    }
    else {

        Write-Fail `
            "S3 access failed."

        Write-Info "$S3Result"
    }

}
catch {

    Write-Fail `
        "S3 test failed: $($_.Exception.Message)"
}


# ==========================================================
# 19. TEST EC2
# ==========================================================

Write-Test "EC2 Access"

try {

    $EC2Result = aws ec2 describe-instances `
        --region $AwsRegion `
        --query "Reservations[].Instances[].InstanceId" `
        --output text 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "EC2 DescribeInstances access is working."

        if ($EC2Result) {

            Write-Info "EC2 Instance IDs:"
            Write-Info "$EC2Result"

        }

    }
    else {

        Write-Fail `
            "EC2 DescribeInstances failed."

        Write-Info "$EC2Result"
    }

}
catch {

    Write-Fail `
        "EC2 test failed: $($_.Exception.Message)"
}


# ==========================================================
# 20. TEST SSM
# ==========================================================

Write-Test "SSM Access"

try {

    $SSMResult = aws ssm describe-instance-information `
        --region $AwsRegion `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "SSM access is working."

        $SSMData = `
            $SSMResult | ConvertFrom-Json

        $SSMCount = `
            @($SSMData.InstanceInformationList).Count

        Write-Info `
            "SSM managed instance count: $SSMCount"

    }
    else {

        Write-Fail `
            "SSM access failed."

        Write-Info "$SSMResult"
    }

}
catch {

    Write-Fail `
        "SSM test failed: $($_.Exception.Message)"
}


# ==========================================================
# 21. TEST LAMBDA
# ==========================================================

Write-Test "Lambda Access"

try {

    $LambdaResult = aws lambda list-functions `
        --region $AwsRegion `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "Lambda list-functions access is working."

        $LambdaData = `
            $LambdaResult | ConvertFrom-Json

        $LambdaCount = `
            @($LambdaData.Functions).Count

        Write-Info `
            "Lambda function count: $LambdaCount"

    }
    else {

        Write-Fail `
            "Lambda access failed."

        Write-Info "$LambdaResult"
    }

}
catch {

    Write-Fail `
        "Lambda test failed: $($_.Exception.Message)"
}


# ==========================================================
# 22. TEST ECR
# ==========================================================

Write-Test "ECR Access"

try {

    $ECRResult = aws ecr describe-repositories `
        --region $AwsRegion `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "ECR access is working."

        $ECRData = `
            $ECRResult | ConvertFrom-Json

        $ECRCount = `
            @($ECRData.repositories).Count

        Write-Info `
            "ECR repository count: $ECRCount"

    }
    else {

        Write-Fail `
            "ECR access failed."

        Write-Info "$ECRResult"
    }

}
catch {

    Write-Fail `
        "ECR test failed: $($_.Exception.Message)"
}


# ==========================================================
# 23. TEST ECS
# ==========================================================

Write-Test "ECS Access"

try {

    $ECSResult = aws ecs list-clusters `
        --region $AwsRegion `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "ECS access is working."

        $ECSData = `
            $ECSResult | ConvertFrom-Json

        $ECSCount = `
            @($ECSData.clusterArns).Count

        Write-Info `
            "ECS cluster count: $ECSCount"

    }
    else {

        Write-Fail `
            "ECS access failed."

        Write-Info "$ECSResult"
    }

}
catch {

    Write-Fail `
        "ECS test failed: $($_.Exception.Message)"
}


# ==========================================================
# 24. TEST CLOUDFORMATION
# ==========================================================

Write-Test "CloudFormation Access"

try {

    $CFResult = aws cloudformation list-stacks `
        --region $AwsRegion `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "CloudFormation access is working."

        $CFData = `
            $CFResult | ConvertFrom-Json

        $CFCount = `
            @($CFData.StackSummaries).Count

        Write-Info `
            "CloudFormation stack count: $CFCount"

    }
    else {

        Write-Fail `
            "CloudFormation access failed."

        Write-Info "$CFResult"
    }

}
catch {

    Write-Fail `
        "CloudFormation test failed: $($_.Exception.Message)"
}


# ==========================================================
# 25. TEST SECRETS MANAGER
# ==========================================================

Write-Test "Secrets Manager Access"

try {

    $SecretResult = aws secretsmanager describe-secret `
        --secret-id $SecretName `
        --region $AwsRegion `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $SecretData = `
            $SecretResult | ConvertFrom-Json

        Write-Pass `
            "Secrets Manager access is working for $SecretName."

        Write-Info `
            "Secret ARN: $($SecretData.ARN)"

        Write-Info `
            "Secret name: $($SecretData.Name)"

    }
    else {

        Write-WarningResult `
            "Secret '$SecretName' could not be found/read. Verify the secret name."

        Write-Info "$SecretResult"
    }

}
catch {

    Write-WarningResult `
        "Secrets Manager test failed: $($_.Exception.Message)"
}


# ==========================================================
# 26. TERRAFORM FORMAT
# ==========================================================

Write-Test "Terraform Format"

try {

    Push-Location $TerraformDirectory

    terraform fmt -check -recursive

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "Terraform formatting is correct."

    }
    else {

        Write-WarningResult `
            "Terraform files require formatting."

        Write-Info `
            "Run: terraform fmt -recursive"
    }

    Pop-Location

}
catch {

    Pop-Location -ErrorAction SilentlyContinue

    Write-Fail `
        "Terraform format check failed: $($_.Exception.Message)"
}


# ==========================================================
# 27. TERRAFORM INIT CHECK
# ==========================================================

Write-Test "Terraform Initialization"

try {

    Push-Location $TerraformDirectory

    if (Test-Path ".terraform") {

        Write-Pass `
            "Terraform initialization directory exists."

    }
    else {

        Write-WarningResult `
            "Terraform does not appear to be initialized."

        Write-Info `
            "Run: terraform init"
    }

    Pop-Location

}
catch {

    Pop-Location -ErrorAction SilentlyContinue

    Write-WarningResult `
        "Terraform initialization check failed."
}


# ==========================================================
# 28. TERRAFORM VALIDATE
# ==========================================================

Write-Test "Terraform Validate"

try {

    Push-Location $TerraformDirectory

    terraform validate

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "Terraform configuration is valid."

    }
    else {

        Write-Fail `
            "Terraform validate failed."

    }

    Pop-Location

}
catch {

    Pop-Location -ErrorAction SilentlyContinue

    Write-Fail `
        "Terraform validation failed: $($_.Exception.Message)"
}


# ==========================================================
# 29. CHECK TERRAFORM FILES
# ==========================================================

Write-Test "Terraform Project Files"

$TerraformFiles = @(
    "main.tf",
    "variables.tf",
    "outputs.tf",
    "provider.tf",
    "iam.tf",
    "terraform.tf"
)

foreach ($File in $TerraformFiles) {

    $FilePath = Join-Path `
        $TerraformDirectory `
        $File

    if (Test-Path $FilePath) {

        Write-Pass `
            "Terraform file exists: $File"

    }
    else {

        Write-WarningResult `
            "Terraform file not found: $File"

    }
}


# ==========================================================
# 30. CHECK TERRAFORM STATE
# ==========================================================

Write-Test "Terraform State"

$TerraformStateFile = `
    Join-Path $TerraformDirectory "terraform.tfstate"

$TerraformStateBackup = `
    Join-Path $TerraformDirectory "terraform.tfstate.backup"

if (Test-Path $TerraformStateFile) {

    Write-Info `
        "Local terraform.tfstate file exists."

    Write-WarningResult `
        "A local terraform.tfstate file exists. Verify whether your project intentionally uses local state."

}
else {

    Write-Info `
        "No local terraform.tfstate file found."

}

if (Test-Path $TerraformStateBackup) {

    Write-Info `
        "terraform.tfstate.backup exists."

}


# ==========================================================
# 31. CHECK GITHUB ACTIONS WORKFLOW DIRECTORY
# ==========================================================

Write-Test "GitHub Actions Workflow"

$WorkflowDirectory = `
    Join-Path $TerraformDirectory ".github\workflows"

if (Test-Path $WorkflowDirectory) {

    Write-Pass `
        "GitHub Actions workflow directory exists."

    $YamlFiles = @(
        Get-ChildItem `
            -Path $WorkflowDirectory `
            -Filter "*.yml" `
            -File `
            -ErrorAction SilentlyContinue
    )

    $YamlFiles += @(
        Get-ChildItem `
            -Path $WorkflowDirectory `
            -Filter "*.yaml" `
            -File `
            -ErrorAction SilentlyContinue
    )

    if ($YamlFiles.Count -gt 0) {

        foreach ($Workflow in $YamlFiles) {

            Write-Pass `
                "GitHub Actions workflow found: $($Workflow.Name)"

        }

    }
    else {

        Write-Fail `
            "No GitHub Actions workflow files were found."

    }

}
else {

    Write-Fail `
        ".github\workflows directory does not exist."

}


# ==========================================================
# 32. CHECK GITHUB WORKFLOW AWS OIDC REFERENCES
# ==========================================================

Write-Test "GitHub Workflow AWS OIDC Configuration"

if ($YamlFiles.Count -gt 0) {

    $OidcWorkflowFound = $false

    foreach ($Workflow in $YamlFiles) {

        $WorkflowContent = `
            Get-Content `
                -Path $Workflow.FullName `
                -Raw `
                -ErrorAction SilentlyContinue

        if ($WorkflowContent -match `
            "id-token:\s*write") {

            $OidcWorkflowFound = $true

            Write-Pass `
                "$($Workflow.Name) contains id-token: write."

        }

    }

    if (-not $OidcWorkflowFound) {

        Write-WarningResult `
            "No workflow was detected with 'id-token: write'."

        Write-Info `
            "GitHub OIDC workflows normally require id-token: write."

    }

}
else {

    Write-WarningResult `
        "Workflow OIDC check skipped because no workflow files were found."
}


# ==========================================================
# 33. CHECK GIT REPOSITORY
# ==========================================================

Write-Test "Git Repository"

try {

    git status --short 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {

        Write-Pass `
            "Current directory is a Git repository."

        $GitBranch = `
            git branch --show-current 2>&1

        Write-Info `
            "Current Git branch: $GitBranch"

        $GitRemote = `
            git remote -v 2>&1

        Write-Info "Git remotes:"
        Write-Info "$GitRemote"

    }
    else {

        Write-WarningResult `
            "Current directory does not appear to be a Git repository."

    }

}
catch {

    Write-WarningResult `
        "Unable to check Git repository: $($_.Exception.Message)"
}


# ==========================================================
# 34. CHECK GITHUB ACTIONS ROLE ARN IN WORKFLOW
# ==========================================================

Write-Test "GitHub Workflow AWS Role Reference"

if ($YamlFiles.Count -gt 0) {

    $RoleReferenceFound = $false

    foreach ($Workflow in $YamlFiles) {

        $WorkflowContent = `
            Get-Content `
                -Path $Workflow.FullName `
                -Raw `
                -ErrorAction SilentlyContinue

        if ($WorkflowContent -match `
            [regex]::Escape($GitHubRoleName)) {

            $RoleReferenceFound = $true

            Write-Pass `
                "$($Workflow.Name) references GitHub Actions role name."

        }

        if ($WorkflowContent -match `
            "AWS_ROLE_ARN") {

            Write-Pass `
                "$($Workflow.Name) references AWS_ROLE_ARN."

        }

    }

    if (-not $RoleReferenceFound) {

        Write-WarningResult `
            "No workflow file directly references role name '$GitHubRoleName'."

    }

}
else {

    Write-WarningResult `
        "Workflow role check skipped because no workflow files were found."
}


# ==========================================================
# 35. FINAL SUMMARY
# ==========================================================

$EndTime = Get-Date

$Duration = $EndTime - $StartTime

$TotalResults = `
    $Passed.Count +
    $Warnings.Count +
    $Errors.Count


# ==========================================================
# BUILD FINAL REPORT
# ==========================================================

$FinalReport = @"

============================================================
 FINAL VERIFICATION REPORT
============================================================

Start Time:
$StartTime

End Time:
$EndTime

Duration:
$($Duration.ToString())

============================================================
 SUMMARY
============================================================

Total Results : $TotalResults
PASSED        : $($Passed.Count)
WARNINGS      : $($Warnings.Count)
ERRORS        : $($Errors.Count)

============================================================
 PASSED TESTS
============================================================

"@

foreach ($Item in $Passed) {

    $FinalReport += "`r`n[PASS] $Item"

}


$FinalReport += @"

============================================================
 WARNINGS
============================================================

"@

if ($Warnings.Count -eq 0) {

    $FinalReport += "`r`nNo warnings."

}
else {

    foreach ($Item in $Warnings) {

        $FinalReport += "`r`n[WARN] $Item"

    }

}


$FinalReport += @"

============================================================
 ERRORS
============================================================

"@

if ($Errors.Count -eq 0) {

    $FinalReport += "`r`nNo errors."

}
else {

    foreach ($Item in $Errors) {

        $FinalReport += "`r`n[FAIL] $Item"

    }

}


$FinalReport += @"

============================================================
 OVERALL RESULT
============================================================

"@


if ($Errors.Count -eq 0) {

    if ($Warnings.Count -eq 0) {

        $FinalReport += @"

STATUS: PASS

All automated verification checks passed.

The AWS/IAM/Terraform configuration appears ready
for the GitHub Actions end-to-end test.

"@

    }
    else {

        $FinalReport += @"

STATUS: PASS WITH WARNINGS

No critical verification errors were detected.

Review the warnings before performing the final
GitHub Actions deployment test.

"@

    }

}
else {

    $FinalReport += @"

STATUS: FAILED

One or more verification checks failed.

Review the ERROR section above before running the
final GitHub Actions deployment.

"@

}


$FinalReport += @"

============================================================
 RECOMMENDED NEXT STEPS
============================================================

1. Review this verification report.

2. Fix every FAIL item.

3. Review every WARN item.

4. Format Terraform:

   terraform fmt -recursive

5. Initialize Terraform:

   terraform init

6. Validate Terraform:

   terraform validate

7. Review Terraform plan:

   terraform plan

8. Check Git status:

   git status

9. Commit the verified configuration:

   git add .
   git commit -m "verify combined GitHub Actions IAM policy"

10. Push to GitHub:

   git push origin main

11. Open the GitHub repository.

12. Go to:

   Actions

13. Open the latest workflow run.

14. Verify that GitHub Actions successfully performs:

   - OIDC authentication
   - AWS STS authentication
   - aws sts get-caller-identity
   - Terraform init
   - Terraform validate
   - Terraform plan
   - Terraform apply

15. IMPORTANT:

   Do NOT detach the old IAM policies until the new
   combined policy has been successfully tested through
   the real GitHub Actions workflow.

============================================================
 REPORT LOCATION
============================================================

$ReportFile

============================================================
 END OF REPORT
============================================================

"@


# ==========================================================
# WRITE FINAL REPORT
# ==========================================================

$FinalReport | Out-File `
    -FilePath $ReportFile `
    -Encoding utf8 `
    -Append


# ==========================================================
# DISPLAY FINAL RESULT
# ==========================================================

Write-Host ""
Write-Host "==========================================================" `
    -ForegroundColor Cyan

Write-Host "FINAL RESULT" `
    -ForegroundColor Cyan

Write-Host "==========================================================" `
    -ForegroundColor Cyan


if ($Errors.Count -eq 0 -and $Warnings.Count -eq 0) {

    Write-Host "STATUS: PASS" `
        -ForegroundColor Green

}
elseif ($Errors.Count -eq 0) {

    Write-Host "STATUS: PASS WITH WARNINGS" `
        -ForegroundColor Yellow

}
else {

    Write-Host "STATUS: FAILED" `
        -ForegroundColor Red

}


Write-Host ""

Write-Host "Passed  : $($Passed.Count)" `
    -ForegroundColor Green

Write-Host "Warnings: $($Warnings.Count)" `
    -ForegroundColor Yellow

Write-Host "Errors  : $($Errors.Count)" `
    -ForegroundColor Red

Write-Host ""

Write-Host "Report saved to:" `
    -ForegroundColor Cyan

Write-Host $ReportFile `
    -ForegroundColor White

Write-Host ""

Write-Host "Verification complete." `
    -ForegroundColor Green


# ==========================================================
# EXIT CODE
# ==========================================================

if ($Errors.Count -gt 0) {

    exit 1

}
else {

    exit 0

}

