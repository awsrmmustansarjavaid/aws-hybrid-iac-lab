# ✅ Final Merged PowerShell Verification Script

I merged the functionality of all **three scripts** into one consolidated verification/audit script.

The merged script below is designed for **Windows PowerShell 5.1+**, keeps the verification read-only, produces a **complete console summary**, and creates separate **timestamped verification and issue reports**.

### Merged script name

> **Recommended filename:** `aws-hybrid-iac-verification-lab.ps1`

You wrote `.psl` in the request, but PowerShell scripts use the **`.ps1`** extension. I therefore used `.ps1`.

### What the merged script verifies

* AWS CLI installation and AWS authentication
* AWS account and caller identity
* AWS region
* GitHub OIDC provider
* OIDC URL and audience
* GitHub Actions IAM role
* IAM trust policy
* Repository and branch restrictions
* GitHub Actions IAM policy
* Policy attachment
* Policy version/document
* `iam:PassRole`
* CloudFormation, S3, EC2, IAM, ECR, EKS, RDS and Lambda permissions
* Terraform installation
* Terraform directory/files
* Terraform AWS provider
* Terraform region configuration
* `terraform fmt -check`
* `terraform init -backend=false`
* `terraform validate`
* Required CloudFormation templates
* Recursive CloudFormation discovery
* AWS CloudFormation validation
* Required GitHub Actions workflows
* `workflow_call`
* GitHub OIDC `id-token: write`
* `AWS_REGION`
* `AWS_ROLE_ARN`
* `configure-aws-credentials@v4`
* `main.yaml` architecture
* `cloudformation.tf` architecture
* `ecr_image_uri` cleanup
* ECR immutable tags
* Docker SHA tagging
* Docker → ECR push
* ECS `EcrImageUri`
* Terraform → Docker → Kubernetes workflow dependencies
* Nested CloudFormation references
* Hard-coded secret patterns
* Bootstrap/ECS separation
* Final architecture logic
* Detailed PASS / FAIL / WARNING report
* Separate error/warning log
* Timestamped report files
* CI/CD-friendly exit code

#requires -Version 5.1

# <#

AWS HYBRID IaC LAB
COMPLETE AWS + TERRAFORM + CLOUDFORMATION + GITHUB OIDC
ARCHITECTURE VERIFICATION AND AUDIT SCRIPT
==========================================

File:
scripts\aws-hybrid-iac-verification-lab.ps1

Project:
aws-hybrid-iac-lab

Purpose:
This script merges the verification functionality of:

```
    1. verify-github-aws-oidc.ps1
    2. verify-hybrid-iac-templates.ps1
    3. verify-hybrid-iac-architecture.ps1

into one complete verification and audit script.
```

=======================================================================
IMPORTANT - READ BEFORE RUNNING
===============================

This script is READ-ONLY with respect to AWS infrastructure.

It DOES NOT:

```
- terraform apply
- terraform destroy
- aws cloudformation deploy
- aws cloudformation create-stack
- aws cloudformation delete-stack
- push Docker images
- deploy ECS
- modify Terraform files
- modify CloudFormation files
- modify GitHub workflows
```

The only local files created by this script are verification reports
inside:

```
scripts\verification-reports
```

=======================================================================
VALIDATION AREAS
================

AWS / IAM / GITHUB OIDC
1. AWS CLI
2. AWS authentication
3. AWS account
4. AWS region
5. GitHub OIDC provider
6. OIDC URL
7. OIDC audience
8. GitHub Actions IAM role
9. IAM trust policy
10. Repository restriction
11. Branch restriction
12. GitHub Actions IAM policy
13. Policy attachment
14. Policy default version
15. Policy document
16. iam:PassRole
17. CloudFormation permissions
18. S3 permissions
19. EC2 permissions
20. IAM permissions
21. ECR permissions
22. EKS permissions
23. RDS permissions
24. Lambda permissions

TERRAFORM
25. Terraform installation
26. Terraform directory
27. Terraform files
28. AWS provider
29. AWS region
30. Terraform formatting
31. Terraform initialization without backend
32. Terraform validation
33. ecr_image_uri cleanup

CLOUDFORMATION
34. CloudFormation directory
35. YAML template discovery
36. Required nested templates
37. AWS CloudFormation validation
38. Root stack architecture

GITHUB ACTIONS
39. main-deploy.yaml
40. terraform.yml
41. docker.yml
42. kubernetes.yml
43. workflow_call
44. id-token: write
45. AWS_REGION
46. AWS_ROLE_ARN
47. configure-aws-credentials@v4
48. Terraform -> Docker dependency
49. Docker -> Kubernetes dependency

DOCKER / ECR / ECS
50. GitHub SHA image tag
51. ECR login
52. docker push
53. ECR IMMUTABLE configuration
54. latest-tag protection
55. ECS EcrImageUri parameter
56. ECS image usage

ARCHITECTURE / SECURITY
57. ECR output flow
58. ECS bootstrap separation
59. Hard-coded secret scan
60. Final architecture logic

=======================================================================
EXPECTED ARCHITECTURE
=====================

PHASE 1 - INFRASTRUCTURE BOOTSTRAP

```
GitHub Actions
      |
      v
  Terraform
      |
      v
Root CloudFormation Stack
      |
      +--> VPC
      +--> S3
      +--> DynamoDB
      +--> ECR
      +--> Lambda
      +--> API Gateway
      +--> CloudFront
      +--> EC2
      +--> EKS
      +--> RDS
```

PHASE 2 - APPLICATION DEPLOYMENT

```
GitHub Actions
      |
      v
  Docker Build
      |
      v
   ECR Login
      |
      v
Push SHA-tagged image
      |
      v
   ECS Deployment
      |
      v
   ECS Service
```

IMPORTANT:

```
ECR repository creation happens during infrastructure bootstrap.

Docker image creation happens after ECR exists.

ECS application deployment happens after the Docker image exists.

Immutable ECR tags should use Git commit SHA values.
```

=======================================================================
PowerShell:
Windows PowerShell 5.1+

Recommended execution:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\aws-hybrid-iac-verification-lab.ps1

=======================================================================
#>

# =====================================================================

# POWERSHELL SAFETY SETTINGS

# =====================================================================

Set-StrictMode -Version 2.0

# Continue after individual verification failures.

# The script should produce a complete report instead of stopping

# after the first failed check.

$ErrorActionPreference = 'Continue'

# =====================================================================

# SCRIPT START TIME

# =====================================================================

$ScriptStartTime = Get-Date

# =====================================================================

# PROJECT PATH CONFIGURATION

# =====================================================================

# The script is expected to live inside:

#

# <project-root>\scripts

#

# Therefore the project root is one directory above $PSScriptRoot.

$ScriptsDirectory = $PSScriptRoot

$ProjectRoot = Split-Path -Parent $ScriptsDirectory

# ---------------------------------------------------------------------

# Terraform

# ---------------------------------------------------------------------

$TerraformDirectory = Join-Path `    $ProjectRoot`
'infrastructure\terraform'

# ---------------------------------------------------------------------

# CloudFormation

# ---------------------------------------------------------------------

$CloudFormationDirectory = Join-Path `    $ProjectRoot`
'infrastructure\cloudformation'

$NestedDirectory = Join-Path `    $CloudFormationDirectory`
'nested'

# ---------------------------------------------------------------------

# GitHub Actions

# ---------------------------------------------------------------------

$WorkflowDirectory = Join-Path `    $ProjectRoot`
'.github\workflows'

# ---------------------------------------------------------------------

# Verification reports

# ---------------------------------------------------------------------

$ReportDirectory = Join-Path `    $PSScriptRoot`
'verification-reports'

$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$ReportFile = Join-Path `    $ReportDirectory`
"aws-hybrid-iac-verification-$Timestamp.txt"

$IssueLogFile = Join-Path `    $ReportDirectory`
"aws-hybrid-iac-errors-warnings-$Timestamp.log"

# =====================================================================

# NORMALIZE IMPORTANT PATHS

# =====================================================================

$TerraformDirectoryFull = [System.IO.Path]::GetFullPath(
$TerraformDirectory
)

$CloudFormationDirectoryFull = [System.IO.Path]::GetFullPath(
$CloudFormationDirectory
)

$NestedDirectoryFull = [System.IO.Path]::GetFullPath(
$NestedDirectory
)

$WorkflowDirectoryFull = [System.IO.Path]::GetFullPath(
$WorkflowDirectory
)

# =====================================================================

# IAM / GITHUB CONFIGURATION

# =====================================================================

# ---------------------------------------------------------------------

# GitHub Actions IAM role

# ---------------------------------------------------------------------

$ExpectedRoleName = 'aws-hybrid-iac-lab-GitHubActions'

# ---------------------------------------------------------------------

# Customer-managed IAM policy

# ---------------------------------------------------------------------

$ExpectedPolicyName = 'aws-hybrid-iac-lab-GitHubActionsPolicy'

# ---------------------------------------------------------------------

# GitHub repository

# ---------------------------------------------------------------------

$ExpectedGitHubRepository = 'awsrmmustansarjavaid/aws-hybrid-iac-lab'

# ---------------------------------------------------------------------

# GitHub branch

# ---------------------------------------------------------------------

$ExpectedGitHubBranch = 'main'

# ---------------------------------------------------------------------

# AWS region

# ---------------------------------------------------------------------

$ExpectedAwsRegion = 'us-east-1'

# ---------------------------------------------------------------------

# GitHub OIDC provider

# ---------------------------------------------------------------------

$ExpectedOidcUrl = '[https://token.actions.githubusercontent.com](https://token.actions.githubusercontent.com)'

# ---------------------------------------------------------------------

# AWS STS audience

# ---------------------------------------------------------------------

$ExpectedOidcAudience = 'sts.amazonaws.com'

# =====================================================================

# RESULT STORAGE

# =====================================================================

$Results = New-Object System.Collections.Generic.List[Object]

$Errors = New-Object System.Collections.Generic.List[string]

$Warnings = New-Object System.Collections.Generic.List[string]

$Passed = 0

$Failed = 0

$WarningCount = 0

# =====================================================================

# INITIALIZE DATA VARIABLES

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

$MainYaml = ''

$CloudFormationTf = ''

$VariablesTf = ''

$MainDeploy = ''

$TerraformWorkflow = ''

$DockerWorkflow = ''

$KubernetesWorkflow = ''

$EcrYaml = ''

$EcsYaml = ''

$TerraformText = ''

$TerraformFiles = @()

$CloudFormationTemplates = @()

# =====================================================================

# CREATE REPORT DIRECTORY

# =====================================================================

try {

```
if (
    -not (
        Test-Path `
            -LiteralPath $ReportDirectory `
            -PathType Container
    )
) {

    New-Item `
        -ItemType Directory `
        -Path $ReportDirectory `
        -Force |
        Out-Null
}
```

}
catch {

```
Write-Host ''
Write-Host 'ERROR: Could not create verification report directory.' `
    -ForegroundColor Red

Write-Host $_.Exception.Message `
    -ForegroundColor Red

exit 1
```

}

# =====================================================================

# HELPER FUNCTION - WRITE SECTION

# =====================================================================

function Write-Section {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Title
)

Write-Host ''
Write-Host '=======================================================================' `
    -ForegroundColor Cyan

Write-Host " $Title" `
    -ForegroundColor Cyan

Write-Host '=======================================================================' `
    -ForegroundColor Cyan
```

}

# =====================================================================

# HELPER FUNCTION - WRITE CHECK

# =====================================================================

function Write-Check {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Name
)

Write-Host ''
Write-Host "[CHECK] $Name" `
    -ForegroundColor Yellow
```

}

# =====================================================================

# HELPER FUNCTION - PASS

# =====================================================================

function Write-Pass {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$script:Passed++

$script:Results.Add(
    [PSCustomObject]@{
        Category = 'GENERAL'
        Check    = $Message
        Status   = 'PASS'
        Details  = $Message
    }
)

Write-Host "[PASS] $Message" `
    -ForegroundColor Green
```

}

# =====================================================================

# HELPER FUNCTION - FAIL

# =====================================================================

function Write-Fail {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$script:Failed++

$script:Errors.Add($Message)

$script:Results.Add(
    [PSCustomObject]@{
        Category = 'GENERAL'
        Check    = $Message
        Status   = 'FAIL'
        Details  = $Message
    }
)

Write-Host "[FAIL] $Message" `
    -ForegroundColor Red
```

}

# =====================================================================

# HELPER FUNCTION - WARNING

# =====================================================================

function Write-Warn {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Message
)

$script:WarningCount++

$script:Warnings.Add($Message)

$script:Results.Add(
    [PSCustomObject]@{
        Category = 'GENERAL'
        Check    = $Message
        Status   = 'WARNING'
        Details  = $Message
    }
)

Write-Host "[WARNING] $Message" `
    -ForegroundColor DarkYellow
```

}

# =====================================================================

# HELPER FUNCTION - STRUCTURED RESULT

# =====================================================================

function Add-Result {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Category,

    [Parameter(Mandatory = $true)]
    [string]$Check,

    [Parameter(Mandatory = $true)]
    [ValidateSet('PASS', 'FAIL', 'WARNING')]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$Details
)

$script:Results.Add(
    [PSCustomObject]@{
        Category = $Category
        Check    = $Check
        Status   = $Status
        Details  = $Details
    }
)

switch ($Status) {

    'PASS' {

        $script:Passed++

        Write-Host `
            "[PASS]    [$Category] $Check - $Details" `
            -ForegroundColor Green
    }

    'FAIL' {

        $script:Failed++

        $script:Errors.Add(
            "[$Category] $Check - $Details"
        )

        Write-Host `
            "[FAIL]    [$Category] $Check - $Details" `
            -ForegroundColor Red
    }

    'WARNING' {

        $script:WarningCount++

        $script:Warnings.Add(
            "[$Category] $Check - $Details"
        )

        Write-Host `
            "[WARNING] [$Category] $Check - $Details" `
            -ForegroundColor DarkYellow
    }
}
```

}

# =====================================================================

# HELPER FUNCTION - COMMAND EXISTS

# =====================================================================

function Test-CommandExists {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName
)

return $null -ne (
    Get-Command `
        $CommandName `
        -ErrorAction SilentlyContinue
)
```

}

# =====================================================================

# HELPER FUNCTION - SAFE FILE READ

# =====================================================================

function Get-FileContentSafe {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

if (
    -not (
        Test-Path `
            -LiteralPath $Path `
            -PathType Leaf
    )
) {

    return ''
}

try {

    return Get-Content `
        -LiteralPath $Path `
        -Raw `
        -ErrorAction Stop
}
catch {

    Add-Result `
        -Category 'FILE' `
        -Check 'Read file' `
        -Status 'FAIL' `
        -Details "Unable to read '$Path'. Error: $($_.Exception.Message)"

    return ''
}
```

}

# =====================================================================

# HELPER FUNCTION - REQUIRED FILE

# =====================================================================

function Test-RequiredFile {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Description
)

if (
    Test-Path `
        -LiteralPath $Path `
        -PathType Leaf
) {

    Add-Result `
        -Category 'FILE' `
        -Check $Description `
        -Status 'PASS' `
        -Details "File exists: $Path"

    return $true
}

Add-Result `
    -Category 'FILE' `
    -Check $Description `
    -Status 'FAIL' `
    -Details "Missing file: $Path"

return $false
```

}

# =====================================================================

# HELPER FUNCTION - TEXT MUST EXIST

# =====================================================================

function Test-ContainsText {

```
param(
    [string]$Content,

    [string]$Text,

    [string]$CheckName,

    [string]$Category = 'CONFIG'
)

if (
    -not [string]::IsNullOrEmpty($Content) -and
    $Content -match [regex]::Escape($Text)
) {

    Add-Result `
        -Category $Category `
        -Check $CheckName `
        -Status 'PASS' `
        -Details "Found expected text: $Text"

    return $true
}

Add-Result `
    -Category $Category `
    -Check $CheckName `
    -Status 'FAIL' `
    -Details "Expected text was not found: $Text"

return $false
```

}

# =====================================================================

# HELPER FUNCTION - TEXT MUST NOT EXIST

# =====================================================================

function Test-NotContainsText {

```
param(
    [string]$Content,

    [string]$Text,

    [string]$CheckName,

    [string]$Category = 'CONFIG'
)

if (
    -not [string]::IsNullOrEmpty($Content) -and
    $Content -match [regex]::Escape($Text)
) {

    Add-Result `
        -Category $Category `
        -Check $CheckName `
        -Status 'FAIL' `
        -Details "Unexpected text was found: $Text"

    return $false
}

Add-Result `
    -Category $Category `
    -Check $CheckName `
    -Status 'PASS' `
    -Details "Unexpected text is absent: $Text"

return $true
```

}

# =====================================================================

# HELPER FUNCTION - SAFE EXTERNAL COMMAND

# =====================================================================

function Invoke-SafeCommand {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
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
```

}

# =====================================================================

# HELPER FUNCTION - URL DECODE AWS IAM DOCUMENT

# =====================================================================

function Convert-IamDocumentToJson {

```
param(
    [Parameter(Mandatory = $true)]
    [string]$Document
)

if (
    [string]::IsNullOrWhiteSpace($Document)
) {

    return $null
}

try {

    # AWS IAM policy documents can sometimes be returned URL encoded.
    $DecodedDocument = [System.Net.WebUtility]::UrlDecode(
        $Document
    )

    return $DecodedDocument | ConvertFrom-Json
}
catch {

    try {

        return $Document | ConvertFrom-Json
    }
    catch {

        return $null
    }
}
```

}

# =====================================================================

# HELPER FUNCTION - EXTRACT POLICY JSON

# =====================================================================

function Get-PolicySearchJson {

```
param(
    [Parameter(Mandatory = $true)]
    $PolicyDocument
)

try {

    return (
        $PolicyDocument |
        ConvertTo-Json -Depth 50
    )
}
catch {

    return ''
}
```

}

# =====================================================================

# HEADER

# =====================================================================

Clear-Host

Write-Host ''
Write-Host '#######################################################################' `
-ForegroundColor Cyan

Write-Host '#                                                                     #' `
-ForegroundColor Cyan

Write-Host '#        AWS HYBRID IaC LAB - COMPLETE VERIFICATION                  #' `
-ForegroundColor Cyan

Write-Host '#                                                                     #' `
-ForegroundColor Cyan

Write-Host '#######################################################################' `
-ForegroundColor Cyan

Write-Host ''

Write-Host 'Repository : ' -ForegroundColor Yellow -NoNewline
Write-Host $ExpectedGitHubRepository

Write-Host 'Branch     : ' -ForegroundColor Yellow -NoNewline
Write-Host $ExpectedGitHubBranch

Write-Host 'AWS Region : ' -ForegroundColor Yellow -NoNewline
Write-Host $ExpectedAwsRegion

Write-Host 'IAM Role   : ' -ForegroundColor Yellow -NoNewline
Write-Host $ExpectedRoleName

Write-Host 'IAM Policy : ' -ForegroundColor Yellow -NoNewline
Write-Host $ExpectedPolicyName

Write-Host ''

Write-Host 'Project Root:' -ForegroundColor Cyan
Write-Host "    $ProjectRoot"

Write-Host ''

Write-Host 'Terraform Directory:' -ForegroundColor Cyan
Write-Host "    $TerraformDirectoryFull"

Write-Host ''

Write-Host 'CloudFormation Directory:' -ForegroundColor Cyan
Write-Host "    $CloudFormationDirectoryFull"

Write-Host ''

Write-Host 'GitHub Workflow Directory:' -ForegroundColor Cyan
Write-Host "    $WorkflowDirectoryFull"

# =====================================================================

# START REPORT FILE

# =====================================================================

$InitialReport = @(
'======================================================================='
'AWS HYBRID IaC LAB - COMPLETE VERIFICATION REPORT'
'======================================================================='
''
"Project Root: $ProjectRoot"
"Verification Started: $ScriptStartTime"
''
"Expected Repository: $ExpectedGitHubRepository"
"Expected Branch: $ExpectedGitHubBranch"
"Expected AWS Region: $ExpectedAwsRegion"
"Expected IAM Role: $ExpectedRoleName"
"Expected IAM Policy: $ExpectedPolicyName"
''
)

$InitialReport |
Set-Content `        -LiteralPath $ReportFile`
-Encoding UTF8

# =====================================================================

# SECTION 1 - REQUIRED PROJECT DIRECTORIES

# =====================================================================

Write-Section '1. REQUIRED PROJECT DIRECTORIES'

$TerraformDirectoryExists =
Test-Path `        -LiteralPath $TerraformDirectoryFull`
-PathType Container

$CloudFormationDirectoryExists =
Test-Path `        -LiteralPath $CloudFormationDirectoryFull`
-PathType Container

$WorkflowDirectoryExists =
Test-Path `        -LiteralPath $WorkflowDirectoryFull`
-PathType Container

if ($TerraformDirectoryExists) {

```
Add-Result `
    -Category 'DIRECTORY' `
    -Check 'Terraform directory' `
    -Status 'PASS' `
    -Details $TerraformDirectoryFull
```

}
else {

```
Add-Result `
    -Category 'DIRECTORY' `
    -Check 'Terraform directory' `
    -Status 'FAIL' `
    -Details "Missing directory: $TerraformDirectoryFull"
```

}

if ($CloudFormationDirectoryExists) {

```
Add-Result `
    -Category 'DIRECTORY' `
    -Check 'CloudFormation directory' `
    -Status 'PASS' `
    -Details $CloudFormationDirectoryFull
```

}
else {

```
Add-Result `
    -Category 'DIRECTORY' `
    -Check 'CloudFormation directory' `
    -Status 'FAIL' `
    -Details "Missing directory: $CloudFormationDirectoryFull"
```

}

if ($WorkflowDirectoryExists) {

```
Add-Result `
    -Category 'DIRECTORY' `
    -Check 'GitHub Actions workflow directory' `
    -Status 'PASS' `
    -Details $WorkflowDirectoryFull
```

}
else {

```
Add-Result `
    -Category 'DIRECTORY' `
    -Check 'GitHub Actions workflow directory' `
    -Status 'FAIL' `
    -Details "Missing directory: $WorkflowDirectoryFull"
```

}

# =====================================================================

# SECTION 2 - REQUIRED PROJECT FILES

# =====================================================================

Write-Section '2. REQUIRED PROJECT FILES'

$MainYamlPath = Join-Path `    $CloudFormationDirectoryFull`
'main.yaml'

$CloudFormationTfPath = Join-Path `    $TerraformDirectoryFull`
'cloudformation.tf'

$VariablesTfPath = Join-Path `    $TerraformDirectoryFull`
'variables.tf'

$MainDeployPath = Join-Path `    $WorkflowDirectoryFull`
'main-deploy.yaml'

$TerraformWorkflowPath = Join-Path `    $WorkflowDirectoryFull`
'terraform.yml'

$DockerWorkflowPath = Join-Path `    $WorkflowDirectoryFull`
'docker.yml'

$KubernetesWorkflowPath = Join-Path `    $WorkflowDirectoryFull`
'kubernetes.yml'

$EcrYamlPath = Join-Path `    $NestedDirectoryFull`
'ecr.yaml'

$EcsYamlPath = Join-Path `    $NestedDirectoryFull`
'ecs.yaml'

$RequiredFiles = @(
@{
Path = $MainYamlPath
Description = 'Root CloudFormation template'
}
@{
Path = $CloudFormationTfPath
Description = 'Terraform CloudFormation configuration'
}
@{
Path = $VariablesTfPath
Description = 'Terraform variables'
}
@{
Path = $MainDeployPath
Description = 'Main deployment workflow'
}
@{
Path = $TerraformWorkflowPath
Description = 'Terraform workflow'
}
@{
Path = $DockerWorkflowPath
Description = 'Docker workflow'
}
@{
Path = $KubernetesWorkflowPath
Description = 'Kubernetes workflow'
}
@{
Path = $EcrYamlPath
Description = 'ECR nested CloudFormation template'
}
@{
Path = $EcsYamlPath
Description = 'ECS nested CloudFormation template'
}
)

foreach ($RequiredFile in $RequiredFiles) {

```
Test-RequiredFile `
    -Path $RequiredFile.Path `
    -Description $RequiredFile.Description |
    Out-Null
```

}

# =====================================================================

# LOAD IMPORTANT FILES

# =====================================================================

$MainYaml = Get-FileContentSafe `
-Path $MainYamlPath

$CloudFormationTf = Get-FileContentSafe `
-Path $CloudFormationTfPath

$VariablesTf = Get-FileContentSafe `
-Path $VariablesTfPath

$MainDeploy = Get-FileContentSafe `
-Path $MainDeployPath

$TerraformWorkflow = Get-FileContentSafe `
-Path $TerraformWorkflowPath

$DockerWorkflow = Get-FileContentSafe `
-Path $DockerWorkflowPath

$KubernetesWorkflow = Get-FileContentSafe `
-Path $KubernetesWorkflowPath

$EcrYaml = Get-FileContentSafe `
-Path $EcrYamlPath

$EcsYaml = Get-FileContentSafe `
-Path $EcsYamlPath

# =====================================================================

# SECTION 3 - AWS CLI

# =====================================================================

Write-Section '3. AWS CLI AND AWS ACCOUNT'

Write-Check 'AWS CLI installation'

if (Test-CommandExists 'aws') {

```
$AwsVersionResult = Invoke-SafeCommand `
    -FilePath 'aws' `
    -Arguments @('--version')

if ($AwsVersionResult.ExitCode -eq 0) {

    Add-Result `
        -Category 'AWS CLI' `
        -Check 'AWS CLI installation' `
        -Status 'PASS' `
        -Details $AwsVersionResult.Output

}
else {

    Add-Result `
        -Category 'AWS CLI' `
        -Check 'AWS CLI installation' `
        -Status 'FAIL' `
        -Details 'AWS CLI exists but could not execute.'
}
```

}
else {

```
Add-Result `
    -Category 'AWS CLI' `
    -Check 'AWS CLI installation' `
    -Status 'FAIL' `
    -Details 'AWS CLI is not installed or is not available in PATH.'
```

}

# =====================================================================

# AWS CALLER IDENTITY

# =====================================================================

if (Test-CommandExists 'aws') {

```
Write-Check 'AWS caller identity'

$CallerIdentityResult = Invoke-SafeCommand `
    -FilePath 'aws' `
    -Arguments @(
        'sts'
        'get-caller-identity'
        '--output'
        'json'
    )

if ($CallerIdentityResult.ExitCode -eq 0) {

    try {

        $CallerIdentity =
            $CallerIdentityResult.Output |
            ConvertFrom-Json

        $AWSAccountId = $CallerIdentity.Account

        $CallerArn = $CallerIdentity.Arn

        Add-Result `
            -Category 'AWS' `
            -Check 'AWS authentication' `
            -Status 'PASS' `
            -Details "Account: $AWSAccountId | ARN: $CallerArn"

    }
    catch {

        Add-Result `
            -Category 'AWS' `
            -Check 'AWS authentication' `
            -Status 'FAIL' `
            -Details 'AWS returned an unexpected caller identity response.'
    }

}
else {

    Add-Result `
        -Category 'AWS' `
        -Check 'AWS authentication' `
        -Status 'FAIL' `
        -Details $CallerIdentityResult.Output
}
```

}
else {

```
Add-Result `
    -Category 'AWS' `
    -Check 'AWS authentication' `
    -Status 'FAIL' `
    -Details 'Cannot check AWS identity because AWS CLI is unavailable.'
```

}

# =====================================================================

# SECTION 4 - AWS REGION

# =====================================================================

Write-Section '4. AWS REGION'

$AwsRegionEnvironment = $env:AWS_REGION

if (
[string]::IsNullOrWhiteSpace(
$AwsRegionEnvironment
)
) {

```
Add-Result `
    -Category 'AWS' `
    -Check 'AWS_REGION environment variable' `
    -Status 'WARNING' `
    -Details "AWS_REGION is not set locally. Expected region: $ExpectedAwsRegion"
```

}
elseif (
$AwsRegionEnvironment -eq $ExpectedAwsRegion
) {

```
Add-Result `
    -Category 'AWS' `
    -Check 'AWS_REGION environment variable' `
    -Status 'PASS' `
    -Details "AWS_REGION matches $ExpectedAwsRegion"
```

}
else {

```
Add-Result `
    -Category 'AWS' `
    -Check 'AWS_REGION environment variable' `
    -Status 'WARNING' `
    -Details "AWS_REGION is '$AwsRegionEnvironment'; expected '$ExpectedAwsRegion'"
```

}

# =====================================================================

# SECTION 5 - GITHUB OIDC PROVIDER

# =====================================================================

Write-Section '5. GITHUB OIDC PROVIDER'

if (
-not [string]::IsNullOrWhiteSpace(
$AWSAccountId
)
) {

```
$OidcProviderArn =
    "arn:aws:iam::$AWSAccountId`:oidc-provider/token.actions.githubusercontent.com"

Write-Check 'GitHub OIDC provider'

$OidcResult = Invoke-SafeCommand `
    -FilePath 'aws' `
    -Arguments @(
        'iam'
        'get-open-id-connect-provider'
        '--open-id-connect-provider-arn'
        $OidcProviderArn
        '--output'
        'json'
    )

if ($OidcResult.ExitCode -eq 0) {

    try {

        $OidcProvider =
            $OidcResult.Output |
            ConvertFrom-Json

        Add-Result `
            -Category 'OIDC' `
            -Check 'GitHub OIDC provider exists' `
            -Status 'PASS' `
            -Details $OidcProviderArn

    }
    catch {

        Add-Result `
            -Category 'OIDC' `
            -Check 'GitHub OIDC provider parsing' `
            -Status 'FAIL' `
            -Details $_.Exception.Message
    }

}
else {

    Add-Result `
        -Category 'OIDC' `
        -Check 'GitHub OIDC provider exists' `
        -Status 'FAIL' `
        -Details $OidcResult.Output
}
```

}
else {

```
Add-Result `
    -Category 'OIDC' `
    -Check 'GitHub OIDC provider' `
    -Status 'FAIL' `
    -Details 'AWS account ID is unavailable.'
```

}

# =====================================================================

# OIDC URL

# =====================================================================

if ($null -ne $OidcProvider) {

```
Write-Check 'OIDC provider URL'

if (
    $OidcProvider.Url -eq $ExpectedOidcUrl
) {

    Add-Result `
        -Category 'OIDC' `
        -Check 'OIDC provider URL' `
        -Status 'PASS' `
        -Details $OidcProvider.Url

}
else {

    Add-Result `
        -Category 'OIDC' `
        -Check 'OIDC provider URL' `
        -Status 'FAIL' `
        -Details "Found '$($OidcProvider.Url)' but expected '$ExpectedOidcUrl'"
}


# -----------------------------------------------------------------
# OIDC AUDIENCE
# -----------------------------------------------------------------

Write-Check 'OIDC audience'

$AudienceFound = $false

if ($null -ne $OidcProvider.ClientIDList) {

    foreach ($ClientId in $OidcProvider.ClientIDList) {

        if (
            $ClientId -eq $ExpectedOidcAudience
        ) {

            $AudienceFound = $true

            break
        }
    }
}

if ($AudienceFound) {

    Add-Result `
        -Category 'OIDC' `
        -Check 'OIDC audience' `
        -Status 'PASS' `
        -Details $ExpectedOidcAudience

}
else {

    Add-Result `
        -Category 'OIDC' `
        -Check 'OIDC audience' `
        -Status 'FAIL' `
        -Details "Expected audience '$ExpectedOidcAudience' was not found."
}
```

}

# =====================================================================

# SECTION 6 - IAM ROLE

# =====================================================================

Write-Section '6. GITHUB ACTIONS IAM ROLE'

$RoleResult = Invoke-SafeCommand `    -FilePath 'aws'`
-Arguments @(
'iam'
'get-role'
'--role-name'
$ExpectedRoleName
'--output'
'json'
)

if ($RoleResult.ExitCode -eq 0) {

```
try {

    $Role =
        $RoleResult.Output |
        ConvertFrom-Json

    $RoleArn = $Role.Role.Arn

    Add-Result `
        -Category 'IAM' `
        -Check 'GitHub Actions IAM role exists' `
        -Status 'PASS' `
        -Details "Role: $ExpectedRoleName | ARN: $RoleArn"

}
catch {

    Add-Result `
        -Category 'IAM' `
        -Check 'GitHub Actions IAM role parsing' `
        -Status 'FAIL' `
        -Details $_.Exception.Message
}
```

}
else {

```
Add-Result `
    -Category 'IAM' `
    -Check 'GitHub Actions IAM role exists' `
    -Status 'FAIL' `
    -Details $RoleResult.Output
```

}

# =====================================================================

# SECTION 7 - IAM TRUST POLICY

# =====================================================================

Write-Section '7. IAM TRUST POLICY'

if ($null -ne $Role) {

```
$TrustPolicyDocument =
    Convert-IamDocumentToJson `
        -Document (
            $Role.Role.AssumeRolePolicyDocument |
            ConvertTo-Json -Depth 50 -Compress
        )

$TrustJson =
    Get-PolicySearchJson `
        -PolicyDocument $TrustPolicyDocument

if (
    [string]::IsNullOrWhiteSpace(
        $TrustJson
    )
) {

    # Fall back to direct JSON if AWS already returned a normal object.
    $TrustJson =
        $Role.Role.AssumeRolePolicyDocument |
        ConvertTo-Json -Depth 50
}


# -----------------------------------------------------------------
# AssumeRoleWithWebIdentity
# -----------------------------------------------------------------

if (
    $TrustJson -match 'AssumeRoleWithWebIdentity'
) {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'AssumeRoleWithWebIdentity' `
        -Status 'PASS' `
        -Details 'Trust policy allows GitHub OIDC web identity federation.'

}
else {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'AssumeRoleWithWebIdentity' `
        -Status 'FAIL' `
        -Details 'Trust policy does not contain AssumeRoleWithWebIdentity.'
}


# -----------------------------------------------------------------
# GitHub OIDC provider
# -----------------------------------------------------------------

if (
    $TrustJson -match `
        [regex]::Escape(
            'token.actions.githubusercontent.com'
        )
) {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'GitHub OIDC provider' `
        -Status 'PASS' `
        -Details 'GitHub OIDC provider is referenced.'

}
else {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'GitHub OIDC provider' `
        -Status 'FAIL' `
        -Details 'GitHub OIDC provider is not referenced.'
}


# -----------------------------------------------------------------
# Audience
# -----------------------------------------------------------------

if (
    $TrustJson -match `
        [regex]::Escape(
            $ExpectedOidcAudience
        )
) {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'OIDC audience condition' `
        -Status 'PASS' `
        -Details $ExpectedOidcAudience

}
else {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'OIDC audience condition' `
        -Status 'FAIL' `
        -Details 'sts.amazonaws.com was not found in the trust policy.'
}


# -----------------------------------------------------------------
# Repository
# -----------------------------------------------------------------

if (
    $TrustJson -match `
        [regex]::Escape(
            $ExpectedGitHubRepository
        )
) {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'GitHub repository restriction' `
        -Status 'PASS' `
        -Details $ExpectedGitHubRepository

}
else {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'GitHub repository restriction' `
        -Status 'FAIL' `
        -Details "Repository '$ExpectedGitHubRepository' was not found."
}


# -----------------------------------------------------------------
# Branch
# -----------------------------------------------------------------

$ExpectedSubject =
    "repo:$ExpectedGitHubRepository`:ref:refs/heads/$ExpectedGitHubBranch"

if (
    $TrustJson -match `
        [regex]::Escape(
            $ExpectedSubject
        )
) {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'GitHub branch restriction' `
        -Status 'PASS' `
        -Details $ExpectedSubject

}
else {

    Add-Result `
        -Category 'IAM TRUST' `
        -Check 'GitHub branch restriction' `
        -Status 'WARNING' `
        -Details "Could not confirm exact subject restriction: $ExpectedSubject"
}
```

}

# =====================================================================

# SECTION 8 - IAM POLICY

# =====================================================================

Write-Section '8. GITHUB ACTIONS IAM POLICY'

$PolicyResult = Invoke-SafeCommand `    -FilePath 'aws'`
-Arguments @(
'iam'
'list-policies'
'--scope'
'Local'
'--output'
'json'
)

if ($PolicyResult.ExitCode -eq 0) {

```
try {

    $LocalPolicies =
        $PolicyResult.Output |
        ConvertFrom-Json

    $MatchingPolicies = @(
        $LocalPolicies.Policies |
        Where-Object {
            $_.PolicyName -eq $ExpectedPolicyName
        }
    )

    if ($MatchingPolicies.Count -gt 0) {

        $Policy = $MatchingPolicies[0]

        $PolicyArn = $Policy.Arn

        Add-Result `
            -Category 'IAM POLICY' `
            -Check 'Customer-managed policy exists' `
            -Status 'PASS' `
            -Details "Policy: $ExpectedPolicyName | ARN: $PolicyArn"

    }
    else {

        Add-Result `
            -Category 'IAM POLICY' `
            -Check 'Customer-managed policy exists' `
            -Status 'FAIL' `
            -Details "Policy '$ExpectedPolicyName' was not found."
    }

}
catch {

    Add-Result `
        -Category 'IAM POLICY' `
        -Check 'Customer-managed policy parsing' `
        -Status 'FAIL' `
        -Details $_.Exception.Message
}
```

}
else {

```
Add-Result `
    -Category 'IAM POLICY' `
    -Check 'Customer-managed policy lookup' `
    -Status 'FAIL' `
    -Details $PolicyResult.Output
```

}

# =====================================================================

# POLICY ATTACHMENT

# =====================================================================

if ($null -ne $Role) {

```
$AttachedPolicyResult = Invoke-SafeCommand `
    -FilePath 'aws' `
    -Arguments @(
        'iam'
        'list-attached-role-policies'
        '--role-name'
        $ExpectedRoleName
        '--output'
        'json'
    )

if ($AttachedPolicyResult.ExitCode -eq 0) {

    try {

        $AttachedPolicies =
            $AttachedPolicyResult.Output |
            ConvertFrom-Json

        $PolicyAttached = @(
            $AttachedPolicies.AttachedPolicies |
            Where-Object {
                $_.PolicyName -eq $ExpectedPolicyName
            }
        )

        if ($PolicyAttached.Count -gt 0) {

            Add-Result `
                -Category 'IAM POLICY' `
                -Check 'Policy attachment' `
                -Status 'PASS' `
                -Details "Policy is attached to $ExpectedRoleName"

        }
        else {

            Add-Result `
                -Category 'IAM POLICY' `
                -Check 'Policy attachment' `
                -Status 'FAIL' `
                -Details "Policy '$ExpectedPolicyName' is not attached to the role."
        }

    }
    catch {

        Add-Result `
            -Category 'IAM POLICY' `
            -Check 'Policy attachment parsing' `
            -Status 'FAIL' `
            -Details $_.Exception.Message
    }

}
else {

    Add-Result `
        -Category 'IAM POLICY' `
        -Check 'Policy attachment lookup' `
        -Status 'FAIL' `
        -Details $AttachedPolicyResult.Output
}
```

}

# =====================================================================

# SECTION 9 - IAM POLICY PERMISSIONS

# =====================================================================

Write-Section '9. IAM POLICY PERMISSIONS'

if (
-not [string]::IsNullOrWhiteSpace(
$PolicyArn
)
) {

```
# -----------------------------------------------------------------
# Default policy version
# -----------------------------------------------------------------

$PolicyVersionResult = Invoke-SafeCommand `
    -FilePath 'aws' `
    -Arguments @(
        'iam'
        'get-policy'
        '--policy-arn'
        $PolicyArn
        '--query'
        'Policy.DefaultVersionId'
        '--output'
        'text'
    )

if ($PolicyVersionResult.ExitCode -eq 0) {

    $PolicyVersion =
        $PolicyVersionResult.Output.Trim()

    Add-Result `
        -Category 'IAM POLICY' `
        -Check 'Default policy version' `
        -Status 'PASS' `
        -Details "Default version: $PolicyVersion"

}
else {

    Add-Result `
        -Category 'IAM POLICY' `
        -Check 'Default policy version' `
        -Status 'FAIL' `
        -Details $PolicyVersionResult.Output
}


# -----------------------------------------------------------------
# Policy document
# -----------------------------------------------------------------

if (
    -not [string]::IsNullOrWhiteSpace(
        $PolicyVersion
    )
) {

    $PolicyDocumentResult = Invoke-SafeCommand `
        -FilePath 'aws' `
        -Arguments @(
            'iam'
            'get-policy-version'
            '--policy-arn'
            $PolicyArn
            '--version-id'
            $PolicyVersion
            '--query'
            'PolicyVersion.Document'
            '--output'
            'json'
        )

    if ($PolicyDocumentResult.ExitCode -eq 0) {

        $PolicyDocument =
            Convert-IamDocumentToJson `
                -Document $PolicyDocumentResult.Output

        if ($null -ne $PolicyDocument) {

            $PolicyJson =
                Get-PolicySearchJson `
                    -PolicyDocument $PolicyDocument

            Add-Result `
                -Category 'IAM POLICY' `
                -Check 'Policy document' `
                -Status 'PASS' `
                -Details 'IAM policy document was successfully read and parsed.'

        }
        else {

            Add-Result `
                -Category 'IAM POLICY' `
                -Check 'Policy document' `
                -Status 'FAIL' `
                -Details 'IAM policy document could not be parsed.'
        }

    }
    else {

        Add-Result `
            -Category 'IAM POLICY' `
            -Check 'Policy document' `
            -Status 'FAIL' `
            -Details $PolicyDocumentResult.Output
    }
}


# -----------------------------------------------------------------
# Permission helper checks
# -----------------------------------------------------------------

if (
    -not [string]::IsNullOrWhiteSpace(
        $PolicyJson
    )
) {

    # =============================================================
    # IAM PASSROLE
    # =============================================================

    if (
        ($PolicyJson -match 'iam:PassRole') -or
        ($PolicyJson -match 'iam:\*')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'iam:PassRole' `
            -Status 'PASS' `
            -Details 'iam:PassRole capability detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'iam:PassRole' `
            -Status 'FAIL' `
            -Details 'iam:PassRole was not detected.'
    }


    # =============================================================
    # CLOUDFORMATION
    # =============================================================

    if (
        ($PolicyJson -match 'cloudformation:\*') -or
        ($PolicyJson -match 'cloudformation:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'CloudFormation permissions' `
            -Status 'PASS' `
            -Details 'CloudFormation permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'CloudFormation permissions' `
            -Status 'WARNING' `
            -Details 'CloudFormation permissions were not detected.'
    }


    # =============================================================
    # S3
    # =============================================================

    if (
        ($PolicyJson -match 's3:\*') -or
        ($PolicyJson -match 's3:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'S3 permissions' `
            -Status 'PASS' `
            -Details 'S3 permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'S3 permissions' `
            -Status 'WARNING' `
            -Details 'S3 permissions were not detected.'
    }


    # =============================================================
    # EC2
    # =============================================================

    if (
        ($PolicyJson -match 'ec2:\*') -or
        ($PolicyJson -match 'ec2:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'EC2 permissions' `
            -Status 'PASS' `
            -Details 'EC2 permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'EC2 permissions' `
            -Status 'WARNING' `
            -Details 'EC2 permissions were not detected.'
    }


    # =============================================================
    # IAM
    # =============================================================

    if (
        ($PolicyJson -match 'iam:\*') -or
        ($PolicyJson -match 'iam:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'IAM permissions' `
            -Status 'PASS' `
            -Details 'IAM permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'IAM permissions' `
            -Status 'WARNING' `
            -Details 'IAM permissions were not detected.'
    }


    # =============================================================
    # ECR
    # =============================================================

    if (
        ($PolicyJson -match 'ecr:\*') -or
        ($PolicyJson -match 'ecr:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'ECR permissions' `
            -Status 'PASS' `
            -Details 'ECR permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'ECR permissions' `
            -Status 'WARNING' `
            -Details 'ECR permissions were not detected.'
    }


    # =============================================================
    # EKS
    # =============================================================

    if (
        ($PolicyJson -match 'eks:\*') -or
        ($PolicyJson -match 'eks:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'EKS permissions' `
            -Status 'PASS' `
            -Details 'EKS permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'EKS permissions' `
            -Status 'WARNING' `
            -Details 'EKS permissions were not detected.'
    }


    # =============================================================
    # RDS
    # =============================================================

    if (
        ($PolicyJson -match 'rds:\*') -or
        ($PolicyJson -match 'rds:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'RDS permissions' `
            -Status 'PASS' `
            -Details 'RDS permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'RDS permissions' `
            -Status 'WARNING' `
            -Details 'RDS permissions were not detected.'
    }


    # =============================================================
    # LAMBDA
    # =============================================================

    if (
        ($PolicyJson -match 'lambda:\*') -or
        ($PolicyJson -match 'lambda:')
    ) {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'Lambda permissions' `
            -Status 'PASS' `
            -Details 'Lambda permissions detected.'

    }
    else {

        Add-Result `
            -Category 'IAM PERMISSIONS' `
            -Check 'Lambda permissions' `
            -Status 'WARNING' `
            -Details 'Lambda permissions were not detected.'
    }
}
```

}

# =====================================================================

# SECTION 10 - TERRAFORM INSTALLATION

# =====================================================================

Write-Section '10. TERRAFORM INSTALLATION'

$TerraformCommand =
Get-Command `        terraform`
-ErrorAction SilentlyContinue

if ($null -eq $TerraformCommand) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'Terraform installation' `
    -Status 'FAIL' `
    -Details 'Terraform is not installed or is not available in PATH.'
```

}
else {

```
$TerraformVersionResult =
    Invoke-SafeCommand `
        -FilePath 'terraform' `
        -Arguments @('version')

if ($TerraformVersionResult.ExitCode -eq 0) {

    Add-Result `
        -Category 'TERRAFORM' `
        -Check 'Terraform installation' `
        -Status 'PASS' `
        -Details $TerraformVersionResult.Output

}
else {

    Add-Result `
        -Category 'TERRAFORM' `
        -Check 'Terraform installation' `
        -Status 'FAIL' `
        -Details $TerraformVersionResult.Output
}
```

}

# =====================================================================

# TERRAFORM DIRECTORY

# =====================================================================

if ($TerraformDirectoryExists) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'Terraform directory' `
    -Status 'PASS' `
    -Details $TerraformDirectoryFull
```

}
else {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'Terraform directory' `
    -Status 'FAIL' `
    -Details $TerraformDirectoryFull
```

}

# =====================================================================

# TERRAFORM FILE DISCOVERY

# =====================================================================

if ($TerraformDirectoryExists) {

```
$TerraformFiles = @(
    Get-ChildItem `
        -LiteralPath $TerraformDirectoryFull `
        -Filter '*.tf' `
        -File `
        -ErrorAction SilentlyContinue
)

if ($TerraformFiles.Count -gt 0) {

    Add-Result `
        -Category 'TERRAFORM' `
        -Check 'Terraform files' `
        -Status 'PASS' `
        -Details "Found $($TerraformFiles.Count) Terraform .tf file(s)."

    foreach ($TerraformFile in $TerraformFiles) {

        Write-Host `
            "        $($TerraformFile.Name)" `
            -ForegroundColor Gray
    }

}
else {

    Add-Result `
        -Category 'TERRAFORM' `
        -Check 'Terraform files' `
        -Status 'FAIL' `
        -Details 'No Terraform .tf files were found.'
}
```

}

# =====================================================================

# LOAD ALL TERRAFORM TEXT

# =====================================================================

if ($TerraformFiles.Count -gt 0) {

```
$TerraformText = ''

foreach ($TerraformFile in $TerraformFiles) {

    try {

        $TerraformText += (
            Get-Content `
                -LiteralPath $TerraformFile.FullName `
                -Raw `
                -ErrorAction Stop
        )

        $TerraformText += "`n"

    }
    catch {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check "Read $($TerraformFile.Name)" `
            -Status 'WARNING' `
            -Details $_.Exception.Message
    }
}
```

}

# =====================================================================

# SECTION 11 - TERRAFORM PROVIDER

# =====================================================================

Write-Section '11. TERRAFORM AWS PROVIDER'

if (
$TerraformText -match 'provider\s+"aws"'
) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'AWS provider block' `
    -Status 'PASS' `
    -Details 'AWS provider block detected.'
```

}
else {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'AWS provider block' `
    -Status 'FAIL' `
    -Details 'AWS provider block was not detected.'
```

}

# =====================================================================

# TERRAFORM REGION

# =====================================================================

if (
($TerraformText -match 'region\s*=\s*var.aws_region') -or
($TerraformText -match 'region\s*=\s*["''][^"'']+["'']')
) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'AWS region configuration' `
    -Status 'PASS' `
    -Details 'Terraform AWS region configuration detected.'
```

}
else {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'AWS region configuration' `
    -Status 'WARNING' `
    -Details 'Could not automatically detect Terraform AWS region configuration.'
```

}

# =====================================================================

# SECTION 12 - TERRAFORM FORMAT

# =====================================================================

Write-Section '12. TERRAFORM FORMAT'

if (
($null -ne $TerraformCommand) -and
$TerraformDirectoryExists
) {

```
Push-Location $TerraformDirectoryFull

try {

    $FmtResult =
        Invoke-SafeCommand `
            -FilePath 'terraform' `
            -Arguments @(
                'fmt'
                '-check'
                '-recursive'
            )

    if ($FmtResult.ExitCode -eq 0) {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check 'terraform fmt -check' `
            -Status 'PASS' `
            -Details 'Terraform files are correctly formatted.'

    }
    else {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check 'terraform fmt -check' `
            -Status 'FAIL' `
            -Details "Formatting check failed. Output: $($FmtResult.Output)"

        Write-Host ''
        Write-Host 'Recommended command:' `
            -ForegroundColor Yellow

        Write-Host 'terraform fmt -recursive' `
            -ForegroundColor Yellow
    }

}
finally {

    Pop-Location
}
```

}
elseif ($null -eq $TerraformCommand) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'terraform fmt -check' `
    -Status 'WARNING' `
    -Details 'Terraform is unavailable. Formatting check was skipped.'
```

}

# =====================================================================

# SECTION 13 - TERRAFORM INIT

# =====================================================================

Write-Section '13. TERRAFORM INITIALIZATION'

if (
($null -ne $TerraformCommand) -and
$TerraformDirectoryExists
) {

```
Push-Location $TerraformDirectoryFull

try {

    # IMPORTANT:
    # -backend=false prevents this verification script from
    # initializing or contacting the configured remote backend.
    #
    # This keeps the verification process focused on configuration
    # validation and avoids unintended backend operations.

    $InitResult =
        Invoke-SafeCommand `
            -FilePath 'terraform' `
            -Arguments @(
                'init'
                '-backend=false'
                '-input=false'
            )

    if ($InitResult.ExitCode -eq 0) {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check 'terraform init -backend=false' `
            -Status 'PASS' `
            -Details 'Terraform initialization completed without the remote backend.'

    }
    else {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check 'terraform init -backend=false' `
            -Status 'FAIL' `
            -Details "Terraform initialization failed. Output: $($InitResult.Output)"
    }

}
finally {

    Pop-Location
}
```

}
elseif ($null -eq $TerraformCommand) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'terraform init -backend=false' `
    -Status 'WARNING' `
    -Details 'Terraform is unavailable. Initialization was skipped.'
```

}

# =====================================================================

# SECTION 14 - TERRAFORM VALIDATION

# =====================================================================

Write-Section '14. TERRAFORM VALIDATION'

if (
($null -ne $TerraformCommand) -and
$TerraformDirectoryExists
) {

```
Push-Location $TerraformDirectoryFull

try {

    $ValidateResult =
        Invoke-SafeCommand `
            -FilePath 'terraform' `
            -Arguments @(
                'validate'
            )

    if ($ValidateResult.ExitCode -eq 0) {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check 'terraform validate' `
            -Status 'PASS' `
            -Details 'Terraform configuration is valid.'

    }
    else {

        Add-Result `
            -Category 'TERRAFORM' `
            -Check 'terraform validate' `
            -Status 'FAIL' `
            -Details "Terraform validation failed. Output: $($ValidateResult.Output)"
    }

}
finally {

    Pop-Location
}
```

}
elseif ($null -eq $TerraformCommand) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'terraform validate' `
    -Status 'WARNING' `
    -Details 'Terraform is unavailable. Validation was skipped.'
```

}

# =====================================================================

# SECTION 15 - ecr_image_uri SEARCH

# =====================================================================

Write-Section '15. ecr_image_uri REFERENCE CHECK'

$EcrImageReferences = @()

if ($TerraformDirectoryExists) {

```
$EcrImageReferences = @(
    Get-ChildItem `
        -Path $TerraformDirectoryFull `
        -Recurse `
        -File `
        -Include '*.tf', '*.tfvars', '*.tfvars.json' `
        -ErrorAction SilentlyContinue |
    Select-String `
        -Pattern 'ecr_image_uri' `
        -SimpleMatch `
        -ErrorAction SilentlyContinue
)
```

}

if ($EcrImageReferences.Count -eq 0) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'No remaining ecr_image_uri references' `
    -Status 'PASS' `
    -Details 'No ecr_image_uri references were found in Terraform files.'
```

}
else {

```
$ReferenceDetails =
    (
        $EcrImageReferences |
        ForEach-Object {
            "{0}:{1}: {2}" -f `
                $_.Path, `
                $_.LineNumber, `
                $_.Line.Trim()
        }
    ) -join ' | '

Add-Result `
    -Category 'TERRAFORM' `
    -Check 'No remaining ecr_image_uri references' `
    -Status 'WARNING' `
    -Details "References still exist: $ReferenceDetails"
```

}

# =====================================================================

# VARIABLES.TF ecr_image_uri CHECK

# =====================================================================

if (
$VariablesTf -match 'variable\s+"ecr_image_uri"'
) {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'ecr_image_uri variable cleanup' `
    -Status 'WARNING' `
    -Details 'variables.tf still declares ecr_image_uri. Review whether it is still required.'
```

}
else {

```
Add-Result `
    -Category 'TERRAFORM' `
    -Check 'ecr_image_uri variable cleanup' `
    -Status 'PASS' `
    -Details 'variables.tf does not declare ecr_image_uri.'
```

}

# =====================================================================

# SECTION 16 - MAIN.YAML ARCHITECTURE

# =====================================================================

Write-Section '16. ROOT CLOUDFORMATION main.yaml ARCHITECTURE'

# ---------------------------------------------------------------------

# Bootstrap must not require EcrImageUri.

# ---------------------------------------------------------------------

Test-NotContainsText `    -Content $MainYaml`
-Text 'EcrImageUri:' `    -CheckName 'main.yaml must not require EcrImageUri'`
-Category 'MAIN.YAML' |
Out-Null

# ---------------------------------------------------------------------

# Bootstrap should not create ECS.

# ---------------------------------------------------------------------

if (
$MainYaml -match '(?m)^\s*ECSStack\s*:'
) {

```
Add-Result `
    -Category 'MAIN.YAML' `
    -Check 'ECS bootstrap separation' `
    -Status 'FAIL' `
    -Details 'An ECSStack resource definition exists in main.yaml. ECS should be deployed separately.'
```

}
else {

```
Add-Result `
    -Category 'MAIN.YAML' `
    -Check 'ECS bootstrap separation' `
    -Status 'PASS' `
    -Details 'No ECSStack resource definition was detected in main.yaml.'
```

}

# ---------------------------------------------------------------------

# ECSStackId should not be exposed by bootstrap.

# ---------------------------------------------------------------------

Test-NotContainsText `    -Content $MainYaml`
-Text 'ECSStackId:' `    -CheckName 'main.yaml must not expose ECSStackId'`
-Category 'MAIN.YAML' |
Out-Null

# ---------------------------------------------------------------------

# Required infrastructure nested stacks.

# ---------------------------------------------------------------------

Test-ContainsText `    -Content $MainYaml`
-Text 'ECRStack:' `    -CheckName 'ECR nested stack'`
-Category 'MAIN.YAML' |
Out-Null

Test-ContainsText `    -Content $MainYaml`
-Text 'ECRRepositoryUri:' `    -CheckName 'ECR repository URI output'`
-Category 'MAIN.YAML' |
Out-Null

Test-ContainsText `    -Content $MainYaml`
-Text 'VPCStack:' `    -CheckName 'VPC nested stack'`
-Category 'MAIN.YAML' |
Out-Null

Test-ContainsText `    -Content $MainYaml`
-Text 'S3Stack:' `    -CheckName 'S3 nested stack'`
-Category 'MAIN.YAML' |
Out-Null

Test-ContainsText `    -Content $MainYaml`
-Text 'LambdaStack:' `    -CheckName 'Lambda nested stack'`
-Category 'MAIN.YAML' |
Out-Null

Test-ContainsText `    -Content $MainYaml`
-Text 'EKSStack:' `    -CheckName 'EKS nested stack'`
-Category 'MAIN.YAML' |
Out-Null

Test-ContainsText `    -Content $MainYaml`
-Text 'RDSStack:' `    -CheckName 'RDS nested stack'`
-Category 'MAIN.YAML' |
Out-Null

# =====================================================================

# SECTION 17 - CLOUDFORMATION.TF ARCHITECTURE

# =====================================================================

Write-Section '17. TERRAFORM cloudformation.tf ARCHITECTURE'

Test-NotContainsText `    -Content $CloudFormationTf`
-Text 'EcrImageUri = var.ecr_image_uri' `    -CheckName 'Terraform must not pass EcrImageUri during bootstrap'`
-Category 'TERRAFORM' |
Out-Null

Test-ContainsText `    -Content $CloudFormationTf`
-Text 'ProjectName = var.project_name' `    -CheckName 'ProjectName parameter'`
-Category 'TERRAFORM' |
Out-Null

Test-ContainsText `    -Content $CloudFormationTf`
-Text 'Environment = var.environment' `    -CheckName 'Environment parameter'`
-Category 'TERRAFORM' |
Out-Null

Test-ContainsText `    -Content $CloudFormationTf`
-Text 'AmiId = var.ami_id' `    -CheckName 'AmiId parameter'`
-Category 'TERRAFORM' |
Out-Null

Test-ContainsText `    -Content $CloudFormationTf`
-Text 'DatabaseUsername = var.database_username' `    -CheckName 'DatabaseUsername parameter'`
-Category 'TERRAFORM' |
Out-Null

Test-ContainsText `    -Content $CloudFormationTf`
-Text 'DatabasePassword = var.database_password' `    -CheckName 'DatabasePassword parameter'`
-Category 'TERRAFORM' |
Out-Null

# =====================================================================

# SECTION 18 - DOCKER WORKFLOW

# =====================================================================

Write-Section '18. DOCKER + ECR WORKFLOW'

$UsesGitHubSha =
($DockerWorkflow -match '${{\s*github.sha\s*}}') -or
($DockerWorkflow -match '${GITHUB_SHA}') -or
($DockerWorkflow -match '$GITHUB_SHA\b')

if ($UsesGitHubSha) {

```
Add-Result `
    -Category 'DOCKER' `
    -Check 'Immutable image tag' `
    -Status 'PASS' `
    -Details 'Docker workflow uses Git commit SHA information for image tagging.'
```

}
else {

```
Add-Result `
    -Category 'DOCKER' `
    -Check 'Immutable image tag' `
    -Status 'WARNING' `
    -Details 'Could not confirm github.sha or GITHUB_SHA image tagging.'
```

}

# ---------------------------------------------------------------------

# ECR login

# ---------------------------------------------------------------------

if (
($DockerWorkflow -match 'amazon-ecr-login') -or
(
($DockerWorkflow -match 'ecr') -and
($DockerWorkflow -match 'login')
)
) {

```
Add-Result `
    -Category 'DOCKER' `
    -Check 'Amazon ECR login' `
    -Status 'PASS' `
    -Details 'Docker workflow contains an ECR login operation.'
```

}
else {

```
Add-Result `
    -Category 'DOCKER' `
    -Check 'Amazon ECR login' `
    -Status 'WARNING' `
    -Details 'Could not confirm an Amazon ECR login step.'
```

}

# ---------------------------------------------------------------------

# Docker push

# ---------------------------------------------------------------------

Test-ContainsText `    -Content $DockerWorkflow`
-Text 'docker push' `    -CheckName 'Docker image push'`
-Category 'DOCKER' |
Out-Null

# ---------------------------------------------------------------------

# ECR immutable tags

# ---------------------------------------------------------------------

if (
$EcrYaml -match 'IMMUTABLE'
) {

```
Add-Result `
    -Category 'ECR' `
    -Check 'ECR tag mutability' `
    -Status 'PASS' `
    -Details 'ECR repository is configured as IMMUTABLE.'
```

}
else {

```
Add-Result `
    -Category 'ECR' `
    -Check 'ECR tag mutability' `
    -Status 'WARNING' `
    -Details 'Could not confirm IMMUTABLE configuration in ecr.yaml.'
```

}

# ---------------------------------------------------------------------

# Protect against latest tag on immutable ECR.

# ---------------------------------------------------------------------

if (
$DockerWorkflow -match `
'docker\s+push[\s\S]{0,500}:latest'
) {

```
Add-Result `
    -Category 'DOCKER' `
    -Check 'Immutable ECR latest-tag protection' `
    -Status 'FAIL' `
    -Details 'docker.yml appears to push :latest while ECR is immutable.'
```

}
else {

```
Add-Result `
    -Category 'DOCKER' `
    -Check 'Immutable ECR latest-tag protection' `
    -Status 'PASS' `
    -Details 'No obvious docker push of :latest was detected.'
```

}

# =====================================================================

# SECTION 19 - ECS DEPLOYMENT

# =====================================================================

Write-Section '19. ECS DEPLOYMENT TEMPLATE'

if (
$EcsYaml -match 'EcrImageUri:'
) {

```
Add-Result `
    -Category 'ECS' `
    -Check 'ECS EcrImageUri parameter' `
    -Status 'PASS' `
    -Details 'ecs.yaml accepts EcrImageUri as an application deployment input.'
```

}
else {

```
Add-Result `
    -Category 'ECS' `
    -Check 'ECS EcrImageUri parameter' `
    -Status 'WARNING' `
    -Details 'Could not confirm EcrImageUri in ecs.yaml.'
```

}

$EcsUsesImageUri =
($EcsYaml -match 'Image:\s*!Ref\s+EcrImageUri') -or
($EcsYaml -match 'Image:\s*\r?\n\s*Ref:\s*EcrImageUri') -or
($EcsYaml -match 'Image:.*EcrImageUri')

if ($EcsUsesImageUri) {

```
Add-Result `
    -Category 'ECS' `
    -Check 'ECS task definition image' `
    -Status 'PASS' `
    -Details 'ECS task definition appears to use EcrImageUri.'
```

}
else {

```
Add-Result `
    -Category 'ECS' `
    -Check 'ECS task definition image' `
    -Status 'WARNING' `
    -Details 'Could not confirm that ECS uses EcrImageUri for the container image.'
```

}

# =====================================================================

# SECTION 20 - GITHUB ACTIONS WORKFLOW FILES

# =====================================================================

Write-Section '20. GITHUB ACTIONS WORKFLOW FILES'

Test-RequiredFile `    -Path $MainDeployPath`
-Description 'main-deploy.yaml' |
Out-Null

Test-RequiredFile `    -Path $TerraformWorkflowPath`
-Description 'terraform.yml' |
Out-Null

Test-RequiredFile `    -Path $DockerWorkflowPath`
-Description 'docker.yml' |
Out-Null

Test-RequiredFile `    -Path $KubernetesWorkflowPath`
-Description 'kubernetes.yml' |
Out-Null

# =====================================================================

# MAIN DEPLOYMENT WORKFLOW

# =====================================================================

if (
$MainDeploy -match 'terraform'
) {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Terraform workflow reference' `
    -Status 'PASS' `
    -Details 'main-deploy.yaml references Terraform.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Terraform workflow reference' `
    -Status 'FAIL' `
    -Details 'Terraform workflow reference was not detected.'
```

}

if (
$MainDeploy -match 'docker'
) {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Docker workflow reference' `
    -Status 'PASS' `
    -Details 'main-deploy.yaml references Docker.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Docker workflow reference' `
    -Status 'FAIL' `
    -Details 'Docker workflow reference was not detected.'
```

}

if (
$MainDeploy -match 'kubernetes'
) {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Kubernetes workflow reference' `
    -Status 'PASS' `
    -Details 'main-deploy.yaml references Kubernetes.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Kubernetes workflow reference' `
    -Status 'WARNING' `
    -Details 'Kubernetes workflow reference was not detected.'
```

}

# =====================================================================

# WORKFLOW DEPENDENCY ORDER

# =====================================================================

$DockerDependsOnTerraform =
($MainDeploy -match `        '(?ms)^\s*docker\s*:.*?^\s*needs\s*:\s*terraform\b') -or
    ($MainDeploy -match`
'(?ms)^\s*docker\s*:.*?^\s*needs\s*:\s*\(.*terraform.*\)') -or
($MainDeploy -match `
'(?ms)^\s*docker\s*:.*?^\s*needs\s*:\s*\(.*terraform.*\)')

if ($DockerDependsOnTerraform) {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Docker runs after Terraform' `
    -Status 'PASS' `
    -Details 'Docker job depends on Terraform.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Docker runs after Terraform' `
    -Status 'WARNING' `
    -Details 'Could not confirm explicit Docker -> Terraform dependency.'
```

}

$KubernetesDependsOnDocker =
($MainDeploy -match `        '(?ms)^\s*kubernetes\s*:.*?^\s*needs\s*:\s*docker\b') -or
    ($MainDeploy -match`
'(?ms)^\s*kubernetes\s*:.*?^\s*needs\s*:\s*\(.*docker.*\)') -or
($MainDeploy -match `
'(?ms)^\s*kubernetes\s*:.*?^\s*needs\s*:\s*\(.*docker.*\)')

if ($KubernetesDependsOnDocker) {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Kubernetes runs after Docker' `
    -Status 'PASS' `
    -Details 'Kubernetes job depends on Docker.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB ACTIONS' `
    -Check 'Kubernetes runs after Docker' `
    -Status 'WARNING' `
    -Details 'Could not confirm explicit Kubernetes -> Docker dependency.'
```

}

# =====================================================================

# SECTION 21 - TERRAFORM WORKFLOW OIDC

# =====================================================================

Write-Section '21. TERRAFORM WORKFLOW OIDC CONFIGURATION'

if (
$TerraformWorkflow -match 'workflow_call'
) {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'workflow_call' `
    -Status 'PASS' `
    -Details 'terraform.yml supports workflow_call.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'workflow_call' `
    -Status 'FAIL' `
    -Details 'terraform.yml does not contain workflow_call.'
```

}

if (
$TerraformWorkflow -match 'id-token:\s*write'
) {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'id-token permission' `
    -Status 'PASS' `
    -Details 'terraform.yml contains id-token: write.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'id-token permission' `
    -Status 'FAIL' `
    -Details 'terraform.yml is missing id-token: write.'
```

}

if (
$TerraformWorkflow -match `
'aws-region:\s*${{\s*vars.AWS_REGION\s*}}'
) {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'AWS_REGION workflow variable' `
    -Status 'PASS' `
    -Details 'terraform.yml uses vars.AWS_REGION.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'AWS_REGION workflow variable' `
    -Status 'FAIL' `
    -Details 'terraform.yml does not use vars.AWS_REGION for aws-region.'
```

}

if (
$TerraformWorkflow -match `
'role-to-assume:\s*${{\s*secrets.AWS_ROLE_ARN\s*}}'
) {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'AWS_ROLE_ARN workflow secret' `
    -Status 'PASS' `
    -Details 'terraform.yml uses secrets.AWS_ROLE_ARN.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'AWS_ROLE_ARN workflow secret' `
    -Status 'FAIL' `
    -Details 'terraform.yml does not use secrets.AWS_ROLE_ARN.'
```

}

if (
$TerraformWorkflow -match `
'aws-actions/configure-aws-credentials@v4'
) {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'configure-aws-credentials@v4' `
    -Status 'PASS' `
    -Details 'terraform.yml uses configure-aws-credentials@v4.'
```

}
else {

```
Add-Result `
    -Category 'GITHUB OIDC' `
    -Check 'configure-aws-credentials@v4' `
    -Status 'FAIL' `
    -Details 'configure-aws-credentials@v4 was not detected.'
```

}

# =====================================================================

# SECTION 22 - CLOUDFORMATION TEMPLATE DISCOVERY

# =====================================================================

Write-Section '22. CLOUDFORMATION TEMPLATE DISCOVERY'

if (
Test-Path `        -LiteralPath $CloudFormationDirectoryFull`
-PathType Container
) {

```
$CloudFormationTemplates = @(
    Get-ChildItem `
        -Path $CloudFormationDirectoryFull `
        -Recurse `
        -File `
        -Filter '*.yaml' `
        -ErrorAction SilentlyContinue |
    Sort-Object FullName
)

if (
    $CloudFormationTemplates.Count -gt 0
) {

    Add-Result `
        -Category 'CLOUDFORMATION' `
        -Check 'CloudFormation template discovery' `
        -Status 'PASS' `
        -Details "Found $($CloudFormationTemplates.Count) YAML template(s)."

    foreach (
        $Template in $CloudFormationTemplates
    ) {

        Write-Host `
            "        $($Template.FullName)" `
            -ForegroundColor Gray
    }

}
else {

    Add-Result `
        -Category 'CLOUDFORMATION' `
        -Check 'CloudFormation template discovery' `
        -Status 'FAIL' `
        -Details 'No .yaml CloudFormation templates were found.'
}
```

}
else {

```
Add-Result `
    -Category 'CLOUDFORMATION' `
    -Check 'CloudFormation template discovery' `
    -Status 'FAIL' `
    -Details "Directory does not exist: $CloudFormationDirectoryFull"
```

}

# =====================================================================

# SECTION 23 - REQUIRED NESTED TEMPLATES

# =====================================================================

Write-Section '23. REQUIRED CLOUDFORMATION NESTED TEMPLATES'

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

foreach (
$TemplateName in $ExpectedNestedTemplates
) {

```
$TemplatePath =
    Join-Path `
        $NestedDirectoryFull `
        $TemplateName

if (
    Test-Path `
        -LiteralPath $TemplatePath `
        -PathType Leaf
) {

    Add-Result `
        -Category 'CLOUDFORMATION' `
        -Check "Nested template $TemplateName" `
        -Status 'PASS' `
        -Details 'Nested template exists.'

}
else {

    Add-Result `
        -Category 'CLOUDFORMATION' `
        -Check "Nested template $TemplateName" `
        -Status 'FAIL' `
        -Details 'Nested template is missing.'
}
```

}

# =====================================================================

# SECTION 24 - AWS CLOUDFORMATION VALIDATION

# =====================================================================

Write-Section '24. AWS CLOUDFORMATION TEMPLATE VALIDATION'

$AwsCommand =
Get-Command `        aws`
-ErrorAction SilentlyContinue

if ($null -eq $AwsCommand) {

```
Add-Result `
    -Category 'CLOUDFORMATION' `
    -Check 'AWS CLI available for CloudFormation validation' `
    -Status 'WARNING' `
    -Details 'AWS CLI unavailable. CloudFormation validation was skipped.'
```

}
else {

```
foreach (
    $Template in $CloudFormationTemplates
) {

    Write-Host ''
    Write-Host '------------------------------------------------------------' `
        -ForegroundColor DarkCyan

    Write-Host 'VALIDATING:' `
        -ForegroundColor Yellow

    Write-Host $Template.FullName `
        -ForegroundColor White

    Write-Host '------------------------------------------------------------' `
        -ForegroundColor DarkCyan


    # -------------------------------------------------------------
    # AWS CLI file URI
    #
    # Using file:// keeps validation local and does not deploy
    # or create the CloudFormation stack.
    # -------------------------------------------------------------

    $TemplateUri =
        "file://$($Template.FullName)"


    $CloudFormationValidation =
        Invoke-SafeCommand `
            -FilePath 'aws' `
            -Arguments @(
                'cloudformation'
                'validate-template'
                '--template-body'
                $TemplateUri
                '--region'
                $ExpectedAwsRegion
            )


    if (
        $CloudFormationValidation.ExitCode -eq 0
    ) {

        Add-Result `
            -Category 'CLOUDFORMATION' `
            -Check "Validate $($Template.Name)" `
            -Status 'PASS' `
            -Details "$($Template.Name) passed AWS CloudFormation validation."

    }
    else {

        Add-Result `
            -Category 'CLOUDFORMATION' `
            -Check "Validate $($Template.Name)" `
            -Status 'FAIL' `
            -Details "$($Template.Name) failed validation. Output: $($CloudFormationValidation.Output)"
    }
}
```

}

# =====================================================================

# SECTION 25 - ECR OUTPUT FLOW

# =====================================================================

Write-Section '25. ECR OUTPUT FLOW'

if (
($MainYaml -match 'ECRStack:') -and
($MainYaml -match 'ECRRepositoryUri:') -and
($MainYaml -match 'GetAtt\s+ECRStack.Outputs.RepositoryUri')
) {

```
Add-Result `
    -Category 'ARCHITECTURE' `
    -Check 'ECR repository output flow' `
    -Status 'PASS' `
    -Details 'main.yaml exposes ECR repository URI from ECRStack.'
```

}
else {

```
Add-Result `
    -Category 'ARCHITECTURE' `
    -Check 'ECR repository output flow' `
    -Status 'FAIL' `
    -Details 'Could not confirm ECR repository URI output flow.'
```

}

# =====================================================================

# SECTION 26 - ECS BOOTSTRAP SEPARATION

# =====================================================================

Write-Section '26. ECS BOOTSTRAP SEPARATION'

if (
$MainYaml -match '(?m)^\s*ECSStack\s*:'
) {

```
Add-Result `
    -Category 'ARCHITECTURE' `
    -Check 'ECS bootstrap separation' `
    -Status 'FAIL' `
    -Details 'main.yaml contains an ECSStack resource definition.'
```

}
else {

```
Add-Result `
    -Category 'ARCHITECTURE' `
    -Check 'ECS bootstrap separation' `
    -Status 'PASS' `
    -Details 'main.yaml does not create ECS during infrastructure bootstrap.'
```

}

# =====================================================================

# SECTION 27 - BASIC SECURITY / SECRET SCAN

# =====================================================================

Write-Section '27. BASIC HARD-CODED SECRET SCAN'

$FilesToScan = @(
$CloudFormationTfPath
$MainDeployPath
$TerraformWorkflowPath
$DockerWorkflowPath
$KubernetesWorkflowPath
)

$PossibleSecretPatterns = @(
'AKIA[0-9A-Z]{16}'
'aws_secret_access_key\s*='
'AWS_SECRET_ACCESS_KEY\s*=\s*["'']?[A-Za-z0-9/+=]+'
'password\s*=\s*["''][^"'']+["'']'
)

$SecretFinding = $false

foreach (
$File in $FilesToScan
) {

```
if (
    -not (
        Test-Path `
            -LiteralPath $File `
            -PathType Leaf
    )
) {

    continue
}

$Content =
    Get-FileContentSafe `
        -Path $File

foreach (
    $Pattern in $PossibleSecretPatterns
) {

    if (
        $Content -match $Pattern
    ) {

        $SecretFinding = $true

        Add-Result `
            -Category 'SECURITY' `
            -Check 'Possible hard-coded secret' `
            -Status 'WARNING' `
            -Details "Potential credential pattern detected in $File. Review manually."
    }
}
```

}

if (-not $SecretFinding) {

```
Add-Result `
    -Category 'SECURITY' `
    -Check 'Hard-coded secret pattern scan' `
    -Status 'PASS' `
    -Details 'No obvious hard-coded credential patterns were detected.'
```

}

# =====================================================================

# SECTION 28 - FINAL ARCHITECTURE LOGIC

# =====================================================================

Write-Section '28. FINAL ARCHITECTURE LOGIC CHECK'

$BootstrapCorrect =
($MainYaml -notmatch 'EcrImageUri:') -and
($MainYaml -notmatch '(?m)^\s*ECSStack\s*:') -and
($CloudFormationTf -notmatch `
'EcrImageUri\s*=\s*var.ecr_image_uri')

if ($BootstrapCorrect) {

```
Add-Result `
    -Category 'ARCHITECTURE' `
    -Check 'Bootstrap does not require Docker image' `
    -Status 'PASS' `
    -Details 'Bootstrap does not require EcrImageUri and does not create ECS.'
```

}
else {

```
Add-Result `
    -Category 'ARCHITECTURE' `
    -Check 'Bootstrap does not require Docker image' `
    -Status 'FAIL' `
    -Details 'Bootstrap still contains an ECR image dependency or ECS resource.'
```

}

# =====================================================================

# SECTION 29 - GITHUB CONFIGURATION REMINDER

# =====================================================================

Write-Section '29. GITHUB REPOSITORY CONFIGURATION REMINDER'

Write-Host ''
Write-Host 'The following values should exist in GitHub:' `
-ForegroundColor Yellow

Write-Host ''

Write-Host 'Repository Variable:' `
-ForegroundColor Cyan

Write-Host "    AWS_REGION = $ExpectedAwsRegion"

Write-Host ''

Write-Host 'Repository Secret:' `
-ForegroundColor Cyan

if (
-not [string]::IsNullOrWhiteSpace(
$RoleArn
)
) {

```
Write-Host "    AWS_ROLE_ARN = $RoleArn"
```

}
else {

```
Write-Host `
    '    AWS_ROLE_ARN = <ROLE ARN COULD NOT BE DETECTED>' `
    -ForegroundColor Yellow
```

}

Write-Host ''

Write-Host 'GitHub Repository:' `
-ForegroundColor Cyan

Write-Host "    $ExpectedGitHubRepository"

Write-Host ''

Write-Host 'GitHub Branch:' `
-ForegroundColor Cyan

Write-Host "    $ExpectedGitHubBranch"

Write-Host ''

Write-Host 'IMPORTANT:' `
-ForegroundColor Yellow

Write-Host `    'GitHub Actions secrets and variables cannot be read directly from AWS CLI.'`
-ForegroundColor DarkYellow

Write-Host `    'Verify AWS_REGION and AWS_ROLE_ARN manually in GitHub Settings.'`
-ForegroundColor DarkYellow

# =====================================================================

# FINAL CALCULATIONS

# =====================================================================

$ScriptEndTime = Get-Date

$Duration =
$ScriptEndTime - $ScriptStartTime

$TotalChecks =
$Results.Count

$TotalPassed =
$Passed

$TotalFailed =
$Failed

$TotalWarnings =
$WarningCount

# =====================================================================

# FINAL RESULT

# =====================================================================

if (
$TotalFailed -eq 0
) {

```
if (
    $TotalWarnings -eq 0
) {

    $FinalResult =
        'PASS - ALL VERIFICATION CHECKS PASSED'

}
else {

    $FinalResult =
        'PASS WITH WARNINGS - REVIEW WARNINGS BEFORE DEPLOYMENT'
}
```

}
else {

```
$FinalResult =
    'FAIL - VERIFICATION FAILED'
```

}

# =====================================================================

# SECTION 30 - FINAL SUMMARY

# =====================================================================

Write-Section '30. FINAL VERIFICATION SUMMARY'

Write-Host ''

Write-Host '                         VERIFICATION RESULT' `
-ForegroundColor Cyan

Write-Host ''

Write-Host "Total Checks : $TotalChecks" `
-ForegroundColor Cyan

Write-Host "PASS         : $TotalPassed" `
-ForegroundColor Green

Write-Host "FAIL         : $TotalFailed" `
-ForegroundColor Red

Write-Host "WARNING      : $TotalWarnings" `
-ForegroundColor Yellow

Write-Host "Duration     : $($Duration.ToString())" `
-ForegroundColor Cyan

Write-Host ''

if (
$TotalFailed -eq 0 -and
$TotalWarnings -eq 0
) {

```
Write-Host '=======================================================================' `
    -ForegroundColor Green

Write-Host ' RESULT: ALL CHECKS PASSED' `
    -ForegroundColor Green

Write-Host '=======================================================================' `
    -ForegroundColor Green
```

}
elseif (
$TotalFailed -eq 0
) {

```
Write-Host '=======================================================================' `
    -ForegroundColor Yellow

Write-Host ' RESULT: PASSED WITH WARNINGS' `
    -ForegroundColor Yellow

Write-Host '=======================================================================' `
    -ForegroundColor Yellow
```

}
else {

```
Write-Host '=======================================================================' `
    -ForegroundColor Red

Write-Host ' RESULT: VERIFICATION FAILED' `
    -ForegroundColor Red

Write-Host '=======================================================================' `
    -ForegroundColor Red
```

}

# =====================================================================

# FAILED CHECK REPORT - CONSOLE

# =====================================================================

Write-Host ''

Write-Host '=======================================================================' `
-ForegroundColor Red

Write-Host ' FAILED CHECKS' `
-ForegroundColor Red

Write-Host '=======================================================================' `
-ForegroundColor Red

Write-Host ''

$FailedResults = @(
$Results |
Where-Object {
$_.Status -eq 'FAIL'
}
)

if (
$FailedResults.Count -eq 0
) {

```
Write-Host 'NO FAILED CHECKS.' `
    -ForegroundColor Green
```

}
else {

```
foreach (
    $FailedResult in $FailedResults
) {

    Write-Host `
        "[FAILED] [$($FailedResult.Category)] $($FailedResult.Check)" `
        -ForegroundColor Red

    Write-Host `
        "         $($FailedResult.Details)" `
        -ForegroundColor Red
}
```

}

# =====================================================================

# WARNING REPORT - CONSOLE

# =====================================================================

Write-Host ''

Write-Host '=======================================================================' `
-ForegroundColor Yellow

Write-Host ' WARNING CHECKS' `
-ForegroundColor Yellow

Write-Host '=======================================================================' `
-ForegroundColor Yellow

Write-Host ''

$WarningResults = @(
$Results |
Where-Object {
$_.Status -eq 'WARNING'
}
)

if (
$WarningResults.Count -eq 0
) {

```
Write-Host 'NO WARNINGS.' `
    -ForegroundColor Green
```

}
else {

```
foreach (
    $WarningResult in $WarningResults
) {

    Write-Host `
        "[WARNING] [$($WarningResult.Category)] $($WarningResult.Check)" `
        -ForegroundColor DarkYellow

    Write-Host `
        "          $($WarningResult.Details)" `
        -ForegroundColor DarkYellow
}
```

}

# =====================================================================

# WRITE COMPLETE VERIFICATION REPORT

# =====================================================================

$ReportLines =
New-Object System.Collections.Generic.List[string]

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'AWS HYBRID IaC LAB - COMPLETE VERIFICATION REPORT'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add('')

$ReportLines.Add(
"Project Root: $ProjectRoot"
)

$ReportLines.Add(
"Verification Started: $ScriptStartTime"
)

$ReportLines.Add(
"Verification Finished: $ScriptEndTime"
)

$ReportLines.Add(
"Duration: $($Duration.ToString())"
)

$ReportLines.Add('')

$ReportLines.Add(
"Repository: $ExpectedGitHubRepository"
)

$ReportLines.Add(
"Branch: $ExpectedGitHubBranch"
)

$ReportLines.Add(
"AWS Region: $ExpectedAwsRegion"
)

$ReportLines.Add(
"IAM Role: $ExpectedRoleName"
)

$ReportLines.Add(
"IAM Policy: $ExpectedPolicyName"
)

$ReportLines.Add('')

$ReportLines.Add(
"FINAL RESULT: $FinalResult"
)

$ReportLines.Add('')

$ReportLines.Add(
"Total Checks : $TotalChecks"
)

$ReportLines.Add(
"PASS         : $TotalPassed"
)

$ReportLines.Add(
"FAIL         : $TotalFailed"
)

$ReportLines.Add(
"WARNING      : $TotalWarnings"
)

$ReportLines.Add('')

# =====================================================================

# DETAILED RESULTS

# =====================================================================

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'DETAILED VERIFICATION RESULTS'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add('')

foreach (
$Result in $Results
) {

```
$ReportLines.Add(
    '[{0}] [{1}] {2} - {3}' -f `
        $Result.Status, `
        $Result.Category, `
        $Result.Check, `
        $Result.Details
)
```

}

# =====================================================================

# FAILED ITEMS

# =====================================================================

$ReportLines.Add('')

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'FAILED ITEMS'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add('')

if (
$FailedResults.Count -eq 0
) {

```
$ReportLines.Add(
    'No failed checks detected.'
)
```

}
else {

```
foreach (
    $FailedResult in $FailedResults
) {

    $ReportLines.Add(
        "[FAILED] [$($FailedResult.Category)] $($FailedResult.Check)"
    )

    $ReportLines.Add(
        "         $($FailedResult.Details)"
    )
}
```

}

# =====================================================================

# WARNING ITEMS

# =====================================================================

$ReportLines.Add('')

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'WARNING ITEMS'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add('')

if (
$WarningResults.Count -eq 0
) {

```
$ReportLines.Add(
    'No warnings detected.'
)
```

}
else {

```
foreach (
    $WarningResult in $WarningResults
) {

    $ReportLines.Add(
        "[WARNING] [$($WarningResult.Category)] $($WarningResult.Check)"
    )

    $ReportLines.Add(
        "          $($WarningResult.Details)"
    )
}
```

}

# =====================================================================

# EXPECTED GITHUB CONFIGURATION

# =====================================================================

$ReportLines.Add('')

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'EXPECTED GITHUB CONFIGURATION'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add('')

$ReportLines.Add(
"Repository: $ExpectedGitHubRepository"
)

$ReportLines.Add(
"Branch: $ExpectedGitHubBranch"
)

$ReportLines.Add(
"AWS_REGION variable: $ExpectedAwsRegion"
)

if (
-not [string]::IsNullOrWhiteSpace(
$RoleArn
)
) {

```
$ReportLines.Add(
    "AWS_ROLE_ARN secret: $RoleArn"
)
```

}
else {

```
$ReportLines.Add(
    'AWS_ROLE_ARN secret: <ROLE ARN COULD NOT BE DETECTED>'
)
```

}

# =====================================================================

# EXPECTED DEPLOYMENT ARCHITECTURE

# =====================================================================

$ReportLines.Add('')

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'EXPECTED DEPLOYMENT ARCHITECTURE'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add('')

$ReportLines.Add(
'PHASE 1 - INFRASTRUCTURE BOOTSTRAP'
)

$ReportLines.Add(
'GitHub Actions'
)

$ReportLines.Add(
' -> Terraform'
)

$ReportLines.Add(
' -> Root CloudFormation Stack'
)

$ReportLines.Add(
' -> VPC'
)

$ReportLines.Add(
' -> S3'
)

$ReportLines.Add(
' -> DynamoDB'
)

$ReportLines.Add(
' -> ECR Repository'
)

$ReportLines.Add(
' -> Lambda'
)

$ReportLines.Add(
' -> API Gateway'
)

$ReportLines.Add(
' -> CloudFront'
)

$ReportLines.Add(
' -> EC2'
)

$ReportLines.Add(
' -> EKS'
)

$ReportLines.Add(
' -> RDS'
)

$ReportLines.Add('')

$ReportLines.Add(
'PHASE 2 - APPLICATION DEPLOYMENT'
)

$ReportLines.Add(
'GitHub Actions'
)

$ReportLines.Add(
' -> Docker Build'
)

$ReportLines.Add(
' -> ECR Login'
)

$ReportLines.Add(
' -> Push immutable image using Git commit SHA'
)

$ReportLines.Add(
' -> ECS Deployment'
)

$ReportLines.Add(
' -> ECS Service'
)

$ReportLines.Add('')

$ReportLines.Add(
'IMPORTANT:'
)

$ReportLines.Add(
'ECR repository creation must happen before Docker push.'
)

$ReportLines.Add(
'Docker image must exist before ECS application deployment.'
)

$ReportLines.Add(
'Immutable ECR tags should use commit SHA values.'
)

$ReportLines.Add(
'ECS should receive the image URI during application deployment.'
)

$ReportLines.Add('')

$ReportLines.Add(
'No infrastructure deployment was performed by this script.'
)

$ReportLines.Add('')

$ReportLines.Add(
'======================================================================='
)

$ReportLines.Add(
'END OF VERIFICATION REPORT'
)

$ReportLines.Add(
'======================================================================='
)

$ReportLines |
Set-Content `        -LiteralPath $ReportFile`
-Encoding UTF8

# =====================================================================

# WRITE ERROR / WARNING LOG

# =====================================================================

$IssueLines =
New-Object System.Collections.Generic.List[string]

$IssueLines.Add(
'AWS HYBRID IaC LAB - ERROR AND WARNING LOG'
)

$IssueLines.Add(
"Generated: $ScriptEndTime"
)

$IssueLines.Add('')

$IssueLines.Add(
"FINAL RESULT: $FinalResult"
)

$IssueLines.Add('')

$IssueLines.Add(
"Total Checks : $TotalChecks"
)

$IssueLines.Add(
"PASS         : $TotalPassed"
)

$IssueLines.Add(
"FAIL         : $TotalFailed"
)

$IssueLines.Add(
"WARNING      : $TotalWarnings"
)

$IssueLines.Add('')

$IssueLines.Add(
'======================================================================='
)

$IssueLines.Add(
'ERRORS / FAILED CHECKS'
)

$IssueLines.Add(
'======================================================================='

)

$IssueLines.Add('')

if (
$FailedResults.Count -eq 0
) {

```
$IssueLines.Add(
    'No errors or failed checks detected.'
)
```

}
else {

```
foreach (
    $FailedResult in $FailedResults
) {

    $IssueLines.Add(
        "[ERROR] [$($FailedResult.Category)] $($FailedResult.Check)"
    )

    $IssueLines.Add(
        "        $($FailedResult.Details)"
    )
}
```

}

$IssueLines.Add('')

$IssueLines.Add(
'======================================================================='
)

$IssueLines.Add(
'WARNINGS'
)

$IssueLines.Add(
'======================================================================='
)

$IssueLines.Add('')

if (
$WarningResults.Count -eq 0
) {

```
$IssueLines.Add(
    'No warnings detected.'
)
```

}
else {

```
foreach (
    $WarningResult in $WarningResults
) {

    $IssueLines.Add(
        "[WARNING] [$($WarningResult.Category)] $($WarningResult.Check)"
    )

    $IssueLines.Add(
        "           $($WarningResult.Details)"
    )
}
```

}

$IssueLines |
Set-Content `        -LiteralPath $IssueLogFile`
-Encoding UTF8

# =====================================================================

# REPORT FILE LOCATIONS

# =====================================================================

Write-Host ''

Write-Host '=======================================================================' `
-ForegroundColor Cyan

Write-Host ' VERIFICATION REPORT FILES' `
-ForegroundColor Cyan

Write-Host '=======================================================================' `
-ForegroundColor Cyan

Write-Host ''

Write-Host 'Full verification report:' `
-ForegroundColor Yellow

Write-Host $ReportFile `
-ForegroundColor White

Write-Host ''

Write-Host 'Errors and warnings log:' `
-ForegroundColor Yellow

Write-Host $IssueLogFile `
-ForegroundColor White

Write-Host ''

# =====================================================================

# FINAL RECOMMENDATION

# =====================================================================

Write-Host '=======================================================================' `
-ForegroundColor Cyan

Write-Host ' FINAL RECOMMENDATION' `
-ForegroundColor Cyan

Write-Host '=======================================================================' `
-ForegroundColor Cyan

Write-Host ''

if (
$TotalFailed -eq 0 -and
$TotalWarnings -eq 0
) {

```
Write-Host `
    'AWS Hybrid IaC verification completed successfully.' `
    -ForegroundColor Green

Write-Host ''

Write-Host `
    'The configuration passed all automated checks.' `
    -ForegroundColor Green
```

}
elseif (
$TotalFailed -eq 0
) {

```
Write-Host `
    'Verification completed without failures, but warnings require review.' `
    -ForegroundColor Yellow

Write-Host ''

Write-Host `
    'Review the WARNING ITEMS section before deployment.' `
    -ForegroundColor Yellow
```

}
else {

```
Write-Host `
    'Verification failed.' `
    -ForegroundColor Red

Write-Host ''

Write-Host `
    'Fix the FAILED ITEMS before running the deployment workflow.' `
    -ForegroundColor Yellow
```

}

Write-Host ''

Write-Host '=======================================================================' `
-ForegroundColor Cyan

Write-Host ' SCRIPT COMPLETE' `
-ForegroundColor Cyan

Write-Host '=======================================================================' `
-ForegroundColor Cyan

Write-Host ''

# =====================================================================

# EXIT CODE

# =====================================================================

#

# 0 = all checks passed

# 0 = checks passed with warnings

# 1 = one or more checks failed

#

# This makes the script suitable for future CI/CD integration.

# =====================================================================

if (
$TotalFailed -eq 0
) {

```
exit 0
```

}
else {

```
exit 1
```

}

## ▶️ How to save and run it

Save the script exactly as:

```text
aws-hybrid-iac-lab
│
├── infrastructure
│   ├── terraform
│   └── cloudformation
│       ├── main.yaml
│       └── nested
│
├── .github
│   └── workflows
│       ├── main-deploy.yaml
│       ├── terraform.yml
│       ├── docker.yml
│       └── kubernetes.yml
│
└── scripts
    └── aws-hybrid-iac-verification-lab.ps1
```

Then from the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then:

```powershell
.\scripts\aws-hybrid-iac-verification-lab.ps1
```

Or:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\aws-hybrid-iac-verification-lab.ps1
```

## 📊 Reports produced

The script automatically creates:

```text
scripts\
└── verification-reports\
    ├── aws-hybrid-iac-verification-20260907-181500.txt
    └── aws-hybrid-iac-errors-warnings-20260907-181500.log
```

The **full verification report** contains:

* Overall PASS / FAIL / WARNING totals
* Every individual check
* AWS/OIDC results
* IAM results
* Terraform results
* CloudFormation results
* GitHub Actions results
* Docker/ECR/ECS results
* Architecture results
* Failed items
* Warning items
* Expected GitHub configuration
* Expected deployment architecture
* Execution time

The **error/warning log** is intentionally smaller and is focused on the things that require your attention.

### Important improvement in this merged version

I intentionally changed the Terraform initialization used by the merged validator to:

```powershell
terraform init -backend=false -input=false
```

rather than the normal:

```powershell
terraform init
```

That keeps this consolidated verification script aligned with your original **validation-only** requirement and avoids unnecessarily initializing the remote backend during local verification.

Also, the script does **not** treat warnings as deployment failures. The exit behavior is:

```text
0 = PASS
0 = PASS WITH WARNINGS
1 = FAIL
```

So you can use it locally now and later integrate it into GitHub Actions without changing the basic design.

A final note: the architecture checks intentionally distinguish **ECR creation during bootstrap** from **ECS application deployment after the Docker image exists**, which is the separation your three original verification scripts were trying to enforce.

----
