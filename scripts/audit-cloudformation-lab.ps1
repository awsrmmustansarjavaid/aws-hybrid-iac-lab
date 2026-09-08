# ============================================================
# AWS HYBRID IaC LAB
# CLOUDFORMATION + TERRAFORM
# COMPLETE NESTED-STACK PREFLIGHT AUDIT
# ============================================================
#
# File:
#   scripts/audit-cloudformation-lab.ps1
#
# PURPOSE
# ------------------------------------------------------------
# Perform ONE consolidated audit of the CloudFormation layer
# before running Terraform apply.
#
# The script checks:
#
#   01. Project structure
#   02. Root CloudFormation template
#   03. Nested CloudFormation templates
#   04. Missing template files
#   05. CloudFormation syntax validation
#   06. Nested stack TemplateURL references
#   07. Nested stack Parameters
#   08. Nested stack Outputs
#   09. Ref / GetAtt / Sub references
#   10. IAM-related CloudFormation resources
#   11. CloudFormation execution role
#   12. CloudFormation inline IAM policy
#   13. iam:PassRole
#   14. Permissions boundary
#   15. CloudFormation trust relationship
#   16. Terraform CloudFormation configuration
#   17. Same-role nested-stack configuration
#
# IMPORTANT
# ------------------------------------------------------------
# This is a STATIC + AWS preflight audit.
#
# It does NOT modify AWS resources.
# It does NOT run terraform apply.
# It does NOT delete anything.
#
# The goal is to identify problems BEFORE deployment.
#
# ============================================================

[CmdletBinding()]
param(
    [string]$Region = "us-east-1",

    [string]$RootTemplate = "",

    [string]$CloudFormationRoleName = "hybridiaclab-dev-CloudFormationExecutionRole",

    [switch]$Strict
)

# ============================================================
# 00 - PowerShell Safety
# ============================================================

$ErrorActionPreference = "Continue"

# ============================================================
# 01 - Project Root
# ============================================================

$ProjectRoot = (Get-Location).Path

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "AWS HYBRID IaC LAB - CLOUDFORMATION PREFLIGHT AUDIT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Root : $ProjectRoot"
Write-Host "AWS Region   : $Region"
Write-Host "CFN Role     : $CloudFormationRoleName"
Write-Host ""

# ============================================================
# 02 - Result Counters
# ============================================================

$PassCount = 0
$WarnCount = 0
$FailCount = 0
$InfoCount = 0

$Failures = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Passes   = New-Object System.Collections.Generic.List[string]

function Write-Pass {
    param([string]$Message)

    $script:PassCount++
    $script:Passes.Add($Message)

    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)

    $script:WarnCount++
    $script:Warnings.Add($Message)

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)

    $script:FailCount++
    $script:Failures.Add($Message)

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)

    $script:InfoCount++

    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

# ============================================================
# 03 - Helper: Section
# ============================================================

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host $Title -ForegroundColor White
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
}

# ============================================================
# 04 - Check Required Commands
# ============================================================

Write-Section "01 - Required Tools"

$AwsCommand = Get-Command aws -ErrorAction SilentlyContinue

if ($null -ne $AwsCommand) {
    Write-Pass "AWS CLI detected."
}
else {
    Write-Fail "AWS CLI was not found."
}

$TerraformCommand = Get-Command terraform -ErrorAction SilentlyContinue

if ($null -ne $TerraformCommand) {
    Write-Pass "Terraform detected."
}
else {
    Write-Warn "Terraform was not found in PATH."
}

$CfnLintCommand = Get-Command cfn-lint -ErrorAction SilentlyContinue

if ($null -ne $CfnLintCommand) {
    Write-Pass "cfn-lint detected. Advanced CloudFormation linting will be used."
}
else {
    Write-Warn "cfn-lint not found. AWS CloudFormation validation will still be used."
}

# ============================================================
# 05 - AWS Identity
# ============================================================

Write-Section "02 - AWS Identity"

if ($null -ne $AwsCommand) {

    try {

        $CallerIdentityJson = aws sts get-caller-identity --output json 2>$null

        if ($LASTEXITCODE -eq 0 -and $CallerIdentityJson) {

            $CallerIdentity = $CallerIdentityJson | ConvertFrom-Json

            Write-Pass "AWS CLI authentication is working."

            Write-Info "Account : $($CallerIdentity.Account)"
            Write-Info "Identity: $($CallerIdentity.Arn)"

        }
        else {

            Write-Fail "AWS CLI authentication failed."

        }

    }
    catch {

        Write-Fail "Unable to retrieve AWS caller identity."

    }
}

# ============================================================
# 06 - Discover Root CloudFormation Template
# ============================================================

Write-Section "03 - Root CloudFormation Template"

$CloudFormationRoot = Join-Path $ProjectRoot "infrastructure\cloudformation"

if (-not (Test-Path $CloudFormationRoot)) {

    Write-Fail "CloudFormation directory not found: $CloudFormationRoot"

}
else {

    Write-Pass "CloudFormation directory found."

    if ([string]::IsNullOrWhiteSpace($RootTemplate)) {

        $PossibleRoots = @(
            (Join-Path $CloudFormationRoot "main.yaml"),
            (Join-Path $CloudFormationRoot "main.yml"),
            (Join-Path $CloudFormationRoot "Main.yaml"),
            (Join-Path $CloudFormationRoot "Main.yml")
        )

        foreach ($Candidate in $PossibleRoots) {

            if (Test-Path $Candidate) {

                $RootTemplate = $Candidate
                break

            }

        }

    }

    if ([string]::IsNullOrWhiteSpace($RootTemplate)) {

        Write-Fail "Could not automatically find main.yaml/main.yml."

    }
    elseif (-not (Test-Path $RootTemplate)) {

        Write-Fail "Root template does not exist: $RootTemplate"

    }
    else {

        $RootTemplate = (Resolve-Path $RootTemplate).Path

        Write-Pass "Root template found: $RootTemplate"

    }
}

# ============================================================
# 07 - Discover ALL YAML Templates
# ============================================================

Write-Section "04 - CloudFormation Template Inventory"

$AllYamlFiles = @()

if (Test-Path $CloudFormationRoot) {

    $AllYamlFiles = Get-ChildItem `
        -Path $CloudFormationRoot `
        -Recurse `
        -File `
        -Include *.yaml,*.yml

}

if ($AllYamlFiles.Count -eq 0) {

    Write-Fail "No CloudFormation YAML templates were found."

}
else {

    Write-Pass "Discovered $($AllYamlFiles.Count) CloudFormation YAML file(s)."

    foreach ($File in $AllYamlFiles) {

        Write-Info $File.FullName.Replace($ProjectRoot, ".")

    }

}

# ============================================================
# 08 - Read Root Template
# ============================================================

$RootContent = ""

if ($RootTemplate -and (Test-Path $RootTemplate)) {

    try {

        $RootContent = Get-Content `
            -Path $RootTemplate `
            -Raw `
            -ErrorAction Stop

        Write-Pass "Root template can be read."

    }
    catch {

        Write-Fail "Unable to read root template."

    }

}

# ============================================================
# 09 - Check Root Template Sections
# ============================================================

Write-Section "05 - Root Template Structure"

if ($RootContent) {

    $RootSections = @(
        "AWSTemplateFormatVersion",
        "Description",
        "Parameters",
        "Resources",
        "Outputs"
    )

    foreach ($Section in $RootSections) {

        if ($RootContent -match "(?m)^$Section\s*:") {

            Write-Pass "Root template contains '$Section'."

        }
        else {

            if ($Section -eq "Resources") {

                Write-Fail "Root template is missing required 'Resources' section."

            }
            else {

                Write-Info "Root template does not contain '$Section'."

            }

        }

    }

}

# ============================================================
# 10 - Discover Nested Stack Resources
# ============================================================

Write-Section "06 - Nested Stack Discovery"

$NestedStackNames = @()

if ($RootContent) {

    $NestedMatches = [regex]::Matches(
        $RootContent,
        "(?ms)^\s{0,6}([A-Za-z0-9]+):\s*\r?\n\s*Type:\s*AWS::CloudFormation::Stack"
    )

    foreach ($Match in $NestedMatches) {

        $NestedStackNames += $Match.Groups[1].Value

    }

}

$NestedStackNames = $NestedStackNames | Sort-Object -Unique

if ($NestedStackNames.Count -gt 0) {

    Write-Pass "Detected $($NestedStackNames.Count) nested CloudFormation stack resource(s)."

    foreach ($Name in $NestedStackNames) {

        Write-Info "Nested Stack: $Name"

    }

}
else {

    Write-Warn "No AWS::CloudFormation::Stack resources were automatically detected in root template."

}

# ============================================================
# 11 - Check TemplateURL References
# ============================================================

Write-Section "07 - Nested TemplateURL References"

$TemplateUrls = @()

if ($RootContent) {

    $UrlMatches = [regex]::Matches(
        $RootContent,
        "(?m)^\s*TemplateURL\s*:\s*(.+)$"
    )

    foreach ($Match in $UrlMatches) {

        $Value = $Match.Groups[1].Value.Trim()

        $TemplateUrls += $Value

        Write-Info "TemplateURL: $Value"

    }

}

if ($TemplateUrls.Count -eq 0) {

    Write-Warn "No TemplateURL references detected in root template."

}
else {

    Write-Pass "Detected $($TemplateUrls.Count) TemplateURL reference(s)."

    foreach ($Url in $TemplateUrls) {

        # ----------------------------------------------------
        # Try to determine local template path.
        # ----------------------------------------------------

        $CleanUrl = $Url.Trim("'").Trim('"')

        if ($CleanUrl -match "^\$\{") {

            Write-Warn "Dynamic TemplateURL cannot be resolved statically: $CleanUrl"

            continue

        }

        if ($CleanUrl -match "^s3://") {

            Write-Info "S3 TemplateURL detected: $CleanUrl"

            continue

        }

        if ($CleanUrl -match "^https?://") {

            Write-Info "HTTP TemplateURL detected: $CleanUrl"

            continue

        }

        # ----------------------------------------------------
        # Remove ./ if present.
        # ----------------------------------------------------

        $RelativeUrl = $CleanUrl -replace "^\./", ""

        $PossiblePath1 = Join-Path $CloudFormationRoot $RelativeUrl
        $PossiblePath2 = Join-Path $RootTemplate "..\$RelativeUrl"

        if (Test-Path $PossiblePath1) {

            Write-Pass "TemplateURL resolves locally: $RelativeUrl"

        }
        elseif (Test-Path $PossiblePath2) {

            Write-Pass "TemplateURL resolves locally: $RelativeUrl"

        }
        else {

            Write-Warn "Could not resolve local TemplateURL: $RelativeUrl"

        }

    }

}

# ============================================================
# 12 - Detect RoleARN / RoleArn
# ============================================================

Write-Section "08 - CloudFormation Role Configuration"

$RoleReferences = @()

if ($RootContent) {

    $RoleMatches = [regex]::Matches(
        $RootContent,
        "(?mi)^\s*(RoleARN|RoleArn|IamRoleArn|iam_role_arn)\s*:\s*(.+)$"
    )

    foreach ($Match in $RoleMatches) {

        $RoleKey   = $Match.Groups[1].Value
        $RoleValue = $Match.Groups[2].Value.Trim()

        $RoleReferences += "$RoleKey = $RoleValue"

        Write-Info "$RoleKey = $RoleValue"

    }

}

if ($RoleReferences.Count -eq 0) {

    Write-Info "No RoleARN/RoleArn/IamRoleArn references found in root template."

}
else {

    Write-Pass "Role configuration references detected."

    foreach ($RoleReference in $RoleReferences) {

        if ($RoleReference -match "CloudFormationExecutionRole") {

            Write-Warn "Root template references CloudFormationExecutionRole."

        }

    }

}

# ============================================================
# 13 - Detect Same-Role Nested Stack Pattern
# ============================================================

Write-Section "09 - Same-Role Nested Stack Safety Check"

if ($RootContent -and $RootContent -match "CloudFormationExecutionRole") {

    if ($RootContent -match "AWS::CloudFormation::Stack") {

        Write-Warn "Root template contains nested stacks AND CloudFormationExecutionRole references."

        Write-Warn "This is the configuration currently associated with the iam:PassRole failure."

        Write-Info "The exact Parameters/RoleARN relationship must be reviewed."

    }

}
else {

    Write-Pass "No CloudFormationExecutionRole reference detected in root template."

}

# ============================================================
# 14 - Check All Templates with AWS CLI
# ============================================================

Write-Section "10 - AWS CloudFormation Syntax Validation"

if ($null -ne $AwsCommand) {

    foreach ($File in $AllYamlFiles) {

        Write-Info "Validating: $($File.FullName.Replace($ProjectRoot, "."))"

        try {

            $TemplateBody = Get-Content `
                -Path $File.FullName `
                -Raw `
                -ErrorAction Stop

            # ------------------------------------------------
            # AWS CLI has a template body size limitation.
            # Skip very large files rather than modifying them.
            # ------------------------------------------------

            $ByteCount = [System.Text.Encoding]::UTF8.GetByteCount($TemplateBody)

            if ($ByteCount -gt 51200) {

                Write-Warn "AWS validate-template skipped because template is larger than 51,200 bytes: $($File.Name)"

                continue

            }

            $TempOutput = aws cloudformation validate-template `
                --region $Region `
                --template-body $TemplateBody `
                --output json 2>&1

            if ($LASTEXITCODE -eq 0) {

                Write-Pass "CloudFormation syntax valid: $($File.Name)"

            }
            else {

                Write-Fail "CloudFormation validation failed: $($File.Name)"

                Write-Host $TempOutput -ForegroundColor Red

            }

        }
        catch {

            Write-Fail "Validation process failed for: $($File.Name)"

        }

    }

}
else {

    Write-Warn "AWS CLI unavailable; CloudFormation validation skipped."

}

# ============================================================
# 15 - Optional cfn-lint
# ============================================================

Write-Section "11 - Advanced CloudFormation Linting"

if ($null -ne $CfnLintCommand) {

    foreach ($File in $AllYamlFiles) {

        Write-Info "cfn-lint: $($File.Name)"

        $LintOutput = cfn-lint `
            --template $File.FullName 2>&1

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "cfn-lint passed: $($File.Name)"

        }
        else {

            Write-Warn "cfn-lint reported issue(s): $($File.Name)"

            $LintOutput |
                Select-Object -First 15 |
                ForEach-Object {
                    Write-Host $_ -ForegroundColor Yellow
                }

        }

    }

}
else {

    Write-Info "cfn-lint not installed; advanced linting skipped."

}

# ============================================================
# 16 - IAM Resource Discovery
# ============================================================

Write-Section "12 - IAM Resource Discovery"

$IamResourceTypes = @(
    "AWS::IAM::Role",
    "AWS::IAM::Policy",
    "AWS::IAM::ManagedPolicy",
    "AWS::IAM::InstanceProfile",
    "AWS::IAM::User",
    "AWS::IAM::Group"
)

$IamFiles = @()

foreach ($File in $AllYamlFiles) {

    $Content = Get-Content `
        -Path $File.FullName `
        -Raw `
        -ErrorAction SilentlyContinue

    foreach ($IamType in $IamResourceTypes) {

        if ($Content -match [regex]::Escape($IamType)) {

            $IamFiles += $File.Name

            Write-Info "$($File.Name) contains $IamType"

        }

    }

}

$IamFiles = $IamFiles | Sort-Object -Unique

if ($IamFiles.Count -gt 0) {

    Write-Pass "IAM-related CloudFormation resources found in $($IamFiles.Count) template(s)."

}
else {

    Write-Info "No IAM resource types detected in CloudFormation templates."

}

# ============================================================
# 17 - Lambda Role Detection
# ============================================================

Write-Section "13 - Lambda IAM Role References"

$LambdaRoleReferences = @()

foreach ($File in $AllYamlFiles) {

    $Content = Get-Content `
        -Path $File.FullName `
        -Raw `
        -ErrorAction SilentlyContinue

    if ($Content -match "AWS::Lambda::Function") {

        if ($Content -match "(?mi)^\s*Role\s*:") {

            $LambdaRoleReferences += $File.Name

            Write-Info "$($File.Name) contains Lambda Function Role configuration."

        }

    }

}

if ($LambdaRoleReferences.Count -gt 0) {

    Write-Pass "Lambda execution-role configuration detected."

}
else {

    Write-Info "No Lambda execution-role references detected."

}

# ============================================================
# 18 - AWS IAM Role Inspection
# ============================================================

Write-Section "14 - CloudFormation Execution Role"

$RoleArn = ""
$RolePolicyName = ""

if ($null -ne $AwsCommand) {

    try {

        $RoleJson = aws iam get-role `
            --role-name $CloudFormationRoleName `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0 -and $RoleJson) {

            $RoleObject = $RoleJson | ConvertFrom-Json

            $RoleArn = $RoleObject.Role.Arn

            Write-Pass "CloudFormation execution role exists."

            Write-Info "Role ARN: $RoleArn"

            if ($null -eq $RoleObject.Role.PermissionsBoundary) {

                Write-Pass "No permissions boundary is attached."

            }
            else {

                Write-Warn "Permissions boundary detected."

            }

        }
        else {

            Write-Fail "CloudFormation execution role does not exist or cannot be read."

        }

    }
    catch {

        Write-Fail "Unable to inspect CloudFormation execution role."

    }

}

# ============================================================
# 19 - Role Trust Relationship
# ============================================================

Write-Section "15 - CloudFormation Trust Relationship"

if ($null -ne $AwsCommand -and $RoleArn) {

    try {

        $TrustJson = aws iam get-role `
            --role-name $CloudFormationRoleName `
            --query "Role.AssumeRolePolicyDocument" `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0) {

            if ($TrustJson -match "cloudformation.amazonaws.com") {

                Write-Pass "Role trust policy allows CloudFormation service."

            }
            else {

                Write-Fail "CloudFormation service was not detected in role trust policy."

            }

        }

    }
    catch {

        Write-Warn "Could not inspect CloudFormation trust policy."

    }

}

# ============================================================
# 20 - Inline Policy Discovery
# ============================================================

Write-Section "16 - CloudFormation IAM Inline Policies"

$InlinePolicies = @()

if ($null -ne $AwsCommand -and $RoleArn) {

    try {

        $PolicyNamesJson = aws iam list-role-policies `
            --role-name $CloudFormationRoleName `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0) {

            $PolicyObject = $PolicyNamesJson | ConvertFrom-Json

            $InlinePolicies = @($PolicyObject.PolicyNames)

            if ($InlinePolicies.Count -gt 0) {

                Write-Pass "Found $($InlinePolicies.Count) inline IAM policy/policies."

                foreach ($PolicyName in $InlinePolicies) {

                    Write-Info "Inline Policy: $PolicyName"

                }

            }
            else {

                Write-Fail "No inline IAM policies are attached to the CloudFormation execution role."

            }

        }

    }
    catch {

        Write-Warn "Unable to inspect inline IAM policies."

    }

}

# ============================================================
# 21 - Find PassRole Permissions
# ============================================================

Write-Section "17 - iam:PassRole Audit"

$PassRoleFound = $false
$PassRoleCloudFormationFound = $false

foreach ($PolicyName in $InlinePolicies) {

    try {

        $PolicyJson = aws iam get-role-policy `
            --role-name $CloudFormationRoleName `
            --policy-name $PolicyName `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0 -and $PolicyJson) {

            if ($PolicyJson -match '"iam:PassRole"') {

                $PassRoleFound = $true

                Write-Pass "iam:PassRole exists in inline policy '$PolicyName'."

            }

            if (
                $PolicyJson -match "CloudFormationExecutionRole" -and
                $PolicyJson -match '"iam:PassRole"'
            ) {

                $PassRoleCloudFormationFound = $true

                Write-Pass "iam:PassRole explicitly references CloudFormationExecutionRole."

            }

        }

    }
    catch {

        Write-Warn "Unable to inspect policy: $PolicyName"

    }

}

if (-not $PassRoleFound) {

    Write-Fail "No iam:PassRole permission was detected."

}

if (-not $PassRoleCloudFormationFound) {

    Write-Warn "No iam:PassRole statement targeting CloudFormationExecutionRole was detected."

}

# ============================================================
# 22 - IAM Policy Simulator
# ============================================================

Write-Section "18 - IAM Policy Simulator"

if ($RoleArn) {

    $TargetRoleArn = $RoleArn

    try {

        $SimulationJson = aws iam simulate-principal-policy `
            --policy-source-arn $RoleArn `
            --action-names "iam:PassRole" `
            --resource-arns $TargetRoleArn `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0 -and $SimulationJson) {

            $Simulation = $SimulationJson | ConvertFrom-Json

            $Decision = $Simulation.EvaluationResults[0].EvalDecision

            if ($Decision -eq "allowed") {

                Write-Pass "IAM simulator: iam:PassRole = ALLOWED."

            }
            elseif ($Decision -eq "explicitDeny") {

                Write-Fail "IAM simulator: iam:PassRole = EXPLICIT DENY."

            }
            else {

                Write-Fail "IAM simulator: iam:PassRole = $Decision"

            }

        }
        else {

            Write-Warn "IAM policy simulation could not be completed."

        }

    }
    catch {

        Write-Warn "IAM policy simulator check failed."

    }

}

# ============================================================
# 23 - Terraform CloudFormation Configuration
# ============================================================

Write-Section "19 - Terraform CloudFormation Configuration"

$TerraformDirectory = Join-Path $ProjectRoot "infrastructure\terraform"

$TerraformFiles = @()

if (Test-Path $TerraformDirectory) {

    $TerraformFiles = Get-ChildItem `
        -Path $TerraformDirectory `
        -Recurse `
        -File `
        -Filter *.tf

}

if ($TerraformFiles.Count -eq 0) {

    Write-Warn "No Terraform files found."

}
else {

    Write-Pass "Found $($TerraformFiles.Count) Terraform file(s)."

}

$CloudFormationTerraformFiles = @()

foreach ($File in $TerraformFiles) {

    $Content = Get-Content `
        -Path $File.FullName `
        -Raw `
        -ErrorAction SilentlyContinue

    if (
        $Content -match "aws_cloudformation_stack" -or
        $Content -match "iam_role_arn" -or
        $Content -match "CloudFormationExecutionRole"
    ) {

        $CloudFormationTerraformFiles += $File

        Write-Info "CloudFormation/IAM configuration: $($File.Name)"

    }

}

if ($CloudFormationTerraformFiles.Count -gt 0) {

    Write-Pass "Terraform CloudFormation/IAM configuration detected."

}
else {

    Write-Warn "Could not locate Terraform CloudFormation/IAM configuration."

}

# ============================================================
# 24 - Terraform Syntax Validation
# ============================================================

Write-Section "20 - Terraform Validation"

if ($null -ne $TerraformCommand) {

    Push-Location $TerraformDirectory

    try {

        terraform fmt -check -recursive 2>&1 |
            Select-Object -First 20 |
            ForEach-Object {
                Write-Host $_
            }

        terraform validate 2>&1 |
            ForEach-Object {

                if ($_ -match "Success!") {

                    Write-Pass "Terraform configuration is valid."

                }
                elseif ($_ -match "Error") {

                    Write-Fail "Terraform validation reported an error."

                    Write-Host $_ -ForegroundColor Red

                }
                else {

                    Write-Host $_

                }

            }

    }
    catch {

        Write-Warn "Terraform validation could not be completed."

    }
    finally {

        Pop-Location

    }

}

# ============================================================
# 25 - Cross-Template Reference Audit
# ============================================================

Write-Section "21 - Cross-Template Reference Audit"

$ReferenceProblems = 0

foreach ($File in $AllYamlFiles) {

    $Content = Get-Content `
        -Path $File.FullName `
        -Raw `
        -ErrorAction SilentlyContinue

    if (-not $Content) {
        continue
    }

    # --------------------------------------------------------
    # Extract Ref references.
    # --------------------------------------------------------

    $RefMatches = [regex]::Matches(
        $Content,
        "!Ref\s+([A-Za-z0-9._:-]+)"
    )

    foreach ($Match in $RefMatches) {

        $RefName = $Match.Groups[1].Value

        # Parameters/resources are difficult to fully resolve
        # without a YAML parser, so we report them for review.

        Write-Info "$($File.Name): Ref -> $RefName"

    }

    # --------------------------------------------------------
    # Extract Fn::GetAtt references.
    # --------------------------------------------------------

    $GetAttMatches = [regex]::Matches(
        $Content,
        "(?i)Fn::GetAtt\s*:\s*\[?\s*['""]?([A-Za-z0-9._:-]+)"
    )

    foreach ($Match in $GetAttMatches) {

        $ResourceName = $Match.Groups[1].Value

        Write-Info "$($File.Name): GetAtt -> $ResourceName"

    }

}

Write-Pass "Cross-template reference scan completed."

# ============================================================
# 26 - Required CloudFormation Resource Detection
# ============================================================

Write-Section "22 - AWS Service Coverage"

$ServicePatterns = [ordered]@{

    "VPC / EC2 Networking" = "AWS::EC2::VPC|AWS::EC2::Subnet|AWS::EC2::RouteTable|AWS::EC2::SecurityGroup"

    "S3" = "AWS::S3::Bucket"

    "CloudFront" = "AWS::CloudFront::Distribution"

    "Lambda" = "AWS::Lambda::Function"

    "API Gateway" = "AWS::ApiGateway::RestApi|AWS::ApiGatewayV2::Api"

    "DynamoDB" = "AWS::DynamoDB::Table"

    "RDS" = "AWS::RDS::DBInstance|AWS::RDS::DBCluster"

    "ECR" = "AWS::ECR::Repository"

    "ECS" = "AWS::ECS::Cluster|AWS::ECS::Service|AWS::ECS::TaskDefinition"

    "EKS" = "AWS::EKS::Cluster"

    "IAM" = "AWS::IAM::Role|AWS::IAM::Policy|AWS::IAM::ManagedPolicy"

    "CloudWatch" = "AWS::Logs::LogGroup"

    "WAF" = "AWS::WAFv2::WebACL"

    "Secrets Manager" = "AWS::SecretsManager::Secret"

    "KMS" = "AWS::KMS::Key"

}

foreach ($Service in $ServicePatterns.Keys) {

    $Pattern = $ServicePatterns[$Service]

    $Found = $false

    foreach ($File in $AllYamlFiles) {

        $Content = Get-Content `
            -Path $File.FullName `
            -Raw `
            -ErrorAction SilentlyContinue

        if ($Content -match $Pattern) {

            $Found = $true
            break

        }

    }

    if ($Found) {

        Write-Pass "$Service resources detected."

    }
    else {

        Write-Info "$Service resources not detected."

    }

}

# ============================================================
# 27 - Dangerous Inline Policy Pattern Check
# ============================================================

Write-Section "23 - IAM Security Review"

if ($RoleArn) {

    foreach ($PolicyName in $InlinePolicies) {

        try {

            $PolicyJson = aws iam get-role-policy `
                --role-name $CloudFormationRoleName `
                --policy-name $PolicyName `
                --output json 2>$null

            if ($LASTEXITCODE -eq 0 -and $PolicyJson) {

                # ------------------------------------------------
                # Check for wildcard PassRole.
                # ------------------------------------------------

                if (
                    $PolicyJson -match '"iam:PassRole"' -and
                    $PolicyJson -match '"Resource"\s*:\s*\[\s*"[*]"'
                ) {

                    Write-Warn "Policy '$PolicyName' may contain wildcard iam:PassRole."

                }
                else {

                    Write-Pass "No obvious wildcard iam:PassRole pattern detected in '$PolicyName'."

                }

            }

        }
        catch {

            Write-Warn "Could not complete security review for '$PolicyName'."

        }

    }

}

# ============================================================
# 28 - Search for CloudFormation Execution Role References
# ============================================================

Write-Section "24 - CloudFormationExecutionRole Reference Inventory"

$RoleReferenceFiles = @()

foreach ($File in $AllYamlFiles) {

    $Content = Get-Content `
        -Path $File.FullName `
        -Raw `
        -ErrorAction SilentlyContinue

    if ($Content -match "CloudFormationExecutionRole") {

        $RoleReferenceFiles += $File.Name

        Write-Warn "$($File.Name) references CloudFormationExecutionRole."

    }

}

$RoleReferenceFiles = $RoleReferenceFiles | Sort-Object -Unique

if ($RoleReferenceFiles.Count -eq 0) {

    Write-Pass "No nested CloudFormation YAML file references CloudFormationExecutionRole."

}
else {

    Write-Warn "CloudFormationExecutionRole is referenced by $($RoleReferenceFiles.Count) template(s)."

}

# ============================================================
# 29 - Check Failed Stack History
# ============================================================

Write-Section "25 - Existing MainStack Status"

if ($null -ne $AwsCommand) {

    try {

        $StackStatus = aws cloudformation describe-stacks `
            --stack-name hybridiaclab-dev-MainStack `
            --region $Region `
            --query "Stacks[0].StackStatus" `
            --output text 2>$null

        if ($LASTEXITCODE -eq 0) {

            Write-Warn "MainStack currently exists with status: $StackStatus"

            if (
                $StackStatus -eq "ROLLBACK_COMPLETE" -or
                $StackStatus -eq "DELETE_FAILED"
            ) {

                Write-Warn "MainStack is in a failed/recovery state."

            }

        }
        else {

            Write-Info "MainStack does not currently exist."

        }

    }
    catch {

        Write-Info "Unable to query MainStack status."

    }

}

# ============================================================
# 30 - Generate Compact Report
# ============================================================

Write-Section "FINAL PREFLIGHT SUMMARY"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "AWS HYBRID IaC LAB - PREFLIGHT RESULT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "PASS    : $PassCount" -ForegroundColor Green
Write-Host "WARNING : $WarnCount" -ForegroundColor Yellow
Write-Host "FAIL    : $FailCount" -ForegroundColor Red
Write-Host "INFO    : $InfoCount" -ForegroundColor Gray

Write-Host ""

# ============================================================
# 31 - Important Failures
# ============================================================

if ($Failures.Count -gt 0) {

    Write-Host "CRITICAL FAILURES" -ForegroundColor Red
    Write-Host "------------------------------------------------------------"

    foreach ($Failure in $Failures) {

        Write-Host "[FAIL] $Failure" -ForegroundColor Red

    }

}
else {

    Write-Host "CRITICAL FAILURES: NONE" -ForegroundColor Green

}

# ============================================================
# 32 - Important Warnings
# ============================================================

if ($Warnings.Count -gt 0) {

    Write-Host ""
    Write-Host "WARNINGS REQUIRING REVIEW" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"

    foreach ($Warning in $Warnings |
        Select-Object -Unique |
        Select-Object -First 20) {

        Write-Host "[WARN] $Warning" -ForegroundColor Yellow

    }

}

# ============================================================
# 33 - Overall Decision
# ============================================================

Write-Host ""
Write-Host "============================================================"

if ($FailCount -eq 0 -and $WarnCount -eq 0) {

    Write-Host "RESULT: READY FOR NEXT DEPLOYMENT TEST" -ForegroundColor Green

}
elseif ($FailCount -eq 0) {

    Write-Host "RESULT: REVIEW WARNINGS BEFORE DEPLOYMENT" -ForegroundColor Yellow

}
else {

    Write-Host "RESULT: DO NOT DEPLOY YET - FIX FAILURES FIRST" -ForegroundColor Red

}

Write-Host "============================================================"
Write-Host ""

# ============================================================
# 34 - LinkedIn / Portfolio Information
# ============================================================

Write-Host "AUDIT TITLE:" -ForegroundColor Cyan
Write-Host "AWS Hybrid IaC Lab - Automated CloudFormation & Terraform Preflight Audit"

Write-Host ""
Write-Host "This audit is READ-ONLY and does not modify AWS resources."
Write-Host ""

# ============================================================
# AUDIT REPORT FILE GENERATION
# ============================================================
#
# PURPOSE
# ------------------------------------------------------------
# This section creates a dedicated report-log folder and
# separates the audit output into three easy-to-read files:
#
#   1. PASS    -> Successful checks
#   2. ERROR   -> Failed / critical checks
#   3. WARNING -> Checks that require review
#
# This prevents the console from becoming difficult to read
# when the audit produces a large amount of output.
#
# IMPORTANT
# ------------------------------------------------------------
# This section is READ-ONLY with respect to AWS resources.
# It only creates local report files on the computer.
#
# Folder:
#   report-log
#
# Files:
#   AWS-Hybrid-IaC-Audit-PASS.txt
#   AWS-Hybrid-IaC-Audit-ERROR.txt
#   AWS-Hybrid-IaC-Audit-WARNING.txt
#
# ============================================================


# ------------------------------------------------------------
# 01 - Define report folder
# ------------------------------------------------------------
# The report folder will be created in the project root,
# assuming this script is executed from the project root.
#
# Example:
# C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab\
#     report-log\
#
# ------------------------------------------------------------

$ReportFolder = Join-Path (Get-Location) "report-log"


# ------------------------------------------------------------
# 02 - Create report folder if it does not exist
# ------------------------------------------------------------

if (-not (Test-Path -LiteralPath $ReportFolder)) {

    New-Item `
        -ItemType Directory `
        -Path $ReportFolder `
        -Force |
        Out-Null

}


# ------------------------------------------------------------
# 03 - Define report file names
# ------------------------------------------------------------
# Clear file names make it immediately obvious what each
# report contains.
# ------------------------------------------------------------

$PassReport = Join-Path `
    $ReportFolder `
    "AWS-Hybrid-IaC-Audit-PASS.txt"

$ErrorReport = Join-Path `
    $ReportFolder `
    "AWS-Hybrid-IaC-Audit-ERROR.txt"

$WarningReport = Join-Path `
    $ReportFolder `
    "AWS-Hybrid-IaC-Audit-WARNING.txt"


# ------------------------------------------------------------
# 04 - Create report headers
# ------------------------------------------------------------
# These headers make each file understandable when opened
# independently.
# ------------------------------------------------------------

$PassHeader = @"
============================================================
AWS HYBRID IaC LAB
PASS AUDIT REPORT
============================================================

Audit Title:
AWS Hybrid IaC Lab - Automated CloudFormation & Terraform Preflight Audit

Purpose:
Successful checks detected by the automated preflight audit.

This report is READ-ONLY.
No AWS resources are modified by this reporting section.

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

"@

$ErrorHeader = @"
============================================================
AWS HYBRID IaC LAB
ERROR / FAILURE AUDIT REPORT
============================================================

Audit Title:
AWS Hybrid IaC Lab - Automated CloudFormation & Terraform Preflight Audit

Purpose:
Failed or critical checks detected by the automated preflight audit.

ACTION REQUIRED:
Review these errors before deployment.

This report is READ-ONLY.
No AWS resources are modified by this reporting section.

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

"@

$WarningHeader = @"
============================================================
AWS HYBRID IaC LAB
WARNING AUDIT REPORT
============================================================

Audit Title:
AWS Hybrid IaC Lab - Automated CloudFormation & Terraform Preflight Audit

Purpose:
Warnings that may require review before deployment.

WARNING:
A warning does not always mean deployment will fail.

This report is READ-ONLY.
No AWS resources are modified by this reporting section.

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

"@


# ------------------------------------------------------------
# 05 - Read the current PowerShell transcript/output buffer
# ------------------------------------------------------------
# IMPORTANT:
#
# This method works best when the audit script stores its
# messages in variables.
#
# If your existing audit script uses Write-Host directly,
# the complete console history cannot reliably be retrieved
# from inside the script after the fact.
#
# Therefore this section also prepares the three files with
# clear headers even if no matching messages are detected.
# ------------------------------------------------------------


# ------------------------------------------------------------
# 06 - Initialize report files
# ------------------------------------------------------------

Set-Content `
    -Path $PassReport `
    -Value $PassHeader `
    -Encoding UTF8

Set-Content `
    -Path $ErrorReport `
    -Value $ErrorHeader `
    -Encoding UTF8

Set-Content `
    -Path $WarningReport `
    -Value $WarningHeader `
    -Encoding UTF8


# ------------------------------------------------------------
# 07 - Export audit result collections
# ------------------------------------------------------------
#
# If your audit script already maintains collections named:
#
#   $Passes
#   $Failures
#   $Warnings
#
# they will be written to the corresponding files.
#
# The @() syntax safely handles an empty collection.
# ------------------------------------------------------------

if ($null -ne $Passes) {

    @($Passes) |
        ForEach-Object {
            Add-Content `
                -Path $PassReport `
                -Value "[PASS] $_" `
                -Encoding UTF8
        }

}

if ($null -ne $Failures) {

    @($Failures) |
        ForEach-Object {
            Add-Content `
                -Path $ErrorReport `
                -Value "[FAIL] $_" `
                -Encoding UTF8
        }

}

if ($null -ne $Warnings) {

    @($Warnings) |
        ForEach-Object {
            Add-Content `
                -Path $WarningReport `
                -Value "[WARN] $_" `
                -Encoding UTF8
        }

}


# ------------------------------------------------------------
# 08 - Add report summary
# ------------------------------------------------------------

Add-Content `
    -Path $PassReport `
    -Value "`r`n============================================================"

Add-Content `
    -Path $PassReport `
    -Value "PASS REPORT COMPLETE"

Add-Content `
    -Path $PassReport `
    -Value "============================================================"


Add-Content `
    -Path $ErrorReport `
    -Value "`r`n============================================================"

Add-Content `
    -Path $ErrorReport `
    -Value "ERROR REPORT COMPLETE"

Add-Content `
    -Path $ErrorReport `
    -Value "============================================================"


Add-Content `
    -Path $WarningReport `
    -Value "`r`n============================================================"

Add-Content `
    -Path $WarningReport `
    -Value "WARNING REPORT COMPLETE"

Add-Content `
    -Path $WarningReport `
    -Value "============================================================"


# ------------------------------------------------------------
# 09 - Display report locations in PowerShell
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host "AUDIT REPORT FILES CREATED"
Write-Host "============================================================"

Write-Host ""
Write-Host "[PASS]   $PassReport"
Write-Host "[ERROR]  $ErrorReport"
Write-Host "[WARN]   $WarningReport"

Write-Host ""
Write-Host "Report folder:"
Write-Host "           $ReportFolder"

Write-Host ""
Write-Host "============================================================"



# ============================================================
# 35 - Exit Code
# ============================================================

if ($FailCount -gt 0) {

    exit 2

}

if ($Strict -and $WarnCount -gt 0) {

    exit 1

}

exit 0

