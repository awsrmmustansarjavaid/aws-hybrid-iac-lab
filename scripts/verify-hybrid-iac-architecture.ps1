#requires -Version 5.1

<#!
.SYNOPSIS
    Verifies the AWS Hybrid IaC Lab architecture after Terraform,
    CloudFormation, Docker/ECR, and GitHub Actions changes.

.DESCRIPTION
    Read-only verification and audit script.

    The script checks:
      1. Required project files
      2. main.yaml architecture
      3. cloudformation.tf architecture
      4. Remaining ecr_image_uri references
      5. Docker/ECR immutable-tag configuration
      6. ECS deployment template configuration
      7. GitHub Actions workflow ordering
      8. Terraform formatting
      9. Terraform validation
     10. CloudFormation template validation
     11. Nested template references
     12. Basic hard-coded secret patterns
     13. Final architecture logic

    The script produces:
      - Console verification output
      - Timestamped verification report
      - Timestamped error/warning log

    IMPORTANT:
      This script DOES NOT:
        - terraform apply
        - terraform destroy
        - create AWS resources
        - delete AWS resources
        - push Docker images
        - deploy ECS
        - modify project files

    It is intended only for verification and auditing.

.NOTES
    File:
        scripts\verify-hybrid-iac-architecture.ps1

    Project:
        aws-hybrid-iac-lab

    Purpose:
        Final architecture verification after separating
        infrastructure bootstrap from Docker/ECS deployment.

.EXAMPLE
    .\verify-hybrid-iac-architecture.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\verify-hybrid-iac-architecture.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\verify-hybrid-iac-architecture.ps1
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

$ScriptStartTime = Get-Date

# ============================================================
# SCRIPT CONFIGURATION
# ============================================================

# $PSScriptRoot points to:
#   aws-hybrid-iac-lab\scripts
# Therefore the project root is one directory above it.
$ProjectRoot = Split-Path -Parent $PSScriptRoot

$TerraformDirectory = Join-Path $ProjectRoot 'infrastructure\terraform'
$CloudFormationDirectory = Join-Path $ProjectRoot 'infrastructure\cloudformation'
$NestedDirectory = Join-Path $CloudFormationDirectory 'nested'
$WorkflowDirectory = Join-Path $ProjectRoot '.github\workflows'

# Reports are stored in scripts\verification-reports.
$ReportDirectory = Join-Path $PSScriptRoot 'verification-reports'
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ReportFile = Join-Path $ReportDirectory "hybrid-iac-verification-$Timestamp.txt"
$IssueLogFile = Join-Path $ReportDirectory "hybrid-iac-errors-warnings-$Timestamp.log"

# ============================================================
# CREATE REPORT DIRECTORY
# ============================================================

if (-not (Test-Path -LiteralPath $ReportDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
}

# ============================================================
# REPORT DATA
# ============================================================

$Results = New-Object System.Collections.Generic.List[Object]
$Errors = New-Object System.Collections.Generic.List[string]
$Warnings = New-Object System.Collections.Generic.List[string]
$Passed = 0
$Failed = 0
$WarningCount = 0

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Add-Result {
    param(
        [Parameter(Mandatory = $true)] [string]$Category,
        [Parameter(Mandatory = $true)] [string]$Check,
        [Parameter(Mandatory = $true)] [ValidateSet('PASS', 'FAIL', 'WARNING')] [string]$Status,
        [Parameter(Mandatory = $true)] [string]$Details
    )

    $script:Results.Add([PSCustomObject]@{
        Category = $Category
        Check    = $Check
        Status   = $Status
        Details  = $Details
    })

    switch ($Status) {
        'PASS' {
            $script:Passed++
        }
        'FAIL' {
            $script:Failed++
            $script:Errors.Add("[$Category] $Check - $Details")
        }
        'WARNING' {
            $script:WarningCount++
            $script:Warnings.Add("[$Category] $Check - $Details")
        }
    }

    # Also show each result immediately in the console.
    switch ($Status) {
        'PASS'    { Write-Host "[PASS]    [$Category] $Check - $Details" }
        'FAIL'    { Write-Host "[FAIL]    [$Category] $Check - $Details" }
        'WARNING' { Write-Host "[WARNING] [$Category] $Check - $Details" }
    }
}

function Test-RequiredFile {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Description
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Add-Result -Category 'FILE' -Check $Description -Status 'PASS' -Details "File exists: $Path"
        return $true
    }

    Add-Result -Category 'FILE' -Check $Description -Status 'FAIL' -Details "Missing file: $Path"
    return $false
}

function Get-FileContentSafe {
    param(
        [Parameter(Mandatory = $true)] [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch {
        Add-Result -Category 'FILE' -Check 'Read file' -Status 'FAIL' -Details "Unable to read: $Path. Error: $($_.Exception.Message)"
        return ''
    }
}

function Test-ContainsText {
    param(
        [string]$Content,
        [string]$Text,
        [string]$CheckName,
        [string]$Category = 'CONFIG'
    )

    if ($Content -match [regex]::Escape($Text)) {
        Add-Result -Category $Category -Check $CheckName -Status 'PASS' -Details "Found expected text: $Text"
        return $true
    }

    Add-Result -Category $Category -Check $CheckName -Status 'FAIL' -Details "Expected text was not found: $Text"
    return $false
}

function Test-NotContainsText {
    param(
        [string]$Content,
        [string]$Text,
        [string]$CheckName,
        [string]$Category = 'CONFIG'
    )

    if ($Content -match [regex]::Escape($Text)) {
        Add-Result -Category $Category -Check $CheckName -Status 'FAIL' -Details "Unexpected text was found: $Text"
        return $false
    }

    Add-Result -Category $Category -Check $CheckName -Status 'PASS' -Details "Unexpected text is absent: $Text"
    return $true
}

function Invoke-SafeCommand {
    param(
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string[]]$Arguments
    )

    try {
        $Output = & $FilePath @Arguments 2>&1
        $ExitCode = $LASTEXITCODE

        return [PSCustomObject]@{
            ExitCode = $ExitCode
            Output   = ($Output | Out-String).Trim()
        }
    }
    catch {
        return [PSCustomObject]@{
            ExitCode = -1
            Output   = $_.Exception.Message
        }
    }
}

function Write-Section {
    param([Parameter(Mandatory = $true)] [string]$Title)

    Write-Host ''
    Write-Host '============================================================'
    Write-Host $Title
    Write-Host '============================================================'
}

# ============================================================
# START REPORT
# ============================================================

$InitialReport = @(
    '============================================================'
    'HYBRID AWS IAC LAB - ARCHITECTURE VERIFICATION REPORT'
    '============================================================'
    ''
    "Project Root: $ProjectRoot"
    "Verification Started: $ScriptStartTime"
    ''
)
$InitialReport | Set-Content -LiteralPath $ReportFile -Encoding UTF8

Write-Host '============================================================'
Write-Host 'HYBRID AWS IAC LAB - ARCHITECTURE VERIFICATION'
Write-Host '============================================================'
Write-Host "Project Root: $ProjectRoot"

# ============================================================
# 1. REQUIRED FILE CHECKS
# ============================================================

Write-Section '1. REQUIRED FILE CHECKS'

$RequiredFiles = @(
    @{ Path = Join-Path $CloudFormationDirectory 'main.yaml'; Description = 'Root CloudFormation template' }
    @{ Path = Join-Path $TerraformDirectory 'cloudformation.tf'; Description = 'Terraform CloudFormation configuration' }
    @{ Path = Join-Path $TerraformDirectory 'variables.tf'; Description = 'Terraform variables' }
    @{ Path = Join-Path $WorkflowDirectory 'main-deploy.yaml'; Description = 'Main deployment workflow' }
    @{ Path = Join-Path $WorkflowDirectory 'terraform.yml'; Description = 'Terraform workflow' }
    @{ Path = Join-Path $WorkflowDirectory 'docker.yml'; Description = 'Docker workflow' }
    @{ Path = Join-Path $WorkflowDirectory 'kubernetes.yml'; Description = 'Kubernetes workflow' }
    @{ Path = Join-Path $NestedDirectory 'ecr.yaml'; Description = 'ECR nested CloudFormation template' }
    @{ Path = Join-Path $NestedDirectory 'ecs.yaml'; Description = 'ECS nested CloudFormation template' }
)

foreach ($RequiredFile in $RequiredFiles) {
    Test-RequiredFile -Path $RequiredFile.Path -Description $RequiredFile.Description | Out-Null
}

# ============================================================
# LOAD IMPORTANT FILES
# ============================================================

$MainYamlPath = Join-Path $CloudFormationDirectory 'main.yaml'
$CloudFormationTfPath = Join-Path $TerraformDirectory 'cloudformation.tf'
$VariablesTfPath = Join-Path $TerraformDirectory 'variables.tf'
$MainDeployPath = Join-Path $WorkflowDirectory 'main-deploy.yaml'
$TerraformWorkflowPath = Join-Path $WorkflowDirectory 'terraform.yml'
$DockerWorkflowPath = Join-Path $WorkflowDirectory 'docker.yml'
$KubernetesWorkflowPath = Join-Path $WorkflowDirectory 'kubernetes.yml'
$EcrYamlPath = Join-Path $NestedDirectory 'ecr.yaml'
$EcsYamlPath = Join-Path $NestedDirectory 'ecs.yaml'

$MainYaml = Get-FileContentSafe -Path $MainYamlPath
$CloudFormationTf = Get-FileContentSafe -Path $CloudFormationTfPath
$VariablesTf = Get-FileContentSafe -Path $VariablesTfPath
$MainDeploy = Get-FileContentSafe -Path $MainDeployPath
$TerraformWorkflow = Get-FileContentSafe -Path $TerraformWorkflowPath
$DockerWorkflow = Get-FileContentSafe -Path $DockerWorkflowPath
$KubernetesWorkflow = Get-FileContentSafe -Path $KubernetesWorkflowPath
$EcrYaml = Get-FileContentSafe -Path $EcrYamlPath
$EcsYaml = Get-FileContentSafe -Path $EcsYamlPath

# ============================================================
# 2. MAIN.YAML ARCHITECTURE CHECK
# ============================================================

Write-Section '2. MAIN.YAML ARCHITECTURE CHECK'

Test-NotContainsText -Content $MainYaml -Text 'EcrImageUri:' -CheckName 'main.yaml must not declare EcrImageUri as a root parameter' -Category 'MAIN.YAML' | Out-Null
Test-NotContainsText -Content $MainYaml -Text 'ECSStack:' -CheckName 'main.yaml must not create ECS during bootstrap' -Category 'MAIN.YAML' | Out-Null
Test-NotContainsText -Content $MainYaml -Text 'ECSStackId:' -CheckName 'main.yaml must not expose ECSStackId from bootstrap' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'ECRStack:' -CheckName 'main.yaml must continue creating the ECR repository' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'ECRRepositoryUri:' -CheckName 'main.yaml must expose ECRRepositoryUri' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'VPCStack:' -CheckName 'main.yaml must create the VPC nested stack' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'S3Stack:' -CheckName 'main.yaml must create the S3 nested stack' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'LambdaStack:' -CheckName 'main.yaml must create the Lambda nested stack' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'EKSStack:' -CheckName 'main.yaml must create the EKS nested stack' -Category 'MAIN.YAML' | Out-Null
Test-ContainsText -Content $MainYaml -Text 'RDSStack:' -CheckName 'main.yaml must create the RDS nested stack' -Category 'MAIN.YAML' | Out-Null

# ============================================================
# 3. CLOUDFORMATION.TF ARCHITECTURE CHECK
# ============================================================

Write-Section '3. CLOUDFORMATION.TF ARCHITECTURE CHECK'

Test-NotContainsText -Content $CloudFormationTf -Text 'EcrImageUri = var.ecr_image_uri' -CheckName 'cloudformation.tf must not pass EcrImageUri' -Category 'TERRAFORM' | Out-Null
Test-ContainsText -Content $CloudFormationTf -Text 'ProjectName = var.project_name' -CheckName 'Terraform must pass ProjectName' -Category 'TERRAFORM' | Out-Null
Test-ContainsText -Content $CloudFormationTf -Text 'Environment = var.environment' -CheckName 'Terraform must pass Environment' -Category 'TERRAFORM' | Out-Null
Test-ContainsText -Content $CloudFormationTf -Text 'AmiId = var.ami_id' -CheckName 'Terraform must pass AmiId' -Category 'TERRAFORM' | Out-Null
Test-ContainsText -Content $CloudFormationTf -Text 'DatabaseUsername = var.database_username' -CheckName 'Terraform must pass DatabaseUsername' -Category 'TERRAFORM' | Out-Null
Test-ContainsText -Content $CloudFormationTf -Text 'DatabasePassword = var.database_password' -CheckName 'Terraform must pass DatabasePassword' -Category 'TERRAFORM' | Out-Null

# ============================================================
# 4. SEARCH FOR ecr_image_uri REFERENCES
# ============================================================

Write-Section '4. SEARCHING FOR ecr_image_uri REFERENCES'

$EcrImageReferences = @()

if (Test-Path -LiteralPath $TerraformDirectory -PathType Container) {
    $EcrImageReferences = @(
        Get-ChildItem -Path $TerraformDirectory -Recurse -File -Include '*.tf', '*.tfvars', '*.tfvars.json' -ErrorAction SilentlyContinue |
            Select-String -Pattern 'ecr_image_uri' -SimpleMatch -ErrorAction SilentlyContinue
    )
}

if ($EcrImageReferences.Count -eq 0) {
    Add-Result -Category 'TERRAFORM' -Check 'No remaining ecr_image_uri references' -Status 'PASS' -Details 'No ecr_image_uri references were found in Terraform files.'
}
else {
    $ReferenceDetails = ($EcrImageReferences | ForEach-Object {
        "{0}:{1}: {2}" -f $_.Path, $_.LineNumber, $_.Line.Trim()
    }) -join ' | '

    Add-Result -Category 'TERRAFORM' -Check 'No remaining ecr_image_uri references' -Status 'WARNING' -Details "References still exist: $ReferenceDetails"
}

# ============================================================
# 5. VARIABLES.TF CHECK
# ============================================================

Write-Section '5. VARIABLES.TF CHECK'

if ($VariablesTf -match 'variable\s+"ecr_image_uri"') {
    Add-Result -Category 'TERRAFORM' -Check 'ecr_image_uri variable cleanup' -Status 'WARNING' -Details 'variables.tf still declares ecr_image_uri. Remove it only after confirming there are no remaining valid references.'
}
else {
    Add-Result -Category 'TERRAFORM' -Check 'ecr_image_uri variable cleanup' -Status 'PASS' -Details 'variables.tf does not declare ecr_image_uri.'
}

# ============================================================
# 6. DOCKER WORKFLOW CHECK
# ============================================================

Write-Section '6. DOCKER WORKFLOW CHECK'

# GitHub Actions normally exposes the commit SHA as github.sha or GITHUB_SHA.
$UsesGitHubSha =
    ($DockerWorkflow -match '\$\{\{\s*github\.sha\s*\}\}') -or
    ($DockerWorkflow -match '\$\{GITHUB_SHA\}') -or
    ($DockerWorkflow -match '\$GITHUB_SHA\b')

if ($UsesGitHubSha) {
    Add-Result -Category 'DOCKER' -Check 'Immutable image tag' -Status 'PASS' -Details 'Docker workflow uses a Git commit SHA for image tagging.'
}
else {
    Add-Result -Category 'DOCKER' -Check 'Immutable image tag' -Status 'WARNING' -Details 'Could not confirm that docker.yml uses GITHUB_SHA or github.sha for image tagging.'
}

# Docker workflow should interact with ECR.
if ((($DockerWorkflow -match 'amazon-ecr-login') -or (($DockerWorkflow -match 'ecr') -and ($DockerWorkflow -match 'login')))) {
    Add-Result -Category 'DOCKER' -Check 'Amazon ECR login' -Status 'PASS' -Details 'Docker workflow contains an Amazon ECR login step.'
}
else {
    Add-Result -Category 'DOCKER' -Check 'Amazon ECR login' -Status 'WARNING' -Details 'Could not confirm an Amazon ECR login step.'
}

# Docker workflow should push an image.
Test-ContainsText -Content $DockerWorkflow -Text 'docker push' -CheckName 'Docker workflow should push the Docker image' -Category 'DOCKER' | Out-Null

# ECR repository should be immutable.
if ($EcrYaml -match 'IMMUTABLE') {
    Add-Result -Category 'ECR' -Check 'ECR repository tag mutability' -Status 'PASS' -Details 'ECR repository is configured as IMMUTABLE.'
}
else {
    Add-Result -Category 'ECR' -Check 'ECR repository tag mutability' -Status 'WARNING' -Details 'Could not confirm IMMUTABLE tag configuration in ecr.yaml.'
}

# With an IMMUTABLE ECR repository, repeatedly pushing :latest can fail.
if ($DockerWorkflow -match 'docker\s+push[\s\S]{0,500}:latest') {
    Add-Result -Category 'DOCKER' -Check 'Immutable ECR latest-tag protection' -Status 'FAIL' -Details 'docker.yml appears to push the latest tag. This can fail with an IMMUTABLE ECR repository.'
}
else {
    Add-Result -Category 'DOCKER' -Check 'Immutable ECR latest-tag protection' -Status 'PASS' -Details 'No obvious docker push of :latest was detected.'
}

# ============================================================
# 7. ECS DEPLOYMENT CHECK
# ============================================================

Write-Section '7. ECS DEPLOYMENT CHECK'

if ($EcsYaml -match 'EcrImageUri:') {
    Add-Result -Category 'ECS' -Check 'ECS template accepts EcrImageUri' -Status 'PASS' -Details 'ecs.yaml still accepts EcrImageUri as an application deployment input.'
}
else {
    Add-Result -Category 'ECS' -Check 'ECS template accepts EcrImageUri' -Status 'WARNING' -Details 'ecs.yaml does not appear to contain an EcrImageUri parameter.'
}

$EcsUsesImageUri =
    ($EcsYaml -match 'Image:\s*!Ref\s+EcrImageUri') -or
    ($EcsYaml -match 'Image:\s*\r?\n\s*Ref:\s*EcrImageUri') -or
    ($EcsYaml -match 'Image:.*EcrImageUri')

if ($EcsUsesImageUri) {
    Add-Result -Category 'ECS' -Check 'ECS task definition uses EcrImageUri' -Status 'PASS' -Details 'ECS task definition appears to use EcrImageUri.'
}
else {
    Add-Result -Category 'ECS' -Check 'ECS task definition uses EcrImageUri' -Status 'WARNING' -Details 'Could not confirm that the ECS container image uses EcrImageUri.'
}

# ============================================================
# 8. MAIN DEPLOYMENT ORDER CHECK
# ============================================================

Write-Section '8. MAIN DEPLOYMENT ORDER CHECK'

if ($MainDeploy -match 'terraform') {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Terraform job exists' -Status 'PASS' -Details 'main-deploy.yaml references Terraform.'
}
else {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Terraform job exists' -Status 'FAIL' -Details 'Terraform workflow reference was not detected.'
}

if ($MainDeploy -match 'docker') {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Docker job exists' -Status 'PASS' -Details 'main-deploy.yaml references Docker.'
}
else {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Docker job exists' -Status 'FAIL' -Details 'Docker workflow reference was not detected.'
}

if ($MainDeploy -match 'kubernetes') {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Kubernetes job exists' -Status 'PASS' -Details 'main-deploy.yaml references Kubernetes.'
}
else {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Kubernetes job exists' -Status 'WARNING' -Details 'Kubernetes workflow reference was not detected.'
}

# Accept common GitHub Actions forms such as:
#   docker:
#     needs: terraform
# and
#   docker:
#     needs: [terraform]
$DockerDependsOnTerraform =
    ($MainDeploy -match '(?ms)^\s*docker\s*:.*?^\s*needs\s*:\s*terraform\b') -or
    ($MainDeploy -match '(?ms)^\s*docker\s*:.*?^\s*needs\s*:\s*\[.*terraform.*\]') -or
    ($MainDeploy -match '(?ms)^\s*docker\s*:.*?^\s*needs\s*:\s*\(.*terraform.*\)')

if ($DockerDependsOnTerraform) {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Docker runs after Terraform' -Status 'PASS' -Details 'Docker job depends on Terraform.'
}
else {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Docker runs after Terraform' -Status 'WARNING' -Details 'Could not confirm that the Docker job explicitly depends on Terraform.'
}

$KubernetesDependsOnDocker =
    ($MainDeploy -match '(?ms)^\s*kubernetes\s*:.*?^\s*needs\s*:\s*docker\b') -or
    ($MainDeploy -match '(?ms)^\s*kubernetes\s*:.*?^\s*needs\s*:\s*\[.*docker.*\]') -or
    ($MainDeploy -match '(?ms)^\s*kubernetes\s*:.*?^\s*needs\s*:\s*\(.*docker.*\)')

if ($KubernetesDependsOnDocker) {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Kubernetes runs after Docker' -Status 'PASS' -Details 'Kubernetes job depends on Docker.'
}
else {
    Add-Result -Category 'GITHUB ACTIONS' -Check 'Kubernetes runs after Docker' -Status 'WARNING' -Details 'Could not confirm that Kubernetes depends on Docker.'
}

# ============================================================
# 9. TERRAFORM FORMAT CHECK
# ============================================================

Write-Section '9. TERRAFORM FORMAT CHECK'

$TerraformCommand = Get-Command terraform -ErrorAction SilentlyContinue

if ($null -eq $TerraformCommand) {
    Add-Result -Category 'TERRAFORM' -Check 'Terraform executable' -Status 'WARNING' -Details 'Terraform is not available in PATH. terraform fmt/validate checks were skipped.'
}
elseif (-not (Test-Path -LiteralPath $TerraformDirectory -PathType Container)) {
    Add-Result -Category 'TERRAFORM' -Check 'Terraform directory' -Status 'FAIL' -Details "Terraform directory does not exist: $TerraformDirectory"
}
else {
    Push-Location $TerraformDirectory
    try {
        $FmtResult = Invoke-SafeCommand -FilePath 'terraform' -Arguments @('fmt', '-check', '-recursive')

        if ($FmtResult.ExitCode -eq 0) {
            Add-Result -Category 'TERRAFORM' -Check 'terraform fmt -check' -Status 'PASS' -Details 'Terraform files are formatted correctly.'
        }
        else {
            Add-Result -Category 'TERRAFORM' -Check 'terraform fmt -check' -Status 'FAIL' -Details "Terraform formatting check failed. Output: $($FmtResult.Output)"
        }
    }
    finally {
        Pop-Location
    }
}

# ============================================================
# 10. TERRAFORM VALIDATION
# ============================================================

Write-Section '10. TERRAFORM VALIDATION'

if ($null -eq $TerraformCommand) {
    Add-Result -Category 'TERRAFORM' -Check 'terraform validate' -Status 'WARNING' -Details 'Terraform executable is unavailable. Validation was skipped.'
}
elseif (-not (Test-Path -LiteralPath $TerraformDirectory -PathType Container)) {
    Add-Result -Category 'TERRAFORM' -Check 'terraform validate' -Status 'FAIL' -Details "Terraform directory does not exist: $TerraformDirectory"
}
else {
    Push-Location $TerraformDirectory
    try {
        $ValidateResult = Invoke-SafeCommand -FilePath 'terraform' -Arguments @('validate')

        if ($ValidateResult.ExitCode -eq 0) {
            Add-Result -Category 'TERRAFORM' -Check 'terraform validate' -Status 'PASS' -Details 'Terraform configuration is valid.'
        }
        else {
            Add-Result -Category 'TERRAFORM' -Check 'terraform validate' -Status 'FAIL' -Details "Terraform validation failed. Output: $($ValidateResult.Output)"
        }
    }
    finally {
        Pop-Location
    }
}

# ============================================================
# 11. CLOUDFORMATION VALIDATION
# ============================================================

Write-Section '11. CLOUDFORMATION VALIDATION'

$AwsCommand = Get-Command aws -ErrorAction SilentlyContinue

if ($null -eq $AwsCommand) {
    Add-Result -Category 'AWS CLI' -Check 'AWS CLI executable' -Status 'WARNING' -Details 'AWS CLI is not available in PATH. CloudFormation validation was skipped.'
}
else {
    $CloudFormationFiles = @(
        (Join-Path $CloudFormationDirectory 'main.yaml')
        (Join-Path $NestedDirectory 'vpc.yaml')
        (Join-Path $NestedDirectory 's3.yaml')
        (Join-Path $NestedDirectory 'dynamodb.yaml')
        (Join-Path $NestedDirectory 'ecr.yaml')
        (Join-Path $NestedDirectory 'lambda.yaml')
        (Join-Path $NestedDirectory 'api-gateway.yaml')
        (Join-Path $NestedDirectory 'cloudfront.yaml')
        (Join-Path $NestedDirectory 'ec2.yaml')
        (Join-Path $NestedDirectory 'ecs.yaml')
        (Join-Path $NestedDirectory 'eks.yaml')
        (Join-Path $NestedDirectory 'rds.yaml')
    )

    foreach ($Template in $CloudFormationFiles) {
        if (-not (Test-Path -LiteralPath $Template -PathType Leaf)) {
            continue
        }

        $TemplateName = Split-Path -Path $Template -Leaf
        $ValidationResult = Invoke-SafeCommand -FilePath 'aws' -Arguments @(
            'cloudformation'
            'validate-template'
            '--template-body'
            "file://$Template"
        )

        if ($ValidationResult.ExitCode -eq 0) {
            Add-Result -Category 'CLOUDFORMATION' -Check "Validate $TemplateName" -Status 'PASS' -Details "$TemplateName passed AWS CloudFormation template validation."
        }
        else {
            Add-Result -Category 'CLOUDFORMATION' -Check "Validate $TemplateName" -Status 'FAIL' -Details "$TemplateName failed validation. Output: $($ValidationResult.Output)"
        }
    }
}

# ============================================================
# 12. TEMPLATE REFERENCE CHECK
# ============================================================

Write-Section '12. TEMPLATE REFERENCE CHECK'

$ExpectedNestedTemplates = @(
    'vpc.yaml'
    's3.yaml'
    'dynamodb.yaml'
    'ecr.yaml'
    'lambda.yaml'
    'api-gateway.yaml'
    'cloudfront.yaml'
    'ec2.yaml'
    'ecs.yaml'
    'eks.yaml'
    'rds.yaml'
)

foreach ($TemplateName in $ExpectedNestedTemplates) {
    $TemplatePath = Join-Path $NestedDirectory $TemplateName

    if (Test-Path -LiteralPath $TemplatePath -PathType Leaf) {
        Add-Result -Category 'CLOUDFORMATION' -Check "Nested template $TemplateName" -Status 'PASS' -Details 'Nested template exists.'
    }
    else {
        Add-Result -Category 'CLOUDFORMATION' -Check "Nested template $TemplateName" -Status 'FAIL' -Details 'Nested template is missing.'
    }
}

# ============================================================
# 13. ROOT MAIN.YAML ECR OUTPUT CHECK
# ============================================================

Write-Section '13. ECR OUTPUT CHECK'

if (
    ($MainYaml -match 'ECRStack:') -and
    ($MainYaml -match 'ECRRepositoryUri:') -and
    ($MainYaml -match 'GetAtt\s+ECRStack\.Outputs\.RepositoryUri')
) {
    Add-Result -Category 'ARCHITECTURE' -Check 'ECR repository output flow' -Status 'PASS' -Details 'main.yaml exposes the ECR repository URI from ECRStack.'
}
else {
    Add-Result -Category 'ARCHITECTURE' -Check 'ECR repository output flow' -Status 'FAIL' -Details 'Could not confirm the ECR repository URI output flow.'
}

# ============================================================
# 14. ECS BOOTSTRAP SEPARATION CHECK
# ============================================================

Write-Section '14. ECS BOOTSTRAP SEPARATION CHECK'

# Search for an actual ECSStack resource definition, not merely the word ECS.
if ($MainYaml -match '(?m)^\s*ECSStack\s*:') {
    Add-Result -Category 'ARCHITECTURE' -Check 'ECS bootstrap separation' -Status 'FAIL' -Details 'An ECSStack resource definition was detected in main.yaml. ECS should be deployed separately.'
}
else {
    Add-Result -Category 'ARCHITECTURE' -Check 'ECS bootstrap separation' -Status 'PASS' -Details 'No ECSStack resource definition was detected in main.yaml.'
}

# ============================================================
# 15. BASIC SECRET CHECK
# ============================================================

Write-Section '15. BASIC SECRET CHECK'

$FilesToScan = @(
    $CloudFormationTfPath
    $MainDeployPath
    $TerraformWorkflowPath
    $DockerWorkflowPath
    $KubernetesWorkflowPath
)

# These are intentionally basic patterns, not a replacement for a real secret scanner.
$PossibleSecretPatterns = @(
    'AKIA[0-9A-Z]{16}'
    'aws_secret_access_key\s*='
    'AWS_SECRET_ACCESS_KEY\s*=\s*["'']?[A-Za-z0-9/+=]+'
    'password\s*=\s*["''][^"'']+["'']'
)

$SecretFinding = $false

foreach ($File in $FilesToScan) {
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        continue
    }

    $Content = Get-FileContentSafe -Path $File

    foreach ($Pattern in $PossibleSecretPatterns) {
        if ($Content -match $Pattern) {
            $SecretFinding = $true
            Add-Result -Category 'SECURITY' -Check 'Possible hard-coded secret' -Status 'WARNING' -Details "Potential credential/secret pattern detected in $File. Review manually."
        }
    }
}

if (-not $SecretFinding) {
    Add-Result -Category 'SECURITY' -Check 'Hard-coded secret pattern scan' -Status 'PASS' -Details 'No obvious hard-coded credential patterns were detected in the scanned files.'
}

# ============================================================
# 16. FINAL ARCHITECTURE LOGIC CHECK
# ============================================================

Write-Section '16. FINAL ARCHITECTURE LOGIC CHECK'

$BootstrapCorrect =
    ($MainYaml -notmatch 'EcrImageUri:') -and
    ($MainYaml -notmatch '(?m)^\s*ECSStack\s*:') -and
    ($CloudFormationTf -notmatch 'EcrImageUri\s*=\s*var\.ecr_image_uri')

if ($BootstrapCorrect) {
    Add-Result -Category 'ARCHITECTURE' -Check 'Bootstrap does not require Docker image' -Status 'PASS' -Details 'Terraform/CloudFormation bootstrap no longer requires EcrImageUri or creates ECS.'
}
else {
    Add-Result -Category 'ARCHITECTURE' -Check 'Bootstrap does not require Docker image' -Status 'FAIL' -Details 'Bootstrap still contains an ECR image dependency or ECS resource.'
}

# ============================================================
# BUILD FINAL REPORT DATA
# ============================================================

$ScriptEndTime = Get-Date
$Duration = $ScriptEndTime - $ScriptStartTime

# ============================================================
# DETERMINE FINAL RESULT
# ============================================================

if ($Failed -eq 0) {
    if ($WarningCount -eq 0) {
        $FinalResult = 'PASS - ARCHITECTURE VERIFICATION SUCCESSFUL'
    }
    else {
        $FinalResult = 'PASS WITH WARNINGS - REVIEW WARNINGS BEFORE DEPLOYMENT'
    }
}
else {
    $FinalResult = 'FAIL - ARCHITECTURE VERIFICATION FAILED'
}

# ============================================================
# CONSOLE SUMMARY
# ============================================================

Write-Host ''
Write-Host '============================================================'
Write-Host 'FINAL VERIFICATION RESULT'
Write-Host '============================================================'
Write-Host ''
Write-Host "Passed Checks : $Passed"
Write-Host "Failed Checks : $Failed"
Write-Host "Warnings      : $WarningCount"
Write-Host "Duration      : $($Duration.ToString())"
Write-Host ''
Write-Host $FinalResult

# ============================================================
# WRITE DETAILED REPORT
# ============================================================

$ReportLines = New-Object System.Collections.Generic.List[string]

$ReportLines.Add('============================================================')
$ReportLines.Add('HYBRID AWS IAC LAB - ARCHITECTURE VERIFICATION REPORT')
$ReportLines.Add('============================================================')
$ReportLines.Add('')
$ReportLines.Add("Project Root: $ProjectRoot")
$ReportLines.Add("Verification Started: $ScriptStartTime")
$ReportLines.Add("Verification Finished: $ScriptEndTime")
$ReportLines.Add("Duration: $($Duration.ToString())")
$ReportLines.Add('')
$ReportLines.Add("FINAL RESULT: $FinalResult")
$ReportLines.Add('')
$ReportLines.Add("Passed Checks : $Passed")
$ReportLines.Add("Failed Checks : $Failed")
$ReportLines.Add("Warnings      : $WarningCount")
$ReportLines.Add('')
$ReportLines.Add('============================================================')
$ReportLines.Add('DETAILED CHECK RESULTS')
$ReportLines.Add('============================================================')

foreach ($Result in $Results) {
    $ReportLines.Add('[{0}] [{1}] {2} - {3}' -f $Result.Status, $Result.Category, $Result.Check, $Result.Details)
}

# ============================================================
# ERROR SECTION
# ============================================================

$ReportLines.Add('')
$ReportLines.Add('============================================================')
$ReportLines.Add('ERROR LOG')
$ReportLines.Add('============================================================')

if ($Errors.Count -eq 0) {
    $ReportLines.Add('No errors detected.')
}
else {
    foreach ($ErrorMessage in $Errors) {
        $ReportLines.Add("[ERROR] $ErrorMessage")
    }
}

# ============================================================
# WARNING SECTION
# ============================================================

$ReportLines.Add('')
$ReportLines.Add('============================================================')
$ReportLines.Add('WARNING LOG')
$ReportLines.Add('============================================================')

if ($Warnings.Count -eq 0) {
    $ReportLines.Add('No warnings detected.')
}
else {
    foreach ($WarningMessage in $Warnings) {
        $ReportLines.Add("[WARNING] $WarningMessage")
    }
}

# ============================================================
# EXPECTED DEPLOYMENT ARCHITECTURE
# ============================================================

$ReportLines.Add('')
$ReportLines.Add('============================================================')
$ReportLines.Add('EXPECTED DEPLOYMENT ARCHITECTURE')
$ReportLines.Add('============================================================')
$ReportLines.Add('')
$ReportLines.Add('PHASE 1 - INFRASTRUCTURE')
$ReportLines.Add('Terraform')
$ReportLines.Add(' -> CloudFormation Template S3 Bucket')
$ReportLines.Add(' -> Root CloudFormation Stack')
$ReportLines.Add(' -> VPC')
$ReportLines.Add(' -> S3')
$ReportLines.Add(' -> DynamoDB')
$ReportLines.Add(' -> ECR Repository')
$ReportLines.Add(' -> Lambda')
$ReportLines.Add(' -> API Gateway')
$ReportLines.Add(' -> CloudFront')
$ReportLines.Add(' -> EC2')
$ReportLines.Add(' -> EKS')
$ReportLines.Add(' -> RDS')
$ReportLines.Add('')
$ReportLines.Add('PHASE 2 - APPLICATION DEPLOYMENT')
$ReportLines.Add('GitHub Actions')
$ReportLines.Add(' -> Docker Build')
$ReportLines.Add(' -> ECR Login')
$ReportLines.Add(' -> Push immutable image using Git commit SHA')
$ReportLines.Add(' -> ECS Deployment')
$ReportLines.Add('')
$ReportLines.Add('IMPORTANT:')
$ReportLines.Add('ECR repository creation must happen before Docker push.')
$ReportLines.Add('Docker image must exist before ECS application deployment.')
$ReportLines.Add('Immutable ECR tags should use commit SHA values.')
$ReportLines.Add('ECS should receive the image URI during application deployment.')
$ReportLines.Add('')
$ReportLines.Add('============================================================')
$ReportLines.Add('END OF VERIFICATION REPORT')
$ReportLines.Add('============================================================')

$ReportLines | Set-Content -LiteralPath $ReportFile -Encoding UTF8

# ============================================================
# SAVE ERROR/WARNING LOG
# ============================================================

$IssueLines = New-Object System.Collections.Generic.List[string]
$IssueLines.Add('HYBRID AWS IAC LAB - ERROR AND WARNING LOG')
$IssueLines.Add("Generated: $ScriptEndTime")
$IssueLines.Add('')
$IssueLines.Add("FINAL RESULT: $FinalResult")
$IssueLines.Add('')
$IssueLines.Add('ERRORS')
$IssueLines.Add('------')

if ($Errors.Count -eq 0) {
    $IssueLines.Add('No errors detected.')
}
else {
    foreach ($ErrorMessage in $Errors) {
        $IssueLines.Add("[ERROR] $ErrorMessage")
    }
}

$IssueLines.Add('')
$IssueLines.Add('WARNINGS')
$IssueLines.Add('--------')

if ($Warnings.Count -eq 0) {
    $IssueLines.Add('No warnings detected.')
}
else {
    foreach ($WarningMessage in $Warnings) {
        $IssueLines.Add("[WARNING] $WarningMessage")
    }
}

$IssueLines | Set-Content -LiteralPath $IssueLogFile -Encoding UTF8

# ============================================================
# FINAL FILE LOCATIONS
# ============================================================

Write-Host ''
Write-Host '============================================================'
Write-Host 'REPORT FILES'
Write-Host '============================================================'
Write-Host ''
Write-Host "Full verification report:"
Write-Host $ReportFile
Write-Host ''
Write-Host "Errors and warnings log:"
Write-Host $IssueLogFile
Write-Host ''
Write-Host '============================================================'
Write-Host 'SCRIPT COMPLETE'
Write-Host '============================================================'

# ============================================================
# EXIT CODE
# ============================================================
# 0 = PASS
# 0 = PASS WITH WARNINGS
# 1 = FAIL
# Suitable for future CI/CD usage.
# ============================================================

if ($Failed -eq 0) {
    exit 0
}
else {
    exit 1
}
