# ================================================================
# AWS FULL ACCOUNT / REGION CLEANUP SCRIPT
# ================================================================
#
# File:
#   scripts/aws-full-cleanup.ps1
#
# Purpose:
#   Discover and delete AWS resources used by the Charlie Cafe /
#   AWS Hybrid IaC Lab.
#
# Resources handled:
#
#   1.  CloudFront distributions
#   2.  S3 buckets and all objects/versions/delete markers
#   3.  ECS services
#   4.  ECS tasks
#   5.  ECS clusters
#   6.  ECR repositories
#   7.  RDS DB instances
#   8.  RDS DB clusters
#   9.  Secrets Manager secrets
#   10. VPC endpoints
#   11. NAT gateways
#   12. Elastic IP addresses
#   13. Internet gateways
#   14. Route tables
#   15. Network interfaces
#   16. Subnets
#   17. Security groups
#   18. VPCs
#
# IMPORTANT:
#
#   This script is DESTRUCTIVE when -Execute is supplied.
#
#   PREVIEW:
#
#       .\aws-full-cleanup.ps1 -Region us-east-1
#
#   ACTUAL DELETION:
#
#       .\aws-full-cleanup.ps1 -Region us-east-1 -Execute
#
#   The script asks for:
#
#       DELETE
#
#   before performing destructive operations.
#
# ================================================================


[CmdletBinding()]
param(

    # ------------------------------------------------------------
    # AWS region containing the lab resources.
    # ------------------------------------------------------------

    [Parameter(Mandatory = $false)]
    [string]$Region = "us-east-1",


    # ------------------------------------------------------------
    # Optional AWS CLI profile.
    #
    # Leave empty to use the default AWS CLI profile.
    #
    # Examples:
    #
    #   -Profile "default"
    #
    #   -Profile "dev"
    # ------------------------------------------------------------

    [Parameter(Mandatory = $false)]
    [string]$Profile = "",


    # ------------------------------------------------------------
    # Actually perform deletion.
    #
    # Without -Execute:
    #
    #   PREVIEW ONLY
    #
    # With -Execute:
    #
    #   resources are actually deleted.
    # ------------------------------------------------------------

    [switch]$Execute,


    # ------------------------------------------------------------
    # Default VPC protection.
    #
    # By default the script DOES NOT delete default VPCs.
    #
    # To intentionally delete default VPCs:
    #
    #   -DeleteDefaultVpc
    # ------------------------------------------------------------

    [switch]$DeleteDefaultVpc
)


# ================================================================
# GLOBAL SETTINGS
# ================================================================

$ErrorActionPreference = "Continue"


# ---------------------------------------------------------------
# Maximum retry count for operations that may temporarily fail.
# ---------------------------------------------------------------

$MaxRetries = 10


# ---------------------------------------------------------------
# Delay between retries.
# ---------------------------------------------------------------

$RetryDelaySeconds = 10


# ---------------------------------------------------------------
# NAT gateway deletion can take several minutes.
# ---------------------------------------------------------------

$NatWaitSeconds = 15


# ================================================================
# AWS CLI COMMAND BUILDER
# ================================================================

function Get-AwsBaseArgs {

    $args = @(
        "--region"
        $Region
        "--no-cli-pager"
    )


    # ------------------------------------------------------------
    # Add AWS profile if supplied.
    # ------------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($Profile)) {

        $args += @(
            "--profile"
            $Profile
        )
    }


    return $args
}


# ================================================================
# RUN AWS CLI
# ================================================================

function Invoke-AwsCli {

    param(

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )


    $baseArgs = Get-AwsBaseArgs

    $finalArgs = $baseArgs + $Arguments


    & aws @finalArgs 2>&1
}


# ================================================================
# RUN AWS CLI AND RETURN JSON
# ================================================================

function Invoke-AwsJson {

    param(

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )


    $output = Invoke-AwsCli -Arguments $Arguments


    if ($LASTEXITCODE -ne 0) {

        return $null
    }


    $text = $output -join "`n"


    if ([string]::IsNullOrWhiteSpace($text)) {

        return $null
    }


    try {

        return $text | ConvertFrom-Json
    }
    catch {

        return $null
    }
}


# ================================================================
# WRITE UTF-8 WITHOUT BOM
# ================================================================
#
# IMPORTANT FOR WINDOWS POWERSHELL 5.1
#
# Windows PowerShell 5.1:
#
#     Set-Content -Encoding UTF8
#
# writes a UTF-8 BOM.
#
# Some AWS CLI JSON parameters can fail when that BOM is present.
#
# This helper always writes UTF-8 WITHOUT BOM.
#
# ================================================================

function Write-Utf8NoBomFile {

    param(

        [Parameter(Mandatory = $true)]
        [string]$Path,


        [Parameter(Mandatory = $true)]
        [string]$Content
    )


    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)


    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        $utf8NoBom
    )
}


# ================================================================
# LOGGING FUNCTIONS
# ================================================================

function Write-Info {

    param(
        [string]$Message
    )


    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}


function Write-Success {

    param(
        [string]$Message
    )


    Write-Host "[PASS] $Message" -ForegroundColor Green
}


function Write-WarningMessage {

    param(
        [string]$Message
    )


    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}


function Write-Failure {

    param(
        [string]$Message
    )


    Write-Host "[FAIL] $Message" -ForegroundColor Red
}


function Write-Section {

    param(
        [string]$Title
    )


    Write-Host ""

    Write-Host "============================================================" `
        -ForegroundColor DarkCyan

    Write-Host $Title -ForegroundColor White

    Write-Host "============================================================" `
        -ForegroundColor DarkCyan
}


# ================================================================
# EXECUTION GUARD
# ================================================================

function Confirm-Execution {

    if ($Execute) {

        Write-WarningMessage "DESTRUCTIVE MODE ENABLED."

        Write-WarningMessage "AWS resources WILL be deleted."

        Write-Host ""


        $confirmation = Read-Host "Type DELETE to continue"


        if ($confirmation -ne "DELETE") {

            Write-WarningMessage `
                "Confirmation failed. Cleanup cancelled."

            exit 1
        }


        return
    }


    Write-WarningMessage "PREVIEW MODE."

    Write-WarningMessage `
        "No resources will actually be deleted."

    Write-WarningMessage `
        "Use -Execute to perform deletion."

    Write-Host ""
}


# ================================================================
# 01 - AWS CLI CHECK
# ================================================================

function Test-AwsCli {

    Write-Section "01 - AWS CLI CHECK"


    # ------------------------------------------------------------
    # Check AWS CLI.
    # ------------------------------------------------------------

    $awsVersion = aws --version 2>&1


    if ($LASTEXITCODE -ne 0) {

        Write-Failure `
            "AWS CLI is not installed or not available in PATH."

        exit 1
    }


    Write-Info "AWS CLI: $awsVersion"


    # ------------------------------------------------------------
    # Test AWS authentication.
    # ------------------------------------------------------------

    $identity = Invoke-AwsJson -Arguments @(
        "sts"
        "get-caller-identity"
    )


    if ($null -eq $identity) {

        Write-Failure `
            "Unable to authenticate to AWS."

        exit 1
    }


    Write-Success "AWS authentication successful."

    Write-Info "Account ID: $($identity.Account)"

    Write-Info "User/Role: $($identity.Arn)"

    Write-Info "Region: $Region"
}


# ================================================================
# WAIT FUNCTION
# ================================================================

function Wait-Seconds {

    param(
        [int]$Seconds
    )


    Start-Sleep -Seconds $Seconds
}


# ================================================================
# 02 - CLOUDFRONT CLEANUP
# ================================================================
#
# CloudFront is a GLOBAL AWS service.
#
# Therefore this function deliberately does NOT depend on the
# normal regional Invoke-AwsCli helper.
#
# CloudFront operations use:
#
#     us-east-1
#
# This function:
#
#   1. Discovers all distributions.
#   2. Supports multiple distributions.
#   3. Supports different distribution IDs/names.
#   4. Handles enabled distributions.
#   5. Handles already-disabled distributions.
#   6. Disables enabled distributions.
#   7. Waits for deployment.
#   8. Gets a fresh ETag.
#   9. Deletes the distribution.
#
# IMPORTANT:
#
# CloudFront requires a distribution to be disabled before deletion.
#
# ================================================================

function Remove-CloudFront {

    Write-Section "02 - CLOUDFRONT CLEANUP"


    Write-Info "CloudFront is a global AWS service."

    Write-Info `
        "Using direct AWS CLI CloudFront discovery..."


    # ------------------------------------------------------------
    # CloudFront control-plane region.
    #
    # Do NOT use the user-selected application region here.
    # ------------------------------------------------------------

    $cloudFrontRegion = "us-east-1"


    Write-Info `
        "Running AWS CloudFront list-distributions..."


    # ============================================================
    # DISCOVER DISTRIBUTIONS
    # ============================================================

    $listArgs = @(
        "cloudfront"
        "list-distributions"
        "--region"
        $cloudFrontRegion
        "--no-cli-pager"
        "--output"
        "json"
    )


    # ------------------------------------------------------------
    # Add profile if supplied.
    # ------------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($Profile)) {

        $listArgs += @(
            "--profile"
            $Profile
        )
    }


    # ------------------------------------------------------------
    # Execute directly.
    #
    # We intentionally do NOT use Invoke-AwsCli here.
    # ------------------------------------------------------------

    $listOutput = & aws @listArgs 2>&1


    # IMPORTANT:
    #
    # Capture LASTEXITCODE immediately.
    # ------------------------------------------------------------

    $listExitCode = $LASTEXITCODE


    if ($listExitCode -ne 0) {

        Write-Failure `
            "AWS CLI CloudFront discovery failed."


        Write-Host ""

        Write-Host "AWS CLI ERROR:" `
            -ForegroundColor Red

        Write-Host `
            "------------------------------------------------------------" `
            -ForegroundColor DarkRed


        foreach ($line in $listOutput) {

            Write-Host $line -ForegroundColor Red
        }


        Write-Host `
            "------------------------------------------------------------" `
            -ForegroundColor DarkRed


        Write-Host ""


        return
    }


    # ============================================================
    # PARSE JSON
    # ============================================================

    $listText = $listOutput -join "`n"


    if ([string]::IsNullOrWhiteSpace($listText)) {

        Write-Info `
            "CloudFront returned an empty response."

        return
    }


    try {

        $cloudFrontData = $listText | ConvertFrom-Json
    }
    catch {

        Write-Failure `
            "Unable to parse CloudFront JSON response."

        Write-Host $_.Exception.Message `
            -ForegroundColor Red

        return
    }


    # ============================================================
    # GET DISTRIBUTIONS
    # ============================================================

    if ($null -eq $cloudFrontData.DistributionList) {

        Write-Info `
            "CloudFront DistributionList was empty."

        return
    }


    if ($null -eq $cloudFrontData.DistributionList.Items) {

        Write-Info `
            "No CloudFront distributions found."

        return
    }


    # ------------------------------------------------------------
    # Force array handling.
    #
    # This is important when AWS returns:
    #
    #   1 distribution
    #
    # instead of:
    #
    #   multiple distributions
    # ------------------------------------------------------------

    $distributions = @(
        $cloudFrontData.DistributionList.Items
    )


    if ($distributions.Count -eq 0) {

        Write-Info `
            "No CloudFront distributions found."

        return
    }


    Write-Success `
        "Found $($distributions.Count) CloudFront distribution(s)."


    # ============================================================
    # DISPLAY ALL DISTRIBUTIONS
    # ============================================================

    foreach ($distribution in $distributions) {

        Write-Host ""

        Write-Host `
            "------------------------------------------------------------" `
            -ForegroundColor DarkGray


        Write-Info `
            "Distribution ID : $($distribution.Id)"

        Write-Info `
            "Status          : $($distribution.Status)"

        Write-Info `
            "Enabled         : $($distribution.Enabled)"

        Write-Info `
            "Domain          : $($distribution.DomainName)"


        Write-Host `
            "------------------------------------------------------------" `
            -ForegroundColor DarkGray
    }


    # ============================================================
    # PROCESS EACH DISTRIBUTION
    # ============================================================

    foreach ($distribution in $distributions) {

        $distributionId = [string]$distribution.Id


        Write-Section `
            "CLOUDFRONT: $distributionId"


        Write-Info `
            "Distribution ID: $distributionId"

        Write-Info `
            "Enabled: $($distribution.Enabled)"


        # ========================================================
        # PREVIEW MODE
        # ========================================================

        if (-not $Execute) {

            if ($distribution.Enabled -eq $true) {

                Write-WarningMessage `
                    "PREVIEW: Would DISABLE distribution $distributionId"

                Write-WarningMessage `
                    "PREVIEW: Would wait for CloudFront deployment."

                Write-WarningMessage `
                    "PREVIEW: Would DELETE distribution $distributionId"
            }
            else {

                Write-WarningMessage `
                    "PREVIEW: Distribution is already disabled."

                Write-WarningMessage `
                    "PREVIEW: Would DELETE distribution $distributionId"
            }


            continue
        }


        # ========================================================
        # GET CURRENT DISTRIBUTION CONFIGURATION
        # ========================================================

        Write-Info `
            "Retrieving CloudFront configuration..."


        $configArgs = @(
            "cloudfront"
            "get-distribution-config"
            "--id"
            $distributionId
            "--region"
            $cloudFrontRegion
            "--no-cli-pager"
            "--output"
            "json"
        )


        if (-not [string]::IsNullOrWhiteSpace($Profile)) {

            $configArgs += @(
                "--profile"
                $Profile
            )
        }


        $configOutput = & aws @configArgs 2>&1

        $configExitCode = $LASTEXITCODE


        if ($configExitCode -ne 0) {

            Write-Failure `
                "Failed to retrieve CloudFront configuration for $distributionId."


            foreach ($line in $configOutput) {

                Write-Host $line -ForegroundColor Red
            }


            continue
        }


        # ========================================================
        # PARSE CONFIGURATION
        # ========================================================

        try {

            $configData = (
                $configOutput -join "`n"
            ) | ConvertFrom-Json
        }
        catch {

            Write-Failure `
                "Unable to parse CloudFront configuration for $distributionId."

            Write-Host $_.Exception.Message `
                -ForegroundColor Red

            continue
        }


        $etag = $configData.ETag

        $distributionConfig = `
            $configData.DistributionConfig


        if ([string]::IsNullOrWhiteSpace($etag)) {

            Write-Failure `
                "CloudFront ETag not found for $distributionId."

            continue
        }


        if ($null -eq $distributionConfig) {

            Write-Failure `
                "CloudFront DistributionConfig not found for $distributionId."

            continue
        }


        # ========================================================
        # DISABLE ENABLED DISTRIBUTION
        # ========================================================

        if ($distributionConfig.Enabled -eq $true) {

            Write-Info `
                "Distribution is ENABLED."

            Write-Info `
                "Disabling distribution..."


            # ----------------------------------------------------
            # Change:
            #
            #     Enabled: true
            #
            # to:
            #
            #     Enabled: false
            # ----------------------------------------------------

            $distributionConfig.Enabled = $false


            # ----------------------------------------------------
            # Convert configuration to JSON.
            # ----------------------------------------------------

            $configJson = `
                $distributionConfig |
                ConvertTo-Json -Depth 100


            # ----------------------------------------------------
            # Create temporary JSON file.
            # ----------------------------------------------------

            $tempConfig = Join-Path `
                $env:TEMP `
                "cloudfront-$distributionId-$([guid]::NewGuid()).json"


            # ----------------------------------------------------
            # IMPORTANT:
            #
            # Write UTF-8 WITHOUT BOM.
            #
            # This fixes the exact error:
            #
            #   Expected: '=', received: '∩'
            #
            # that occurred with:
            #
            #   Set-Content -Encoding UTF8
            #
            # on Windows PowerShell 5.1.
            # ----------------------------------------------------

            Write-Utf8NoBomFile `
                -Path $tempConfig `
                -Content $configJson


            # ----------------------------------------------------
            # Verify temporary file exists.
            # ----------------------------------------------------

            if (-not (Test-Path $tempConfig)) {

                Write-Failure `
                    "Temporary CloudFront configuration file was not created."

                continue
            }


            # ====================================================
            # UPDATE DISTRIBUTION
            # ====================================================

            $updateArgs = @(
                "cloudfront"
                "update-distribution"
                "--id"
                $distributionId
                "--distribution-config"
                "file://$tempConfig"
                "--if-match"
                $etag
                "--region"
                $cloudFrontRegion
                "--no-cli-pager"
            )


            if (-not [string]::IsNullOrWhiteSpace($Profile)) {

                $updateArgs += @(
                    "--profile"
                    $Profile
                )
            }


            Write-Info `
                "Submitting CloudFront disable request..."


            $updateOutput = & aws @updateArgs 2>&1

            $updateExitCode = $LASTEXITCODE


            # ----------------------------------------------------
            # Delete temporary file.
            # ----------------------------------------------------

            if (Test-Path $tempConfig) {

                Remove-Item `
                    -Path $tempConfig `
                    -Force `
                    -ErrorAction SilentlyContinue
            }


            # ====================================================
            # CHECK UPDATE RESULT
            # ====================================================

            if ($updateExitCode -ne 0) {

                Write-Failure `
                    "Failed to disable CloudFront distribution $distributionId."


                Write-Host ""

                foreach ($line in $updateOutput) {

                    Write-Host $line -ForegroundColor Red
                }


                continue
            }


            Write-Success `
                "Disable request submitted for $distributionId."


            # ====================================================
            # WAIT FOR CLOUDFRONT DEPLOYMENT
            # ====================================================

            Write-Info `
                "Waiting for CloudFront deployment..."


            $waitArgs = @(
                "cloudfront"
                "wait"
                "distribution-deployed"
                "--id"
                $distributionId
                "--region"
                $cloudFrontRegion
                "--no-cli-pager"
            )


            if (-not [string]::IsNullOrWhiteSpace($Profile)) {

                $waitArgs += @(
                    "--profile"
                    $Profile
                )
            }


            $waitOutput = & aws @waitArgs 2>&1

            $waitExitCode = $LASTEXITCODE


            if ($waitOutput) {

                foreach ($line in $waitOutput) {

                    Write-Host $line
                }
            }


            if ($waitExitCode -ne 0) {

                Write-Failure `
                    "CloudFront deployment wait failed for $distributionId."


                continue
            }


            Write-Success `
                "CloudFront distribution is deployed with Enabled=false."
        }
        else {

            Write-Info `
                "Distribution is already DISABLED."
        }


        # ========================================================
        # GET FRESH ETAG
        # ========================================================
        #
        # CloudFront changes the ETag after an update.
        #
        # Therefore we MUST retrieve the latest ETag before
        # attempting deletion.
        #
        # ========================================================

        Write-Info `
            "Retrieving fresh CloudFront ETag..."


        $freshConfigArgs = @(
            "cloudfront"
            "get-distribution-config"
            "--id"
            $distributionId
            "--region"
            $cloudFrontRegion
            "--no-cli-pager"
            "--output"
            "json"
        )


        if (-not [string]::IsNullOrWhiteSpace($Profile)) {

            $freshConfigArgs += @(
                "--profile"
                $Profile
            )
        }


        $freshConfigOutput = `
            & aws @freshConfigArgs 2>&1


        $freshConfigExitCode = $LASTEXITCODE


        if ($freshConfigExitCode -ne 0) {

            Write-Failure `
                "Unable to retrieve fresh CloudFront ETag for $distributionId."


            foreach ($line in $freshConfigOutput) {

                Write-Host $line -ForegroundColor Red
            }


            continue
        }


        # ========================================================
        # PARSE FRESH CONFIGURATION
        # ========================================================

        try {

            $freshConfigData = (
                $freshConfigOutput -join "`n"
            ) | ConvertFrom-Json
        }
        catch {

            Write-Failure `
                "Unable to parse fresh CloudFront configuration."

            Write-Host $_.Exception.Message `
                -ForegroundColor Red

            continue
        }


        $freshEtag = $freshConfigData.ETag


        if ([string]::IsNullOrWhiteSpace($freshEtag)) {

            Write-Failure `
                "Fresh CloudFront ETag is empty for $distributionId."

            continue
        }


        # ========================================================
        # DELETE DISTRIBUTION
        # ========================================================

        Write-Info `
            "Deleting CloudFront distribution $distributionId..."


        $deleteArgs = @(
            "cloudfront"
            "delete-distribution"
            "--id"
            $distributionId
            "--if-match"
            $freshEtag
            "--region"
            $cloudFrontRegion
            "--no-cli-pager"
        )


        if (-not [string]::IsNullOrWhiteSpace($Profile)) {

            $deleteArgs += @(
                "--profile"
                $Profile
            )
        }


        $deleteOutput = & aws @deleteArgs 2>&1

        $deleteExitCode = $LASTEXITCODE


        if ($deleteExitCode -eq 0) {

            Write-Success `
                "CloudFront distribution deleted: $distributionId"
        }
        else {

            Write-Failure `
                "CloudFront distribution deletion failed: $distributionId"


            foreach ($line in $deleteOutput) {

                Write-Host $line -ForegroundColor Red
            }
        }
    }


    Write-Host ""

    Write-Success `
        "CloudFront cleanup processing completed."
}


# ================================================================
# 03 - S3 CLEANUP
# ================================================================

function Remove-S3 {

    Write-Section "03 - S3 CLEANUP"


    $buckets = Invoke-AwsJson -Arguments @(
        "s3api"
        "list-buckets"
    )


    if ($null -eq $buckets) {

        Write-Info "No S3 buckets found."

        return
    }


    foreach ($bucket in $buckets.Buckets) {

        $bucketName = $bucket.Name


        Write-Info `
            "S3 bucket discovered: $bucketName"


        # --------------------------------------------------------
        # PREVIEW MODE
        # --------------------------------------------------------

        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would empty and delete bucket $bucketName"

            continue
        }


        # ========================================================
        # DELETE NORMAL OBJECTS
        # ========================================================

        Write-Info `
            "Deleting normal objects from $bucketName"


        Invoke-AwsCli -Arguments @(
            "s3"
            "rm"
            "s3://$bucketName"
            "--recursive"
        ) | Out-Null


        # ========================================================
        # DELETE VERSIONED OBJECTS / DELETE MARKERS
        # ========================================================

        Write-Info `
            "Deleting object versions and delete markers..."


        while ($true) {

            $versions = Invoke-AwsJson -Arguments @(
                "s3api"
                "list-object-versions"
                "--bucket"
                $bucketName
            )


            if ($null -eq $versions) {

                break
            }


            $objects = @()


            # ----------------------------------------------------
            # Add object versions.
            # ----------------------------------------------------

            if ($versions.Versions) {

                foreach ($version in $versions.Versions) {

                    $objects += [PSCustomObject]@{
                        Key       = $version.Key
                        VersionId = $version.VersionId
                    }
                }
            }


            # ----------------------------------------------------
            # Add delete markers.
            # ----------------------------------------------------

            if ($versions.DeleteMarkers) {

                foreach ($marker in $versions.DeleteMarkers) {

                    $objects += [PSCustomObject]@{
                        Key       = $marker.Key
                        VersionId = $marker.VersionId
                    }
                }
            }


            if ($objects.Count -eq 0) {

                break
            }


            # ----------------------------------------------------
            # S3 allows maximum 1000 objects per delete request.
            # ----------------------------------------------------

            for (
                $i = 0;
                $i -lt $objects.Count;
                $i += 1000
            ) {

                $end = [Math]::Min(
                    $i + 999,
                    $objects.Count - 1
                )


                $batch = @(
                    $objects[$i..$end]
                )


                $deletePayload = @{
                    Objects = $batch
                    Quiet   = $true
                }


                $tempFile = Join-Path `
                    $env:TEMP `
                    "s3-delete-$([guid]::NewGuid()).json"


                # ------------------------------------------------
                # Write JSON WITHOUT BOM.
                # ------------------------------------------------

                $deleteJson = `
                    $deletePayload |
                    ConvertTo-Json -Depth 20


                Write-Utf8NoBomFile `
                    -Path $tempFile `
                    -Content $deleteJson


                Invoke-AwsCli -Arguments @(
                    "s3api"
                    "delete-objects"
                    "--bucket"
                    $bucketName
                    "--delete"
                    "file://$tempFile"
                ) | Out-Null


                if (Test-Path $tempFile) {

                    Remove-Item `
                        -Path $tempFile `
                        -Force `
                        -ErrorAction SilentlyContinue
                }
            }
        }


        # ========================================================
        # DELETE EMPTY BUCKET
        # ========================================================

        Write-Info `
            "Deleting S3 bucket: $bucketName"


        Invoke-AwsCli -Arguments @(
            "s3api"
            "delete-bucket"
            "--bucket"
            $bucketName
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "S3 bucket deleted: $bucketName"
        }
        else {

            Write-Failure `
                "S3 bucket deletion failed: $bucketName"
        }
    }
}


# ================================================================
# 04 - ECS CLEANUP
# ================================================================

function Remove-Ecs {

    Write-Section "04 - ECS CLEANUP"


    $clustersData = Invoke-AwsJson -Arguments @(
        "ecs"
        "list-clusters"
    )


    if ($null -eq $clustersData) {

        Write-Info "No ECS clusters found."

        return
    }


    foreach ($clusterArn in $clustersData.clusterArns) {

        $clusterName = (
            $clusterArn -split "/"
        )[-1]


        Write-Info `
            "ECS cluster: $clusterName"


        # ========================================================
        # LIST SERVICES
        # ========================================================

        $servicesData = Invoke-AwsJson -Arguments @(
            "ecs"
            "list-services"
            "--cluster"
            $clusterArn
        )


        if ($null -ne $servicesData) {

            foreach ($serviceArn in $servicesData.serviceArns) {

                $serviceName = (
                    $serviceArn -split "/"
                )[-1]


                Write-Info `
                    "ECS service: $serviceName"


                if (-not $Execute) {

                    Write-WarningMessage `
                        "PREVIEW: Would delete ECS service $serviceName"

                    continue
                }


                # ------------------------------------------------
                # Scale service to zero.
                # ------------------------------------------------

                Invoke-AwsCli -Arguments @(
                    "ecs"
                    "update-service"
                    "--cluster"
                    $clusterArn
                    "--service"
                    $serviceArn
                    "--desired-count"
                    "0"
                ) | Out-Null


                # ------------------------------------------------
                # Force delete service.
                # ------------------------------------------------

                Invoke-AwsCli -Arguments @(
                    "ecs"
                    "delete-service"
                    "--cluster"
                    $clusterArn
                    "--service"
                    $serviceArn
                    "--force"
                ) | Out-Null


                if ($LASTEXITCODE -eq 0) {

                    Write-Success `
                        "ECS service deleted: $serviceName"
                }
                else {

                    Write-Failure `
                        "ECS service deletion failed: $serviceName"
                }
            }
        }


        # ========================================================
        # STOP RUNNING TASKS
        # ========================================================

        if ($Execute) {

            $tasksData = Invoke-AwsJson -Arguments @(
                "ecs"
                "list-tasks"
                "--cluster"
                $clusterArn
                "--desired-status"
                "RUNNING"
            )


            if ($null -ne $tasksData) {

                foreach ($taskArn in $tasksData.taskArns) {

                    Write-Info `
                        "Stopping ECS task: $taskArn"


                    Invoke-AwsCli -Arguments @(
                        "ecs"
                        "stop-task"
                        "--cluster"
                        $clusterArn
                        "--task"
                        $taskArn
                    ) | Out-Null
                }
            }


            # ====================================================
            # DELETE ECS CLUSTER
            # ====================================================

            Write-Info `
                "Deleting ECS cluster: $clusterName"


            Invoke-AwsCli -Arguments @(
                "ecs"
                "delete-cluster"
                "--cluster"
                $clusterArn
            ) | Out-Null


            if ($LASTEXITCODE -eq 0) {

                Write-Success `
                    "ECS cluster deleted: $clusterName"
            }
            else {

                Write-Failure `
                    "ECS cluster deletion failed: $clusterName"
            }
        }
    }
}


# ================================================================
# 05 - ECR CLEANUP
# ================================================================

function Remove-Ecr {

    Write-Section "05 - ECR CLEANUP"


    $repos = Invoke-AwsJson -Arguments @(
        "ecr"
        "describe-repositories"
    )


    if ($null -eq $repos) {

        Write-Info "No ECR repositories found."

        return
    }


    foreach ($repo in $repos.repositories) {

        $repoName = $repo.repositoryName


        Write-Info `
            "ECR repository: $repoName"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would force-delete ECR repository $repoName"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ecr"
            "delete-repository"
            "--repository-name"
            $repoName
            "--force"
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "ECR repository deleted: $repoName"
        }
        else {

            Write-Failure `
                "ECR repository deletion failed: $repoName"
        }
    }
}


# ================================================================
# 06 - RDS CLEANUP
# ================================================================

function Remove-Rds {

    Write-Section "06 - RDS CLEANUP"


    # ============================================================
    # RDS DB INSTANCES
    # ============================================================

    $instances = Invoke-AwsJson -Arguments @(
        "rds"
        "describe-db-instances"
    )


    if ($null -ne $instances) {

        foreach ($db in $instances.DBInstances) {

            $identifier = `
                $db.DBInstanceIdentifier


            Write-Info `
                "RDS DB instance: $identifier"


            if (-not $Execute) {

                Write-WarningMessage `
                    "PREVIEW: Would delete RDS instance $identifier"

                continue
            }


            # ----------------------------------------------------
            # Delete without final snapshot.
            #
            # IMPORTANT:
            #
            # This is destructive.
            # ----------------------------------------------------

            Invoke-AwsCli -Arguments @(
                "rds"
                "delete-db-instance"
                "--db-instance-identifier"
                $identifier
                "--skip-final-snapshot"
                "--delete-automated-backups"
            ) | Out-Null


            if ($LASTEXITCODE -eq 0) {

                Write-Success `
                    "RDS deletion requested: $identifier"
            }
            else {

                Write-Failure `
                    "RDS deletion failed: $identifier"
            }
        }
    }


    # ============================================================
    # RDS DB CLUSTERS / AURORA
    # ============================================================

    $clusters = Invoke-AwsJson -Arguments @(
        "rds"
        "describe-db-clusters"
    )


    if ($null -ne $clusters) {

        foreach ($cluster in $clusters.DBClusters) {

            $identifier = `
                $cluster.DBClusterIdentifier


            Write-Info `
                "RDS cluster: $identifier"


            if (-not $Execute) {

                Write-WarningMessage `
                    "PREVIEW: Would delete RDS cluster $identifier"

                continue
            }


            Invoke-AwsCli -Arguments @(
                "rds"
                "delete-db-cluster"
                "--db-cluster-identifier"
                $identifier
                "--skip-final-snapshot"
            ) | Out-Null


            if ($LASTEXITCODE -eq 0) {

                Write-Success `
                    "RDS cluster deletion requested: $identifier"
            }
            else {

                Write-Failure `
                    "RDS cluster deletion failed: $identifier"
            }
        }
    }
}


# ================================================================
# 07 - SECRETS MANAGER CLEANUP
# ================================================================

function Remove-Secrets {

    Write-Section "07 - SECRETS MANAGER CLEANUP"


    $secrets = Invoke-AwsJson -Arguments @(
        "secretsmanager"
        "list-secrets"
    )


    if ($null -eq $secrets) {

        Write-Info `
            "No Secrets Manager secrets found."

        return
    }


    foreach ($secret in $secrets.SecretList) {

        $arn = $secret.ARN

        $name = $secret.Name


        Write-Info `
            "Secret: $name"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete secret $name"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "secretsmanager"
            "delete-secret"
            "--secret-id"
            $arn
            "--force-delete-without-recovery"
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "Secret deleted: $name"
        }
        else {

            Write-Failure `
                "Secret deletion failed: $name"
        }
    }
}


# ================================================================
# 08 - VPC ENDPOINT CLEANUP
# ================================================================

function Remove-VpcEndpoints {

    Write-Section "08 - VPC ENDPOINT CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-vpc-endpoints"
    )


    if ($null -eq $data) {

        Write-Info `
            "No VPC endpoints found."

        return
    }


    foreach ($endpoint in $data.VpcEndpoints) {

        $id = $endpoint.VpcEndpointId


        Write-Info `
            "VPC endpoint: $id"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete VPC endpoint $id"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-vpc-endpoints"
            "--vpc-endpoint-ids"
            $id
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "VPC endpoint deletion requested: $id"
        }
        else {

            Write-Failure `
                "VPC endpoint deletion failed: $id"
        }
    }
}


# ================================================================
# 09 - NAT GATEWAY CLEANUP
# ================================================================

function Remove-NatGateways {

    Write-Section "09 - NAT GATEWAY CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-nat-gateways"
        "--filter"
        "Name=state,Values=available,pending,failed"
    )


    if ($null -eq $data) {

        Write-Info `
            "No NAT gateways found."

        return
    }


    foreach ($nat in $data.NatGateways) {

        $natId = $nat.NatGatewayId


        Write-Info `
            "NAT gateway: $natId"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete NAT gateway $natId"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-nat-gateway"
            "--nat-gateway-id"
            $natId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "NAT gateway deletion requested: $natId"
        }
        else {

            Write-Failure `
                "NAT gateway deletion failed: $natId"
        }
    }


    # ============================================================
    # WAIT FOR NAT GATEWAYS
    # ============================================================

    if ($Execute) {

        Write-Info `
            "Waiting for NAT gateways to finish deleting..."


        for (
            $attempt = 1;
            $attempt -le 40;
            $attempt++
        ) {

            $remaining = Invoke-AwsJson -Arguments @(
                "ec2"
                "describe-nat-gateways"
                "--filter"
                "Name=state,Values=pending,available,deleting"
            )


            if (
                $null -eq $remaining -or
                $null -eq $remaining.NatGateways -or
                $remaining.NatGateways.Count -eq 0
            ) {

                Write-Success `
                    "NAT gateways are gone."

                break
            }


            Write-Info `
                "NAT gateways still deleting. Waiting..."


            Wait-Seconds `
                -Seconds $NatWaitSeconds
        }
    }
}


# ================================================================
# 10 - ELASTIC IP CLEANUP
# ================================================================
#
# Release only UNASSOCIATED Elastic IP addresses.
#
# Associated EIPs are skipped.
#
# NAT gateway EIPs normally become available after NAT gateway
# deletion completes.
#
# ================================================================

function Remove-UnassociatedElasticIps {

    Write-Section "10 - ELASTIC IP CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-addresses"
    )


    if ($null -eq $data) {

        Write-Info `
            "No Elastic IPs found."

        return
    }


    foreach ($address in $data.Addresses) {

        $allocationId = $address.AllocationId

        $publicIp = $address.PublicIp

        $associationId = $address.AssociationId


        # --------------------------------------------------------
        # Skip associated addresses.
        # --------------------------------------------------------

        if ($associationId) {

            Write-Info `
                "EIP still associated: $publicIp"

            continue
        }


        Write-Info `
            "Unassociated EIP: $publicIp"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would release EIP $publicIp"

            continue
        }


        if ($allocationId) {

            Invoke-AwsCli -Arguments @(
                "ec2"
                "release-address"
                "--allocation-id"
                $allocationId
            ) | Out-Null


            if ($LASTEXITCODE -eq 0) {

                Write-Success `
                    "EIP released: $publicIp"
            }
            else {

                Write-Failure `
                    "EIP release failed: $publicIp"
            }
        }
    }
}


# ================================================================
# 11 - INTERNET GATEWAY CLEANUP
# ================================================================

function Remove-InternetGateways {

    Write-Section "11 - INTERNET GATEWAY CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-internet-gateways"
    )


    if ($null -eq $data) {

        Write-Info `
            "No Internet Gateways found."

        return
    }


    foreach ($igw in $data.InternetGateways) {

        $igwId = $igw.InternetGatewayId


        Write-Info `
            "Internet Gateway: $igwId"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would detach/delete IGW $igwId"

            continue
        }


        # ========================================================
        # DETACH FROM ALL VPCS
        # ========================================================

        foreach ($attachment in $igw.Attachments) {

            if ($attachment.VpcId) {

                Write-Info `
                    "Detaching $igwId from VPC $($attachment.VpcId)"


                Invoke-AwsCli -Arguments @(
                    "ec2"
                    "detach-internet-gateway"
                    "--internet-gateway-id"
                    $igwId
                    "--vpc-id"
                    $attachment.VpcId
                ) | Out-Null
            }
        }


        # ========================================================
        # DELETE IGW
        # ========================================================

        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-internet-gateway"
            "--internet-gateway-id"
            $igwId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "Internet Gateway deleted: $igwId"
        }
        else {

            Write-Failure `
                "Internet Gateway deletion failed: $igwId"
        }
    }
}


# ================================================================
# 12 - ROUTE TABLE CLEANUP
# ================================================================

function Remove-RouteTables {

    Write-Section "12 - ROUTE TABLE CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-route-tables"
    )


    if ($null -eq $data) {

        Write-Info `
            "No route tables found."

        return
    }


    foreach ($rt in $data.RouteTables) {

        $routeTableId = $rt.RouteTableId


        # --------------------------------------------------------
        # Main route tables cannot be deleted manually.
        # They are removed with their VPC.
        # --------------------------------------------------------

        $isMain = $false


        foreach ($association in $rt.Associations) {

            if ($association.Main -eq $true) {

                $isMain = $true

                break
            }
        }


        if ($isMain) {

            Write-Info `
                "Skipping main route table: $routeTableId"

            continue
        }


        Write-Info `
            "Route table: $routeTableId"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete route table $routeTableId"

            continue
        }


        # ========================================================
        # DISASSOCIATE ROUTE TABLE
        # ========================================================

        foreach ($association in $rt.Associations) {

            if ($association.RouteTableAssociationId) {

                Invoke-AwsCli -Arguments @(
                    "ec2"
                    "disassociate-route-table"
                    "--association-id"
                    $association.RouteTableAssociationId
                ) | Out-Null
            }
        }


        # ========================================================
        # DELETE ROUTE TABLE
        # ========================================================

        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-route-table"
            "--route-table-id"
            $routeTableId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "Route table deleted: $routeTableId"
        }
        else {

            Write-WarningMessage `
                "Route table could not be deleted: $routeTableId"
        }
    }
}


# ================================================================
# 13 - NETWORK INTERFACE CLEANUP
# ================================================================
#
# Only AVAILABLE ENIs can normally be manually deleted.
#
# ENIs in use by AWS services are skipped.
#
# Examples of service-owned ENIs:
#
#   Lambda
#   ECS
#   VPC endpoints
#   Load balancers
#   RDS
#   EFS
#
# The owning service must be deleted first.
#
# ================================================================

function Remove-NetworkInterfaces {

    Write-Section "13 - NETWORK INTERFACE CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-network-interfaces"
    )


    if ($null -eq $data) {

        Write-Info `
            "No network interfaces found."

        return
    }


    foreach ($eni in $data.NetworkInterfaces) {

        $eniId = $eni.NetworkInterfaceId

        $status = $eni.Status

        $description = $eni.Description


        Write-Info `
            "ENI: $eniId"

        Write-Info `
            "Status: $status"

        Write-Info `
            "Description: $description"


        # --------------------------------------------------------
        # Only available ENIs can normally be deleted manually.
        # --------------------------------------------------------

        if ($status -ne "available") {

            Write-WarningMessage `
                "Skipping ENI because it is in use: $eniId"

            continue
        }


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete available ENI $eniId"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-network-interface"
            "--network-interface-id"
            $eniId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "ENI deleted: $eniId"
        }
        else {

            Write-WarningMessage `
                "Could not delete ENI: $eniId"
        }
    }
}


# ================================================================
# 14 - SUBNET CLEANUP
# ================================================================

function Remove-Subnets {

    Write-Section "14 - SUBNET CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-subnets"
    )


    if ($null -eq $data) {

        Write-Info `
            "No subnets found."

        return
    }


    foreach ($subnet in $data.Subnets) {

        $subnetId = $subnet.SubnetId


        Write-Info `
            "Subnet: $subnetId"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete subnet $subnetId"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-subnet"
            "--subnet-id"
            $subnetId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "Subnet deleted: $subnetId"
        }
        else {

            Write-WarningMessage `
                "Subnet could not be deleted: $subnetId"
        }
    }
}


# ================================================================
# 15 - SECURITY GROUP CLEANUP
# ================================================================

function Remove-SecurityGroups {

    Write-Section "15 - SECURITY GROUP CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-security-groups"
    )


    if ($null -eq $data) {

        Write-Info `
            "No security groups found."

        return
    }


    foreach ($sg in $data.SecurityGroups) {

        $groupId = $sg.GroupId

        $groupName = $sg.GroupName

        $vpcId = $sg.VpcId


        # --------------------------------------------------------
        # Default security groups cannot be deleted manually.
        # --------------------------------------------------------

        if ($groupName -eq "default") {

            Write-Info `
                "Skipping default security group: $groupId"

            continue
        }


        Write-Info `
            "Security Group: $groupName ($groupId)"


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete security group $groupId"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-security-group"
            "--group-id"
            $groupId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "Security group deleted: $groupId"
        }
        else {

            Write-WarningMessage `
                "Security group could not be deleted: $groupId"
        }
    }
}


# ================================================================
# 16 - VPC CLEANUP
# ================================================================

function Remove-Vpcs {

    Write-Section "16 - VPC CLEANUP"


    $data = Invoke-AwsJson -Arguments @(
        "ec2"
        "describe-vpcs"
    )


    if ($null -eq $data) {

        Write-Info `
            "No VPCs found."

        return
    }


    foreach ($vpc in $data.Vpcs) {

        $vpcId = $vpc.VpcId

        $isDefault = $vpc.IsDefault


        Write-Info `
            "VPC: $vpcId"


        # --------------------------------------------------------
        # Protect default VPC by default.
        # --------------------------------------------------------

        if ($isDefault -and -not $DeleteDefaultVpc) {

            Write-WarningMessage `
                "Skipping DEFAULT VPC: $vpcId"

            Write-WarningMessage `
                "Use -DeleteDefaultVpc if you intentionally want to delete it."

            continue
        }


        if (-not $Execute) {

            Write-WarningMessage `
                "PREVIEW: Would delete VPC $vpcId"

            continue
        }


        Invoke-AwsCli -Arguments @(
            "ec2"
            "delete-vpc"
            "--vpc-id"
            $vpcId
        ) | Out-Null


        if ($LASTEXITCODE -eq 0) {

            Write-Success `
                "VPC deleted: $vpcId"
        }
        else {

            Write-Failure `
                "VPC deletion failed: $vpcId"

            Write-WarningMessage `
                "There may still be a dependency attached to this VPC."
        }
    }
}


# ================================================================
# MAIN EXECUTION
# ================================================================

Write-Host ""

Write-Host `
    "################################################################" `
    -ForegroundColor Red

Write-Host `
    "#              AWS COMPLETE CLEANUP SCRIPT                    #" `
    -ForegroundColor Red

Write-Host `
    "################################################################" `
    -ForegroundColor Red

Write-Host ""


Write-Info `
    "AWS Region: $Region"


if ($Execute) {

    Write-WarningMessage `
        "MODE: DESTRUCTIVE EXECUTION"
}
else {

    Write-WarningMessage `
        "MODE: PREVIEW ONLY"
}


Write-Host ""


# ================================================================
# CONFIRM EXECUTION MODE
# ================================================================

Confirm-Execution


# ================================================================
# VALIDATE AWS CLI / CREDENTIALS
# ================================================================

Test-AwsCli


# ================================================================
# RESOURCE DELETION ORDER
# ================================================================
#
# CloudFront
#       ↓
# S3
#       ↓
# ECS
#       ↓
# ECR
#       ↓
# RDS
#       ↓
# Secrets Manager
#       ↓
# VPC endpoints
#       ↓
# NAT gateways
#       ↓
# Elastic IPs
#       ↓
# Internet gateways
#       ↓
# Network interfaces
#       ↓
# Route tables
#       ↓
# Subnets
#       ↓
# Security groups
#       ↓
# VPCs
#
# ================================================================


Remove-CloudFront

Remove-S3

Remove-Ecs

Remove-Ecr

Remove-Rds

Remove-Secrets

Remove-VpcEndpoints

Remove-NatGateways

Remove-UnassociatedElasticIps

Remove-InternetGateways

Remove-NetworkInterfaces

Remove-RouteTables

Remove-Subnets

Remove-SecurityGroups

Remove-Vpcs


# ================================================================
# FINAL MESSAGE
# ================================================================

Write-Section "17 - CLEANUP COMPLETE"


if ($Execute) {

    Write-Success `
        "Cleanup process finished."


    Write-Host ""

    Write-Info `
        "Some AWS resources may still be deleting asynchronously."

    Write-Info `
        "Run the script again if dependencies remain."

    Write-Info `
        "This is especially common with RDS, NAT gateways and CloudFront."
}
else {

    Write-WarningMessage `
        "Preview finished."

    Write-WarningMessage `
        "Nothing was deleted."

    Write-Host ""

    Write-Info `
        "To actually delete resources run:"

    Write-Host ""

    Write-Host `
        ".\aws-full-cleanup.ps1 -Region $Region -Execute" `
        -ForegroundColor Yellow
}


Write-Host ""