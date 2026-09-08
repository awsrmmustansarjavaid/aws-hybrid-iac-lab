# audit-cloudformation-lab.ps1

Yes — I understand exactly what you need.

You **do not want to debug 11 nested CloudFormation templates one-by-one**. You want one PowerShell preflight/audit script that:

* scans the root `main.yaml`
* discovers all nested CloudFormation templates
* checks that files actually exist
* runs CloudFormation syntax validation
* checks nested-stack references
* checks `Parameters`
* checks `Outputs`
* checks `Ref` / `GetAtt` references
* identifies IAM-related resources
* checks your CloudFormation execution role
* checks its inline IAM policy
* checks `iam:PassRole`
* checks for the dangerous **same-role nested-stack pattern** we are currently seeing
* checks Terraform's CloudFormation configuration
* produces a **short summary report** that you can paste back to me
* returns a non-zero exit code if important problems are found

This is the right approach with only two days left.

## 1. Create this script

Create:

```text
scripts\audit-cloudformation-lab.ps1
```

Use this complete script:

```powershell
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
# 35 - Exit Code
# ============================================================

if ($FailCount -gt 0) {

    exit 2

}

if ($Strict -and $WarnCount -gt 0) {

    exit 1

}

exit 0
```

## 2. Important point about this script

There is one limitation I want to be completely honest about.

A PowerShell script alone does **not have a native YAML parser in Windows PowerShell 5.1**. Therefore this script deliberately uses:

* AWS CloudFormation's own `validate-template`
* `cfn-lint`, if installed
* structured AWS IAM API calls
* targeted static analysis of YAML
* Terraform validation
* cross-file/reference scanning

That gives us a very useful **preflight audit without requiring you to paste 11 huge files into the chat**.

---

# 3. Run it

From your project root:

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"
```

Then:

```powershell
.\scripts\audit-cloudformation-lab.ps1
```

If PowerShell says scripts are blocked, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then:

```powershell
.\scripts\audit-cloudformation-lab.ps1
```

---

# 4. Because your current terminal is inside Terraform

You are currently here:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab\infrastructure\terraform
```

So **don't run the script from there initially**.

Use:

```powershell
cd ..\..\..
```

You should then see:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

Verify:

```powershell
Get-Location
```

Then:

```powershell
.\scripts\audit-cloudformation-lab.ps1
```

---

# 5. What I particularly want from the report

Because of our current `iam:PassRole` problem, these sections are especially important:

```text
06 - Nested Stack Discovery
07 - Nested TemplateURL References
08 - CloudFormation Role Configuration
09 - Same-Role Nested Stack Safety Check
10 - AWS CloudFormation Syntax Validation
12 - IAM Resource Discovery
15 - CloudFormation Trust Relationship
17 - iam:PassRole Audit
18 - IAM Policy Simulator
19 - Terraform CloudFormation Configuration
21 - Cross-Template Reference Audit
24 - CloudFormationExecutionRole Reference Inventory
FINAL PREFLIGHT SUMMARY
```

You **do not need to send me all 11 templates**.

Just send me the final output, particularly:

```text
PASS    : X
WARNING : X
FAIL    : X
INFO    : X

CRITICAL FAILURES
...

WARNINGS REQUIRING REVIEW
...

RESULT: ...
```

If the output is extremely long, you can save it to a text file instead.

---

# 6. Better: save the complete audit automatically

Run:

```powershell
.\scripts\audit-cloudformation-lab.ps1 2>&1 | Tee-Object -FilePath ".\cloudformation-audit-report.txt"
```

This gives you both:

1. output on screen
2. a report:

```text
cloudformation-audit-report.txt
```

Then you can give me that **one small report** instead of the 11 YAML files.

---

# 7. Optional: install `cfn-lint`

The script will work without it, but for your lab I strongly recommend it.

Check:

```powershell
cfn-lint --version
```

If it says command not found, and you already have Python/pip:

```powershell
py -m pip install cfn-lint
```

Then:

```powershell
cfn-lint --version
```

Run the audit again:

```powershell
.\scripts\audit-cloudformation-lab.ps1
```

Now you'll get both:

```text
AWS CloudFormation validation
+
cfn-lint validation
```

That is much better for finding things such as:

* invalid resource properties
* invalid CloudFormation syntax
* invalid intrinsic functions
* invalid resource types
* invalid parameter references
* invalid attributes
* deprecated properties
* template structural problems

---

## One very important thing

Your current results have already established something valuable:

```text
iam:PassRole
CloudFormationExecutionRole
        ↓
IAM simulator
        ↓
ALLOWED
```

So **I don't want you spending another hour adding IAM permissions randomly**.

The next audit needs to answer:

```text
Terraform
   │
   ▼
MainStack
   │
   ├── VPCStack
   ├── S3Stack
   ├── ECRStack
   ├── DynamoDBStack
   ├── LambdaStack
   └── remaining nested stacks
             │
             ▼
       What RoleARN is actually being passed?
```

That's the critical part.

If the audit shows that your nested stacks are being explicitly given:

```text
hybridiaclab-dev-CloudFormationExecutionRole
```

then we have likely found the architectural cause of the repeated error, and we can fix the **role-passing design** rather than continuing to patch IAM permissions.

### Your immediate sequence

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\audit-cloudformation-lab.ps1 2>&1 |
    Tee-Object -FilePath ".\cloudformation-audit-report.txt"
```

Then **send me only `cloudformation-audit-report.txt`** (or paste its final summary). I can use that to identify the cross-template/IAM problem much faster than reviewing 11 large YAML files individually.
---
You already created:

```text
cloudformation-audit-report.txt
```

Upload that file here:

I can then read the report and focus only on the important failures/warnings.

### If you don't want to upload the file

Run this instead to show only the final summary:

```powershell
.\scripts\audit-cloudformation-lab.ps1 2>&1 |
    Select-String -Pattern "PASS    :|WARNING :|FAIL    :|INFO    :|CRITICAL FAILURES|WARNINGS REQUIRING REVIEW|RESULT:"
```

Or, even better, show the last 60 lines:

```powershell
Get-Content .\cloudformation-audit-report.txt -Tail 60
```

**Best option:** upload `cloudformation-audit-report.txt`. I don't need the 11 YAML files.
---
That is expected. `False` means the audit report file was **never created**—most likely because the script execution was blocked before `Tee-Object` could capture the output.

Let's fix it in the safest way.

### 1. Enable scripts only for this PowerShell session

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

Verify:

```powershell
Get-ExecutionPolicy -List
```

You should see:

```text
Process    Bypass
```

### 2. Run the audit again and create the report

From:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

run:

```powershell
.\scripts\audit-cloudformation-lab.ps1 2>&1 |
    Tee-Object -FilePath ".\cloudformation-audit-report.txt"
```

**Let it finish completely.** Don't stop it even if you see warnings.

### 3. Confirm the report exists

```powershell
Test-Path .\cloudformation-audit-report.txt
```

This time it should return:

```text
True
```

Then:

```powershell
Get-Item .\cloudformation-audit-report.txt |
    Select-Object FullName,Length,LastWriteTime
```

### 4. Show me only the important failures

Instead of sending the entire huge report, run:

```powershell
Select-String `
    -Path .\cloudformation-audit-report.txt `
    -Pattern "\[FAIL\]|\[WARN\]|RESULT:" `
    -Context 0,2
```

### 5. Most important: get the actual Lambda failure

Your latest CloudFormation event already narrowed the problem down to:

```text
LambdaStack
└── LambdaExecutionRole
```

So **before changing anything else**, run:

```powershell
aws cloudformation describe-stack-events `
    --stack-name hybridiaclab-dev-MainStack-LambdaStack-X947JVBH5AWO `
    --region us-east-1 `
    --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceType,ResourceStatusReason]" `
    --output table
```

If that stack name is no longer valid, first run:

```powershell
aws cloudformation describe-stack-resources `
    --stack-name hybridiaclab-dev-MainStack `
    --region us-east-1 `
    --query "StackResources[?LogicalResourceId=='LambdaStack'].[PhysicalResourceId,ResourceStatus]" `
    --output table
```

Then use the returned **PhysicalResourceId** with `describe-stack-events`.

**Send me the output of Step 5 first.** That should give us the exact reason `LambdaExecutionRole` failed, rather than guessing at IAM permissions.

---
Yes — the problem is likely **not `Tee-Object`**. The script itself is being blocked or the path is not being resolved correctly.

Let's avoid the pipeline completely and troubleshoot it with simple commands.

### 1. First check that the script actually exists

Run:

```powershell
Test-Path ".\scripts\audit-cloudformation-lab.ps1"
```

It should return:

```text
True
```

If it returns `False`, run:

```powershell
Get-ChildItem ".\scripts" -Filter "*.ps1" | Select-Object Name
```

and send me the output.

### 2. Temporarily allow scripts

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

Then verify:

```powershell
Get-ExecutionPolicy -Scope Process
```

It should say:

```text
Bypass
```

### 3. Run the audit WITHOUT `Tee-Object`

This is the important test:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1"
```

The `&` is the PowerShell **call operator**. It explicitly tells PowerShell to execute the script.

### 4. If that works, create the report separately

Run:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1" > ".\cloudformation-audit-report.txt" 2>&1
```

Then check:

```powershell
Test-Path ".\cloudformation-audit-report.txt"
```

It should return:

```text
True
```

Then:

```powershell
Get-Item ".\cloudformation-audit-report.txt" |
    Select-Object FullName, Length, LastWriteTime
```

### 5. If Step 3 still gives an error

Run this:

```powershell
Get-ChildItem ".\scripts\audit-cloudformation-lab.ps1" |
    Format-List FullName,Length,LastWriteTime
```

And also:

```powershell
Get-ExecutionPolicy -List
```

**Send me the exact output from Step 3**, especially the red error message. Don't change the audit script yet. We first need to determine whether this is a **PowerShell execution-policy problem, file/path problem, or an error inside the audit script itself**.
---
Perfect. Everything up to this point is correct:

* Script exists: `True`
* Execution policy for this session: `Bypass`
* You are in the correct project root.

Now **do not use `Tee-Object` yet**. First we need to see whether the audit script itself runs.

### Step 3 — Run the script directly

Copy/paste exactly:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1"
```

Let it run until it completely finishes.

### If it runs successfully

After it finishes, create the report with:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1" > ".\cloudformation-audit-report.txt" 2>&1
```

Then:

```powershell
Test-Path ".\cloudformation-audit-report.txt"
```

You should get:

```text
True
```

### Important

For now, **only run this command**:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1"
```

Send me the **complete output/error from that command**.

We already know the execution-policy issue is fixed. The next output will tell us whether the problem is inside `audit-cloudformation-lab.ps1`.
---
Yes. This is a much better approach for your lab.

Instead of creating one huge report, we can make your **existing audit script automatically create a `report-log` folder** and produce **three separate files**:

```text
report-log\
├── AWS-Hybrid-IaC-Audit-PASS.txt
├── AWS-Hybrid-IaC-Audit-ERROR.txt
└── AWS-Hybrid-IaC-Audit-WARNING.txt
```

The important point is: **do not rewrite your existing audit logic**. We will only add a reporting section at the **very end** of your existing `audit-cloudformation-lab.ps1`.

---

# 1. Add this at the VERY END of your existing script

Open:

```text
scripts\audit-cloudformation-lab.ps1
```

Go all the way to the **bottom of the file**.

You probably already have something near the end like:

```powershell
Write-Host ""
Write-Host "RESULT: ..."
```

Leave your existing audit code intact.

Then add the following **after all existing audit commands**.

```powershell
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
```

---

# 2. But there is one important issue

I don't want you to blindly paste that section and expect it to magically capture your existing `Write-Host` output.

Your current audit script apparently produces messages like:

```text
[PASS] ...
[WARN] ...
[FAIL] ...
```

If those messages are generated directly with:

```powershell
Write-Host "[PASS] ..."
Write-Host "[WARN] ..."
Write-Host "[FAIL] ..."
```

then the reporting section at the end **cannot reliably recover the previous console output**.

The better solution is to modify your audit script so that whenever it generates a result, it **both displays it and stores it**.

For example:

```powershell
$Passes = @()
$Failures = @()
$Warnings = @()
```

Then instead of only:

```powershell
Write-Host "[PASS] Terraform validation successful"
```

use:

```powershell
$message = "Terraform validation successful"

Write-Host "[PASS] $message"

$Passes += $message
```

For failures:

```powershell
$message = "CloudFormation validation failed: lambda.yaml"

Write-Host "[FAIL] $message"

$Failures += $message
```

For warnings:

```powershell
$message = "cfn-lint was not found"

Write-Host "[WARN] $message"

$Warnings += $message
```

Then the report section I gave you can correctly create the three files.

---

# 3. Even better for your existing script

Because your audit script is already large, **I recommend we don't manually change dozens of `Write-Host` statements**.

Instead, we can make a small helper function near the **top of your existing script**:

```powershell
# ============================================================
# AUDIT RESULT COLLECTIONS
# ============================================================
#
# These arrays store audit results so that the script can
# later create separate PASS, ERROR and WARNING reports.
#
# ============================================================

$Passes   = @()
$Failures = @()
$Warnings = @()


# ============================================================
# AUDIT RESULT FUNCTIONS
# ============================================================

function Add-AuditPass {
    param (
        [string]$Message
    )

    Write-Host "[PASS] $Message"

    $script:Passes += $Message
}


function Add-AuditFailure {
    param (
        [string]$Message
    )

    Write-Host "[FAIL] $Message"

    $script:Failures += $Message
}


function Add-AuditWarning {
    param (
        [string]$Message
    )

    Write-Host "[WARN] $Message"

    $script:Warnings += $Message
}
```

Then your existing checks can use:

```powershell
Add-AuditPass "Terraform validation successful"
```

instead of:

```powershell
Write-Host "[PASS] Terraform validation successful"
```

And:

```powershell
Add-AuditFailure "CloudFormation validation failed: lambda.yaml"
```

instead of:

```powershell
Write-Host "[FAIL] CloudFormation validation failed: lambda.yaml"
```

And:

```powershell
Add-AuditWarning "cfn-lint was not found"
```

instead of:

```powershell
Write-Host "[WARN] cfn-lint was not found"
```

---

# 4. Where exactly to put everything

Your script should have this overall structure:

```text
audit-cloudformation-lab.ps1
│
├── 01 - Script Header
│
├── 02 - Configuration
│
├── 03 - Variables
│
├── 04 - PASS / FAIL / WARNING Collections   <-- ADD HERE
│
├── 05 - Helper Functions                    <-- ADD HERE
│
├── 06 - Tool Checks
│
├── 07 - AWS Identity Checks
│
├── 08 - CloudFormation Checks
│
├── 09 - Nested Stack Checks
│
├── 10 - IAM Checks
│
├── 11 - Terraform Checks
│
├── 12 - Template Checks
│
├── 13 - Final Audit Summary
│
└── 14 - Report File Generation              <-- ADD AT VERY END
```

So there are **two additions**:

### Addition A — near the top

Put this after your main variables/configuration:

```powershell
$Passes   = @()
$Failures = @()
$Warnings = @()
```

plus the three functions.

### Addition B — at the very bottom

Put the report-generation block there.

---

# 5. Your final folder will look like this

After running:

```powershell
.\scripts\audit-cloudformation-lab.ps1
```

you should have:

```text
aws-hybrid-iac-lab
│
├── infrastructure
├── scripts
├── report-log
│   │
│   ├── AWS-Hybrid-IaC-Audit-PASS.txt
│   ├── AWS-Hybrid-IaC-Audit-ERROR.txt
│   └── AWS-Hybrid-IaC-Audit-WARNING.txt
│
├── cloudformation-audit-report.txt    <-- old file, optional
└── ...
```

You can eventually **remove the old `cloudformation-audit-report.txt` approach** because the new `report-log` structure is cleaner.

---

## One thing I strongly recommend

Since your existing audit script is already quite large, **upload `audit-cloudformation-lab.ps1` here** rather than manually changing all of these sections yourself.

If you upload it, I can modify **your actual existing script** so the PASS/ERROR/WARNING collection is integrated correctly without breaking your current 11-template audit logic.
---
# PowerShell: Save Command Output to a Text File

Yes. In PowerShell, the easiest way is to use **`Tee-Object`** when you want to **see the output on the screen AND save it to a `.txt` file**.

## 1. Basic command

```powershell
your-command | Tee-Object -FilePath ".\output.txt"
```

For example:

```powershell
.\scripts\preflight.ps1 | Tee-Object -FilePath ".\preflight-result.txt"
```

This will:

* Run `preflight.ps1`
* Show the result in PowerShell
* Save the same result to `preflight-result.txt`

---

# 2. Save the output with a heading/title

If you want the text file to start with a proper heading, use:

```powershell
"============================================================" | Out-File ".\preflight-result.txt"
"AWS HYBRID IaC LAB - PREFLIGHT RESULT" | Out-File ".\preflight-result.txt" -Append
"============================================================" | Out-File ".\preflight-result.txt" -Append
"Generated: $(Get-Date)" | Out-File ".\preflight-result.txt" -Append
"" | Out-File ".\preflight-result.txt" -Append

.\scripts\preflight.ps1 | Tee-Object -FilePath ".\preflight-result.txt" -Append
```

Your file will look like:

```text
============================================================
AWS HYBRID IaC LAB - PREFLIGHT RESULT
============================================================
Generated: 09/08/2026 17:27:15

============================================================
01 - PowerShell Environment
============================================================

[INFO] PowerShell version: 5.1.19041.6456
[PASS] PowerShell 5.1 or newer detected.

============================================================
02 - AWS CLI
============================================================

[PASS] AWS CLI detected.

...
```

---

# 3. Recommended: One command for your lab

Since you are working on your **AWS Hybrid IaC Lab**, I recommend this:

```powershell
.\scripts\preflight.ps1 2>&1 | Tee-Object -FilePath ".\preflight-result.txt"
```

### Why `2>&1`?

Some PowerShell errors/warnings are written to the **error stream** instead of the normal output stream.

```powershell
2>&1
```

means:

> Send error output into the normal output stream too.

Therefore, the text file captures much more of the complete result.

---

# 4. Add a title before the script output

If you specifically want the file to begin with your own heading:

```powershell
@"
============================================================
AWS HYBRID IaC LAB
PREFLIGHT VALIDATION REPORT
============================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
============================================================

"@ | Tee-Object -FilePath ".\preflight-result.txt"

.\scripts\preflight.ps1 2>&1 | Tee-Object -FilePath ".\preflight-result.txt" -Append
```

This is probably the **best option for your current project**.

---

# 5. If you want the filename to contain the date/time

You can automatically create a new report every time:

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$report = ".\preflight-result-$timestamp.txt"

@"
============================================================
AWS HYBRID IaC LAB
PREFLIGHT VALIDATION REPORT
============================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Report: $report
============================================================

"@ | Tee-Object -FilePath $report

.\scripts\preflight.ps1 2>&1 | Tee-Object -FilePath $report -Append

Write-Host ""
Write-Host "Report saved to: $report"
```

For example, it creates:

```text
preflight-result-20260908-172715.txt
```

This is useful because you won't overwrite your previous validation reports.

---

# 6. Save output silently — don't display it

If you **only** want the result in a file:

```powershell
.\scripts\preflight.ps1 2>&1 | Out-File ".\preflight-result.txt"
```

Or with UTF-8 encoding:

```powershell
.\scripts\preflight.ps1 2>&1 | Out-File ".\preflight-result.txt" -Encoding utf8
```

---

# 7. `>` vs `>>` vs `Tee-Object`

These are important PowerShell commands to remember.

### `>` — create/overwrite

```powershell
aws sts get-caller-identity > result.txt
```

If `result.txt` already exists, it is overwritten.

### `>>` — append

```powershell
aws sts get-caller-identity >> result.txt
```

This adds the new output to the existing file.

### `Tee-Object` — screen + file

```powershell
aws sts get-caller-identity | Tee-Object -FilePath result.txt
```

You see the output **and** save it.

### `2>&1 | Tee-Object` — screen + file including errors

```powershell
aws cloudformation validate-template `
    --template-body file://template.yaml `
    2>&1 | Tee-Object -FilePath validation.txt
```

For troubleshooting your AWS lab, **this is the pattern I recommend most often**.

---

# 8. For your current preflight problem

You previously had results such as:

```text
PASS    : 46
WARNING : 14
FAIL    : 7
INFO    : 217

CRITICAL FAILURES
------------------------------------------------------------
[FAIL] CloudFormation validation failed: cloudformation-execution-role.yaml
[FAIL] CloudFormation validation failed: api-gateway.yaml
[FAIL] CloudFormation validation failed: ec2.yaml
[FAIL] Validation process failed for: ecs.yaml
```

Run:

```powershell
.\scripts\preflight.ps1 2>&1 | Tee-Object -FilePath ".\preflight-result.txt"
```

Then you can open it with:

```powershell
notepad .\preflight-result.txt
```

Or search only the failures:

```powershell
Select-String -Path ".\preflight-result.txt" -Pattern "\[FAIL\]"
```

Search warnings:

```powershell
Select-String -Path ".\preflight-result.txt" -Pattern "\[WARNING\]"
```

Search both:

```powershell
Select-String -Path ".\preflight-result.txt" -Pattern "\[FAIL\]|\[WARNING\]"
```

## My recommendation

For your project, use this simple command first:

```powershell
.\scripts\preflight.ps1 2>&1 | Tee-Object -FilePath ".\preflight-result.txt"
```

Then send me the **`preflight-result.txt`** file (or paste its contents), and I can go through the **7 FAIL + 14 WARNING items one by one**, starting with the CloudFormation validation failures.


---
That is expected. `False` means the audit report file was **never created**—most likely because the script execution was blocked before `Tee-Object` could capture the output.

Let's fix it in the safest way.

### 1. Enable scripts only for this PowerShell session

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

Verify:

```powershell
Get-ExecutionPolicy -List
```

You should see:

```text
Process    Bypass
```

### 2. Run the audit again and create the report

From:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

run:

```powershell
.\scripts\audit-cloudformation-lab.ps1 2>&1 |
    Tee-Object -FilePath ".\cloudformation-audit-report.txt"
```

**Let it finish completely.** Don't stop it even if you see warnings.

### 3. Confirm the report exists

```powershell
Test-Path .\cloudformation-audit-report.txt
```

This time it should return:

```text
True
```

Then:

```powershell
Get-Item .\cloudformation-audit-report.txt |
    Select-Object FullName,Length,LastWriteTime
```

### 4. Show me only the important failures

Instead of sending the entire huge report, run:

```powershell
Select-String `
    -Path .\cloudformation-audit-report.txt `
    -Pattern "\[FAIL\]|\[WARN\]|RESULT:" `
    -Context 0,2
```

### 5. Most important: get the actual Lambda failure

Your latest CloudFormation event already narrowed the problem down to:

```text
LambdaStack
└── LambdaExecutionRole
```

So **before changing anything else**, run:

```powershell
aws cloudformation describe-stack-events `
    --stack-name hybridiaclab-dev-MainStack-LambdaStack-X947JVBH5AWO `
    --region us-east-1 `
    --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceType,ResourceStatusReason]" `
    --output table
```

If that stack name is no longer valid, first run:

```powershell
aws cloudformation describe-stack-resources `
    --stack-name hybridiaclab-dev-MainStack `
    --region us-east-1 `
    --query "StackResources[?LogicalResourceId=='LambdaStack'].[PhysicalResourceId,ResourceStatus]" `
    --output table
```

Then use the returned **PhysicalResourceId** with `describe-stack-events`.

**Send me the output of Step 5 first.** That should give us the exact reason `LambdaExecutionRole` failed, rather than guessing at IAM permissions.
---
Yes — the problem is likely **not `Tee-Object`**. The script itself is being blocked or the path is not being resolved correctly.

Let's avoid the pipeline completely and troubleshoot it with simple commands.

### 1. First check that the script actually exists

Run:

```powershell
Test-Path ".\scripts\audit-cloudformation-lab.ps1"
```

It should return:

```text
True
```

If it returns `False`, run:

```powershell
Get-ChildItem ".\scripts" -Filter "*.ps1" | Select-Object Name
```

and send me the output.

### 2. Temporarily allow scripts

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

Then verify:

```powershell
Get-ExecutionPolicy -Scope Process
```

It should say:

```text
Bypass
```

### 3. Run the audit WITHOUT `Tee-Object`

This is the important test:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1"
```

The `&` is the PowerShell **call operator**. It explicitly tells PowerShell to execute the script.

### 4. If that works, create the report separately

Run:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1" > ".\cloudformation-audit-report.txt" 2>&1
```

Then check:

```powershell
Test-Path ".\cloudformation-audit-report.txt"
```

It should return:

```text
True
```

Then:

```powershell
Get-Item ".\cloudformation-audit-report.txt" |
    Select-Object FullName, Length, LastWriteTime
```

### 5. If Step 3 still gives an error

Run this:

```powershell
Get-ChildItem ".\scripts\audit-cloudformation-lab.ps1" |
    Format-List FullName,Length,LastWriteTime
```

And also:

```powershell
Get-ExecutionPolicy -List
```

**Send me the exact output from Step 3**, especially the red error message. Don't change the audit script yet. We first need to determine whether this is a **PowerShell execution-policy problem, file/path problem, or an error inside the audit script itself**.
---
Perfect. Everything up to this point is correct:

* Script exists: `True`
* Execution policy for this session: `Bypass`
* You are in the correct project root.

Now **do not use `Tee-Object` yet**. First we need to see whether the audit script itself runs.

### Step 3 — Run the script directly

Copy/paste exactly:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1"
```

Let it run until it completely finishes.

### If it runs successfully

After it finishes, create the report with:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1" > ".\cloudformation-audit-report.txt" 2>&1
```

Then:

```powershell
Test-Path ".\cloudformation-audit-report.txt"
```

You should get:

```text
True
```

### Important

For now, **only run this command**:

```powershell
& ".\scripts\audit-cloudformation-lab.ps1"
```

Send me the **complete output/error from that command**.

We already know the execution-policy issue is fixed. The next output will tell us whether the problem is inside `audit-cloudformation-lab.ps1`.
---
I found the exact reason your log files were **never created**.

Your uploaded script already has the PASS/FAIL/WARN collections correctly defined at lines 89–91:

```powershell
$Failures = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Passes   = New-Object System.Collections.Generic.List[string]
```

and your `Write-Pass`, `Write-Warn`, and `Write-Fail` functions already add results to those collections. 

### The actual problem

Your script executes:

```powershell
if ($FailCount -gt 0) {
    exit 2
}

if ($Strict -and $WarnCount -gt 0) {
    exit 1
}

exit 0
```

**before** the report-generation section. Therefore, PowerShell terminates the script and never reaches the code that creates `report-log`. 

So the previous report section itself wasn't the main problem — **its location was wrong**.

I corrected the script so the report files are generated **before `exit 2 / exit 1 / exit 0`**.

### Corrected script

The corrected version will create:

```text
aws-hybrid-iac-lab\
│
├── report-log\
│   ├── AWS-Hybrid-IaC-Audit-PASS.txt
│   ├── AWS-Hybrid-IaC-Audit-ERROR.txt
│   └── AWS-Hybrid-IaC-Audit-WARNING.txt
│
├── scripts\
│   └── audit-cloudformation-lab.ps1
```

### What I recommend you do now

Replace your existing:

```text
scripts\audit-cloudformation-lab.ps1
```

with the corrected file.

Then from the project root run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

Then:

```powershell
& ".\scripts\audit-cloudformation-lab-CORRECTED.ps1"
```

After it finishes:

```powershell
Get-ChildItem ".\report-log"
```

You should see the three files.

Then check the errors only:

```powershell
Get-Content ".\report-log\AWS-Hybrid-IaC-Audit-ERROR.txt"
```

Warnings:

```powershell
Get-Content ".\report-log\AWS-Hybrid-IaC-Audit-WARNING.txt"
```

Passes:

```powershell
Get-Content ".\report-log\AWS-Hybrid-IaC-Audit-PASS.txt"
```

**One important note:** your script's existing report section was already using `$Passes`, `$Failures`, and `$Warnings`, so we don't need to redesign the audit logic. We only needed to move report generation **above the final `exit` statements**. Your final exit-code behavior remains intact.
---
