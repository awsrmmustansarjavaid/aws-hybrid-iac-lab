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

