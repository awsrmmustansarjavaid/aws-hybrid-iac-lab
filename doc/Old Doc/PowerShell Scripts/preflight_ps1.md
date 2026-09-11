## **Hybrid IaC AWS Lab — Pre-Deployment Infrastructure Validation & Readiness Check**

### preflight.ps1

**everything you want the PowerShell script to do before the GitHub Actions workflow runs**.

For example:

1. Check required tools are installed (`git`, `aws`, `terraform`, etc.)
2. Check AWS credentials / AWS account
3. Check GitHub repository status
4. Validate Terraform
5. Run `terraform fmt`
6. Run `terraform validate`
7. Run CloudFormation validation
8. Check required AWS resources
9. Check OIDC/IAM configuration
10. Check Docker
11. Check environment variables
12. Show a final **READY / NOT READY** summary
13. Stop immediately if any prerequisite fails

Yes. Before I generate the script, I recommend making it a **pre-flight / pre-deployment validator**, rather than simply a collection of commands.

### Helpful improvements I recommend

1. **Use `-StrictMode` and `$ErrorActionPreference = "Stop"`**

   * Catches PowerShell mistakes early.
   * Prevents the script from continuing after a critical failure.

2. **Have severity levels**

   * `PASS` — check succeeded.
   * `WARN` — potentially important but not necessarily blocking.
   * `FAIL` — deployment must stop.

3. **Keep the report extremely short**
   For example:

   ```text
   FAIL | infrastructure/terraform/iam.tf:42
        Invalid IAM policy JSON - missing closing brace.
   ```

4. **Always report file + line + reason**
   Where possible:

   ```text
   FAIL | .github/workflows/deploy.yml:27
        Unknown GitHub Actions property.
        Cause: invalid workflow YAML structure.
   ```

5. **Create a timestamped log**
   Something like:

   ```text
   logs/preflight-2026-09-08-0025.log
   ```

   But keep the console output short.

6. **Never expose secrets**
   The script should **not print**:

   * AWS secret keys
   * GitHub tokens
   * Secrets Manager secret values
   * passwords
   * private keys

   It can safely report:

   ```text
   PASS | Secrets Manager | CafeDevDBSM exists
   ```

7. **Use AWS identity verification**
   Run an AWS STS identity check and display only safe information such as:

   ```text
   Account: 123456789012
   ARN: arn:aws:iam::123456789012:user/...
   Region: us-east-1
   ```

8. **Add AWS account safety protection**

   This is especially important for your lab. The script should support an expected account ID, for example:

   ```powershell
   $ExpectedAwsAccountId = "YOUR_ACCOUNT_ID"
   ```

   If you're accidentally authenticated against another AWS account:

   ```text
   FAIL | AWS Account
        Expected account 123456789012
        Current account 999999999999
        Deployment stopped.
   ```

9. **Separate local validation from AWS validation**

   I recommend this order:

   ```text
   01. PowerShell environment
   02. Required tools
   03. Git repository
   04. Project structure / directions
   05. Terraform files
   06. CloudFormation files
   07. GitHub workflows
   08. Shell/PowerShell scripts
   09. JSON / IAM policies
   10. Docker
   11. Environment configuration
   12. AWS credentials/account
   13. IAM/OIDC
   14. Secrets Manager
   15. Existing AWS resources
   16. Terraform fmt
   17. Terraform validate
   18. CloudFormation validation
   19. Final readiness decision
   ```

10. **Validate before modifying anything**

One important design choice: `terraform fmt` normally modifies files. I would make the script first detect formatting problems and only apply formatting if you explicitly allow it, e.g.:

```powershell
.\preflight.ps1
```

versus:

```powershell
.\preflight.ps1 -Fix
```

11. **Add a `-SkipAws` mode**

Useful when you're working offline:

```powershell
.\preflight.ps1 -SkipAws
```

12. **Add a `-Verbose` mode**

Normal:

```text
PASS | Git
PASS | Terraform
FAIL | IAM policy
```

Verbose:

```text
[INFO] Checking infrastructure/terraform/iam.tf
[INFO] Running terraform validate
[INFO] Checking IAM trust policy conditions
```

13. **Validate JSON independently**

Don't assume IAM JSON is valid just because AWS accepts some other resource. The script should recursively locate relevant `.json` files and parse them locally.

14. **Validate CloudFormation using AWS CLI**

For your nested-stack architecture, the script should check the relevant CloudFormation templates rather than just checking that `.yaml` syntax exists.

15. **Validate GitHub workflows separately**

YAML syntax and GitHub Actions semantics are different things. The script can catch malformed YAML and obvious workflow structure problems, but it should not pretend that local YAML parsing proves GitHub will accept every workflow feature.

16. **Check IAM relationships**

For your lab, I would specifically inspect:

```text
IAM User
   |
   +-- attached managed policies
   +-- inline policies
   +-- groups
   |
IAM Role
   |
   +-- trust policy
   +-- attached policies
   +-- inline policies
   |
GitHub OIDC
   |
   +-- token.actions.githubusercontent.com
   +-- audience
   +-- repository/branch conditions
```

17. **AWS resource checks should be read-only**

The preflight script should **inspect**, not create/delete/update AWS resources.

18. **Detect drift / unexpected resources**

Where practical, report:

```text
WARN | ECR repository exists but is not expected by current configuration
```

rather than automatically changing it.

19. **Architecture/design validation**

This part needs special treatment. A PowerShell script cannot truly understand whether your entire AWS architecture is "correct" from a diagram alone. However, if your repository contains an architecture specification such as:

```text
docs/
architecture/
README.md
```

we can make the script verify that required architecture components and files are present.

20. **Make the final result machine-readable**

At the end:

```text
=========================================================
PRE-FLIGHT RESULT
=========================================================

PASS : 47
WARN : 2
FAIL : 0

STATUS: READY
GitHub workflow may be started.
=========================================================
```

Or:

```text
STATUS: NOT READY
GitHub workflow MUST NOT be started.
```

### One thing I strongly recommend for your particular lab

Because you're combining **CloudFormation + Terraform + GitHub Actions + OIDC + IAM + Docker + AWS resources**, I would make the script **project-aware** rather than writing a generic AWS checker.

For example, it can understand your expected structure:

```text
aws-hybrid-iac-lab/
│
├── infrastructure/
│   ├── cloudformation/
│   │   ├── root/
│   │   └── nested/
│   └── terraform/
│
├── .github/
│   └── workflows/
│
├── scripts/
│
├── policies/
│
├── docs/
│
├── docker/
│
├── README.md
└── ...
```

Then the script can tell you exactly:

```text
FAIL | infrastructure/terraform/iam-imports.tf:18
      Terraform syntax error.
      Cause: malformed resource block.

FAIL | infrastructure/cloudformation/nested/ecr.yaml:31
      CloudFormation validation failed.
      Cause: invalid property.

FAIL | .github/workflows/deploy.yml:44
      Workflow configuration problem.
      Cause: referenced secret is missing.

FAIL | policies/github-oidc-trust.json:19
      IAM trust policy problem.
      Cause: invalid OIDC condition.

WARN | AWS ECR
      Repository exists but differs from expected configuration.
```

That would make it much more useful than a generic "Terraform passed" script.

### One final recommendation

I would structure the script into independent functions:

```powershell
Test-RequiredTools
Test-GitRepository
Test-ProjectStructure
Test-Documentation
Test-JsonFiles
Test-IamPolicies
Test-Terraform
Test-CloudFormation
Test-GitHubWorkflows
Test-Docker
Test-Environment
Test-AwsCredentials
Test-AwsAccount
Test-IamUsers
Test-IamRoles
Test-Oidc
Test-SecretsManager
Test-AwsResources
Test-TerraformValidation
Test-CloudFormationValidation
Write-FinalReport
```

This makes it much easier to maintain as your hybrid IaC lab grows.

**And I would not put actual AWS credentials, secret values, or tokens inside this PowerShell script.** It should use the AWS CLI's existing credential mechanism/profile/environment and only verify that authentication works.

Absolutely. Below is a **complete PowerShell pre-flight validation script** designed specifically for your **Hybrid IaC AWS DevOps Lab**.

It is intentionally **read-only against AWS**: it checks and validates resources but does not create, modify, or delete AWS resources.

It includes:

* Colored output
* PASS / WARN / FAIL / INFO
* Required-tool checks
* Git repository checks
* Project structure checks
* Architecture/documentation checks
* Terraform checks
* `terraform fmt -check`
* `terraform validate`
* CloudFormation validation
* JSON validation
* IAM policy validation
* IAM user checks
* IAM role checks
* Trust-policy checks
* GitHub OIDC checks
* Secrets Manager checks
* Existing AWS resource checks
* Docker checks
* Environment-variable checks
* GitHub workflow checks
* Short file + line + reason reports where possible
* Timestamped log file
* `-Fix` option
* `-SkipAws` option
* `-VerboseOutput` option
* Immediate stop on critical prerequisite failure
* Final **READY / NOT READY** result

One important choice: I use **`terraform fmt -check` by default**, so the preflight does not unexpectedly modify your project. If you want the script to automatically format Terraform files, use `-Fix`.

```powershell
#requires -Version 5.1

<#
.SYNOPSIS
    Hybrid IaC AWS DevOps Lab - Pre-Flight Validation Script

.DESCRIPTION
    Performs pre-deployment validation before running the GitHub Actions
    workflow for the Hybrid IaC AWS DevOps Lab.

    This script is designed for a project containing:

        - Terraform
        - AWS CloudFormation
        - GitHub Actions
        - AWS IAM
        - GitHub OIDC
        - AWS Secrets Manager
        - Docker
        - AWS resources
        - JSON IAM policies
        - PowerShell / Bash scripts

    IMPORTANT:
        This script is primarily READ-ONLY against AWS.

        It does NOT:
            - Create AWS resources
            - Delete AWS resources
            - Modify IAM
            - Modify Secrets Manager
            - Modify Terraform state
            - Deploy CloudFormation
            - Run terraform apply

    By default Terraform formatting is checked with:

        terraform fmt -check

    To automatically format Terraform files:

        .\preflight.ps1 -Fix

.PARAMETER ProjectRoot
    Root directory of the project.

    Default:
        Current directory.

.PARAMETER ExpectedAwsAccountId
    Expected AWS account ID.

    Example:

        .\preflight.ps1 -ExpectedAwsAccountId "123456789012"

    This is strongly recommended for AWS deployment labs.

.PARAMETER AwsProfile
    Optional AWS CLI profile.

    Example:

        .\preflight.ps1 -AwsProfile "default"

.PARAMETER AwsRegion
    Optional AWS region.

    Example:

        .\preflight.ps1 -AwsRegion "us-east-1"

.PARAMETER Fix
    Automatically run:

        terraform fmt

    instead of only checking formatting.

.PARAMETER SkipAws
    Skip AWS-side checks.

    Useful when working offline.

.PARAMETER VerboseOutput
    Display additional diagnostic information.

.EXAMPLE

    .\preflight.ps1

.EXAMPLE

    .\preflight.ps1 -ExpectedAwsAccountId "123456789012"

.EXAMPLE

    .\preflight.ps1 -ExpectedAwsAccountId "123456789012" -AwsRegion "us-east-1"

.EXAMPLE

    .\preflight.ps1 -Fix

.EXAMPLE

    .\preflight.ps1 -SkipAws

.NOTES
    Project:
        aws-hybrid-iac-lab

    Purpose:
        Validate the local repository and AWS environment before
        starting the GitHub Actions deployment workflow.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,

    [string]$ExpectedAwsAccountId = "",

    [string]$AwsProfile = "",

    [string]$AwsRegion = "",

    [switch]$Fix,

    [switch]$SkipAws,

    [switch]$VerboseOutput
)

# ============================================================
# GLOBAL SETTINGS
# ============================================================

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

# Resolve project root to an absolute path.
$ProjectRoot = (Resolve-Path $ProjectRoot).Path

# ============================================================
# LOGGING
# ============================================================

$LogDirectory = Join-Path $ProjectRoot "logs"

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

$LogFile = Join-Path `
    $LogDirectory `
    "preflight-$Timestamp.log"

# ============================================================
# RESULT COUNTERS
# ============================================================

$script:PassCount = 0
$script:WarnCount = 0
$script:FailCount = 0
$script:InfoCount = 0

$script:Failures = @()
$script:Warnings = @()

# ============================================================
# COLOR DEFINITIONS
# ============================================================

$Colors = @{
    Header = "Cyan"
    Info   = "White"
    Pass   = "Green"
    Warn   = "Yellow"
    Fail   = "Red"
    Debug  = "DarkGray"
    Title  = "Magenta"
}

# ============================================================
# OUTPUT FUNCTIONS
# ============================================================

function Write-Log {
    param(
        [string]$Message
    )

    $Message | Out-File `
        -FilePath $LogFile `
        -Append `
        -Encoding utf8
}

function Write-Header {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor $Colors.Header

    Write-Host $Message `
        -ForegroundColor $Colors.Header

    Write-Host "============================================================" `
        -ForegroundColor $Colors.Header

    Write-Log ""
    Write-Log "============================================================"
    Write-Log $Message
    Write-Log "============================================================"
}

function Write-Info {
    param(
        [string]$Message
    )

    $script:InfoCount++

    Write-Host "[INFO] " -NoNewline -ForegroundColor $Colors.Header
    Write-Host $Message -ForegroundColor $Colors.Info

    Write-Log "[INFO] $Message"
}

function Write-Pass {
    param(
        [string]$Message
    )

    $script:PassCount++

    Write-Host "[PASS] " -NoNewline -ForegroundColor $Colors.Pass
    Write-Host $Message -ForegroundColor $Colors.Pass

    Write-Log "[PASS] $Message"
}

function Write-Warn {
    param(
        [string]$Message
    )

    $script:WarnCount++

    Write-Host "[WARN] " -NoNewline -ForegroundColor $Colors.Warn
    Write-Host $Message -ForegroundColor $Colors.Warn

    Write-Log "[WARN] $Message"

    $script:Warnings += $Message
}

function Write-Fail {
    param(
        [string]$Message
    )

    $script:FailCount++

    Write-Host "[FAIL] " -NoNewline -ForegroundColor $Colors.Fail
    Write-Host $Message -ForegroundColor $Colors.Fail

    Write-Log "[FAIL] $Message"

    $script:Failures += $Message
}

function Write-DebugInfo {
    param(
        [string]$Message
    )

    if ($VerboseOutput) {
        Write-Host "[DEBUG] " -NoNewline -ForegroundColor $Colors.Debug
        Write-Host $Message -ForegroundColor $Colors.Debug
    }

    Write-Log "[DEBUG] $Message"
}

# ============================================================
# COMMAND HELPERS
# ============================================================

function Test-CommandExists {
    param(
        [Parameter(Mandatory)]
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [string[]]$Arguments = @()
    )

    try {
        $Output = & $Command @Arguments 2>&1

        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Output   = ($Output -join [Environment]::NewLine)
        }
    }
    catch {
        return [PSCustomObject]@{
            ExitCode = 1
            Output   = $_.Exception.Message
        }
    }
}

# ============================================================
# FILE HELPERS
# ============================================================

function Get-RelativePath {
    param(
        [string]$FullPath
    )

    try {
        return [System.IO.Path]::GetRelativePath(
            $ProjectRoot,
            $FullPath
        )
    }
    catch {
        return $FullPath
    }
}

function Get-FileLineNumber {
    param(
        [string]$FilePath,

        [string]$Pattern
    )

    if (-not (Test-Path $FilePath)) {
        return 0
    }

    try {
        $Lines = Get-Content `
            -Path $FilePath `
            -ErrorAction Stop

        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {

            if ($Lines[$Index] -match $Pattern) {
                return ($Index + 1)
            }
        }
    }
    catch {
        return 0
    }

    return 0
}

function Report-FileFailure {
    param(
        [string]$FilePath,

        [string]$Reason,

        [string]$Cause = ""
    )

    $RelativePath = Get-RelativePath $FilePath

    $Line = Get-FileLineNumber `
        -FilePath $FilePath `
        -Pattern $Reason

    if ($Line -gt 0) {
        $Location = "${RelativePath}:$Line"
    }
    else {
        $Location = $RelativePath
    }

    if ([string]::IsNullOrWhiteSpace($Cause)) {
        Write-Fail "$Location | $Reason"
    }
    else {
        Write-Fail "$Location | $Reason | Cause: $Cause"
    }
}

# ============================================================
# STOP FUNCTION
# ============================================================

function Stop-Preflight {
    param(
        [string]$Reason
    )

    Write-Host ""
    Write-Host "CRITICAL PREREQUISITE FAILURE" `
        -ForegroundColor $Colors.Fail

    Write-Host $Reason `
        -ForegroundColor $Colors.Fail

    Write-Log "[CRITICAL] $Reason"

    Write-Host ""
    Write-Host "Pre-flight validation stopped." `
        -ForegroundColor $Colors.Fail

    Write-Host "Log: $LogFile" `
        -ForegroundColor $Colors.Info

    exit 1
}

# ============================================================
# SECTION 01
# BASIC ENVIRONMENT
# ============================================================

Write-Header "01 - PowerShell Environment"

Write-Info "Project root: $ProjectRoot"
Write-Info "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Info "Operating system: $([System.Environment]::OSVersion.VersionString)"

# ============================================================
# SECTION 02
# REQUIRED TOOLS
# ============================================================

Write-Header "02 - Required Tools"

$RequiredTools = @(
    "git",
    "aws",
    "terraform",
    "docker"
)

foreach ($Tool in $RequiredTools) {

    if (Test-CommandExists $Tool) {

        $CommandInfo = Get-Command $Tool

        Write-Pass "$Tool installed: $($CommandInfo.Source)"
    }
    else {

        Write-Fail "$Tool is not installed or not available in PATH."
    }
}

if ($script:FailCount -gt 0) {
    Stop-Preflight `
        "One or more required tools are missing. Install them and run the pre-flight script again."
}

# ============================================================
# TOOL VERSION CHECK
# ============================================================

Write-Header "03 - Tool Versions"

$GitVersion = Invoke-ExternalCommand `
    -Command "git" `
    -Arguments @("--version")

if ($GitVersion.ExitCode -eq 0) {
    Write-Pass "Git: $($GitVersion.Output.Trim())"
}
else {
    Write-Fail "Unable to determine Git version."
}

$TerraformVersion = Invoke-ExternalCommand `
    -Command "terraform" `
    -Arguments @("version")

if ($TerraformVersion.ExitCode -eq 0) {
    $TerraformFirstLine = `
        ($TerraformVersion.Output -split "`r?`n")[0]

    Write-Pass "Terraform: $TerraformFirstLine"
}
else {
    Write-Fail "Unable to determine Terraform version."
}

$AwsVersion = Invoke-ExternalCommand `
    -Command "aws" `
    -Arguments @("--version")

if ($AwsVersion.ExitCode -eq 0) {
    Write-Pass "AWS CLI: $($AwsVersion.Output.Trim())"
}
else {
    Write-Fail "Unable to determine AWS CLI version."
}

$DockerVersion = Invoke-ExternalCommand `
    -Command "docker" `
    -Arguments @("--version")

if ($DockerVersion.ExitCode -eq 0) {
    Write-Pass "Docker: $($DockerVersion.Output.Trim())"
}
else {
    Write-Warn "Docker command exists but version check failed."
}

# ============================================================
# SECTION 04
# GIT REPOSITORY
# ============================================================

Write-Header "04 - Git Repository"

$GitDirectory = Join-Path $ProjectRoot ".git"

if (Test-Path $GitDirectory) {

    Write-Pass "Git repository detected."

    $GitStatus = Invoke-ExternalCommand `
        -Command "git" `
        -Arguments @(
            "-C",
            $ProjectRoot,
            "status",
            "--short"
        )

    if ($GitStatus.ExitCode -eq 0) {

        if ([string]::IsNullOrWhiteSpace($GitStatus.Output)) {

            Write-Pass "Working tree is clean."
        }
        else {

            Write-Warn `
                "Git working tree contains uncommitted changes."

            Write-DebugInfo $GitStatus.Output
        }
    }
    else {

        Write-Fail "Unable to read Git repository status."
    }

    $GitBranch = Invoke-ExternalCommand `
        -Command "git" `
        -Arguments @(
            "-C",
            $ProjectRoot,
            "branch",
            "--show-current"
        )

    if ($GitBranch.ExitCode -eq 0) {
        Write-Info "Current branch: $($GitBranch.Output.Trim())"
    }

    $GitRemote = Invoke-ExternalCommand `
        -Command "git" `
        -Arguments @(
            "-C",
            $ProjectRoot,
            "remote",
            "-v"
        )

    if ($GitRemote.ExitCode -eq 0) {

        if (-not [string]::IsNullOrWhiteSpace($GitRemote.Output)) {
            Write-Pass "Git remote configuration detected."
        }
        else {
            Write-Warn "No Git remote is configured."
        }
    }
}
else {

    Write-Fail "Project root is not a Git repository."
}

# ============================================================
# SECTION 05
# PROJECT STRUCTURE
# ============================================================

Write-Header "05 - Project Structure"

$RequiredDirectories = @(
    "infrastructure",
    "infrastructure/terraform",
    "infrastructure/cloudformation",
    ".github",
    ".github/workflows",
    "scripts",
    "logs"
)

foreach ($Directory in $RequiredDirectories) {

    $Path = Join-Path $ProjectRoot $Directory

    if (Test-Path $Path -PathType Container) {
        Write-Pass "Directory exists: $Directory"
    }
    else {
        Write-Fail "Required directory missing: $Directory"
    }
}

$RequiredFiles = @(
    "README.md"
)

foreach ($File in $RequiredFiles) {

    $Path = Join-Path $ProjectRoot $File

    if (Test-Path $Path -PathType Leaf) {
        Write-Pass "Required file exists: $File"
    }
    else {
        Write-Warn "Expected documentation file missing: $File"
    }
}

# ============================================================
# SECTION 06
# ARCHITECTURE / DOCUMENTATION
# ============================================================

Write-Header "06 - Lab Architecture Design"

$ArchitectureCandidates = @(
    "README.md",
    "docs",
    "docs/architecture",
    "architecture",
    "ARCHITECTURE.md"
)

$ArchitectureFound = $false

foreach ($Item in $ArchitectureCandidates) {

    $Path = Join-Path $ProjectRoot $Item

    if (Test-Path $Path) {

        $ArchitectureFound = $true

        Write-Pass "Architecture/documentation reference found: $Item"
    }
}

if (-not $ArchitectureFound) {

    Write-Warn `
        "No dedicated architecture document/directory was found."

    Write-Info `
        "The script cannot mathematically verify an architecture diagram. It can verify required architecture files and AWS resources."
}

# ============================================================
# SECTION 07
# TERRAFORM FILES
# ============================================================

Write-Header "07 - Terraform Files"

$TerraformDirectory = Join-Path `
    $ProjectRoot `
    "infrastructure/terraform"

$TerraformFiles = @()

if (Test-Path $TerraformDirectory) {

    $TerraformFiles = @(
        Get-ChildItem `
            -Path $TerraformDirectory `
            -Recurse `
            -File `
            -Include "*.tf", "*.tfvars"
}

if ($TerraformFiles.Count -gt 0) {

    Write-Pass `
        "Terraform files found: $($TerraformFiles.Count)"

    foreach ($File in $TerraformFiles) {

        Write-DebugInfo `
            "Terraform file: $(Get-RelativePath $File.FullName)"
    }
}
else {

    Write-Fail `
        "No Terraform files were found under infrastructure/terraform."
}

# ============================================================
# SECTION 08
# TERRAFORM FORMAT
# ============================================================

Write-Header "08 - Terraform Formatting"

if ($Fix) {

    Write-Info "Running terraform fmt..."

    $FmtResult = Invoke-ExternalCommand `
        -Command "terraform" `
        -Arguments @(
            "-chdir=$TerraformDirectory",
            "fmt",
            "-recursive"
        )

    if ($FmtResult.ExitCode -eq 0) {

        Write-Pass "Terraform formatting completed."

        if (-not [string]::IsNullOrWhiteSpace($FmtResult.Output)) {
            Write-DebugInfo $FmtResult.Output
        }
    }
    else {

        Write-Fail "terraform fmt failed."

        Write-DebugInfo $FmtResult.Output
    }
}
else {

    Write-Info `
        "Checking Terraform formatting without modifying files."

    $FmtCheck = Invoke-ExternalCommand `
        -Command "terraform" `
        -Arguments @(
            "-chdir=$TerraformDirectory",
            "fmt",
            "-check",
            "-recursive"
        )

    if ($FmtCheck.ExitCode -eq 0) {

        Write-Pass "Terraform formatting is correct."
    }
    else {

        Write-Fail `
            "Terraform formatting check failed."

        Write-DebugInfo $FmtCheck.Output

        Write-Warn `
            "Run .\preflight.ps1 -Fix to automatically format Terraform files."
    }
}

# ============================================================
# SECTION 09
# TERRAFORM VALIDATION
# ============================================================

Write-Header "09 - Terraform Validation"

$TerraformInitCheck = Invoke-ExternalCommand `
    -Command "terraform" `
    -Arguments @(
        "-chdir=$TerraformDirectory",
        "init",
        "-backend=false",
        "-input=false",
        "-upgrade=false"
    )

if ($TerraformInitCheck.ExitCode -eq 0) {

    Write-Pass `
        "Terraform initialization check completed."

}
else {

    Write-Fail `
        "Terraform initialization failed."

    Write-DebugInfo $TerraformInitCheck.Output
}

$TerraformValidate = Invoke-ExternalCommand `
    -Command "terraform" `
    -Arguments @(
        "-chdir=$TerraformDirectory",
        "validate"
    )

if ($TerraformValidate.ExitCode -eq 0) {

    Write-Pass "Terraform validate passed."
}
else {

    Write-Fail "Terraform validate failed."

    Write-DebugInfo $TerraformValidate.Output
}

# ============================================================
# SECTION 10
# CLOUD FORMATION FILES
# ============================================================

Write-Header "10 - CloudFormation Templates"

$CloudFormationDirectory = Join-Path `
    $ProjectRoot `
    "infrastructure/cloudformation"

$CloudFormationFiles = @()

if (Test-Path $CloudFormationDirectory) {

    $CloudFormationFiles = @(
        Get-ChildItem `
            -Path $CloudFormationDirectory `
            -Recurse `
            -File `
            -Include "*.yaml", "*.yml"
}

if ($CloudFormationFiles.Count -gt 0) {

    Write-Pass `
        "CloudFormation files found: $($CloudFormationFiles.Count)"

    foreach ($File in $CloudFormationFiles) {

        Write-DebugInfo `
            "CloudFormation file: $(Get-RelativePath $File.FullName)"
    }
}
else {

    Write-Fail `
        "No CloudFormation templates found."
}

# ============================================================
# SECTION 11
# CLOUDFORMATION VALIDATION
# ============================================================

Write-Header "11 - CloudFormation Validation"

foreach ($Template in $CloudFormationFiles) {

    $RelativeTemplate = Get-RelativePath $Template.FullName

    Write-Info "Validating: $RelativeTemplate"

    $Validation = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments @(
            "cloudformation",
            "validate-template",
            "--template-body",
            "file://$($Template.FullName)"
        )

    if ($Validation.ExitCode -eq 0) {

        Write-Pass `
            "CloudFormation validation passed: $RelativeTemplate"
    }
    else {

        Write-Fail `
            "$RelativeTemplate | CloudFormation validation failed"

        Write-DebugInfo $Validation.Output
    }
}

# ============================================================
# SECTION 12
# JSON FILE VALIDATION
# ============================================================

Write-Header "12 - JSON File Validation"

$JsonFiles = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -Filter "*.json"
)        

foreach ($JsonFile in $JsonFiles) {

    # Ignore generated / dependency directories.
    if (
        $JsonFile.FullName -match "\\\.git\\" -or
        $JsonFile.FullName -match "\\node_modules\\" -or
        $JsonFile.FullName -match "\\\.terraform\\"
    ) {
        continue
    }

    $RelativeJson = Get-RelativePath $JsonFile.FullName

    try {

        $Content = Get-Content `
            -Path $JsonFile.FullName `
            -Raw

        $null = $Content | ConvertFrom-Json

        Write-Pass "Valid JSON: $RelativeJson"
    }
    catch {

        $Message = $_.Exception.Message

        Write-Fail `
            "$RelativeJson | Invalid JSON | Cause: $Message"
    }
}

# ============================================================
# SECTION 13
# IAM POLICY JSON
# ============================================================

Write-Header "13 - IAM Policy Files"

$PotentialIamFiles = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -Filter "*.json" |
        Where-Object {
            $_.FullName -notmatch "\\\.git\\" -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\\.terraform\\"
        }
)

foreach ($PolicyFile in $PotentialIamFiles) {

    $RelativePolicy = Get-RelativePath $PolicyFile.FullName

    try {

        $PolicyContent = Get-Content `
            -Path $PolicyFile.FullName `
            -Raw

        $PolicyObject = $PolicyContent | ConvertFrom-Json

        if (
            $PolicyObject.Version -and
            $PolicyObject.Statement
        ) {

            Write-Pass `
                "IAM-style policy structure detected: $RelativePolicy"

            if (-not $PolicyObject.Statement) {

                Write-Fail `
                    "$RelativePolicy | IAM policy has no Statement."
            }
        }
    }
    catch {

        # Already reported by general JSON validation.
        Write-DebugInfo `
            "IAM policy parsing skipped: $RelativePolicy"
    }
}

# ==========================================================
# 14 - GitHub Actions Workflows
# ==========================================================

Write-Header "14 - GitHub Actions Workflows"

$WorkflowDirectory = Join-Path $ProjectRoot ".github\workflows"

$WorkflowFiles = @()

if (Test-Path $WorkflowDirectory) {

    $WorkflowFiles = @(
        Get-ChildItem `
            -Path $WorkflowDirectory `
            -File `
            -Include "*.yml", "*.yaml"
    )

    if ($WorkflowFiles.Count -eq 0) {

        Write-Warn "No GitHub Actions workflow files found."

    }
    else {

        Write-Pass "GitHub Actions workflow files found: $($WorkflowFiles.Count)"

        foreach ($WorkflowFile in $WorkflowFiles) {

            Write-Info "Checking workflow: $($WorkflowFile.FullName)"

            try {

                $WorkflowContent = Get-Content `
                    -Path $WorkflowFile.FullName `
                    -Raw `
                    -ErrorAction Stop

                if ([string]::IsNullOrWhiteSpace($WorkflowContent)) {

                    Write-Fail `
                        "Workflow file is empty: $($WorkflowFile.FullName)"

                    continue
                }

                if ($WorkflowContent -notmatch "(?m)^\s*name\s*:") {

                    Write-Warn `
                        "Workflow name not detected: $($WorkflowFile.FullName)"
                }
                else {

                    Write-Pass `
                        "Workflow name detected: $($WorkflowFile.Name)"
                }

                if ($WorkflowContent -notmatch "(?m)^\s*jobs\s*:") {

                    Write-Fail `
                        "GitHub Actions 'jobs:' section not detected: $($WorkflowFile.FullName)"
                }
                else {

                    Write-Pass `
                        "GitHub Actions 'jobs:' section detected: $($WorkflowFile.Name)"
                }

                if ($WorkflowContent -match "aws-actions/configure-aws-credentials") {

                    Write-Pass `
                        "AWS credentials action detected: $($WorkflowFile.Name)"
                }
                else {

                    Write-Warn `
                        "AWS credentials action not detected: $($WorkflowFile.Name)"
                }

                if ($WorkflowContent -match "role-to-assume") {

                    Write-Pass `
                        "OIDC role-to-assume detected: $($WorkflowFile.Name)"
                }
                else {

                    Write-Warn `
                        "OIDC 'role-to-assume' not detected: $($WorkflowFile.Name)"
                }

                if ($WorkflowContent -match "id-token:\s*write") {

                    Write-Pass `
                        "GitHub OIDC id-token permission detected: $($WorkflowFile.Name)"
                }
                else {

                    Write-Warn `
                        "GitHub OIDC 'id-token: write' permission not detected: $($WorkflowFile.Name)"
                }
            }
            catch {

                Write-Fail `
                    "Unable to read workflow file: $($WorkflowFile.FullName)"
            }
        }
    }
}
else {

    Write-Fail `
        "GitHub Actions workflow directory not found: $WorkflowDirectory"
}


# ============================================================
# SECTION 15
# SCRIPTS
# ============================================================

Write-Header "15 - Deployment Scripts"

$ScriptFiles = Get-ChildItem `
    -Path (Join-Path $ProjectRoot "scripts") `
    -Recurse `
    -File `
    -Include "*.ps1","*.sh","*.cmd","*.bat" `
    -ErrorAction SilentlyContinue

if ($ScriptFiles.Count -gt 0) {

    Write-Pass `
        "Deployment/utility scripts found: $($ScriptFiles.Count)"

    foreach ($Script in $ScriptFiles) {

        Write-DebugInfo `
            "Script: $(Get-RelativePath $Script.FullName)"
    }
}
else {

    Write-Warn `
        "No deployment scripts were found under scripts/."
}

# ============================================================
# SECTION 16
# DOCKER
# ============================================================

Write-Header "16 - Docker"

$DockerInfo = Invoke-ExternalCommand `
    -Command "docker" `
    -Arguments @("info")

if ($DockerInfo.ExitCode -eq 0) {

    Write-Pass "Docker daemon is available."
}
else {

    Write-Warn `
        "Docker CLI exists but Docker daemon is not available."

    Write-DebugInfo $DockerInfo.Output
}

$DockerFiles = Get-ChildItem `
    -Path $ProjectRoot `
    -Recurse `
    -File `
    -Filter "Dockerfile" `
    -ErrorAction SilentlyContinue

if ($DockerFiles.Count -gt 0) {

    Write-Pass `
        "Dockerfiles found: $($DockerFiles.Count)"
}
else {

    Write-Warn `
        "No Dockerfile found in project."
}

$DockerComposeFiles = Get-ChildItem `
    -Path $ProjectRoot `
    -Recurse `
    -File `
    -Include "docker-compose.yml","docker-compose.yaml" `
    -ErrorAction SilentlyContinue

if ($DockerComposeFiles.Count -gt 0) {

    Write-Pass `
        "Docker Compose file(s) detected."
}

# ============================================================
# SECTION 17
# ENVIRONMENT VARIABLES
# ============================================================

Write-Header "17 - Environment Variables"

$ImportantEnvironmentVariables = @(
    "AWS_REGION",
    "AWS_DEFAULT_REGION",
    "AWS_PROFILE"
)

foreach ($Variable in $ImportantEnvironmentVariables) {

    $Value = [Environment]::GetEnvironmentVariable($Variable)

    if (-not [string]::IsNullOrWhiteSpace($Value)) {

        Write-Pass "$Variable is configured."
    }
    else {

        Write-Info "$Variable is not set."
    }
}

# Never print secret values.

$SensitiveEnvironmentPatterns = @(
    "SECRET",
    "PASSWORD",
    "TOKEN",
    "ACCESS_KEY",
    "PRIVATE_KEY"
)

foreach ($EnvironmentVariable in `
    [Environment]::GetEnvironmentVariables("Process").Keys) {

    foreach ($Pattern in $SensitiveEnvironmentPatterns) {

        if ($EnvironmentVariable -match $Pattern) {

            Write-DebugInfo `
                "Sensitive environment variable detected: $EnvironmentVariable (value hidden)"

            break
        }
    }
}

# ============================================================
# SECTION 18
# AWS CHECKS
# ============================================================

if ($SkipAws) {

    Write-Header "18 - AWS Checks"

    Write-Warn "AWS checks skipped because -SkipAws was specified."
}
else {

    # ========================================================
    # AWS CREDENTIALS
    # ========================================================

    Write-Header "18 - AWS Credentials / Account"

    $AwsIdentityArguments = @(
        "sts",
        "get-caller-identity",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {

        $AwsIdentityArguments += @(
            "--profile",
            $AwsProfile
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {

        $AwsIdentityArguments += @(
            "--region",
            $AwsRegion
        )
    }

    $IdentityResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $AwsIdentityArguments

    if ($IdentityResult.ExitCode -ne 0) {

        Write-Fail `
            "AWS authentication failed | Cause: $($IdentityResult.Output)"

        Stop-Preflight `
            "AWS credentials are not valid or AWS CLI authentication failed."
    }

    try {

        $Identity = `
            $IdentityResult.Output |
            ConvertFrom-Json

        $AwsAccountId = [string]$Identity.Account
        $AwsArn = [string]$Identity.Arn

        Write-Pass "AWS credentials are valid."
        Write-Pass "AWS account: $AwsAccountId"

        # ARN is safe to display, but no credential material is printed.
        Write-Info "Caller ARN: $AwsArn"
    }
    catch {

        Stop-Preflight `
            "AWS STS returned an unexpected response."
    }

    # ========================================================
    # AWS ACCOUNT PROTECTION
    # ========================================================

    if (-not [string]::IsNullOrWhiteSpace($ExpectedAwsAccountId)) {

        if ($AwsAccountId -eq $ExpectedAwsAccountId) {

            Write-Pass `
                "AWS account matches expected account."
        }
        else {

            Write-Fail `
                "AWS account mismatch | Expected: $ExpectedAwsAccountId | Current: $AwsAccountId"

            Stop-Preflight `
                "Safety check stopped deployment because the authenticated AWS account is not the expected account."
        }
    }
    else {

        Write-Warn `
            "Expected AWS account ID was not supplied. Account safety protection is disabled."

        Write-Info `
            "Recommended: use -ExpectedAwsAccountId YOUR_ACCOUNT_ID"
    }

    # ========================================================
    # AWS REGION
    # ========================================================

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {

        Write-Pass `
            "AWS region supplied: $AwsRegion"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:AWS_REGION)) {

        Write-Pass `
            "AWS region from environment: $env:AWS_REGION"
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:AWS_DEFAULT_REGION)) {

        Write-Pass `
            "AWS region from environment: $env:AWS_DEFAULT_REGION"
    }
    else {

        Write-Warn `
            "AWS region was not explicitly configured."
    }

    # ========================================================
    # IAM USERS
    # ========================================================

    Write-Header "19 - IAM Users"

    $IamUsersArguments = @(
        "iam",
        "list-users",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {

        $IamUsersArguments += @(
            "--profile",
            $AwsProfile
        )
    }

    $IamUsersResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $IamUsersArguments

    if ($IamUsersResult.ExitCode -eq 0) {

        try {

            $IamUsers = `
                $IamUsersResult.Output |
                ConvertFrom-Json

            $UserCount = @($IamUsers.Users).Count

            Write-Pass `
                "IAM users query succeeded. User count: $UserCount"

            foreach ($User in @($IamUsers.Users)) {

                $Username = [string]$User.UserName

                Write-Info `
                    "IAM user detected: $Username"

                # Attached managed policies.
                $UserPoliciesArgs = @(
                    "iam",
                    "list-attached-user-policies",
                    "--user-name",
                    $Username,
                    "--output",
                    "json"
                )

                if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                    $UserPoliciesArgs += @(
                        "--profile",
                        $AwsProfile
                    )
                }

                $UserPolicies = Invoke-ExternalCommand `
                    -Command "aws" `
                    -Arguments $UserPoliciesArgs

                if ($UserPolicies.ExitCode -eq 0) {

                    Write-Pass `
                        "$Username | Attached managed policies query succeeded."
                }
                else {

                    Write-Warn `
                        "$Username | Unable to query attached policies."
                }

                # Inline policies.
                $InlineArgs = @(
                    "iam",
                    "list-user-policies",
                    "--user-name",
                    $Username,
                    "--output",
                    "json"
                )

                if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                    $InlineArgs += @(
                        "--profile",
                        $AwsProfile
                    )
                }

                $InlineResult = Invoke-ExternalCommand `
                    -Command "aws" `
                    -Arguments $InlineArgs

                if ($InlineResult.ExitCode -eq 0) {

                    Write-Pass `
                        "$Username | Inline policy query succeeded."
                }
                else {

                    Write-Warn `
                        "$Username | Unable to query inline policies."
                }

                # Groups.
                $GroupArgs = @(
                    "iam",
                    "list-groups-for-user",
                    "--user-name",
                    $Username,
                    "--output",
                    "json"
                )

                if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                    $GroupArgs += @(
                        "--profile",
                        $AwsProfile
                    )
                }

                $GroupResult = Invoke-ExternalCommand `
                    -Command "aws" `
                    -Arguments $GroupArgs

                if ($GroupResult.ExitCode -eq 0) {

                    Write-Pass `
                        "$Username | Group membership query succeeded."
                }
                else {

                    Write-Warn `
                        "$Username | Unable to query group membership."
                }
            }
        }
        catch {

            Write-Fail `
                "Unable to parse IAM users response."
        }
    }
    else {

        Write-Warn `
            "Unable to query IAM users | Cause: $($IamUsersResult.Output)"
    }

    # ========================================================
    # IAM ROLES
    # ========================================================

    Write-Header "20 - IAM Roles / Trust Policies"

    $IamRolesArguments = @(
        "iam",
        "list-roles",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {

        $IamRolesArguments += @(
            "--profile",
            $AwsProfile
        )
    }

    $IamRolesResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $IamRolesArguments

    if ($IamRolesResult.ExitCode -eq 0) {

        try {

            $IamRoles = `
                $IamRolesResult.Output |
                ConvertFrom-Json

            $RoleCount = @($IamRoles.Roles).Count

            Write-Pass `
                "IAM roles query succeeded. Role count: $RoleCount"

            foreach ($Role in @($IamRoles.Roles)) {

                $RoleName = [string]$Role.RoleName

                Write-Info `
                    "IAM role detected: $RoleName"

                # Get role trust policy.
                $RoleArgs = @(
                    "iam",
                    "get-role",
                    "--role-name",
                    $RoleName,
                    "--output",
                    "json"
                )

                if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                    $RoleArgs += @(
                        "--profile",
                        $AwsProfile
                    )
                }

                $RoleResult = Invoke-ExternalCommand `
                    -Command "aws" `
                    -Arguments $RoleArgs

                if ($RoleResult.ExitCode -eq 0) {

                    Write-Pass `
                        "$RoleName | Trust policy query succeeded."
                }
                else {

                    Write-Warn `
                        "$RoleName | Trust policy query failed."
                }

                # Managed policies attached to role.
                $AttachedRolePolicyArgs = @(
                    "iam",
                    "list-attached-role-policies",
                    "--role-name",
                    $RoleName,
                    "--output",
                    "json"
                )

                if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                    $AttachedRolePolicyArgs += @(
                        "--profile",
                        $AwsProfile
                    )
                }

                $AttachedRolePolicyResult = Invoke-ExternalCommand `
                    -Command "aws" `
                    -Arguments $AttachedRolePolicyArgs

                if ($AttachedRolePolicyResult.ExitCode -eq 0) {

                    Write-Pass `
                        "$RoleName | Attached role policies query succeeded."
                }
                else {

                    Write-Warn `
                        "$RoleName | Attached role policies query failed."
                }

                # Inline policies.
                $InlineRoleArgs = @(
                    "iam",
                    "list-role-policies",
                    "--role-name",
                    $RoleName,
                    "--output",
                    "json"
                )

                if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                    $InlineRoleArgs += @(
                        "--profile",
                        $AwsProfile
                    )
                }

                $InlineRoleResult = Invoke-ExternalCommand `
                    -Command "aws" `
                    -Arguments $InlineRoleArgs

                if ($InlineRoleResult.ExitCode -eq 0) {

                    Write-Pass `
                        "$RoleName | Inline role policy query succeeded."
                }
                else {

                    Write-Warn `
                        "$RoleName | Inline role policy query failed."
                }
            }
        }
        catch {

            Write-Fail `
                "Unable to parse IAM roles response."
        }
    }
    else {

        Write-Warn `
            "Unable to query IAM roles | Cause: $($IamRolesResult.Output)"
    }

    # ========================================================
    # GITHUB OIDC
    # ========================================================

    Write-Header "21 - GitHub OIDC"

    $OidcListArguments = @(
        "iam",
        "list-open-id-connect-providers",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {

        $OidcListArguments += @(
            "--profile",
            $AwsProfile
        )
    }

    $OidcResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $OidcListArguments

    if ($OidcResult.ExitCode -eq 0) {

        try {

            $OidcProviders = `
                $OidcResult.Output |
                ConvertFrom-Json

            $GitHubOidcFound = $false

            foreach ($Provider in @($OidcProviders.OpenIDConnectProviderList)) {

                $Arn = [string]$Provider.Arn

                if ($Arn -match "token\.actions\.githubusercontent\.com") {

                    $GitHubOidcFound = $true

                    Write-Pass `
                        "GitHub OIDC provider detected."

                    Write-Info `
                        "OIDC provider ARN: $Arn"

                    $OidcDetailsArgs = @(
                        "iam",
                        "get-open-id-connect-provider",
                        "--open-id-connect-provider-arn",
                        $Arn,
                        "--output",
                        "json"
                    )

                    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
                        $OidcDetailsArgs += @(
                            "--profile",
                            $AwsProfile
                        )
                    }

                    $OidcDetails = Invoke-ExternalCommand `
                        -Command "aws" `
                        -Arguments $OidcDetailsArgs

                    if ($OidcDetails.ExitCode -eq 0) {

                        Write-Pass `
                            "GitHub OIDC provider details verified."
                    }
                    else {

                        Write-Warn `
                            "Unable to retrieve GitHub OIDC provider details."
                    }
                }
            }

            if (-not $GitHubOidcFound) {

                Write-Warn `
                    "GitHub OIDC provider was not found in this AWS account."
            }
        }
        catch {

            Write-Warn `
                "Unable to parse OIDC provider response."
        }
    }
    else {

        Write-Warn `
            "Unable to query OIDC providers."
    }

    # ========================================================
    # SECRETS MANAGER
    # ========================================================

    Write-Header "22 - AWS Secrets Manager"

    $SecretsArguments = @(
        "secretsmanager",
        "list-secrets",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {

        $SecretsArguments += @(
            "--profile",
            $AwsProfile
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {

        $SecretsArguments += @(
            "--region",
            $AwsRegion
        )
    }

    $SecretsResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $SecretsArguments

    if ($SecretsResult.ExitCode -eq 0) {

        try {

            $Secrets = `
                $SecretsResult.Output |
                ConvertFrom-Json

            $SecretCount = @($Secrets.SecretList).Count

            Write-Pass `
                "Secrets Manager query succeeded. Secret count: $SecretCount"

            foreach ($Secret in @($Secrets.SecretList)) {

                $SecretName = [string]$Secret.Name

                Write-Info `
                    "Secret detected: $SecretName"

                # IMPORTANT:
                # We intentionally DO NOT retrieve SecretString.
                # Secret values must never appear in this log.
            }
        }
        catch {

            Write-Warn `
                "Unable to parse Secrets Manager response."
        }
    }
    else {

        Write-Warn `
            "Secrets Manager query failed | Cause: $($SecretsResult.Output)"
    }

    # ========================================================
    # AWS RESOURCE DISCOVERY
    # ========================================================

    Write-Header "23 - Existing AWS Resources"

    # --------------------------------------------------------
    # CloudFormation
    # --------------------------------------------------------

    $StackArgs = @(
        "cloudformation",
        "list-stacks",
        "--stack-status-filter",
        "CREATE_COMPLETE",
        "UPDATE_COMPLETE",
        "UPDATE_ROLLBACK_COMPLETE",
        "UPDATE_ROLLBACK_FAILED",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $StackArgs += @("--profile", $AwsProfile)
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {
        $StackArgs += @("--region", $AwsRegion)
    }

    $StacksResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $StackArgs

    if ($StacksResult.ExitCode -eq 0) {

        try {

            $Stacks = `
                $StacksResult.Output |
                ConvertFrom-Json

            $StackCount = @($Stacks.StackSummaries).Count

            Write-Pass `
                "CloudFormation stacks query succeeded. Stack count: $StackCount"
        }
        catch {

            Write-Warn `
                "Unable to parse CloudFormation stack response."
        }
    }
    else {

        Write-Warn `
            "CloudFormation stack query failed."
    }

    # --------------------------------------------------------
    # ECR
    # --------------------------------------------------------

    $EcrArgs = @(
        "ecr",
        "describe-repositories",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $EcrArgs += @("--profile", $AwsProfile)
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {
        $EcrArgs += @("--region", $AwsRegion)
    }

    $EcrResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $EcrArgs

    if ($EcrResult.ExitCode -eq 0) {

        try {

            $Repositories = `
                $EcrResult.Output |
                ConvertFrom-Json

            $RepositoryCount = @($Repositories.repositories).Count

            Write-Pass `
                "ECR query succeeded. Repository count: $RepositoryCount"
        }
        catch {

            Write-Warn `
                "Unable to parse ECR response."
        }
    }
    else {

        Write-Info `
            "No ECR repositories returned or ECR is not configured."
    }

    # --------------------------------------------------------
    # S3
    # --------------------------------------------------------

    $S3Args = @(
        "s3api",
        "list-buckets",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $S3Args += @("--profile", $AwsProfile)
    }

    $S3Result = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $S3Args

    if ($S3Result.ExitCode -eq 0) {

        try {

            $Buckets = `
                $S3Result.Output |
                ConvertFrom-Json

            $BucketCount = @($Buckets.Buckets).Count

            Write-Pass `
                "S3 query succeeded. Bucket count: $BucketCount"
        }
        catch {

            Write-Warn `
                "Unable to parse S3 response."
        }
    }
    else {

        Write-Warn `
            "Unable to query S3 buckets."
    }

    # --------------------------------------------------------
    # VPC
    # --------------------------------------------------------

    $VpcArgs = @(
        "ec2",
        "describe-vpcs",
        "--output",
        "json"
    )

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $VpcArgs += @("--profile", $AwsProfile)
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {
        $VpcArgs += @("--region", $AwsRegion)
    }

    $VpcResult = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $VpcArgs

    if ($VpcResult.ExitCode -eq 0) {

        try {

            $Vpcs = `
                $VpcResult.Output |
                ConvertFrom-Json

            $VpcCount = @($Vpcs.Vpcs).Count

            Write-Pass `
                "VPC query succeeded. VPC count: $VpcCount"
        }
        catch {

            Write-Warn `
                "Unable to parse VPC response."
        }
    }
    else {

        Write-Warn `
            "Unable to query VPC resources."
    }
}

# ============================================================
# SECTION 24
# FINAL REPORT
# ============================================================

Write-Header "FINAL PRE-FLIGHT REPORT"

Write-Host ""
Write-Host "PASS : $script:PassCount" `
    -ForegroundColor $Colors.Pass

Write-Host "WARN : $script:WarnCount" `
    -ForegroundColor $Colors.Warn

Write-Host "FAIL : $script:FailCount" `
    -ForegroundColor $Colors.Fail

Write-Host "INFO : $script:InfoCount" `
    -ForegroundColor $Colors.Info

Write-Host ""

if ($script:Failures.Count -gt 0) {

    Write-Host "============================================================" `
        -ForegroundColor $Colors.Fail

    Write-Host "STATUS: NOT READY" `
        -ForegroundColor $Colors.Fail

    Write-Host "============================================================" `
        -ForegroundColor $Colors.Fail

    Write-Host ""
    Write-Host "Critical issues:" `
        -ForegroundColor $Colors.Fail

    foreach ($Failure in $script:Failures) {

        Write-Host " - $Failure" `
            -ForegroundColor $Colors.Fail
    }

    Write-Host ""

    if ($script:Warnings.Count -gt 0) {

        Write-Host "Warnings:" `
            -ForegroundColor $Colors.Warn

        foreach ($Warning in $script:Warnings) {

            Write-Host " - $Warning" `
                -ForegroundColor $Colors.Warn
        }
    }

    Write-Host ""
    Write-Host "GitHub workflow MUST NOT be started." `
        -ForegroundColor $Colors.Fail

    Write-Host ""
    Write-Host "Short log report:" `
        -ForegroundColor $Colors.Info

    Write-Host $LogFile `
        -ForegroundColor $Colors.Info

    Write-Log ""
    Write-Log "============================================================"
    Write-Log "STATUS: NOT READY"
    Write-Log "============================================================"

    exit 1
}
else {

    Write-Host "============================================================" `
        -ForegroundColor $Colors.Pass

    Write-Host "STATUS: READY" `
        -ForegroundColor $Colors.Pass

    Write-Host "============================================================" `
        -ForegroundColor $Colors.Pass

    Write-Host ""
    Write-Host "All blocking pre-flight checks passed." `
        -ForegroundColor $Colors.Pass

    Write-Host "GitHub workflow may be started." `
        -ForegroundColor $Colors.Pass

    Write-Host ""
    Write-Host "Log:" `
        -ForegroundColor $Colors.Info

    Write-Host $LogFile `
        -ForegroundColor $Colors.Info

    Write-Log ""
    Write-Log "============================================================"
    Write-Log "STATUS: READY"
    Write-Log "============================================================"

    exit 0
}
```

### Recommended usage

From the **root of your repository**:

```powershell
.\preflight.ps1
```

For your actual lab, I recommend using the AWS-account safety check:

```powershell
.\preflight.ps1 -ExpectedAwsAccountId "537236558357"
```

If you use a particular AWS CLI profile:

```powershell
.\preflight.ps1 -ExpectedAwsAccountId "537236558357" -AwsProfile "default"
```

If you want Terraform automatically formatted:

```powershell
.\preflight.ps1 -ExpectedAwsAccountId "537236558357" -Fix
```

If you're working without AWS connectivity:

```powershell
.\preflight.ps1 -SkipAws
```

For more detailed diagnostic output:

```powershell
.\preflight.ps1 -VerboseOutput
```

### What the console will look like

The script deliberately uses different colors:

```text
============================================================
02 - Required Tools
============================================================

[PASS] git installed
[PASS] aws installed
[PASS] terraform installed
[PASS] docker installed

============================================================
09 - Terraform Validation
============================================================

[PASS] Terraform formatting is correct.
[PASS] Terraform initialization check completed.
[PASS] Terraform validate passed.

============================================================
21 - GitHub OIDC
============================================================

[PASS] GitHub OIDC provider detected.
[PASS] GitHub OIDC provider details verified.

============================================================
FINAL PRE-FLIGHT REPORT
============================================================

PASS : 47
WARN : 2
FAIL : 0
INFO : 18

============================================================
STATUS: READY
============================================================

All blocking pre-flight checks passed.
GitHub workflow may be started.
```

If something fails:

```text
[FAIL] infrastructure/terraform/iam.tf:42 | Terraform validate failed
[FAIL] policies/github-oidc-trust.json | Invalid JSON
[WARN] Docker CLI exists but Docker daemon is not available.

============================================================
STATUS: NOT READY
============================================================

GitHub workflow MUST NOT be started.
```

### Important improvement for your lab

There is one area I would **not pretend this first version can fully validate**: the actual relationship between your **architecture design → Terraform → CloudFormation → AWS resources**.

For example, merely finding an ECR repository doesn't prove that:

```text
CloudFormation
      ↓
ECR
      ↓
Terraform reference/import
      ↓
GitHub Actions
      ↓
Docker
      ↓
ECS/EKS
```

is correctly wired.

The next version can make this much more powerful by adding a **Lab Manifest**, for example:

```yaml
# preflight-manifest.yaml

aws:
  region: us-east-1
  account_id: "537236558357"

resources:
  ecr:
    - charlie-cafe

  secrets_manager:
    - CafeDevDBSM

  iam_roles:
    - GitHubActionsRole

  oidc:
    provider: token.actions.githubusercontent.com

terraform:
  required_directories:
    - infrastructure/terraform

cloudformation:
  required_directories:
    - infrastructure/cloudformation

github:
  workflows:
    - deploy.yml

docker:
  required: true
```

Then the PowerShell script can compare:

**Expected architecture/configuration**

against

**actual repository**

and

**actual AWS account**

and produce a much more useful result such as:

```text
PASS | ECR | charlie-cafe
PASS | Secrets Manager | CafeDevDBSM
PASS | IAM Role | GitHubActionsRole
PASS | GitHub OIDC | token.actions.githubusercontent.com
PASS | Terraform | validated
PASS | CloudFormation | validated
PASS | GitHub Workflow | deploy.yml
PASS | Docker | available

FAIL | IAM Role | GitHubActionsRole
      Trust policy does not match expected GitHub repository.

FAIL | Terraform | infrastructure/terraform/iam-imports.tf:42
      Expected IAM role ARN does not match configured role.

STATUS: NOT READY
```

That **manifest-driven approach is what I recommend for the final version of your lab**, because it prevents the pre-flight script from merely checking whether something exists; it checks whether the pieces are the **specific pieces your hybrid IaC architecture expects**.

Also, the script above deliberately **never retrieves or prints Secrets Manager secret values**. It only verifies the Secrets Manager service/query and secret metadata, which is the safer behavior for a pre-deployment validator.

What I recommend before deployment

For your Hybrid IaC AWS lab, I would not change the infrastructure yet. First, eliminate the warnings that are meaningful for deployment.

Run the preflight with your known AWS account ID and your actual AWS region:

.\scripts\preflight.ps1 `
    -ExpectedAwsAccountId "537236558357" `
    -AwsRegion "YOUR-AWS-REGION"

For example, if your lab is actually in ap-south-1:

.\scripts\preflight.ps1 `
    -ExpectedAwsAccountId "537236558357" `
    -AwsRegion "ap-south-1"

Don't use ap-south-1 unless that is really where your resources are deployed.

Docker warning

If Docker is supposed to be used by your GitHub Actions/deployment process, start Docker Desktop and verify:

docker info

You want Docker to return server/engine information rather than a daemon connection error.

If Docker isn't required for this particular preflight/deployment path, this can remain a warning.

The three AWS query warnings

These are the ones I'd investigate next:

aws secretsmanager list-secrets --output table
aws eks list-clusters
aws cloudfront list-distributions --output table

These commands do not retrieve secret values. list-secrets only lists metadata.

If your AWS CLI uses a specific region/profile, include those explicitly, for example:

aws eks list-clusters --region YOUR-AWS-REGION

EKS is regional, while CloudFront is a global AWS service, so their handling in the validator should be slightly different.

main-deploy.yaml

I would not automatically modify this workflow just because the validator reports:

[WARN] AWS authentication action/reference not detected
[WARN] role-to-assume not detected

Your other workflows already have:

AWS authentication action/reference detected
role-to-assume detected
GitHub OIDC id-token: write detected

main-deploy.yaml may be a caller/reusable workflow or may delegate AWS authentication to another workflow/job. The validator should ideally understand that rather than treating every workflow as independently responsible for authentication.
---
You actually have **two different issues**, and the second one confirms that the script **does exist**.

### 1. First command

You ran:

```powershell
.\preflight.ps1
```

from:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

But the script is inside `scripts`, so PowerShell correctly says it cannot find it.

### 2. Correct location

You then ran:

```powershell
.\scripts\preflight.ps1
```

This time PowerShell **found the script**, but Windows PowerShell's execution policy blocked it:

```text
running scripts is disabled on this system
```

### Recommended solution

You can allow scripts **only for the current PowerShell session**. This does not permanently change your machine's execution policy.

Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then:

```powershell
.\scripts\preflight.ps1
```

So your exact sequence is:

```powershell
PS C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

PS C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab> .\scripts\preflight.ps1
```

If PowerShell asks:

```text
Execution Policy Change
```

choose:

```text
Y
```

### Why I recommend `-Scope Process`

`Process` means the bypass applies **only to this PowerShell window**.

When you close the PowerShell window, the setting goes away. You don't need to weaken your system-wide execution policy.

---

### If you want to verify first

Run:

```powershell
Get-ExecutionPolicy -List
```

You can also confirm the script exists:

```powershell
Test-Path .\scripts\preflight.ps1
```

Expected:

```text
True
```

Then run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\preflight.ps1
```

**Do not move the script** just to fix this. Your current location:

```text
aws-hybrid-iac-lab\
└── scripts\
    └── preflight.ps1
```

is perfectly fine.
---
Fully Final Script


```
#requires -Version 5.1

<#
.SYNOPSIS
    Read-only pre-flight validator for the AWS Hybrid IaC Lab.

.DESCRIPTION
    Validates the local project, required tools, Terraform,
    CloudFormation, IAM JSON, GitHub Actions, Docker, AWS
    credentials, IAM resources, GitHub OIDC, Secrets Manager,
    and selected existing AWS resources.

    IMPORTANT:
    - This script is READ-ONLY against AWS.
    - It does NOT create, modify, delete, import, or deploy AWS resources.
    - It does NOT retrieve or print secret values.
    - It does NOT run "terraform apply".
    - It does NOT run "terraform destroy".
    - It does NOT run CloudFormation create/update/delete commands.

    The script is intended to run BEFORE the GitHub Actions deployment
    workflow so that configuration problems are detected early.

.EXAMPLE
    .\scripts\preflight.ps1

.EXAMPLE
    .\scripts\preflight.ps1 -ExpectedAwsAccountId "537236558357"

.EXAMPLE
    .\scripts\preflight.ps1 -AwsRegion "us-east-1"

.EXAMPLE
    .\scripts\preflight.ps1 `
        -ExpectedAwsAccountId "537236558357" `
        -AwsRegion "us-east-1"

.NOTES
    Compatible with Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    # Project root defaults to the directory from which the script is started.
    [string]$ProjectRoot = (Get-Location).Path,

    # Optional AWS account ID expected by this lab.
    [string]$ExpectedAwsAccountId = "",

    # Optional AWS CLI profile.
    [string]$AwsProfile = "",

    # Optional AWS region.
    [string]$AwsRegion = "",

    # Reserved for future repair functionality.
    # This script intentionally does not mutate AWS resources.
    [switch]$Fix,

    # Skip all AWS checks.
    [switch]$SkipAws,

    # Enable additional diagnostic output.
    [switch]$VerboseOutput
)

# ============================================================
# GLOBAL SETTINGS
# ============================================================

Set-StrictMode -Version Latest

# Stop only inside controlled function blocks.
# Individual validation functions catch expected command failures.
$ErrorActionPreference = "Stop"

# Resolve project root to an absolute path.
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

# Script directory.
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Log directory.
$LogDirectory = Join-Path $ProjectRoot "logs"

# Create log directory if it does not exist.
if (-not (Test-Path -LiteralPath $LogDirectory)) {
    New-Item `
        -Path $LogDirectory `
        -ItemType Directory `
        -Force `
        | Out-Null
}

# Timestamp used for the preflight log.
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Full log path.
$LogFile = Join-Path $LogDirectory "preflight-$Timestamp.log"

# ============================================================
# COLORS
# ============================================================

$Colors = @{
    Header = "Cyan"
    Pass   = "Green"
    Warn   = "Yellow"
    Fail   = "Red"
    Info   = "White"
    Detail = "DarkGray"
}

# ============================================================
# RESULT STORAGE
# ============================================================

$Results = New-Object System.Collections.ArrayList

$GlobalState = @{
    CriticalFailure = $false
    AwsAvailable    = $false
    AwsAccountId    = ""
    AwsRegion       = ""
}

# ============================================================
# LOGGING FUNCTIONS
# ============================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to the preflight log.

    .IMPORTANT
        AllowEmptyString() is required because the script intentionally
        writes blank lines to the log.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message
    )

    try {
        $Message |
            Out-File `
                -FilePath $LogFile `
                -Append `
                -Encoding utf8
    }
    catch {
        # Logging failure must never hide the real validation result.
    }
}

function Write-Header {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Colors.Header
    Write-Host $Message -ForegroundColor $Colors.Header
    Write-Host "============================================================" -ForegroundColor $Colors.Header

    Write-Log ""
    Write-Log "============================================================"
    Write-Log $Message
    Write-Log "============================================================"
}

function Write-Info {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Info
    Write-Log "[INFO] $Message"
}

function Write-Pass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[PASS] $Message" -ForegroundColor $Colors.Pass
    Write-Log "[PASS] $Message"

    [void]$Results.Add(
        [PSCustomObject]@{
            Status  = "PASS"
            Message = $Message
        }
    )
}

function Write-Warn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "[WARN] $Message" -ForegroundColor $Colors.Warn
    Write-Log "[WARN] $Message"

    [void]$Results.Add(
        [PSCustomObject]@{
            Status  = "WARN"
            Message = $Message
        }
    )
}

function Write-Fail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [switch]$Critical
    )

    Write-Host "[FAIL] $Message" -ForegroundColor $Colors.Fail
    Write-Log "[FAIL] $Message"

    [void]$Results.Add(
        [PSCustomObject]@{
            Status  = "FAIL"
            Message = $Message
        }
    )

    if ($Critical) {
        $GlobalState.CriticalFailure = $true
    }
}

function Write-Detail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($VerboseOutput) {
        Write-Host "       $Message" -ForegroundColor $Colors.Detail
    }

    Write-Log "       $Message"
}

# ============================================================
# GENERAL HELPERS
# ============================================================

function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $RootUri = New-Object System.Uri(
            ((Get-Item -LiteralPath $ProjectRoot).FullName + [System.IO.Path]::DirectorySeparatorChar)
        )

        $PathUri = New-Object System.Uri(
            (Get-Item -LiteralPath $Path).FullName
        )

        return [System.Uri]::UnescapeDataString(
            $RootUri.MakeRelativeUri($PathUri).ToString()
        ).Replace("/", "\")
    }
    catch {
        return $Path
    }
}

function Get-FileLineNumber {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    try {
        $Lines = @(Get-Content -LiteralPath $FilePath -ErrorAction Stop)

        for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
            if ($Lines[$Index] -match $Pattern) {
                return ($Index + 1)
            }
        }
    }
    catch {
        return 0
    }

    return 0
}

function Add-Result {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    switch ($Status) {
        "PASS" {
            Write-Pass $Message
        }

        "WARN" {
            Write-Warn $Message
        }

        "FAIL" {
            Write-Fail $Message
        }
    }
}

# ============================================================
# EXTERNAL COMMAND EXECUTION
# ============================================================

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
        Executes a local command and captures output safely.

    .NOTES
        Works with Windows PowerShell 5.1.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @()
    )

    $Output = @()

    try {
        $Output = @(
            & $Command @Arguments 2>&1
        )

        return [PSCustomObject]@{
            Success = ($LASTEXITCODE -eq 0)
            ExitCode = $LASTEXITCODE
            Output = $Output
        }
    }
    catch {
        return [PSCustomObject]@{
            Success = $false
            ExitCode = -1
            Output = @($_.Exception.Message)
        }
    }
}

# ============================================================
# AWS ARGUMENT HELPERS
# ============================================================

function Get-AwsArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $FinalArguments = New-Object System.Collections.Generic.List[string]

    foreach ($Argument in $Arguments) {
        [void]$FinalArguments.Add($Argument)
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        [void]$FinalArguments.Add("--profile")
        [void]$FinalArguments.Add($AwsProfile)
    }

    if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {
        [void]$FinalArguments.Add("--region")
        [void]$FinalArguments.Add($AwsRegion)
    }

    return @($FinalArguments)
}

function Invoke-AwsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $FinalArguments = Get-AwsArguments -Arguments $Arguments

    return Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments $FinalArguments
}

# ============================================================
# JSON VALIDATION
# ============================================================

function Test-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        $Content = Get-Content `
            -LiteralPath $FilePath `
            -Raw `
            -ErrorAction Stop

        $null = $Content | ConvertFrom-Json

        return $true
    }
    catch {
        return $false
    }
}

# ============================================================
# SECTION 01
# POWERSHELL ENVIRONMENT
# ============================================================

Write-Header "01 - PowerShell Environment"

Write-Info "PowerShell version: $($PSVersionTable.PSVersion)"

if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Pass "Windows PowerShell 5.1 or newer detected."
}
else {
    Write-Fail "PowerShell 5.1 or newer is required."
}

Write-Info "Project root: $ProjectRoot"

if (Test-Path -LiteralPath $ProjectRoot) {
    Write-Pass "Project root exists."
}
else {
    Write-Fail "Project root does not exist: $ProjectRoot" -Critical
}

# ============================================================
# SECTION 02
# REQUIRED TOOLS
# ============================================================

Write-Header "02 - Required Tools"

$RequiredCommands = @(
    "git",
    "aws",
    "terraform",
    "docker"
)

foreach ($Tool in $RequiredCommands) {
    if (Test-CommandExists $Tool) {
        Write-Pass "$Tool command is available."
    }
    else {
        Write-Fail "$Tool command is NOT available in PATH."
    }
}

# ============================================================
# SECTION 03
# TOOL VERSIONS
# ============================================================

Write-Header "03 - Tool Versions"

if (Test-CommandExists "git") {
    $GitVersion = Invoke-ExternalCommand `
        -Command "git" `
        -Arguments @("--version")

    if ($GitVersion.Success) {
        Write-Pass "Git: $($GitVersion.Output -join ' ')"
    }
    else {
        Write-Warn "Unable to determine Git version."
    }
}

if (Test-CommandExists "aws") {
    $AwsCliVersion = Invoke-ExternalCommand `
        -Command "aws" `
        -Arguments @("--version")

    if ($AwsCliVersion.Success) {
        Write-Pass "AWS CLI: $($AwsCliVersion.Output -join ' ')"
    }
    else {
        Write-Warn "Unable to determine AWS CLI version."
    }
}

if (Test-CommandExists "terraform") {
    $TerraformVersion = Invoke-ExternalCommand `
        -Command "terraform" `
        -Arguments @("version")

    if ($TerraformVersion.Success) {
        $TerraformFirstLine = $TerraformVersion.Output |
            Select-Object -First 1

        Write-Pass "Terraform: $TerraformFirstLine"
    }
    else {
        Write-Warn "Unable to determine Terraform version."
    }
}

if (Test-CommandExists "docker") {
    $DockerVersion = Invoke-ExternalCommand `
        -Command "docker" `
        -Arguments @("--version")

    if ($DockerVersion.Success) {
        Write-Pass "Docker: $($DockerVersion.Output -join ' ')"
    }
    else {
        Write-Warn "Unable to determine Docker version."
    }
}

# ============================================================
# SECTION 04
# GIT
# ============================================================

Write-Header "04 - Git Repository"

if (Test-CommandExists "git") {

    $GitRoot = Invoke-ExternalCommand `
        -Command "git" `
        -Arguments @("-C", $ProjectRoot, "rev-parse", "--show-toplevel")

    if ($GitRoot.Success) {

        Write-Pass "Git repository detected."

        $Branch = Invoke-ExternalCommand `
            -Command "git" `
            -Arguments @("-C", $ProjectRoot, "branch", "--show-current")

        if ($Branch.Success) {
            Write-Pass "Current branch: $($Branch.Output -join ' ')"
        }

        $Remote = Invoke-ExternalCommand `
            -Command "git" `
            -Arguments @("-C", $ProjectRoot, "remote", "-v")

        if ($Remote.Success -and $Remote.Output.Count -gt 0) {
            Write-Pass "Git remote configured."
        }
        else {
            Write-Warn "No Git remote configured."
        }

        $GitStatus = Invoke-ExternalCommand `
            -Command "git" `
            -Arguments @("-C", $ProjectRoot, "status", "--porcelain")

        if ($GitStatus.Success) {

            if ($GitStatus.Output.Count -eq 0) {
                Write-Pass "Git working tree is clean."
            }
            else {
                Write-Warn "Git working tree contains uncommitted changes."
            }
        }
    }
    else {
        Write-Fail "Project root is not a Git repository."
    }
}

# ============================================================
# SECTION 05
# PROJECT STRUCTURE
# ============================================================

Write-Header "05 - Project Structure"

$RequiredDirectories = @(
    ".github",
    ".github\workflows",
    "infrastructure",
    "infrastructure\terraform",
    "infrastructure\cloudformation",
    "scripts"
)

foreach ($Directory in $RequiredDirectories) {

    $FullPath = Join-Path $ProjectRoot $Directory

    if (Test-Path -LiteralPath $FullPath -PathType Container) {
        Write-Pass "Directory exists: $Directory"
    }
    else {
        Write-Warn "Directory missing: $Directory"
    }
}

$RequiredFiles = @(
    "README.md"
)

foreach ($File in $RequiredFiles) {

    $FullPath = Join-Path $ProjectRoot $File

    if (Test-Path -LiteralPath $FullPath -PathType Leaf) {
        Write-Pass "File exists: $File"
    }
    else {
        Write-Warn "File missing: $File"
    }
}

# ============================================================
# SECTION 06
# ARCHITECTURE / DOCUMENTATION
# ============================================================

Write-Header "06 - Architecture / Documentation"

$ReadmePath = Join-Path $ProjectRoot "README.md"

if (Test-Path -LiteralPath $ReadmePath) {

    $ReadmeContent = Get-Content `
        -LiteralPath $ReadmePath `
        -Raw `
        -ErrorAction SilentlyContinue

    $ArchitectureKeywords = @(
        "Terraform",
        "CloudFormation",
        "AWS",
        "ECR",
        "ECS",
        "EKS",
        "S3",
        "IAM"
    )

    $ArchitectureMatches = 0

    foreach ($Keyword in $ArchitectureKeywords) {

        if ($ReadmeContent -match [regex]::Escape($Keyword)) {
            $ArchitectureMatches++
        }
    }

    if ($ArchitectureMatches -gt 0) {
        Write-Pass "README contains AWS architecture references."
    }
    else {
        Write-Warn "README does not contain recognizable AWS architecture references."
    }
}
else {
    Write-Warn "README.md not found; architecture documentation cannot be checked."
}

# ============================================================
# SECTION 07
# TERRAFORM FILES
# ============================================================

Write-Header "07 - Terraform Files"

$TerraformFiles = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -Filter "*.tf" `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\\.terraform\\" -and
            $_.FullName -notmatch "\\\.git\\"
        }
)

if ($TerraformFiles.Count -gt 0) {

    Write-Pass "Terraform files found: $($TerraformFiles.Count)"

    foreach ($File in $TerraformFiles) {
        Write-Detail "$(Get-RelativePath $File.FullName)"
    }
}
else {
    Write-Fail "No Terraform .tf files found."
}

# ============================================================
# SECTION 08
# TERRAFORM FORMAT
# ============================================================

Write-Header "08 - Terraform Formatting"

$TerraformDirectory = Join-Path $ProjectRoot "infrastructure\terraform"

if (
    (Test-Path -LiteralPath $TerraformDirectory -PathType Container) -and
    (Test-CommandExists "terraform")
) {

    $TerraformFmt = Invoke-ExternalCommand `
        -Command "terraform" `
        -Arguments @(
            "-chdir=$TerraformDirectory",
            "fmt",
            "-check"
        )

    if ($TerraformFmt.Success) {
        Write-Pass "Terraform formatting check passed."
    }
    else {
        Write-Warn "Terraform formatting check reported formatting differences."

        foreach ($Line in $TerraformFmt.Output) {
            Write-Detail "$Line"
        }
    }
}
else {
    Write-Warn "Terraform directory or Terraform CLI unavailable."
}

# ============================================================
# SECTION 09
# TERRAFORM INIT / VALIDATE
# ============================================================

Write-Header "09 - Terraform Init / Validate"

if (
    (Test-Path -LiteralPath $TerraformDirectory -PathType Container) -and
    (Test-CommandExists "terraform")
) {

    # Terraform init is executed with -backend=false so this preflight
    # does not modify or access a remote backend.
    $TerraformInit = Invoke-ExternalCommand `
        -Command "terraform" `
        -Arguments @(
            "-chdir=$TerraformDirectory",
            "init",
            "-backend=false",
            "-input=false"
        )

    if ($TerraformInit.Success) {
        Write-Pass "Terraform init check passed."
    }
    else {
        Write-Fail "Terraform init check failed."

        foreach ($Line in $TerraformInit.Output) {
            Write-Detail "$Line"
        }
    }

    $TerraformValidate = Invoke-ExternalCommand `
        -Command "terraform" `
        -Arguments @(
            "-chdir=$TerraformDirectory",
            "validate"
        )

    if ($TerraformValidate.Success) {
        Write-Pass "Terraform validate passed."
    }
    else {
        Write-Fail "Terraform validate failed."

        foreach ($Line in $TerraformValidate.Output) {
            Write-Detail "$Line"
        }
    }
}
else {
    Write-Warn "Terraform validation skipped because Terraform directory or CLI is unavailable."
}

# ============================================================
# SECTION 10
# CLOUDFORMATION FILES
# ============================================================

Write-Header "10 - CloudFormation Files"

$CloudFormationDirectory = Join-Path `
    $ProjectRoot `
    "infrastructure\cloudformation"

$CloudFormationFiles = @(
    Get-ChildItem `
        -Path $CloudFormationDirectory `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(
                ".yaml",
                ".yml",
                ".json"
            )
        }
)

if ($CloudFormationFiles.Count -gt 0) {

    Write-Pass "CloudFormation templates found: $($CloudFormationFiles.Count)"

    foreach ($Template in $CloudFormationFiles) {
        Write-Detail "$(Get-RelativePath $Template.FullName)"
    }
}
else {
    Write-Warn "No CloudFormation templates found."
}

# ============================================================
# SECTION 11
# CLOUDFORMATION VALIDATION
# ============================================================

Write-Header "11 - CloudFormation Validation"

if (
    $CloudFormationFiles.Count -gt 0 -and
    (Test-CommandExists "aws")
) {

    foreach ($Template in $CloudFormationFiles) {

        # IMPORTANT:
        # Do NOT create file://file:///...
        #
        # AWS CLI accepts:
        # file://C:\path\template.yaml
        #
        # The previous implementation created:
        # file://file:///C:/path/template.yaml
        #
        # which is invalid.
        $Validation = Invoke-AwsCommand `
            -Arguments @(
                "cloudformation",
                "validate-template",
                "--template-body",
                "file://$($Template.FullName)"
            )

        $Relative = Get-RelativePath $Template.FullName

        if ($Validation.Success) {
            Write-Pass "CloudFormation template valid: $Relative"
        }
        else {
            Write-Fail "CloudFormation template validation failed: $Relative"

            foreach ($Line in $Validation.Output) {
                Write-Detail "$Line"
            }
        }
    }
}
else {
    Write-Warn "CloudFormation validation skipped."
}

# ============================================================
# SECTION 12
# JSON VALIDATION
# ============================================================

Write-Header "12 - JSON Validation"

$JsonFiles = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -Filter "*.json" `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "\\\.git\\" -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\\.terraform\\"
        }
)

if ($JsonFiles.Count -gt 0) {

    Write-Info "JSON files found: $($JsonFiles.Count)"

    foreach ($JsonFile in $JsonFiles) {

        if (Test-JsonFile $JsonFile.FullName) {
            Write-Pass "Valid JSON: $(Get-RelativePath $JsonFile.FullName)"
        }
        else {
            Write-Fail "Invalid JSON: $(Get-RelativePath $JsonFile.FullName)"
        }
    }
}
else {
    Write-Info "No JSON files found."
}

# ============================================================
# SECTION 13
# IAM POLICY JSON FILES
# ============================================================

Write-Header "13 - IAM Policy JSON"

<#
    IAM JSON files can represent several different IAM structures:

        1. Identity policy
        2. Resource policy
        3. Assume-role trust policy
        4. OIDC trust policy
        5. Other IAM-related documents

    IMPORTANT:
    We must NOT directly access properties such as:

        $Json.Version
        $Json.Statement
        $Json.Principal

    under StrictMode because the property may legitimately not exist.

    Instead, this section checks whether the property actually exists
    before accessing it.
#>

$PotentialIamFiles = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -Filter "*.json" `
        -ErrorAction SilentlyContinue |
        Where-Object {

            $_.FullName -notmatch "\\\.git\\" -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\\.terraform\\" -and
            (
                $_.Name -match "(?i)iam" -or
                $_.Name -match "(?i)policy" -or
                $_.Name -match "(?i)trust" -or
                $_.Name -match "(?i)role" -or
                $_.Name -match "(?i)oidc"
            )
        }
)

if ($PotentialIamFiles.Count -gt 0) {

    Write-Info "IAM-related JSON files detected: $($PotentialIamFiles.Count)"

    foreach ($IamFile in $PotentialIamFiles) {

        $RelativePath = Get-RelativePath $IamFile.FullName

        try {

            # ------------------------------------------------
            # Read JSON
            # ------------------------------------------------

            $JsonContent = Get-Content `
                -LiteralPath $IamFile.FullName `
                -Raw `
                -ErrorAction Stop

            $Json = $JsonContent | ConvertFrom-Json

            # ------------------------------------------------
            # Safely inspect available properties.
            #
            # PSObject.Properties avoids StrictMode errors
            # when a property does not exist.
            # ------------------------------------------------

            $PropertyNames = @(
                $Json.PSObject.Properties |
                    Select-Object -ExpandProperty Name
            )

            $HasVersion = $PropertyNames -contains "Version"
            $HasStatement = $PropertyNames -contains "Statement"
            $HasAction = $PropertyNames -contains "Action"
            $HasPrincipal = $PropertyNames -contains "Principal"
            $HasEffect = $PropertyNames -contains "Effect"
            $HasResource = $PropertyNames -contains "Resource"
            $HasCondition = $PropertyNames -contains "Condition"

            # ------------------------------------------------
            # Determine whether this looks like an IAM
            # policy/trust document.
            # ------------------------------------------------

            $LooksLikeIamDocument = (
                $HasVersion -or
                $HasStatement -or
                $HasAction -or
                $HasPrincipal -or
                $HasEffect -or
                $HasResource -or
                $HasCondition
            )

            if ($LooksLikeIamDocument) {

                Write-Pass "IAM-style policy structure detected: $RelativePath"

                # ------------------------------------------------
                # Additional useful diagnostics
                # ------------------------------------------------

                if ($HasVersion) {
                    Write-Detail "Version property detected."
                }

                if ($HasStatement) {
                    Write-Detail "Statement property detected."
                }

                if ($HasPrincipal) {
                    Write-Detail "Principal property detected."
                }

                if ($HasAction) {
                    Write-Detail "Action property detected."
                }

                if ($HasEffect) {
                    Write-Detail "Effect property detected."
                }

                if ($HasResource) {
                    Write-Detail "Resource property detected."
                }

                if ($HasCondition) {
                    Write-Detail "Condition property detected."
                }

            }
            else {

                Write-Warn "JSON file does not appear to contain an IAM policy/trust structure: $RelativePath"
            }
        }
        catch {

            Write-Fail "Unable to inspect IAM JSON: $RelativePath"
            Write-Detail "Cause: $($_.Exception.Message)"
        }
    }

}
else {

    Write-Info "No IAM-style JSON files detected."
}

# ============================================================
# SECTION 14
# GITHUB ACTIONS WORKFLOWS
# ============================================================

Write-Header "14 - GitHub Actions Workflows"

$WorkflowDirectory = Join-Path `
    $ProjectRoot `
    ".github\workflows"

$WorkflowFiles = @(
    Get-ChildItem `
        -Path $WorkflowDirectory `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(
                ".yaml",
                ".yml"
            )
        }
)

if ($WorkflowFiles.Count -eq 0) {

    Write-Warn "No GitHub Actions workflow files found."

}
else {

    Write-Pass "GitHub Actions workflow files found: $($WorkflowFiles.Count)"

    foreach ($Workflow in $WorkflowFiles) {

        $WorkflowPath = $Workflow.FullName

        $WorkflowContent = Get-Content `
            -LiteralPath $WorkflowPath `
            -Raw `
            -ErrorAction SilentlyContinue

        $Relative = Get-RelativePath $WorkflowPath

        if ($WorkflowContent -match "(?m)^\s*name\s*:") {
            Write-Pass "Workflow name detected: $Relative"
        }
        else {
            Write-Warn "Workflow name not detected: $Relative"
        }

        if ($WorkflowContent -match "(?m)^\s*on\s*:") {
            Write-Pass "Workflow trigger detected: $Relative"
        }
        else {
            Write-Warn "Workflow trigger 'on:' not detected: $Relative"
        }

        if ($WorkflowContent -match "(?m)^\s*jobs\s*:") {
            Write-Pass "Workflow jobs detected: $Relative"
        }
        else {
            Write-Fail "Workflow jobs section missing: $Relative"
        }

        # GitHub OIDC requirement.
        if (
            $WorkflowContent -match "aws-actions/configure-aws-credentials" -or
            $WorkflowContent -match "role-to-assume"
        ) {
            Write-Pass "AWS GitHub Actions authentication reference detected: $Relative"
        }
        else {
            Write-Warn "AWS authentication action/reference not detected: $Relative"
        }

        if ($WorkflowContent -match "role-to-assume") {
            Write-Pass "role-to-assume detected: $Relative"
        }
        else {
            Write-Warn "role-to-assume not detected: $Relative"
        }

        if ($WorkflowContent -match "id-token\s*:\s*write") {
            Write-Pass "GitHub OIDC id-token: write detected: $Relative"
        }
        else {
            Write-Warn "GitHub OIDC id-token: write not detected: $Relative"
        }

        if (
            $WorkflowContent -match "(?i)terraform" -or
            $WorkflowContent -match "(?i)aws"
        ) {
            Write-Pass "Terraform/AWS deployment references detected: $Relative"
        }
        else {
            Write-Warn "Terraform/AWS deployment references not detected: $Relative"
        }
    }
}

# ============================================================
# SECTION 15
# DEPLOYMENT SCRIPTS
# ============================================================

Write-Header "15 - Deployment Scripts"

$DeploymentScripts = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @(
                ".ps1",
                ".sh",
                ".bat",
                ".cmd"
            ) -and
            $_.FullName -notmatch "\\\.git\\" -and
            $_.FullName -notmatch "\\node_modules\\" -and
            $_.FullName -notmatch "\\\.terraform\\"
        }
)

if ($DeploymentScripts.Count -gt 0) {

    Write-Pass "Deployment/automation scripts found: $($DeploymentScripts.Count)"

    foreach ($Script in $DeploymentScripts) {
        Write-Detail "$(Get-RelativePath $Script.FullName)"
    }
}
else {
    Write-Warn "No deployment/automation scripts found."
}

# ============================================================
# SECTION 16
# DOCKER
# ============================================================

Write-Header "16 - Docker"

$DockerFiles = @(
    Get-ChildItem `
        -Path $ProjectRoot `
        -Recurse `
        -File `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "Dockerfile" -or
            $_.Name -eq "docker-compose.yml" -or
            $_.Name -eq "docker-compose.yaml"
        }
)

if ($DockerFiles.Count -gt 0) {

    Write-Pass "Docker-related files found: $($DockerFiles.Count)"

    foreach ($DockerFile in $DockerFiles) {
        Write-Detail "$(Get-RelativePath $DockerFile.FullName)"
    }

}
else {
    Write-Warn "No Dockerfile or docker-compose file detected."
}

if (Test-CommandExists "docker") {

    $DockerInfo = Invoke-ExternalCommand `
        -Command "docker" `
        -Arguments @("info")

    if ($DockerInfo.Success) {
        Write-Pass "Docker daemon is available."
    }
    else {
        Write-Warn "Docker CLI exists but Docker daemon is unavailable."
    }
}

# ============================================================
# SECTION 17
# ENVIRONMENT VARIABLES
# ============================================================

Write-Header "17 - Environment Variables"

$ExpectedEnvironmentVariables = @(
    "AWS_REGION",
    "AWS_DEFAULT_REGION"
)

foreach ($VariableName in $ExpectedEnvironmentVariables) {

    $Value = [Environment]::GetEnvironmentVariable($VariableName)

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        Write-Pass "Environment variable available: $VariableName"
    }
    else {
        Write-Detail "Environment variable not set: $VariableName"
    }
}

if (-not [string]::IsNullOrWhiteSpace($AwsRegion)) {

    Write-Info "Preflight region parameter: $AwsRegion"

    $GlobalState.AwsRegion = $AwsRegion

}
elseif (-not [string]::IsNullOrWhiteSpace($env:AWS_REGION)) {

    $GlobalState.AwsRegion = $env:AWS_REGION

}
elseif (-not [string]::IsNullOrWhiteSpace($env:AWS_DEFAULT_REGION)) {

    $GlobalState.AwsRegion = $env:AWS_DEFAULT_REGION

}
else {

    Write-Warn "AWS region was not explicitly provided."
}

# ============================================================
# SECTION 18
# AWS CREDENTIALS / ACCOUNT
# ============================================================

Write-Header "18 - AWS Credentials / Account"

if ($SkipAws) {

    Write-Warn "AWS validation was skipped because -SkipAws was specified."

}
elseif (-not (Test-CommandExists "aws")) {

    Write-Fail "AWS CLI is unavailable; AWS validation cannot run." -Critical

}
else {

    $AwsIdentity = Invoke-AwsCommand `
        -Arguments @(
            "sts",
            "get-caller-identity"
        )

    if ($AwsIdentity.Success) {

        try {

            $IdentityObject = (
                $AwsIdentity.Output -join "`n"
            ) | ConvertFrom-Json

            $GlobalState.AwsAvailable = $true
            $GlobalState.AwsAccountId = [string]$IdentityObject.Account

            Write-Pass "AWS credentials are valid."
            Write-Pass "AWS account ID: $($GlobalState.AwsAccountId)"

            if (-not [string]::IsNullOrWhiteSpace($ExpectedAwsAccountId)) {

                if ($GlobalState.AwsAccountId -eq $ExpectedAwsAccountId) {

                    Write-Pass "AWS account matches expected account ID."

                }
                else {

                    Write-Fail `
                        "AWS account mismatch. Expected '$ExpectedAwsAccountId' but authenticated as '$($GlobalState.AwsAccountId)'." `
                        -Critical
                }
            }
            else {

                Write-Warn "Expected AWS account ID was not supplied."
            }
        }
        catch {

            Write-Fail "AWS STS returned an unexpected response." -Critical
        }

    }
    else {

        Write-Fail "AWS credentials/account validation failed." -Critical

        foreach ($Line in $AwsIdentity.Output) {
            Write-Detail "$Line"
        }
    }
}

# ============================================================
# SECTION 19
# IAM USERS / POLICIES / GROUPS
# ============================================================

Write-Header "19 - IAM Users / Policies / Groups"

if ($SkipAws) {

    Write-Warn "IAM checks skipped because AWS validation was skipped."

}
elseif ($GlobalState.AwsAvailable) {

    $IamUsers = Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "list-users",
            "--query",
            "Users[].UserName",
            "--output",
            "json"
        )

    if ($IamUsers.Success) {

        try {
            $Users = @(
                (
                    $IamUsers.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "IAM users query succeeded. User count: $($Users.Count)"
        }
        catch {
            Write-Warn "IAM users query returned an unexpected format."
        }

    }
    else {
        Write-Warn "Unable to list IAM users."
    }

    $IamPolicies = Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "list-policies",
            "--scope",
            "Local",
            "--query",
            "Policies[].PolicyName",
            "--output",
            "json"
        )

    if ($IamPolicies.Success) {

        try {
            $Policies = @(
                (
                    $IamPolicies.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "Customer-managed IAM policies query succeeded. Count: $($Policies.Count)"
        }
        catch {
            Write-Warn "IAM policy query returned an unexpected format."
        }

    }
    else {
        Write-Warn "Unable to list customer-managed IAM policies."
    }

    $IamGroups = Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "list-groups",
            "--query",
            "Groups[].GroupName",
            "--output",
            "json"
        )

    if ($IamGroups.Success) {

        try {
            $Groups = @(
                (
                    $IamGroups.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "IAM groups query succeeded. Group count: $($Groups.Count)"
        }
        catch {
            Write-Warn "IAM group query returned an unexpected format."
        }

    }
    else {
        Write-Warn "Unable to list IAM groups."
    }
}

# ============================================================
# SECTION 20
# IAM ROLES / TRUST / ROLE POLICIES
# ============================================================

Write-Header "20 - IAM Roles / Trust Policies"

if ($SkipAws) {

    Write-Warn "IAM role checks skipped because AWS validation was skipped."

}
elseif ($GlobalState.AwsAvailable) {

    $IamRoles = Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "list-roles",
            "--query",
            "Roles[].RoleName",
            "--output",
            "json"
        )

    if ($IamRoles.Success) {

        try {

            $Roles = @(
                (
                    $IamRoles.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "IAM roles query succeeded. Role count: $($Roles.Count)"

            foreach ($RoleName in $Roles) {

                $RoleInfo = Invoke-AwsCommand `
                    -Arguments @(
                        "iam",
                        "get-role",
                        "--role-name",
                        "$RoleName",
                        "--query",
                        "Role.AssumeRolePolicyDocument",
                        "--output",
                        "json"
                    )

                if ($RoleInfo.Success) {

                    $TrustText = $RoleInfo.Output -join "`n"

                    # Detect GitHub OIDC trust configuration.
                    if ($TrustText -match "token\.actions\.githubusercontent\.com") {

                        Write-Pass "GitHub OIDC trust detected in IAM role: $RoleName"

                    }
                }
            }

        }
        catch {

            Write-Warn "Unable to process IAM role results."
        }

    }
    else {

        Write-Warn "Unable to list IAM roles."
    }
}

# ============================================================
# SECTION 21
# GITHUB OIDC
# ============================================================

Write-Header "21 - GitHub OIDC Provider"

if ($SkipAws) {

    Write-Warn "GitHub OIDC check skipped because AWS validation was skipped."

}
elseif ($GlobalState.AwsAvailable) {

    $OidcProviders = Invoke-AwsCommand `
        -Arguments @(
            "iam",
            "list-open-id-connect-providers",
            "--output",
            "json"
        )

    if ($OidcProviders.Success) {

        $OidcText = $OidcProviders.Output -join "`n"

        if ($OidcText -match "token\.actions\.githubusercontent\.com") {

            Write-Pass "GitHub Actions OIDC provider is present."

        }
        else {

            # The AWS CLI list response contains provider ARNs.
            # A direct provider lookup is used below.
            $GithubOidcArn = "arn:aws:iam::$($GlobalState.AwsAccountId):oidc-provider/token.actions.githubusercontent.com"

            $ProviderCheck = Invoke-AwsCommand `
                -Arguments @(
                    "iam",
                    "get-open-id-connect-provider",
                    "--open-id-connect-provider-arn",
                    $GithubOidcArn
                )

            if ($ProviderCheck.Success) {
                Write-Pass "GitHub Actions OIDC provider is present."
            }
            else {
                Write-Warn "GitHub Actions OIDC provider was not confirmed."
            }
        }

    }
    else {

        Write-Warn "Unable to list IAM OIDC providers."
    }
}

# ============================================================
# SECTION 22
# SECRETS MANAGER
# ============================================================

Write-Header "22 - Secrets Manager"

if ($SkipAws) {

    Write-Warn "Secrets Manager check skipped because AWS validation was skipped."

}
elseif ($GlobalState.AwsAvailable) {

    $Secrets = Invoke-AwsCommand `
        -Arguments @(
            "secretsmanager",
            "list-secrets",
            "--query",
            "SecretList[].Name",
            "--output",
            "json"
        )

    if ($Secrets.Success) {

        try {

            $SecretNames = @(
                (
                    $Secrets.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "Secrets Manager query succeeded. Secret count: $($SecretNames.Count)"

            # IMPORTANT:
            # Only secret names are checked.
            # Secret values are NEVER retrieved or printed.
            foreach ($SecretName in $SecretNames) {

                Write-Detail "Secret detected: $SecretName"
            }

        }
        catch {

            Write-Warn "Secrets Manager returned an unexpected response."
        }

    }
    else {

        Write-Warn "Unable to list Secrets Manager secrets."
    }
}

# ============================================================
# SECTION 23
# EXISTING AWS RESOURCES
# ============================================================

Write-Header "23 - Existing AWS Resources"

if ($SkipAws) {

    Write-Warn "AWS resource checks skipped because AWS validation was skipped."

}
elseif ($GlobalState.AwsAvailable) {

    # --------------------------------------------------------
    # CloudFormation
    # --------------------------------------------------------

    $Stacks = Invoke-AwsCommand `
        -Arguments @(
            "cloudformation",
            "list-stacks",
            "--stack-status-filter",
            "CREATE_COMPLETE",
            "UPDATE_COMPLETE",
            "UPDATE_ROLLBACK_COMPLETE",
            "--query",
            "StackSummaries[].StackName",
            "--output",
            "json"
        )

    if ($Stacks.Success) {

        try {

            $StackNames = @(
                (
                    $Stacks.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "CloudFormation stack query succeeded. Matching stacks: $($StackNames.Count)"

            foreach ($StackName in $StackNames) {
                Write-Detail "CloudFormation stack: $StackName"
            }

        }
        catch {

            Write-Warn "CloudFormation stack response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query CloudFormation stacks."
    }

    # --------------------------------------------------------
    # ECR
    # --------------------------------------------------------

    $EcrRepositories = Invoke-AwsCommand `
        -Arguments @(
            "ecr",
            "describe-repositories",
            "--query",
            "repositories[].repositoryName",
            "--output",
            "json"
        )

    if ($EcrRepositories.Success) {

        try {

            $Repositories = @(
                (
                    $EcrRepositories.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "ECR repository query succeeded. Repository count: $($Repositories.Count)"

            foreach ($Repository in $Repositories) {
                Write-Detail "ECR repository: $Repository"
            }

        }
        catch {

            Write-Warn "ECR response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query ECR repositories."
    }

    # --------------------------------------------------------
    # S3
    # --------------------------------------------------------

    $S3Buckets = Invoke-AwsCommand `
        -Arguments @(
            "s3api",
            "list-buckets",
            "--query",
            "Buckets[].Name",
            "--output",
            "json"
        )

    if ($S3Buckets.Success) {

        try {

            $Buckets = @(
                (
                    $S3Buckets.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "S3 bucket query succeeded. Bucket count: $($Buckets.Count)"

            foreach ($Bucket in $Buckets) {
                Write-Detail "S3 bucket: $Bucket"
            }

        }
        catch {

            Write-Warn "S3 response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query S3 buckets."
    }

    # --------------------------------------------------------
    # VPC
    # --------------------------------------------------------

    $Vpcs = Invoke-AwsCommand `
        -Arguments @(
            "ec2",
            "describe-vpcs",
            "--query",
            "Vpcs[].VpcId",
            "--output",
            "json"
        )

    if ($Vpcs.Success) {

        try {

            $VpcList = @(
                (
                    $Vpcs.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "VPC query succeeded. VPC count: $($VpcList.Count)"

            foreach ($VpcId in $VpcList) {
                Write-Detail "VPC: $VpcId"
            }

        }
        catch {

            Write-Warn "VPC response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query VPCs."
    }

    # --------------------------------------------------------
    # EC2
    # --------------------------------------------------------

    $Instances = Invoke-AwsCommand `
        -Arguments @(
            "ec2",
            "describe-instances",
            "--query",
            "Reservations[].Instances[].InstanceId",
            "--output",
            "json"
        )

    if ($Instances.Success) {

        try {

            $InstanceList = @(
                (
                    $Instances.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "EC2 query succeeded. Instance count: $($InstanceList.Count)"

        }
        catch {

            Write-Warn "EC2 response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query EC2 instances."
    }

    # --------------------------------------------------------
    # ECS
    # --------------------------------------------------------

    $EcsClusters = Invoke-AwsCommand `
        -Arguments @(
            "ecs",
            "list-clusters",
            "--query",
            "clusterArns",
            "--output",
            "json"
        )

    if ($EcsClusters.Success) {

        try {

            $Clusters = @(
                (
                    $EcsClusters.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "ECS cluster query succeeded. Cluster count: $($Clusters.Count)"

        }
        catch {

            Write-Warn "ECS response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query ECS clusters."
    }

    # --------------------------------------------------------
    # EKS
    # --------------------------------------------------------

    $EksClusters = Invoke-AwsCommand `
        -Arguments @(
            "eks",
            "list-clusters",
            "--query",
            "clusters",
            "--output",
            "json"
        )

    if ($EksClusters.Success) {

        try {

            $Clusters = @(
                (
                    $EksClusters.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "EKS cluster query succeeded. Cluster count: $($Clusters.Count)"

        }
        catch {

            Write-Warn "EKS response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query EKS clusters."
    }

    # --------------------------------------------------------
    # Lambda
    # --------------------------------------------------------

    $Lambdas = Invoke-AwsCommand `
        -Arguments @(
            "lambda",
            "list-functions",
            "--query",
            "Functions[].FunctionName",
            "--output",
            "json"
        )

    if ($Lambdas.Success) {

        try {

            $Functions = @(
                (
                    $Lambdas.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "Lambda query succeeded. Function count: $($Functions.Count)"

        }
        catch {

            Write-Warn "Lambda response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query Lambda functions."
    }

    # --------------------------------------------------------
    # RDS
    # --------------------------------------------------------

    $RdsInstances = Invoke-AwsCommand `
        -Arguments @(
            "rds",
            "describe-db-instances",
            "--query",
            "DBInstances[].DBInstanceIdentifier",
            "--output",
            "json"
        )

    if ($RdsInstances.Success) {

        try {

            $Databases = @(
                (
                    $RdsInstances.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "RDS query succeeded. DB instance count: $($Databases.Count)"

        }
        catch {

            Write-Warn "RDS response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query RDS instances."
    }

    # --------------------------------------------------------
    # ALB / ELBv2
    # --------------------------------------------------------

    $LoadBalancers = Invoke-AwsCommand `
        -Arguments @(
            "elbv2",
            "describe-load-balancers",
            "--query",
            "LoadBalancers[].LoadBalancerName",
            "--output",
            "json"
        )

    if ($LoadBalancers.Success) {

        try {

            $LbList = @(
                (
                    $LoadBalancers.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "ELBv2 query succeeded. Load balancer count: $($LbList.Count)"

        }
        catch {

            Write-Warn "ELBv2 response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query ELBv2 load balancers."
    }

    # --------------------------------------------------------
    # CloudFront
    # --------------------------------------------------------

    $CloudFront = Invoke-AwsCommand `
        -Arguments @(
            "cloudfront",
            "list-distributions",
            "--query",
            "DistributionList.Items[].Id",
            "--output",
            "json"
        )

    if ($CloudFront.Success) {

        try {

            $Distributions = @(
                (
                    $CloudFront.Output -join "`n"
                ) | ConvertFrom-Json
            )

            Write-Pass "CloudFront query succeeded. Distribution count: $($Distributions.Count)"

        }
        catch {

            Write-Warn "CloudFront response could not be parsed."
        }

    }
    else {

        Write-Warn "Unable to query CloudFront distributions."
    }
}

# ============================================================
# SECTION 24
# FINAL REPORT
# ============================================================

Write-Header "24 - Final Preflight Report"

$PassCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "PASS"
        }
).Count

$WarnCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "WARN"
        }
).Count

$FailCount = @(
    $Results |
        Where-Object {
            $_.Status -eq "FAIL"
        }
).Count

Write-Host ""
Write-Host "-------------------- SUMMARY --------------------" -ForegroundColor $Colors.Header

Write-Host "PASS : $PassCount" -ForegroundColor $Colors.Pass
Write-Host "WARN : $WarnCount" -ForegroundColor $Colors.Warn
Write-Host "FAIL : $FailCount" -ForegroundColor $Colors.Fail

Write-Host ""

Write-Log ""
Write-Log "-------------------- SUMMARY --------------------"
Write-Log "PASS : $PassCount"
Write-Log "WARN : $WarnCount"
Write-Log "FAIL : $FailCount"

# ============================================================
# CRITICAL FAILURE DECISION
# ============================================================

if ($GlobalState.CriticalFailure) {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Colors.Fail
    Write-Host "NOT READY - CRITICAL PREREQUISITE FAILURE" -ForegroundColor $Colors.Fail
    Write-Host "============================================================" -ForegroundColor $Colors.Fail

    Write-Log ""
    Write-Log "============================================================"
    Write-Log "NOT READY - CRITICAL PREREQUISITE FAILURE"
    Write-Log "============================================================"

    Write-Host ""
    Write-Host "Fix the critical issue(s) above before running deployment." -ForegroundColor $Colors.Warn
    Write-Host "Preflight log: $LogFile" -ForegroundColor $Colors.Info

    Write-Log "Fix the critical issue(s) above before running deployment."
    Write-Log "Preflight log: $LogFile"

    exit 1
}

if ($FailCount -gt 0) {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Colors.Fail
    Write-Host "NOT READY - VALIDATION FAILURES FOUND" -ForegroundColor $Colors.Fail
    Write-Host "============================================================" -ForegroundColor $Colors.Fail

    Write-Log ""
    Write-Log "============================================================"
    Write-Log "NOT READY - VALIDATION FAILURES FOUND"
    Write-Log "============================================================"

    Write-Host ""
    Write-Host "Fix the FAIL items before deployment." -ForegroundColor $Colors.Warn
    Write-Host "Preflight log: $LogFile" -ForegroundColor $Colors.Info

    Write-Log "Fix the FAIL items before deployment."
    Write-Log "Preflight log: $LogFile"

    exit 1
}

if ($WarnCount -gt 0) {

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor $Colors.Warn
    Write-Host "READY WITH WARNINGS" -ForegroundColor $Colors.Warn
    Write-Host "============================================================" -ForegroundColor $Colors.Warn

    Write-Log ""
    Write-Log "============================================================"
    Write-Log "READY WITH WARNINGS"
    Write-Log "============================================================"

    Write-Host ""
    Write-Host "No FAIL conditions were detected." -ForegroundColor $Colors.Info
    Write-Host "Review WARN items before deployment." -ForegroundColor $Colors.Warn
    Write-Host "Preflight log: $LogFile" -ForegroundColor $Colors.Info

    Write-Log "No FAIL conditions were detected."
    Write-Log "Review WARN items before deployment."
    Write-Log "Preflight log: $LogFile"

    exit 0
}

# ============================================================
# EVERYTHING PASSED
# ============================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor $Colors.Pass
Write-Host "READY - PREFLIGHT PASSED" -ForegroundColor $Colors.Pass
Write-Host "============================================================" -ForegroundColor $Colors.Pass

Write-Log ""
Write-Log "============================================================"
Write-Log "READY - PREFLIGHT PASSED"
Write-Log "============================================================"

Write-Host ""
Write-Host "All validation checks passed." -ForegroundColor $Colors.Pass
Write-Host "Preflight log: $LogFile" -ForegroundColor $Colors.Info

Write-Log "All validation checks passed."
Write-Log "Preflight log: $LogFile"

exit 0
```

---

