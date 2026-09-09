# ============================================================
# AWS HYBRID IaC LAB - LOCAL PRE-PUSH CHECK
# ============================================================
#
# PURPOSE
# ------------------------------------------------------------
# This script performs local validation before pushing the
# AWS Hybrid IaC Lab changes to GitHub.
#
# The script:
#
# 1. Automatically detects its own location.
# 2. Automatically detects the repository root.
# 3. Works regardless of the current PowerShell directory.
# 4. Verifies required Terraform and CloudFormation files.
# 5. Automatically formats iam.tf.
# 6. Checks Terraform formatting.
# 7. Verifies AWS CLI availability.
# 8. Verifies the active AWS identity.
# 9. Checks the Terraform S3 backend bucket.
# 10. Creates the backend bucket if it does not exist.
# 11. Enables S3 bucket versioning.
# 12. Enables default S3 encryption.
# 13. Blocks public access to the backend bucket.
# 14. Initializes/reconfigures Terraform.
# 15. Validates the Terraform configuration.
# 16. Creates a Terraform execution plan.
# 17. Verifies the plan file.
# 18. Restores the user's original PowerShell location.
# 19. Does NOT perform a GitHub push.
#
# IMPORTANT
# ------------------------------------------------------------
# The script is expected to be stored here:
#
#   <repository-root>\scripts\pre-push-check.ps1
#
# Example:
#
#   C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab\
#   scripts\pre-push-check.ps1
#
# ============================================================


# ============================================================
# GLOBAL ERROR BEHAVIOR
# ============================================================

# Stop PowerShell when a terminating error occurs.
$ErrorActionPreference = "Stop"


# ============================================================
# STORE ORIGINAL POWERSHELL LOCATION
# ============================================================

# Save the user's current PowerShell location.
#
# The script may temporarily enter the Terraform directory,
# but the user's original location will always be restored.
$OriginalLocation = Get-Location


# ============================================================
# VALIDATION SUCCESS FLAG
# ============================================================

# Used to determine whether the complete validation passed.
$ValidationSucceeded = $false


try {

    # ========================================================
    # 0. PATH DETECTION
    # ========================================================

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " AWS HYBRID IaC LAB - PRE-PUSH VALIDATION" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "=== 0. PATH DETECTION ===" -ForegroundColor Yellow


    # --------------------------------------------------------
    # Detect the directory where this PowerShell script exists.
    #
    # $PSScriptRoot does not depend on the directory from which
    # the script was launched.
    # --------------------------------------------------------

    $ScriptDirectory = $PSScriptRoot


    # --------------------------------------------------------
    # The repository root is the parent directory of "scripts".
    # --------------------------------------------------------

    $RepositoryRoot = Split-Path -Parent $ScriptDirectory


    # --------------------------------------------------------
    # Terraform directory.
    # --------------------------------------------------------

    $TerraformDirectory = Join-Path `
        $RepositoryRoot `
        "infrastructure\terraform"


    # --------------------------------------------------------
    # IAM Terraform file.
    # --------------------------------------------------------

    $IamFile = Join-Path `
        $TerraformDirectory `
        "iam.tf"


    # --------------------------------------------------------
    # Required CloudFormation files.
    # --------------------------------------------------------

    $VpcFile = Join-Path `
        $RepositoryRoot `
        "infrastructure\cloudformation\nested\vpc.yaml"

    $EksFile = Join-Path `
        $RepositoryRoot `
        "infrastructure\cloudformation\nested\eks.yaml"

    $MainFile = Join-Path `
        $RepositoryRoot `
        "infrastructure\cloudformation\main.yaml"


    # --------------------------------------------------------
    # Terraform CloudFormation configuration.
    # --------------------------------------------------------

    $CloudFormationTerraformFile = Join-Path `
        $TerraformDirectory `
        "cloudformation.tf"


    # --------------------------------------------------------
    # Terraform plan output file.
    # --------------------------------------------------------

    $PlanFile = Join-Path `
        $TerraformDirectory `
        "pre-push.tfplan"


    # --------------------------------------------------------
    # Terraform backend settings.
    #
    # These values match backend.tf for this lab.
    # --------------------------------------------------------

    $TerraformStateBucket = `
        "aws-hybrid-iac-lab-terraform-state-537236558357"

    $TerraformStateRegion = "us-east-1"


    # --------------------------------------------------------
    # Display detected paths.
    # --------------------------------------------------------

    Write-Host "[INFO] Current PowerShell location:" -ForegroundColor Cyan
    Write-Host "       $OriginalLocation"

    Write-Host ""
    Write-Host "[INFO] Script location:" -ForegroundColor Cyan
    Write-Host "       $ScriptDirectory"

    Write-Host ""
    Write-Host "[INFO] Repository root:" -ForegroundColor Cyan
    Write-Host "       $RepositoryRoot"

    Write-Host ""
    Write-Host "[INFO] Terraform directory:" -ForegroundColor Cyan
    Write-Host "       $TerraformDirectory"

    Write-Host ""
    Write-Host "[INFO] IAM file:" -ForegroundColor Cyan
    Write-Host "       $IamFile"

    Write-Host ""
    Write-Host "[INFO] Terraform state bucket:" -ForegroundColor Cyan
    Write-Host "       $TerraformStateBucket"

    Write-Host ""
    Write-Host "[INFO] Terraform state region:" -ForegroundColor Cyan
    Write-Host "       $TerraformStateRegion"


    # ========================================================
    # 1. CHECK REQUIRED FILES
    # ========================================================

    Write-Host ""
    Write-Host "=== 1. CHECK REQUIRED FILES ===" -ForegroundColor Yellow


    $RequiredFiles = @(
        $VpcFile,
        $EksFile,
        $MainFile,
        $IamFile,
        $CloudFormationTerraformFile
    )


    foreach ($File in $RequiredFiles) {

        if (Test-Path -LiteralPath $File -PathType Leaf) {

            # Convert absolute path into a repository-relative
            # path for cleaner output.
            $RelativePath = $File.Substring(
                $RepositoryRoot.Length
            ).TrimStart('\')

            Write-Host "[OK] $RelativePath" -ForegroundColor Green
        }
        else {

            throw "Missing required file: $File"
        }
    }


    Write-Host ""
    Write-Host "[OK] Required repository files found." -ForegroundColor Green


    # ========================================================
    # 2. CHECK TERRAFORM COMMAND
    # ========================================================

    Write-Host ""
    Write-Host "=== 2. CHECK TERRAFORM ===" -ForegroundColor Yellow


    # --------------------------------------------------------
    # Verify that Terraform is installed and available through
    # the current PowerShell PATH.
    # --------------------------------------------------------

    $TerraformCommand = Get-Command terraform `
        -ErrorAction SilentlyContinue


    if ($null -eq $TerraformCommand) {

        throw `
            "Terraform was not found in PATH. Install Terraform or add it to PATH."
    }


    # --------------------------------------------------------
    # Display Terraform version.
    # --------------------------------------------------------

    terraform version


    if ($LASTEXITCODE -ne 0) {

        throw `
            "Terraform command is not working correctly."
    }


    Write-Host "[OK] Terraform is available." -ForegroundColor Green


    # ========================================================
    # 3. FIX TERRAFORM FORMATTING
    # ========================================================

    Write-Host ""
    Write-Host "=== 3. FIX TERRAFORM FORMATTING ===" -ForegroundColor Yellow


    Write-Host "[INFO] Formatting:" -ForegroundColor Cyan
    Write-Host "       $IamFile"


    # --------------------------------------------------------
    # Automatically format iam.tf.
    # --------------------------------------------------------

    terraform fmt "$IamFile"


    if ($LASTEXITCODE -ne 0) {

        throw `
            "Terraform formatting command failed."
    }


    Write-Host "[OK] iam.tf formatting completed." -ForegroundColor Green


    # ========================================================
    # 4. TERRAFORM FORMAT CHECK
    # ========================================================

    Write-Host ""
    Write-Host "=== 4. TERRAFORM FORMAT CHECK ===" -ForegroundColor Yellow


    # --------------------------------------------------------
    # Verify formatting throughout the Terraform directory.
    #
    # -check
    #     Checks formatting without changing files.
    #
    # -recursive
    #     Checks Terraform files in subdirectories.
    # --------------------------------------------------------

    terraform fmt `
        -check `
        -recursive `
        "$TerraformDirectory"


    if ($LASTEXITCODE -ne 0) {

        throw `
            "Terraform formatting check failed."
    }


    Write-Host "[OK] Terraform formatting is correct." -ForegroundColor Green


    # ========================================================
    # 5. CHECK AWS CLI
    # ========================================================

    Write-Host ""
    Write-Host "=== 5. CHECK AWS CLI ===" -ForegroundColor Yellow


    # --------------------------------------------------------
    # Verify AWS CLI is installed.
    # --------------------------------------------------------

    $AwsCommand = Get-Command aws `
        -ErrorAction SilentlyContinue


    if ($null -eq $AwsCommand) {

        throw `
            "AWS CLI was not found in PATH."
    }


    Write-Host "[OK] AWS CLI is available." -ForegroundColor Green


    # ========================================================
    # 6. CHECK AWS IDENTITY
    # ========================================================

    Write-Host ""
    Write-Host "=== 6. CHECK AWS IDENTITY ===" -ForegroundColor Yellow


    # --------------------------------------------------------
    # Verify that AWS credentials are configured and usable.
    #
    # This also confirms which AWS account the validation will
    # operate against.
    # --------------------------------------------------------

    $AwsIdentityJson = aws sts get-caller-identity


    if ($LASTEXITCODE -ne 0) {

        throw `
            "AWS credentials are not working. Configure valid AWS CLI credentials."
    }


    $AwsIdentity = $AwsIdentityJson | ConvertFrom-Json


    Write-Host "[INFO] AWS Account:" -ForegroundColor Cyan
    Write-Host "       $($AwsIdentity.Account)"

    Write-Host "[INFO] AWS ARN:" -ForegroundColor Cyan
    Write-Host "       $($AwsIdentity.Arn)"


    Write-Host "[OK] AWS credentials are valid." -ForegroundColor Green


    # ========================================================
    # 7. CHECK / CREATE TERRAFORM STATE BUCKET
    # ========================================================

    Write-Host ""
    Write-Host "=== 7. TERRAFORM STATE BUCKET ===" -ForegroundColor Yellow


    Write-Host "[INFO] Checking S3 backend bucket:" -ForegroundColor Cyan
    Write-Host "       $TerraformStateBucket"


    # --------------------------------------------------------
    # Check whether the bucket exists in the current AWS
    # account.
    #
    # list-buckets is used here so a missing bucket can be
    # distinguished from an inaccessible bucket.
    # --------------------------------------------------------

    $BucketExists = $false


    $BucketListJson = aws s3api list-buckets `
        --output json `
        2>$null


    if ($LASTEXITCODE -eq 0) {

        $BucketList = $BucketListJson | ConvertFrom-Json


        foreach ($Bucket in $BucketList.Buckets) {

            if ($Bucket.Name -eq $TerraformStateBucket) {

                $BucketExists = $true
                break
            }
        }
    }
    else {

        throw `
            "Unable to list S3 buckets. Verify that the AWS identity has permission to list S3 buckets."
    }


    # --------------------------------------------------------
    # Create the Terraform backend bucket when it does not
    # already exist.
    #
    # This must happen BEFORE terraform init because the S3
    # backend requires the bucket to already exist.
    # --------------------------------------------------------

    if (-not $BucketExists) {

        Write-Host ""
        Write-Host "[INFO] Terraform state bucket does not exist." `
            -ForegroundColor Yellow

        Write-Host "[INFO] Creating:" -ForegroundColor Cyan
        Write-Host "       $TerraformStateBucket"


        # ----------------------------------------------------
        # us-east-1 has special S3 CreateBucket behavior.
        #
        # LocationConstraint must NOT be supplied for
        # us-east-1.
        # ----------------------------------------------------

        if ($TerraformStateRegion -eq "us-east-1") {

            aws s3api create-bucket `
                --bucket $TerraformStateBucket `
                --region $TerraformStateRegion
        }
        else {

            aws s3api create-bucket `
                --bucket $TerraformStateBucket `
                --region $TerraformStateRegion `
                --create-bucket-configuration `
                "LocationConstraint=$TerraformStateRegion"
        }


        if ($LASTEXITCODE -ne 0) {

            throw `
                "Failed to create Terraform state bucket: $TerraformStateBucket"
        }


        Write-Host "[OK] Terraform state bucket created." `
            -ForegroundColor Green
    }
    else {

        Write-Host "[OK] Terraform state bucket already exists." `
            -ForegroundColor Green
    }


    # ========================================================
    # 8. CONFIGURE TERRAFORM STATE BUCKET SECURITY
    # ========================================================

    Write-Host ""
    Write-Host "=== 8. CONFIGURE STATE BUCKET SECURITY ===" -ForegroundColor Yellow


    # --------------------------------------------------------
    # Enable S3 versioning.
    #
    # Versioning provides protection against accidental
    # overwrites/deletions of Terraform state objects.
    # --------------------------------------------------------

    aws s3api put-bucket-versioning `
        --bucket $TerraformStateBucket `
        --versioning-configuration Status=Enabled


    if ($LASTEXITCODE -ne 0) {

        throw `
            "Failed to enable S3 versioning on the Terraform state bucket."
    }


    Write-Host "[OK] S3 versioning enabled." -ForegroundColor Green


    # --------------------------------------------------------
    # Enable default S3 server-side encryption (SSE-S3).
    #
    # IMPORTANT:
    #
    # The AWS CLI expects ONLY the
    # ServerSideEncryptionConfiguration object for this
    # parameter.
    #
    # A temporary JSON file is used because Windows PowerShell
    # can alter quotation marks when JSON is passed directly
    # to a native executable.
    #
    # The JSON file therefore avoids PowerShell argument
    # parsing problems completely.
    # --------------------------------------------------------

    $EncryptionConfigurationFile = Join-Path `
        $env:TEMP `
        "aws-hybrid-iac-s3-encryption.json"


    # --------------------------------------------------------
    # This is the exact JSON structure required by:
    #
    # aws s3api put-bucket-encryption
    #
    # DO NOT add "Bucket" or other fields here.
    # --------------------------------------------------------

    $EncryptionConfiguration = @'
{
  "Rules": [
    {
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }
  ]
}
'@


    try {

        # ----------------------------------------------------
        # Write UTF-8 JSON WITHOUT a BOM.
        #
        # Using .NET directly avoids Windows PowerShell 5.1
        # UTF-8/BOM compatibility problems with the AWS CLI.
        # ----------------------------------------------------

        $Utf8NoBom = New-Object `
            System.Text.UTF8Encoding($false)


        [System.IO.File]::WriteAllText(
            $EncryptionConfigurationFile,
            $EncryptionConfiguration,
            $Utf8NoBom
        )


        # ----------------------------------------------------
        # Verify that the temporary JSON file was created.
        # ----------------------------------------------------

        if (-not (
            Test-Path `
                -LiteralPath $EncryptionConfigurationFile `
                -PathType Leaf
        )) {

            throw `
                "Failed to create temporary S3 encryption configuration file."
        }


        # ----------------------------------------------------
        # Apply default SSE-S3 encryption.
        #
        # file:// tells AWS CLI to read the JSON configuration
        # from the temporary file.
        # ----------------------------------------------------

        aws s3api put-bucket-encryption `
            --bucket $TerraformStateBucket `
            --server-side-encryption-configuration `
            "file://$EncryptionConfigurationFile"


        if ($LASTEXITCODE -ne 0) {

            throw `
                "Failed to enable default S3 encryption."
        }


        Write-Host "[OK] S3 default encryption enabled." `
            -ForegroundColor Green
    }
    finally {

        # ----------------------------------------------------
        # Always remove the temporary JSON file.
        # ----------------------------------------------------

        if (Test-Path `
            -LiteralPath $EncryptionConfigurationFile
        ) {

            Remove-Item `
                -LiteralPath $EncryptionConfigurationFile `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }


    # --------------------------------------------------------
    # Block all public access.
    #
    # Terraform state should never be publicly accessible.
    # --------------------------------------------------------

    aws s3api put-public-access-block `
        --bucket $TerraformStateBucket `
        --public-access-block-configuration `
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"


    if ($LASTEXITCODE -ne 0) {

        throw `
            "Failed to configure S3 public access blocking."
    }


    Write-Host "[OK] S3 public access blocked." -ForegroundColor Green


    # ========================================================
    # 9. ENTER TERRAFORM DIRECTORY
    # ========================================================

    # --------------------------------------------------------
    # Terraform commands below must run from the Terraform
    # configuration directory.
    #
    # Push-Location changes only the script's internal location.
    # The user's original PowerShell location is restored later.
    # --------------------------------------------------------

    Push-Location -LiteralPath $TerraformDirectory


    try {

        # ====================================================
        # 10. TERRAFORM INIT
        # ====================================================

        Write-Host ""
        Write-Host "=== 10. TERRAFORM INIT ===" -ForegroundColor Yellow


        # ----------------------------------------------------
        # Reconfigure the Terraform S3 backend.
        #
        # The backend bucket now exists and has been secured.
        # ----------------------------------------------------

        terraform init -reconfigure


        if ($LASTEXITCODE -ne 0) {

            throw `
                "Terraform initialization failed."
        }


        Write-Host "[OK] Terraform backend initialized." `
            -ForegroundColor Green


        # ====================================================
        # 11. TERRAFORM VALIDATE
        # ====================================================

        Write-Host ""
        Write-Host "=== 11. TERRAFORM VALIDATE ===" -ForegroundColor Yellow


        Write-Host "[INFO] Terraform working directory:" `
            -ForegroundColor Cyan

        Write-Host "       $TerraformDirectory"


        terraform validate


        if ($LASTEXITCODE -ne 0) {

            throw `
                "Terraform validation failed."
        }


        Write-Host "[OK] Terraform configuration is valid." `
            -ForegroundColor Green


        # ====================================================
        # 12. TERRAFORM PLAN
        # ====================================================

        Write-Host ""
        Write-Host "=== 12. TERRAFORM PLAN ===" -ForegroundColor Yellow


        Write-Host "[INFO] Plan output:" -ForegroundColor Cyan
        Write-Host "       $PlanFile"


        # ----------------------------------------------------
        # Remove an old plan file before generating a new one.
        # ----------------------------------------------------

        if (Test-Path `
            -LiteralPath $PlanFile `
            -PathType Leaf
        ) {

            Remove-Item `
                -LiteralPath $PlanFile `
                -Force
        }


        # ----------------------------------------------------
        # Generate a fresh Terraform execution plan.
        #
        # IMPORTANT:
        # Keep the output argument in this form:
        #
        #   -out "pre-push.tfplan"
        #
        # This is compatible with the working command behavior
        # already established in this lab.
        # ----------------------------------------------------

        terraform plan -out "pre-push.tfplan"


        if ($LASTEXITCODE -ne 0) {

            throw `
                "Terraform plan failed."
        }


        Write-Host "[OK] Terraform plan completed successfully." `
            -ForegroundColor Green


        # ====================================================
        # 13. PLAN FILE CHECK
        # ====================================================

        Write-Host ""
        Write-Host "=== 13. PLAN FILE CHECK ===" -ForegroundColor Yellow


        if (Test-Path `
            -LiteralPath $PlanFile `
            -PathType Leaf
        ) {

            Write-Host "[OK] Terraform plan file created." `
                -ForegroundColor Green
        }
        else {

            throw @"
Terraform plan reported success, but the expected plan file
was not found:

$PlanFile
"@
        }


        # ----------------------------------------------------
        # Everything completed successfully.
        # ----------------------------------------------------

        $ValidationSucceeded = $true
    }


    finally {

        # ----------------------------------------------------
        # Always leave the Terraform directory.
        # ----------------------------------------------------

        Pop-Location
    }


    # ========================================================
    # SUCCESS
    # ========================================================

    if ($ValidationSucceeded) {

        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Green

        Write-Host " SUCCESS - LOCAL VALIDATION PASSED" `
            -ForegroundColor Green

        Write-Host "============================================================" `
            -ForegroundColor Green


        Write-Host ""
        Write-Host "Your code passed:" -ForegroundColor Green

        Write-Host "  [OK] Automatic path detection"
        Write-Host "  [OK] Required file check"
        Write-Host "  [OK] Terraform availability"
        Write-Host "  [OK] iam.tf formatting"
        Write-Host "  [OK] Terraform formatting"
        Write-Host "  [OK] AWS CLI availability"
        Write-Host "  [OK] AWS credentials"
        Write-Host "  [OK] Terraform state bucket"
        Write-Host "  [OK] S3 versioning"
        Write-Host "  [OK] S3 encryption"
        Write-Host "  [OK] S3 public access protection"
        Write-Host "  [OK] Terraform initialization"
        Write-Host "  [OK] Terraform validation"
        Write-Host "  [OK] Terraform plan"
        Write-Host "  [OK] Terraform plan file"


        Write-Host ""
        Write-Host "Terraform plan:" -ForegroundColor Cyan
        Write-Host "  $PlanFile"


        Write-Host ""
        Write-Host "Original PowerShell location:" -ForegroundColor Cyan
        Write-Host "  $OriginalLocation"


        Write-Host ""
        Write-Host "No GitHub push was performed." -ForegroundColor Cyan
    }
}


# ============================================================
# ERROR HANDLING
# ============================================================

catch {

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Red

    Write-Host " VALIDATION FAILED" `
        -ForegroundColor Red

    Write-Host "============================================================" `
        -ForegroundColor Red


    Write-Host ""
    Write-Host "ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red


    Write-Host ""
    Write-Host "The validation stopped safely." -ForegroundColor Yellow


    $ValidationSucceeded = $false
}


# ============================================================
# ALWAYS RESTORE ORIGINAL POWERSHELL LOCATION
# ============================================================

finally {

    # --------------------------------------------------------
    # Make absolutely sure the user's original PowerShell
    # location is restored.
    # --------------------------------------------------------

    try {

        if ((Get-Location).Path -ne $OriginalLocation.Path) {

            Set-Location -LiteralPath $OriginalLocation
        }
    }
    catch {

        Write-Host ""
        Write-Host "[WARNING] Could not restore the original location." `
            -ForegroundColor Yellow
    }


    # ========================================================
    # FINAL LOCATION CHECK
    # ========================================================

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " CURRENT POWERSHELL LOCATION" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan


    Write-Host ""
    Write-Host (Get-Location).Path -ForegroundColor Green


    # ========================================================
    # FINAL STATUS
    # ========================================================

    Write-Host ""

    if ($ValidationSucceeded) {

        Write-Host "FINAL STATUS: PASSED" -ForegroundColor Green
    }
    else {

        Write-Host "FINAL STATUS: FAILED" -ForegroundColor Red
    }


    # ========================================================
    # FINAL PAUSE
    # ========================================================

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host " PRESS ENTER TO CLOSE" `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan


    Read-Host
}

