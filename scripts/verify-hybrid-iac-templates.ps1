# ============================================================
# AWS HYBRID IaC LAB
# TERRAFORM + CLOUDFORMATION VALIDATION SCRIPT
# ============================================================
#
# File:
#
#   scripts\verify-hybrid-iac-templates.ps1
#
# Purpose:
#
#   Validates the Terraform and CloudFormation configuration
#   for the AWS Hybrid IaC Lab.
#
# Validation performed:
#
#   TERRAFORM
#   1. Verify Terraform installation
#   2. Check Terraform formatting
#   3. Initialize Terraform without the remote backend
#   4. Validate Terraform configuration
#
#   CLOUDFORMATION
#   5. Verify AWS CLI installation
#   6. Discover CloudFormation YAML templates
#   7. Validate every CloudFormation template
#
# IMPORTANT:
#
#   This is a VALIDATION-ONLY script.
#
#   It does NOT execute:
#
#     terraform apply
#     terraform destroy
#     aws cloudformation deploy
#     aws cloudformation create-stack
#
#   Therefore, this script is not intended to create or destroy
#   AWS infrastructure.
#
# ============================================================


# ============================================================
# 1. POWERSHELL ERROR HANDLING
# ============================================================

# Stop the script when a terminating PowerShell error occurs.
$ErrorActionPreference = "Stop"


# ============================================================
# 2. DETERMINE SCRIPT AND PROJECT LOCATIONS
# ============================================================

# $PSScriptRoot is the directory containing this script.
#
# Expected:
#
#   <project-root>\scripts
#
$ScriptsDirectory = $PSScriptRoot

# The project root is the parent directory of "scripts".
#
# Expected:
#
#   <project-root>
#
$ProjectRoot = Split-Path -Parent $ScriptsDirectory


# ============================================================
# 3. DEFINE TERRAFORM DIRECTORY
# ============================================================

$TerraformDirectory = Join-Path `
    $ProjectRoot `
    "infrastructure\terraform"


# ============================================================
# 4. DEFINE CLOUDFORMATION DIRECTORY
# ============================================================

$CloudFormationDirectory = Join-Path `
    $ProjectRoot `
    "infrastructure\cloudformation"


# ============================================================
# 5. CREATE VALIDATION RESULT ARRAYS
# ============================================================

$TerraformResults = @()

$CloudFormationResults = @()

$FailedItems = @()


# ============================================================
# 6. DISPLAY SCRIPT HEADER
# ============================================================

Write-Host ""

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AWS HYBRID IaC LAB" -ForegroundColor Cyan
Write-Host " TERRAFORM + CLOUDFORMATION VALIDATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""

Write-Host "Project Root:" -ForegroundColor Yellow
Write-Host $ProjectRoot -ForegroundColor White

Write-Host ""

Write-Host "Terraform Directory:" -ForegroundColor Yellow
Write-Host $TerraformDirectory -ForegroundColor White

Write-Host ""

Write-Host "CloudFormation Directory:" -ForegroundColor Yellow
Write-Host $CloudFormationDirectory -ForegroundColor White

Write-Host ""


# ============================================================
# 7. VERIFY REQUIRED DIRECTORIES
# ============================================================

Write-Host "Checking required project directories..." -ForegroundColor Yellow

$TerraformDirectoryExists = Test-Path `
    -Path $TerraformDirectory `
    -PathType Container

$CloudFormationDirectoryExists = Test-Path `
    -Path $CloudFormationDirectory `
    -PathType Container


# ------------------------------------------------------------
# Terraform directory check
# ------------------------------------------------------------

if (-not $TerraformDirectoryExists) {

    Write-Host ""
    Write-Host "ERROR: Terraform directory was not found." -ForegroundColor Red
    Write-Host $TerraformDirectory -ForegroundColor Red
    Write-Host ""

    $FailedItems += "Terraform directory"

}
else {

    Write-Host "Terraform directory: PASS" -ForegroundColor Green

}


# ------------------------------------------------------------
# CloudFormation directory check
# ------------------------------------------------------------

if (-not $CloudFormationDirectoryExists) {

    Write-Host ""
    Write-Host "ERROR: CloudFormation directory was not found." -ForegroundColor Red
    Write-Host $CloudFormationDirectory -ForegroundColor Red
    Write-Host ""

    $FailedItems += "CloudFormation directory"

}
else {

    Write-Host "CloudFormation directory: PASS" -ForegroundColor Green

}

Write-Host ""


# ------------------------------------------------------------
# Stop if required directories are missing.
# ------------------------------------------------------------

if (
    -not $TerraformDirectoryExists -or
    -not $CloudFormationDirectoryExists
) {

    Write-Host "Required project directories are missing." -ForegroundColor Red
    Write-Host "Validation cannot continue." -ForegroundColor Red
    Write-Host ""

    exit 1

}


# ============================================================
# ============================================================
# TERRAFORM VALIDATION
# ============================================================
# ============================================================

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host " TERRAFORM VALIDATION" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

Write-Host ""


# ============================================================
# 8. CHECK TERRAFORM INSTALLATION
# ============================================================

Write-Host "[TF 1/4] Checking Terraform installation..." -ForegroundColor Yellow

$TerraformCommand = Get-Command `
    terraform `
    -ErrorAction SilentlyContinue


if ($null -eq $TerraformCommand) {

    Write-Host "Terraform installation: FAILED" -ForegroundColor Red

    $TerraformResults += [PSCustomObject]@{
        Check  = "Terraform installation"
        Status = "FAILED"
    }

    $FailedItems += "Terraform installation"

}
else {

    # Display installed Terraform version.
    terraform version

    if ($LASTEXITCODE -eq 0) {

        Write-Host "Terraform installation: PASS" -ForegroundColor Green

        $TerraformResults += [PSCustomObject]@{
            Check  = "Terraform installation"
            Status = "PASS"
        }

    }
    else {

        Write-Host "Terraform installation: FAILED" -ForegroundColor Red

        $TerraformResults += [PSCustomObject]@{
            Check  = "Terraform installation"
            Status = "FAILED"
        }

        $FailedItems += "Terraform installation"

    }

}

Write-Host ""


# ============================================================
# 9. CHECK TERRAFORM FORMATTING
# ============================================================
#
# terraform fmt -check -recursive
#
# The -check option only checks formatting.
#
# It does NOT modify Terraform files.
# ============================================================

Write-Host "[TF 2/4] Checking Terraform formatting..." -ForegroundColor Yellow

Push-Location $TerraformDirectory

try {

    $TerraformFmtOutput = @(
        terraform fmt -check -recursive 2>&1
    )

    $TerraformFmtExitCode = $LASTEXITCODE

    if ($TerraformFmtExitCode -eq 0) {

        Write-Host "Terraform formatting: PASS" -ForegroundColor Green

        $TerraformResults += [PSCustomObject]@{
            Check  = "terraform fmt -check"
            Status = "PASS"
        }

    }
    else {

        Write-Host "Terraform formatting: FAILED" -ForegroundColor Red

        Write-Host ""
        Write-Host "Terraform files requiring formatting:" -ForegroundColor Yellow

        foreach ($Line in $TerraformFmtOutput) {

            Write-Host $Line -ForegroundColor Red

        }

        $TerraformResults += [PSCustomObject]@{
            Check  = "terraform fmt -check"
            Status = "FAILED"
        }

        $FailedItems += "Terraform formatting"

    }

}
catch {

    Write-Host "Terraform formatting: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $TerraformResults += [PSCustomObject]@{
        Check  = "terraform fmt -check"
        Status = "FAILED"
    }

    $FailedItems += "Terraform formatting"

}
finally {

    Pop-Location

}

Write-Host ""


# ============================================================
# 10. INITIALIZE TERRAFORM WITHOUT REMOTE BACKEND
# ============================================================
#
# -backend=false
#
# Prevents Terraform from initializing the configured
# remote backend.
#
# -input=false
#
# Prevents interactive Terraform questions.
#
# This command does not deploy infrastructure.
# ============================================================

Write-Host "[TF 3/4] Initializing Terraform without backend..." -ForegroundColor Yellow

Push-Location $TerraformDirectory

try {

    terraform init -backend=false -input=false

    $TerraformInitExitCode = $LASTEXITCODE

    if ($TerraformInitExitCode -eq 0) {

        Write-Host "Terraform initialization: PASS" -ForegroundColor Green

        $TerraformResults += [PSCustomObject]@{
            Check  = "terraform init -backend=false"
            Status = "PASS"
        }

    }
    else {

        Write-Host "Terraform initialization: FAILED" -ForegroundColor Red

        $TerraformResults += [PSCustomObject]@{
            Check  = "terraform init -backend=false"
            Status = "FAILED"
        }

        $FailedItems += "Terraform initialization"

    }

}
catch {

    Write-Host "Terraform initialization: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $TerraformResults += [PSCustomObject]@{
        Check  = "terraform init -backend=false"
        Status = "FAILED"
    }

    $FailedItems += "Terraform initialization"

}
finally {

    Pop-Location

}

Write-Host ""


# ============================================================
# 11. VALIDATE TERRAFORM CONFIGURATION
# ============================================================
#
# terraform validate checks the Terraform configuration.
#
# It checks:
#
#   - Terraform syntax
#   - Resource configuration
#   - Variable references
#   - Attribute references
#   - Provider configuration
#   - Module configuration
#   - Configuration structure
#
# It does NOT deploy infrastructure.
# ============================================================

Write-Host "[TF 4/4] Validating Terraform configuration..." -ForegroundColor Yellow

Push-Location $TerraformDirectory

try {

    terraform validate

    $TerraformValidateExitCode = $LASTEXITCODE

    if ($TerraformValidateExitCode -eq 0) {

        Write-Host "Terraform validation: PASS" -ForegroundColor Green

        $TerraformResults += [PSCustomObject]@{
            Check  = "terraform validate"
            Status = "PASS"
        }

    }
    else {

        Write-Host "Terraform validation: FAILED" -ForegroundColor Red

        $TerraformResults += [PSCustomObject]@{
            Check  = "terraform validate"
            Status = "FAILED"
        }

        $FailedItems += "Terraform configuration"

    }

}
catch {

    Write-Host "Terraform validation: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $TerraformResults += [PSCustomObject]@{
        Check  = "terraform validate"
        Status = "FAILED"
    }

    $FailedItems += "Terraform configuration"

}
finally {

    Pop-Location

}

Write-Host ""


# ============================================================
# ============================================================
# CLOUDFORMATION VALIDATION
# ============================================================
# ============================================================

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host " CLOUDFORMATION VALIDATION" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

Write-Host ""


# ============================================================
# 12. CHECK AWS CLI INSTALLATION
# ============================================================

Write-Host "[CFN 1/2] Checking AWS CLI installation..." -ForegroundColor Yellow

$AwsCommand = Get-Command `
    aws `
    -ErrorAction SilentlyContinue


if ($null -eq $AwsCommand) {

    Write-Host "AWS CLI installation: FAILED" -ForegroundColor Red

    $FailedItems += "AWS CLI installation"

    $CloudFormationResults += [PSCustomObject]@{
        Template = "AWS CLI"
        Status   = "FAILED"
    }

}
else {

    aws --version

    $AwsVersionExitCode = $LASTEXITCODE

    if ($AwsVersionExitCode -eq 0) {

        Write-Host "AWS CLI installation: PASS" -ForegroundColor Green

        $CloudFormationResults += [PSCustomObject]@{
            Template = "AWS CLI"
            Status   = "PASS"
        }

    }
    else {

        Write-Host "AWS CLI installation: FAILED" -ForegroundColor Red

        $FailedItems += "AWS CLI installation"

        $CloudFormationResults += [PSCustomObject]@{
            Template = "AWS CLI"
            Status   = "FAILED"
        }

    }

}

Write-Host ""


# ============================================================
# 13. DISCOVER CLOUDFORMATION YAML FILES
# ============================================================
#
# Search recursively under:
#
#   infrastructure\cloudformation
#
# This finds:
#
#   main.yaml
#
# and nested templates such as:
#
#   nested\api-gateway.yaml
#   nested\cloudfront.yaml
#   nested\dynamodb.yaml
#   nested\ec2.yaml
#   nested\ecr.yaml
#   nested\ecs.yaml
#   nested\eks.yaml
#   nested\lambda.yaml
#   nested\rds.yaml
#   nested\s3.yaml
#   nested\vpc.yaml
#
# Any additional .yaml file is also discovered automatically.
# ============================================================

Write-Host "[CFN 2/2] Discovering CloudFormation templates..." -ForegroundColor Yellow

$CloudFormationTemplates = @(
    Get-ChildItem `
        -Path $CloudFormationDirectory `
        -Recurse `
        -File `
        -Filter "*.yaml" |
        Sort-Object FullName
)


if ($CloudFormationTemplates.Count -eq 0) {

    Write-Host ""
    Write-Host "ERROR: No CloudFormation YAML templates were found." -ForegroundColor Red
    Write-Host $CloudFormationDirectory -ForegroundColor Red
    Write-Host ""

    $FailedItems += "CloudFormation template discovery"

}
else {

    Write-Host ""
    Write-Host "Found $($CloudFormationTemplates.Count) CloudFormation template(s)." -ForegroundColor Cyan
    Write-Host ""

}


# ============================================================
# 14. VALIDATE EVERY CLOUDFORMATION TEMPLATE
# ============================================================

foreach ($Template in $CloudFormationTemplates) {

    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "VALIDATING CLOUDFORMATION TEMPLATE:" -ForegroundColor Yellow

    Write-Host $Template.FullName -ForegroundColor White

    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan


    # --------------------------------------------------------
    # Create the local file URI used by AWS CloudFormation.
    # --------------------------------------------------------

    $TemplateUri = "file://$($Template.FullName)"


    # --------------------------------------------------------
    # Validate the CloudFormation template.
    #
    # AWS CloudFormation validation does not deploy the stack.
    # --------------------------------------------------------

    try {

        aws cloudformation validate-template `
            --template-body $TemplateUri `
            --region us-east-1 *> $null

        $CloudFormationExitCode = $LASTEXITCODE

    }
    catch {

        $CloudFormationExitCode = 1

    }


    # --------------------------------------------------------
    # Check AWS CLI exit code.
    # --------------------------------------------------------

    if ($CloudFormationExitCode -eq 0) {

        Write-Host "RESULT: VALID" -ForegroundColor Green

        $CloudFormationResults += [PSCustomObject]@{
            Template = $Template.FullName
            Status   = "VALID"
        }

    }
    else {

        Write-Host "RESULT: FAILED" -ForegroundColor Red

        $CloudFormationResults += [PSCustomObject]@{
            Template = $Template.FullName
            Status   = "FAILED"
        }

        $FailedItems += $Template.FullName

    }

    Write-Host ""

}


# ============================================================
# ============================================================
# FINAL VERIFICATION REPORT
# ============================================================
# ============================================================

Write-Host ""

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " FINAL AWS HYBRID IaC VALIDATION REPORT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""


# ============================================================
# 15. TERRAFORM SUMMARY
# ============================================================

Write-Host "TERRAFORM SUMMARY" -ForegroundColor Yellow

Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($TerraformResults.Count -gt 0) {

    $TerraformResults |
        Format-Table -AutoSize

}
else {

    Write-Host "No Terraform results were recorded." -ForegroundColor Red

}


$TerraformPassed = @(
    $TerraformResults |
        Where-Object { $_.Status -eq "PASS" }
).Count


$TerraformFailed = @(
    $TerraformResults |
        Where-Object { $_.Status -eq "FAILED" }
).Count


Write-Host "Terraform checks : $TerraformResults.Count" -ForegroundColor Cyan

Write-Host "Terraform passed : $TerraformPassed" -ForegroundColor Green

Write-Host "Terraform failed : $TerraformFailed" -ForegroundColor Red

Write-Host ""


# ============================================================
# 16. CLOUDFORMATION SUMMARY
# ============================================================

Write-Host "CLOUDFORMATION SUMMARY" -ForegroundColor Yellow

Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

if ($CloudFormationResults.Count -gt 0) {

    $CloudFormationResults |
        Format-Table -AutoSize

}
else {

    Write-Host "No CloudFormation results were recorded." -ForegroundColor Red

}


$CloudFormationPassed = @(
    $CloudFormationResults |
        Where-Object { $_.Status -eq "VALID" -or $_.Status -eq "PASS" }
).Count


$CloudFormationFailed = @(
    $CloudFormationResults |
        Where-Object { $_.Status -eq "FAILED" }
).Count


Write-Host "CloudFormation checks : $CloudFormationResults.Count" -ForegroundColor Cyan

Write-Host "CloudFormation passed : $CloudFormationPassed" -ForegroundColor Green

Write-Host "CloudFormation failed : $CloudFormationFailed" -ForegroundColor Red

Write-Host ""


# ============================================================
# 17. FAILED ITEMS REPORT
# ============================================================

Write-Host "============================================================" -ForegroundColor Yellow

Write-Host " FAILED ITEMS" -ForegroundColor Yellow

Write-Host "============================================================" -ForegroundColor Yellow

Write-Host ""


if ($FailedItems.Count -eq 0) {

    Write-Host "NO FAILED ITEMS FOUND." -ForegroundColor Green

}
else {

    Write-Host "The following item(s) failed validation:" -ForegroundColor Red

    Write-Host ""

    foreach ($FailedItem in $FailedItems) {

        Write-Host "[FAILED] $FailedItem" -ForegroundColor Red

    }

}

Write-Host ""


# ============================================================
# 18. CALCULATE FINAL TOTALS
# ============================================================

$TotalChecks = `
    $TerraformResults.Count + `
    $CloudFormationResults.Count


$TotalPassed = `
    $TerraformPassed + `
    $CloudFormationPassed


$TotalFailed = `
    $TerraformFailed + `
    $CloudFormationFailed


Write-Host "============================================================" -ForegroundColor Cyan

Write-Host " FINAL TOTALS" -ForegroundColor Cyan

Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""

Write-Host "Total validation checks : $TotalChecks" -ForegroundColor Cyan

Write-Host "Total passed           : $TotalPassed" -ForegroundColor Green

Write-Host "Total failed           : $TotalFailed" -ForegroundColor Red

Write-Host ""


# ============================================================
# 19. FINAL RESULT
# ============================================================

if ($TotalFailed -eq 0) {

    Write-Host "============================================================" -ForegroundColor Green

    Write-Host " ALL TERRAFORM + CLOUDFORMATION CHECKS PASSED" -ForegroundColor Green

    Write-Host "============================================================" -ForegroundColor Green

    Write-Host ""

    Write-Host `
        "AWS Hybrid IaC configuration verification completed successfully." `
        -ForegroundColor Green

    Write-Host ""

    Write-Host `
        "No infrastructure was deployed or destroyed." `
        -ForegroundColor Cyan

    Write-Host ""

    exit 0

}
else {

    Write-Host "============================================================" -ForegroundColor Red

    Write-Host " TERRAFORM + CLOUDFORMATION VALIDATION FAILED" -ForegroundColor Red

    Write-Host "============================================================" -ForegroundColor Red

    Write-Host ""

    Write-Host `
        "Review the FAILED ITEMS section above." `
        -ForegroundColor Yellow

    Write-Host `
        "Fix the reported problem(s) and run this script again." `
        -ForegroundColor Yellow

    Write-Host ""

    exit 1

}

