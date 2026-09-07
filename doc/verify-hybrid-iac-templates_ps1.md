# ✅ Final Solution: Verify **All Terraform + CloudFormation Templates** With One PowerShell Script

Yes — now I understand exactly what you want.

You don't just want separate Terraform and CloudFormation validation commands. You want **one reusable PowerShell `.ps1` script** for your entire **AWS Hybrid IaC Lab** that:

* ✅ Verifies all Terraform `.tf` files/configuration
* ✅ Runs `terraform fmt -check`
* ✅ Runs `terraform init -backend=false`
* ✅ Runs `terraform validate`
* ✅ Finds `main.yaml` + every nested CloudFormation `.yaml`
* ✅ Runs `aws cloudformation validate-template` against every YAML template
* ✅ Does **not** deploy or destroy infrastructure
* ✅ Produces a final summary
* ❌ Clearly lists every failed Terraform/CloudFormation file
* ✅ Shows total PASS/FAILED counts
* ✅ Can be run from the project root
* ✅ Uses the script's own location, so you don't have to manually `cd` into Terraform or CloudFormation directories

And importantly, **the earlier "script not recognized" problem was not caused by the PowerShell code**. Your script is located under:

```text
scripts\verify-terraform.ps1
```

while you were trying to execute it from the project root as:

```powershell
.\verify-terraform.ps1
```

The new script below is designed specifically around your existing project structure.

---

# 📄 Recommended File Name

I recommend renaming/creating the final script as:

```text
verify-hybrid-iac-templates.ps1
```

Put it here:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab\scripts\verify-hybrid-iac-templates.ps1
```

Your structure will become:

```text
aws-hybrid-iac-lab\
│
├── infrastructure\
│   │
│   ├── terraform\
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── provider.tf
│   │   ├── outputs.tf
│   │   ├── iam.tf
│   │   ├── cloudformation.tf
│   │   └── ...
│   │
│   └── cloudformation\
│       ├── main.yaml
│       │
│       └── nested\
│           ├── api-gateway.yaml
│           ├── cloudfront.yaml
│           ├── dynamodb.yaml
│           ├── ec2.yaml
│           ├── ecr.yaml
│           ├── ecs.yaml
│           ├── eks.yaml
│           ├── lambda.yaml
│           ├── rds.yaml
│           ├── s3.yaml
│           └── vpc.yaml
│
└── scripts\
    ├── validate-cfn.ps1
    ├── verify-github-aws-oidc.ps1
    ├── verify-github-ci-cd.ps1
    ├── verify-hybrid-iac-architecture.ps1
    ├── verify-terraform.ps1
    │
    └── verify-hybrid-iac-templates.ps1   ← NEW FINAL SCRIPT
```

---

# 📝 Complete `verify-hybrid-iac-templates.ps1`

This version automatically discovers your project root from the script location, so **you don't have to worry about running it from the wrong directory**.

```
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
```

---

# 🚀 How to Create the New Script

Since your existing script is:

```text
scripts\verify-terraform.ps1
```

I recommend **keeping it for now** and creating the new combined script.

From your project root:

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"
```

Create the new file:

```powershell
notepad ".\scripts\verify-hybrid-iac-templates.ps1"
```

Paste the complete script above.

Save it as:

```text
verify-hybrid-iac-templates.ps1
```

Make sure it is **not**:

```text
verify-hybrid-iac-templates.ps1.txt
```

---

# 🔎 Verify the File Exists

From your project root:

```powershell
Get-ChildItem ".\scripts\verify-hybrid-iac-templates.ps1"
```

You should see something similar to:

```text
Mode   LastWriteTime   Length Name
----   -------------   ------ ----
-a---- ...             ...    verify-hybrid-iac-templates.ps1
```

---

# ▶️ Run the Entire Verification With One Command

This is the important part.

From:

```text
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

run:

```powershell
.\scripts\verify-hybrid-iac-templates.ps1
```

You **do not need to `cd` into Terraform**.

You **do not need to `cd` into CloudFormation**.

You **do not need separate commands**.

The script automatically knows:

```text
Project Root
     │
     ├── infrastructure\terraform
     │
     └── infrastructure\cloudformation
```

---

# 🔐 If PowerShell Execution Policy Blocks It

Run this once in the current PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Answer:

```text
Y
```

Then:

```powershell
.\scripts\verify-hybrid-iac-templates.ps1
```

You don't need to repeatedly execute `Set-ExecutionPolicy` after that in the same PowerShell session.

---

# 📊 What Your Final Report Will Look Like

If everything passes, you'll get something similar to:

```text
============================================================
 FINAL AWS HYBRID IaC VALIDATION REPORT
============================================================

TERRAFORM SUMMARY
------------------------------------------------------------

Check                              Status
-----                              ------
terraform fmt                      PASS
terraform init -backend=false      PASS
terraform validate                 PASS

Terraform checks: 3
Terraform passed: 3
Terraform failed: 0


CLOUDFORMATION SUMMARY
------------------------------------------------------------

Template                                             Status
--------                                             ------
...\cloudformation\main.yaml                        VALID
...\cloudformation\nested\api-gateway.yaml          VALID
...\cloudformation\nested\cloudfront.yaml            VALID
...\cloudformation\nested\dynamodb.yaml              VALID
...\cloudformation\nested\ec2.yaml                   VALID
...\cloudformation\nested\ecr.yaml                   VALID
...\cloudformation\nested\ecs.yaml                   VALID
...\cloudformation\nested\eks.yaml                   VALID
...\cloudformation\nested\lambda.yaml                VALID
...\cloudformation\nested\rds.yaml                   VALID
...\cloudformation\nested\s3.yaml                   VALID
...\cloudformation\nested\vpc.yaml                  VALID

CloudFormation templates: 12
CloudFormation passed: 12
CloudFormation failed: 0


============================================================
 FAILED ITEMS
============================================================

NO FAILED ITEMS FOUND.


============================================================
 FINAL TOTALS
============================================================

Total validation checks : 15
Total passed            : 15
Total failed            : 0

============================================================
 ALL TERRAFORM + CLOUDFORMATION CHECKS PASSED
============================================================
```

---

# ❌ If Something Fails

This is where the new script is particularly useful.

For example, suppose `ec2.yaml` and `cloudformation.tf` have problems.

The final report will identify them:

```text
============================================================
 FAILED ITEMS
============================================================

The following item(s) failed validation:

[FAILED] Terraform configuration
[FAILED] C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab\infrastructure\cloudformation\nested\ec2.yaml
```

And you'll also see:

```text
Total validation checks : 15
Total passed            : 13
Total failed            : 2
```

So you immediately know **what needs to be fixed**.

---

# ⭐ Your New IaC Verification Workflow

You can now treat this as your main verification command:

```text
AWS HYBRID IaC LAB
       │
       │
       ▼
verify-hybrid-iac-templates.ps1
       │
       ├───────────────────────────┐
       │                           │
       ▼                           ▼
 TERRAFORM                   CLOUDFORMATION
       │                           │
       ├─ fmt -check               ├─ main.yaml
       │                           │
       ├─ init                     ├─ api-gateway.yaml
       │                           ├─ cloudfront.yaml
       ├─ validate                 ├─ dynamodb.yaml
       │                           ├─ ec2.yaml
       │                           ├─ ecr.yaml
       │                           ├─ ecs.yaml
       │                           ├─ eks.yaml
       │                           ├─ lambda.yaml
       │                           ├─ rds.yaml
       │                           ├─ s3.yaml
       │                           └─ vpc.yaml
       │
       └───────────────┬───────────┘
                       │
                       ▼
                FINAL REPORT
                       │
              ┌────────┴────────┐
              ▼                 ▼
           PASSED             FAILED
                                │
                                ▼
                       EXACT FILE / ITEM
                       IS DISPLAYED
```

### One final command to remember

From the **root of `aws-hybrid-iac-lab`**:

```powershell
.\scripts\verify-hybrid-iac-templates.ps1
```

That's the command I recommend you use as the **main Terraform + CloudFormation verification command for this lab**.
---
