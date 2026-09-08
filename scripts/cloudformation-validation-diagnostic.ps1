# ============================================================
# AWS HYBRID IaC LAB
# CLOUDFORMATION VALIDATION + AUDIT REPORT SCRIPT
# ============================================================
#
# File:
#   scripts/cloudformation-validation-diagnostic.ps1
#
# PURPOSE
# ------------------------------------------------------------
# Validate every CloudFormation YAML template in the project
# and capture the ACTUAL AWS CLI validation error.
#
# This script also generates the standard audit reports:
#
#   report-log\
#   |
#   +-- CloudFormation-Validation-Diagnostic.txt
#   +-- AWS-Hybrid-IaC-Audit-PASS.txt
#   +-- AWS-Hybrid-IaC-Audit-ERROR.txt
#   +-- AWS-Hybrid-IaC-Audit-WARNING.txt
#
# IMPORTANT
# ------------------------------------------------------------
# READ-ONLY / VALIDATION ONLY
#
# This script:
#
#   - DOES NOT create AWS resources
#   - DOES NOT update AWS resources
#   - DOES NOT delete AWS resources
#   - DOES NOT run Terraform
#   - DOES NOT run terraform apply
#   - DOES NOT run terraform destroy
#   - DOES NOT deploy CloudFormation stacks
#
# CloudFormation validation does call the AWS API to validate
# the template, but validation itself does not deploy resources.
#
# ============================================================


# ============================================================
# 01 - SCRIPT CONFIGURATION
# ============================================================

# ------------------------------------------------------------
# AWS Region
# ------------------------------------------------------------
#
# Change this if your CloudFormation templates use another
# region.
#
# ------------------------------------------------------------

$Region = "us-east-1"


# ------------------------------------------------------------
# Strict Mode
# ------------------------------------------------------------
#
# $Strict = $true
#   Warnings cause exit code 1.
#
# $Strict = $false
#   Warnings do not cause failure.
#
# ------------------------------------------------------------

$Strict = $false


# ============================================================
# 02 - DETERMINE PROJECT ROOT
# ============================================================
#
# The script is expected to live inside:
#
#   aws-hybrid-iac-lab\
#       scripts\
#           cloudformation-validation-diagnostic.ps1
#
# Therefore:
#
#   $PSScriptRoot = ...\aws-hybrid-iac-lab\scripts
#
# and:
#
#   $ProjectRoot = ...\aws-hybrid-iac-lab
#
# ============================================================

$ProjectRoot = Split-Path `
    -Parent `
    $PSScriptRoot


# ============================================================
# 03 - REPORT DIRECTORY
# ============================================================
#
# All reports are stored in:
#
#   aws-hybrid-iac-lab\
#       report-log\
#
# ============================================================

$ReportFolder = Join-Path `
    -Path $ProjectRoot `
    -ChildPath "report-log"


# ------------------------------------------------------------
# Create report directory
# ------------------------------------------------------------

try {

    if (-not (Test-Path -LiteralPath $ReportFolder)) {

        New-Item `
            -Path $ReportFolder `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop |
            Out-Null

    }

}
catch {

    Write-Host ""
    Write-Host "[ERROR] Unable to create report-log directory." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 2
}


# ============================================================
# 04 - REPORT FILE PATHS
# ============================================================

# ------------------------------------------------------------
# Dedicated CloudFormation diagnostic report
# ------------------------------------------------------------

$CloudFormationReport = Join-Path `
    -Path $ReportFolder `
    -ChildPath "CloudFormation-Validation-Diagnostic.txt"


# ------------------------------------------------------------
# Standard audit reports
# ------------------------------------------------------------

$PassReport = Join-Path `
    -Path $ReportFolder `
    -ChildPath "AWS-Hybrid-IaC-Audit-PASS.txt"


$ErrorReport = Join-Path `
    -Path $ReportFolder `
    -ChildPath "AWS-Hybrid-IaC-Audit-ERROR.txt"


$WarningReport = Join-Path `
    -Path $ReportFolder `
    -ChildPath "AWS-Hybrid-IaC-Audit-WARNING.txt"


# ============================================================
# 05 - INITIALIZE RESULT ARRAYS
# ============================================================

$Passes = @()

$Failures = @()

$Warnings = @()

$CloudFormationFailures = @()

$CloudFormationPasses = @()


# ============================================================
# 06 - DISPLAY SCRIPT HEADER
# ============================================================

Write-Host ""

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "CLOUDFORMATION VALIDATION DIAGNOSTIC" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host "Project Root:" `
    -ForegroundColor Yellow

Write-Host $ProjectRoot `
    -ForegroundColor Gray

Write-Host ""

Write-Host "AWS Region:" `
    -ForegroundColor Yellow

Write-Host $Region `
    -ForegroundColor Gray

Write-Host ""

Write-Host "Report Directory:" `
    -ForegroundColor Yellow

Write-Host $ReportFolder `
    -ForegroundColor Gray

Write-Host ""


# ============================================================
# 07 - START FRESH CLOUDFORMATION REPORT
# ============================================================
#
# The previous diagnostic report is removed so every execution
# starts with a clean report.
#
# This only deletes the LOCAL report file.
#
# It does NOT delete anything from AWS.
#
# ============================================================

Remove-Item `
    -LiteralPath $CloudFormationReport `
    -Force `
    -ErrorAction SilentlyContinue


# ============================================================
# 08 - CLOUDFORMATION REPORT HEADER
# ============================================================

$CloudFormationHeader = @"
============================================================
AWS HYBRID IaC LAB
CLOUDFORMATION VALIDATION DIAGNOSTIC REPORT
============================================================

Purpose:
Validate every CloudFormation YAML template and capture the
ACTUAL AWS CLI validation error.

Project Root:
$ProjectRoot

AWS Region:
$Region

Report Type:
CloudFormation Validation Diagnostic

IMPORTANT:
This script is READ-ONLY.

It does NOT:
- create AWS resources
- update AWS resources
- delete AWS resources
- deploy CloudFormation stacks
- run Terraform
- run terraform apply
- run terraform destroy

AWS CLI Command:
aws cloudformation validate-template

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

VALIDATION RESULTS
============================================================

"@


try {

    Set-Content `
        -LiteralPath $CloudFormationReport `
        -Value $CloudFormationHeader `
        -Encoding UTF8 `
        -Force `
        -ErrorAction Stop

}
catch {

    Write-Host ""
    Write-Host "[ERROR] Unable to create CloudFormation report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

    exit 2
}


# ============================================================
# 09 - CHECK AWS CLI
# ============================================================
#
# The script requires the AWS CLI.
#
# ============================================================

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "AWS CLI CHECK" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host ""

$AwsCommand = Get-Command `
    aws `
    -ErrorAction SilentlyContinue


if (-not $AwsCommand) {

    Write-Host "[FAIL] AWS CLI was not found." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Install AWS CLI before running this script." `
        -ForegroundColor Yellow

    $Failures += "AWS CLI is not installed or is not available in PATH."

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value "[FAIL] AWS CLI was not found."

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value "Install AWS CLI and make sure 'aws' is available in PATH."

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value ""

}
else {

    Write-Host "[PASS] AWS CLI detected." `
        -ForegroundColor Green

    Write-Host "       $($AwsCommand.Source)" `
        -ForegroundColor Gray

    $Passes += "AWS CLI detected."
}


# ============================================================
# 10 - CHECK AWS CREDENTIALS
# ============================================================
#
# aws sts get-caller-identity is read-only.
#
# It confirms that the AWS CLI can authenticate.
#
# ============================================================

if ($AwsCommand) {

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host "AWS CREDENTIAL CHECK" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    $IdentityOutput = & aws sts get-caller-identity `
        --region $Region `
        2>&1

    $IdentityExitCode = $LASTEXITCODE


    if ($IdentityExitCode -eq 0) {

        Write-Host "[PASS] AWS credentials are working." `
            -ForegroundColor Green

        $Passes += "AWS credentials authenticated successfully."

    }
    else {

        Write-Host "[FAIL] AWS authentication failed." `
            -ForegroundColor Red

        $IdentityOutput | ForEach-Object {

            Write-Host $_ `
                -ForegroundColor Red

        }

        $Failures += "AWS CLI authentication failed."

        Add-Content `
            -LiteralPath $CloudFormationReport `
            -Value ""

        Add-Content `
            -LiteralPath $CloudFormationReport `
            -Value "============================================================"

        Add-Content `
            -LiteralPath $CloudFormationReport `
            -Value "[FAIL] AWS AUTHENTICATION"

        Add-Content `
            -LiteralPath $CloudFormationReport `
            -Value "============================================================"

        $IdentityOutput | ForEach-Object {

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value $_

        }

    }

}


# ============================================================
# 11 - FIND CLOUDFORMATION YAML FILES
# ============================================================
#
# Search recursively from the project root.
#
# Excluded directories:
#
#   .git
#   .terraform
#   .terraform-backup
#   node_modules
#   report-log
#
# This prevents third-party/generated YAML files from being
# incorrectly treated as your CloudFormation templates.
#
# ============================================================

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "DISCOVERING CLOUDFORMATION YAML FILES" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host ""


$YamlFiles = Get-ChildItem `
    -Path $ProjectRoot `
    -Recurse `
    -File `
    -Filter "*.yaml" `
    -ErrorAction SilentlyContinue |
    Where-Object {

        $_.FullName -notmatch "\\\.git\\" -and
        $_.FullName -notmatch "\\\.terraform\\" -and
        $_.FullName -notmatch "\\\.terraform-backup[^\\]*\\" -and
        $_.FullName -notmatch "\\node_modules\\" -and
        $_.FullName -notmatch "\\report-log\\"

    } |
    Sort-Object FullName


# ============================================================
# 12 - CHECK IF YAML FILES WERE FOUND
# ============================================================

if (-not $YamlFiles -or $YamlFiles.Count -eq 0) {

    Write-Host "[FAIL] No CloudFormation YAML files were found." `
        -ForegroundColor Red

    $Failures += "No CloudFormation YAML files were found."

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value ""

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value "[FAIL] No CloudFormation YAML files were found."

}
else {

    Write-Host "[INFO] YAML files discovered: $($YamlFiles.Count)" `
        -ForegroundColor Yellow

    Write-Host ""

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value "YAML FILE COUNT: $($YamlFiles.Count)"

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value ""

}


# ============================================================
# 13 - VALIDATE EACH CLOUDFORMATION TEMPLATE
# ============================================================
#
# IMPORTANT:
#
# 2>&1 is VERY IMPORTANT.
#
# AWS CLI often writes errors to stderr.
#
# Without:
#
#     2>&1
#
# the actual AWS error may not be captured correctly.
#
# ============================================================

if ($AwsCommand -and $IdentityExitCode -eq 0 -and $YamlFiles.Count -gt 0) {

    foreach ($File in $YamlFiles) {

        $Template = $File.FullName

        $TemplateName = $File.Name


        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Cyan

        Write-Host "VALIDATING: $TemplateName" `
            -ForegroundColor Yellow

        Write-Host "PATH: $Template" `
            -ForegroundColor Gray

        Write-Host "============================================================" `
            -ForegroundColor Cyan


        # ----------------------------------------------------
        # Run AWS CloudFormation validation.
        #
        # file:// URI is used so AWS CLI reads the local file.
        #
        # 2>&1 captures BOTH:
        #
        #   stdout
        #   stderr
        #
        # ----------------------------------------------------

        $Output = & aws cloudformation validate-template `
            --template-body "file://$Template" `
            --region $Region `
            2>&1


        # ----------------------------------------------------
        # Capture AWS CLI exit code immediately.
        # ----------------------------------------------------

        $ExitCode = $LASTEXITCODE


        # ====================================================
        # VALIDATION SUCCESS
        # ====================================================

        if ($ExitCode -eq 0) {

            Write-Host "[PASS] $TemplateName" `
                -ForegroundColor Green


            $CloudFormationPasses += $TemplateName

            $Passes += "CloudFormation template validated successfully: $TemplateName"


            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value ""

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "============================================================"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "[PASS] $TemplateName"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "PATH: $Template"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "AWS CLI EXIT CODE: $ExitCode"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "============================================================"


            # ------------------------------------------------
            # Do not dump the complete successful AWS response.
            #
            # The purpose of this report is diagnostic output.
            # ------------------------------------------------

        }


        # ====================================================
        # VALIDATION FAILURE
        # ====================================================

        else {

            Write-Host "[FAIL] $TemplateName" `
                -ForegroundColor Red

            Write-Host ""

            Write-Host "ACTUAL AWS ERROR:" `
                -ForegroundColor Yellow


            # ------------------------------------------------
            # Display ACTUAL AWS CLI error.
            # ------------------------------------------------

            if ($Output) {

                $Output | ForEach-Object {

                    Write-Host $_ `
                        -ForegroundColor Red

                }

            }
            else {

                Write-Host "[ERROR] AWS CLI returned no diagnostic output." `
                    -ForegroundColor Red

            }


            # ------------------------------------------------
            # Save failure details.
            # ------------------------------------------------

            $CloudFormationFailures += $TemplateName

            $Failures += "CloudFormation validation failed: $TemplateName"


            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value ""

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "============================================================"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "[FAIL] $TemplateName"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "PATH: $Template"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "AWS CLI EXIT CODE: $ExitCode"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "============================================================"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value ""

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value "ACTUAL AWS ERROR:"

            Add-Content `
                -LiteralPath $CloudFormationReport `
                -Value ""


            # ------------------------------------------------
            # Save ACTUAL AWS CLI error.
            # ------------------------------------------------

            if ($Output) {

                $Output | ForEach-Object {

                    Add-Content `
                        -LiteralPath $CloudFormationReport `
                        -Value $_

                }

            }
            else {

                Add-Content `
                    -LiteralPath $CloudFormationReport `
                    -Value "[ERROR] AWS CLI returned no diagnostic output."

            }

        }

    }

}
elseif (-not $AwsCommand) {

    Write-Host ""
    Write-Host "[SKIP] CloudFormation validation skipped because AWS CLI is missing." `
        -ForegroundColor Yellow

}
elseif ($IdentityExitCode -ne 0) {

    Write-Host ""
    Write-Host "[SKIP] CloudFormation validation skipped because AWS authentication failed." `
        -ForegroundColor Yellow

}
elseif ($YamlFiles.Count -eq 0) {

    Write-Host ""
    Write-Host "[SKIP] CloudFormation validation skipped because no YAML files were found." `
        -ForegroundColor Yellow

}


# ============================================================
# 14 - CLOUDFORMATION VALIDATION SUMMARY
# ============================================================

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value ""

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value "============================================================"

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value "CLOUDFORMATION VALIDATION SUMMARY"

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value "============================================================"

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value "TOTAL YAML FILES: $($YamlFiles.Count)"

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value "PASS COUNT: $($CloudFormationPasses.Count)"

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value "FAILURE COUNT: $($CloudFormationFailures.Count)"

Add-Content `
    -LiteralPath $CloudFormationReport `
    -Value ""


if ($CloudFormationFailures.Count -gt 0) {

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value "FAILED TEMPLATES:"

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value ""

    foreach ($Failure in $CloudFormationFailures) {

        Add-Content `
            -LiteralPath $CloudFormationReport `
            -Value "[FAIL] $Failure"

    }

}
else {

    Add-Content `
        -LiteralPath $CloudFormationReport `
        -Value "[PASS] All discovered CloudFormation YAML files passed validation."

}


# ============================================================
# 15 - GENERATE PASS AUDIT REPORT
# ============================================================

$PassHeader = @"
============================================================
AWS HYBRID IaC LAB
PASS AUDIT REPORT
============================================================

Audit Title:
AWS Hybrid IaC Lab - CloudFormation Validation Diagnostic

Project Root:
$ProjectRoot

AWS Region:
$Region

Report Type:
PASS

Purpose:
Successful validation and audit checks.

IMPORTANT:
This validation is READ-ONLY and does not modify AWS resources.

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

PASS RESULTS
============================================================

"@


try {

    Set-Content `
        -LiteralPath $PassReport `
        -Value $PassHeader `
        -Encoding UTF8 `
        -Force `
        -ErrorAction Stop


    foreach ($Pass in ($Passes | Select-Object -Unique)) {

        Add-Content `
            -LiteralPath $PassReport `
            -Value "[PASS] $Pass" `
            -Encoding UTF8

    }


    Add-Content `
        -LiteralPath $PassReport `
        -Value ""

    Add-Content `
        -LiteralPath $PassReport `
        -Value "============================================================"

    Add-Content `
        -LiteralPath $PassReport `
        -Value "PASS COUNT: $(($Passes | Select-Object -Unique).Count)"

    Add-Content `
        -LiteralPath $PassReport `
        -Value "============================================================"

}
catch {

    Write-Host ""
    Write-Host "[ERROR] Failed to create PASS report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

}


# ============================================================
# 16 - GENERATE ERROR AUDIT REPORT
# ============================================================

$ErrorHeader = @"
============================================================
AWS HYBRID IaC LAB
ERROR / FAILURE AUDIT REPORT
============================================================

Audit Title:
AWS Hybrid IaC Lab - CloudFormation Validation Diagnostic

Project Root:
$ProjectRoot

AWS Region:
$Region

Report Type:
ERROR / FAILURE

Purpose:
Failed or critical validation checks.

ACTION REQUIRED:
Fix these failures before deployment.

IMPORTANT:
This validation is READ-ONLY and does not modify AWS resources.

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

ERROR / FAILURE RESULTS
============================================================

"@


try {

    Set-Content `
        -LiteralPath $ErrorReport `
        -Value $ErrorHeader `
        -Encoding UTF8 `
        -Force `
        -ErrorAction Stop


    $UniqueFailures = $Failures | Select-Object -Unique


    if ($UniqueFailures.Count -gt 0) {

        foreach ($Failure in $UniqueFailures) {

            Add-Content `
                -LiteralPath $ErrorReport `
                -Value "[FAIL] $Failure" `
                -Encoding UTF8

        }

    }
    else {

        Add-Content `
            -LiteralPath $ErrorReport `
            -Value "[PASS] No failures detected." `
            -Encoding UTF8

    }


    Add-Content `
        -LiteralPath $ErrorReport `
        -Value ""

    Add-Content `
        -LiteralPath $ErrorReport `
        -Value "============================================================"

    Add-Content `
        -LiteralPath $ErrorReport `
        -Value "FAILURE COUNT: $($UniqueFailures.Count)"

    Add-Content `
        -LiteralPath $ErrorReport `
        -Value "============================================================"

}
catch {

    Write-Host ""
    Write-Host "[ERROR] Failed to create ERROR report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

}


# ============================================================
# 17 - GENERATE WARNING AUDIT REPORT
# ============================================================

$WarningHeader = @"
============================================================
AWS HYBRID IaC LAB
WARNING AUDIT REPORT
============================================================

Audit Title:
AWS Hybrid IaC Lab - CloudFormation Validation Diagnostic

Project Root:
$ProjectRoot

AWS Region:
$Region

Report Type:
WARNING

Purpose:
Warnings detected during validation.

IMPORTANT:
A warning does not necessarily mean deployment will fail.

This validation is READ-ONLY and does not modify AWS resources.

Generated:
$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

============================================================

WARNING RESULTS
============================================================

"@


try {

    Set-Content `
        -LiteralPath $WarningReport `
        -Value $WarningHeader `
        -Encoding UTF8 `
        -Force `
        -ErrorAction Stop


    $UniqueWarnings = $Warnings | Select-Object -Unique


    if ($UniqueWarnings.Count -gt 0) {

        foreach ($Warning in $UniqueWarnings) {

            Add-Content `
                -LiteralPath $WarningReport `
                -Value "[WARN] $Warning" `
                -Encoding UTF8

        }

    }
    else {

        Add-Content `
            -LiteralPath $WarningReport `
            -Value "[PASS] No warnings detected." `
            -Encoding UTF8

    }


    Add-Content `
        -LiteralPath $WarningReport `
        -Value ""

    Add-Content `
        -LiteralPath $WarningReport `
        -Value "============================================================"

    Add-Content `
        -LiteralPath $WarningReport `
        -Value "WARNING COUNT: $($UniqueWarnings.Count)"

    Add-Content `
        -LiteralPath $WarningReport `
        -Value "============================================================"

}
catch {

    Write-Host ""
    Write-Host "[ERROR] Failed to create WARNING report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message `
        -ForegroundColor Red

}


# ============================================================
# 18 - FINAL REPORT FILE CHECK
# ============================================================

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "AUDIT REPORT FILES" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host ""


# ------------------------------------------------------------
# CloudFormation Diagnostic Report
# ------------------------------------------------------------

if (Test-Path -LiteralPath $CloudFormationReport) {

    Write-Host "[PASS] CloudFormation diagnostic report created:" `
        -ForegroundColor Green

    Write-Host "       $CloudFormationReport" `
        -ForegroundColor Gray

}
else {

    Write-Host "[FAIL] CloudFormation diagnostic report was NOT created." `
        -ForegroundColor Red

}


# ------------------------------------------------------------
# PASS report
# ------------------------------------------------------------

if (Test-Path -LiteralPath $PassReport) {

    Write-Host "[PASS] PASS report created:" `
        -ForegroundColor Green

    Write-Host "       $PassReport" `
        -ForegroundColor Gray

}
else {

    Write-Host "[FAIL] PASS report was NOT created." `
        -ForegroundColor Red

}


# ------------------------------------------------------------
# ERROR report
# ------------------------------------------------------------

if (Test-Path -LiteralPath $ErrorReport) {

    Write-Host "[PASS] ERROR report created:" `
        -ForegroundColor Green

    Write-Host "       $ErrorReport" `
        -ForegroundColor Gray

}
else {

    Write-Host "[FAIL] ERROR report was NOT created." `
        -ForegroundColor Red

}


# ------------------------------------------------------------
# WARNING report
# ------------------------------------------------------------

if (Test-Path -LiteralPath $WarningReport) {

    Write-Host "[PASS] WARNING report created:" `
        -ForegroundColor Green

    Write-Host "       $WarningReport" `
        -ForegroundColor Gray

}
else {

    Write-Host "[FAIL] WARNING report was NOT created." `
        -ForegroundColor Red

}


# ============================================================
# 19 - FINAL SUMMARY
# ============================================================

$PassCount = @(
    $Passes | Select-Object -Unique
).Count


$FailCount = @(
    $Failures | Select-Object -Unique
).Count


$WarnCount = @(
    $Warnings | Select-Object -Unique
).Count


Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "VALIDATION SUMMARY" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host "CloudFormation YAML Files:" `
    -ForegroundColor Yellow

Write-Host "  Total : $($YamlFiles.Count)"


Write-Host "  Pass  : $($CloudFormationPasses.Count)" `
    -ForegroundColor Green

Write-Host "  Fail  : $($CloudFormationFailures.Count)" `
    -ForegroundColor Red


Write-Host ""

Write-Host "Audit Results:" `
    -ForegroundColor Yellow

Write-Host "  PASS    : $PassCount" `
    -ForegroundColor Green

Write-Host "  ERROR   : $FailCount" `
    -ForegroundColor Red

Write-Host "  WARNING : $WarnCount" `
    -ForegroundColor Yellow


# ============================================================
# 20 - REPORT LOCATION
# ============================================================

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "REPORT LOCATION" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host ""

Write-Host $ReportFolder `
    -ForegroundColor Gray


Write-Host ""
Write-Host "CloudFormation Diagnostic:" `
    -ForegroundColor Yellow

Write-Host $CloudFormationReport `
    -ForegroundColor Gray


Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan

Write-Host "VALIDATION DIAGNOSTIC COMPLETE" `
    -ForegroundColor Cyan

Write-Host "============================================================" `
    -ForegroundColor Cyan


# ============================================================
# 21 - HOW TO OPEN THE CLOUDFORMATION ERROR REPORT
# ============================================================
#
# The following commands are intentionally displayed for the
# user to run manually.
#
# They are NOT automatically executed.
#
# ============================================================

Write-Host ""
Write-Host "To view the CloudFormation validation report:" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host 'Get-Content ".\report-log\CloudFormation-Validation-Diagnostic.txt"' `
    -ForegroundColor White


Write-Host ""
Write-Host "If the output is very long:" `
    -ForegroundColor Yellow

Write-Host ""
Write-Host 'notepad ".\report-log\CloudFormation-Validation-Diagnostic.txt"' `
    -ForegroundColor White


# ============================================================
# 22 - FINAL EXIT CODE
# ============================================================
#
# IMPORTANT:
#
# Reports have already been generated above.
#
# Therefore the EXIT command is intentionally LAST.
#
# Exit codes:
#
#   0 = PASS
#   1 = WARNING in Strict mode
#   2 = FAIL
#
# GitHub Actions, CI/CD pipelines, and other automation can
# use these exit codes.
#
# ============================================================

if ($FailCount -gt 0) {

    exit 2

}


if ($Strict -and $WarnCount -gt 0) {

    exit 1

}


exit 0