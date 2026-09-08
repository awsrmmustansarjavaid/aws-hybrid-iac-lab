#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 CLOUDFORMATION LIVE MONITOR
====================================================================

 File:
   scripts/Monitor-CloudFormation.ps1

 Purpose:
   Continuously monitor an AWS CloudFormation root stack and its
   nested stacks while Terraform is deploying infrastructure.

 Designed for:
   - Local PowerShell
   - GitHub Actions Windows runners
   - GitHub Actions PowerShell Core
   - Terraform + CloudFormation hybrid deployments

 IMPORTANT
 -------------------------------------------------------------------
 This script is READ-ONLY.

 It does NOT:
   - create AWS resources
   - update AWS resources
   - delete AWS resources
   - execute Terraform
   - modify CloudFormation

 It only calls CloudFormation READ operations such as:

   Get-CFNStack
   Get-CFNStackResource
   Get-CFNStackEvent

 Terraform remains the authoritative deployment process.

====================================================================
 REQUIREMENTS
====================================================================

 1. PowerShell 7+
 2. AWS CLI
 3. Valid AWS credentials
 4. AWS region
 5. CloudFormation stack name

 Example:

   pwsh ./scripts/Monitor-CloudFormation.ps1 `
      -StackName "hybridiaclab-dev-MainStack" `
      -Region "us-east-1"

====================================================================
#>

[CmdletBinding()]
param(

    # ---------------------------------------------------------------
    # CloudFormation root stack name.
    # ---------------------------------------------------------------
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    # ---------------------------------------------------------------
    # AWS region.
    # ---------------------------------------------------------------
    [Parameter(Mandatory = $true)]
    [string]$Region,

    # ---------------------------------------------------------------
    # Polling interval.
    #
    # Default:
    #   3 seconds
    # ---------------------------------------------------------------
    [int]$PollingIntervalSeconds = 3,

    # ---------------------------------------------------------------
    # Directory where diagnostic files will be stored.
    # ---------------------------------------------------------------
    [string]$LogDirectory = "./cloudformation-live-diagnostics",

    # ---------------------------------------------------------------
    # Optional maximum monitoring time.
    #
    # 0 = unlimited
    #
    # This protects GitHub Actions from an accidentally infinite
    # monitor.
    # ---------------------------------------------------------------
    [int]$MaximumRuntimeMinutes = 0,

    # ---------------------------------------------------------------
    # Keep monitoring after CREATE_COMPLETE / UPDATE_COMPLETE?
    #
    # Default:
    #   false
    #
    # For Terraform deployment diagnostics, false is recommended.
    # ---------------------------------------------------------------
    [switch]$ContinueAfterSuccess
)

# ====================================================================
# GLOBAL SETTINGS
# ====================================================================

$ErrorActionPreference = "Continue"

# Convert relative log directory to an absolute path.
$LogDirectory = [System.IO.Path]::GetFullPath($LogDirectory)

# Create diagnostic directory if it does not exist.
if (-not (Test-Path -LiteralPath $LogDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $LogDirectory `
        -Force `
        | Out-Null
}

# ====================================================================
# FILE PATHS
# ====================================================================

$MonitorLog = Join-Path `
    $LogDirectory `
    "cloudformation-live-monitor.log"

$MainStackSnapshot = Join-Path `
    $LogDirectory `
    "main-stack.json"

$MainResourcesSnapshot = Join-Path `
    $LogDirectory `
    "main-resources.json"

$MainEventsSnapshot = Join-Path `
    $LogDirectory `
    "main-events.json"

$FailureLog = Join-Path `
    $LogDirectory `
    "cloudformation-failures.log"

# ====================================================================
# HELPER FUNCTION
# ====================================================================

function Write-MonitorLog {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [switch]$NoConsole
    )

    $Timestamp = (
        Get-Date
    ).ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ssZ"
    )

    $Line = "[${Timestamp}] $Message"

    if (-not $NoConsole) {
        Write-Host $Line
    }

    Add-Content `
        -LiteralPath $MonitorLog `
        -Value $Line `
        -Encoding UTF8
}

# ====================================================================
# SECTION HEADER
# ====================================================================

function Write-Section {

    param(
        [string]$Title
    )

    Write-MonitorLog ""
    Write-MonitorLog "============================================================"
    Write-MonitorLog $Title
    Write-MonitorLog "============================================================"
}

# ====================================================================
# CHECK REQUIRED COMMANDS
# ====================================================================

Write-Section "CLOUDFORMATION LIVE MONITOR STARTING"

Write-MonitorLog "Stack:"
Write-MonitorLog $StackName

Write-MonitorLog "Region:"
Write-MonitorLog $Region

Write-MonitorLog "Polling interval:"
Write-MonitorLog "$PollingIntervalSeconds seconds"

Write-MonitorLog "Diagnostic directory:"
Write-MonitorLog $LogDirectory

# ---------------------------------------------------------------
# Verify AWS CLI.
# ---------------------------------------------------------------

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {

    Write-MonitorLog ""
    Write-MonitorLog "ERROR: AWS CLI was not found."
    Write-MonitorLog "Install AWS CLI before running this monitor."

    exit 2
}

# ---------------------------------------------------------------
# Verify AWS credentials / identity.
#
# This is read-only.
# ---------------------------------------------------------------

Write-MonitorLog ""
Write-MonitorLog "Checking AWS identity..."

$IdentityJson = & aws sts get-caller-identity `
    --region $Region `
    --output json `
    2>&1

if ($LASTEXITCODE -ne 0) {

    Write-MonitorLog ""
    Write-MonitorLog "ERROR: AWS credentials are not available."
    Write-MonitorLog "AWS CLI response:"
    Write-MonitorLog ($IdentityJson -join "`n")

    exit 2
}

try {

    $Identity = $IdentityJson -join "`n" | ConvertFrom-Json

    Write-MonitorLog "AWS Account:"
    Write-MonitorLog $Identity.Account

    Write-MonitorLog "AWS Principal:"
    Write-MonitorLog $Identity.Arn

}
catch {

    Write-MonitorLog "WARNING: Could not parse AWS identity response."
}

# ====================================================================
# STATE
# ====================================================================

$StackDiscovered = $false

$LastMainStatus = ""

$StartTime = Get-Date

# ---------------------------------------------------------------
# Hashtable containing CloudFormation EventIds already processed.
#
# This prevents the same event from being printed repeatedly.
# ---------------------------------------------------------------

$SeenEvents = @{}

# ---------------------------------------------------------------
# Hashtable containing nested stacks already discovered.
# ---------------------------------------------------------------

$NestedStacks = @{}

# ====================================================================
# FAILURE CLASSIFICATION
# ====================================================================

function Get-FailureClassification {

    param(
        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($Reason)) {

        return "UNKNOWN CLOUDFORMATION FAILURE"
    }

    if (
        $Reason -match
        "NoSuchKey|does not exist.*yaml|S3 object|does not exist.*template"
    ) {

        return "MISSING S3 CLOUDFORMATION TEMPLATE"
    }

    if (
        $Reason -match
        "AccessDenied|not authorized|Unauthorized"
    ) {

        return "IAM / ACCESS DENIED"
    }

    if (
        $Reason -match
        "PassRole|iam:PassRole"
    ) {

        return "IAM PassRole PERMISSION FAILURE"
    }

    if (
        $Reason -match
        "TemplateURL|invalid.*template|template.*invalid"
    ) {

        return "CLOUDFORMATION TEMPLATE ERROR"
    }

    if (
        $Reason -match
        "API Gateway|apigateway"
    ) {

        return "API GATEWAY FAILURE"
    }

    if (
        $Reason -match
        "Lambda|lambda"
    ) {

        return "LAMBDA FAILURE"
    }

    if (
        $Reason -match
        "ECS|ecs"
    ) {

        return "ECS FAILURE"
    }

    if (
        $Reason -match
        "IAM|iam"
    ) {

        return "IAM FAILURE"
    }

    if (
        $Reason -match
        "S3|s3"
    ) {

        return "S3 FAILURE"
    }

    if (
        $Reason -match
        "DynamoDB|dynamodb"
    ) {

        return "DYNAMODB FAILURE"
    }

    if (
        $Reason -match
        "RDS|rds"
    ) {

        return "RDS DATABASE FAILURE"
    }

    if (
        $Reason -match
        "VPC|Subnet|SecurityGroup"
    ) {

        return "NETWORK / VPC FAILURE"
    }

    return "CLOUDFORMATION RESOURCE FAILURE"
}

# ====================================================================
# PROCESS CLOUDFORMATION EVENT
# ====================================================================

function Process-CloudFormationEvent {

    param(
        [Parameter(Mandatory = $true)]
        $Event,

        [Parameter(Mandatory = $true)]
        [string]$StackContext
    )

    $EventId = $Event.EventId

    if ([string]::IsNullOrWhiteSpace($EventId)) {
        return
    }

    # ---------------------------------------------------------------
    # Ignore events that have already been printed.
    # ---------------------------------------------------------------

    if ($SeenEvents.ContainsKey($EventId)) {
        return
    }

    $SeenEvents[$EventId] = $true

    $Status = [string]$Event.ResourceStatus

    # ---------------------------------------------------------------
    # Only display important failure-related events.
    # ---------------------------------------------------------------

    if (
        $Status -notmatch
        "FAILED|ROLLBACK|DELETE_FAILED|CANCELLED"
    ) {

        return
    }

    $EventTime = [string]$Event.Timestamp

    $LogicalId = [string]$Event.LogicalResourceId

    $ResourceType = [string]$Event.ResourceType

    $PhysicalId = [string]$Event.PhysicalResourceId

    $Reason = [string]$Event.ResourceStatusReason

    if ([string]::IsNullOrWhiteSpace($PhysicalId)) {
        $PhysicalId = "N/A"
    }

    if ([string]::IsNullOrWhiteSpace($Reason)) {
        $Reason = "No CloudFormation status reason provided."
    }

    $Classification = Get-FailureClassification `
        -Reason $Reason

    # =================================================================
    # DISPLAY FAILURE
    # =================================================================

    Write-MonitorLog ""

    Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    Write-MonitorLog "LIVE CLOUDFORMATION FAILURE DETECTED"

    Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    Write-MonitorLog ""

    Write-MonitorLog "Stack Context:"
    Write-MonitorLog $StackContext

    Write-MonitorLog ""

    Write-MonitorLog "Event Time:"
    Write-MonitorLog $EventTime

    Write-MonitorLog ""

    Write-MonitorLog "Logical Resource:"
    Write-MonitorLog $LogicalId

    Write-MonitorLog ""

    Write-MonitorLog "Resource Type:"
    Write-MonitorLog $ResourceType

    Write-MonitorLog ""

    Write-MonitorLog "Status:"
    Write-MonitorLog $Status

    Write-MonitorLog ""

    Write-MonitorLog "Physical Resource:"
    Write-MonitorLog $PhysicalId

    Write-MonitorLog ""

    Write-MonitorLog "EXACT CLOUDFORMATION REASON:"
    Write-MonitorLog "------------------------------------------------------------"
    Write-MonitorLog $Reason
    Write-MonitorLog "------------------------------------------------------------"

    Write-MonitorLog ""

    Write-MonitorLog "ROOT CAUSE CLASSIFICATION:"
    Write-MonitorLog $Classification

    Write-MonitorLog ""
    Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    # =================================================================
    # PERSIST FAILURE
    # =================================================================

    $FailureRecord = [ordered]@{

        DetectedAt        = (
            (Get-Date).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ssZ"
            )
        )

        StackContext      = $StackContext
        EventTime         = $EventTime
        EventId           = $EventId
        LogicalResourceId = $LogicalId
        ResourceType      = $ResourceType
        ResourceStatus    = $Status
        PhysicalResourceId = $PhysicalId
        Reason            = $Reason
        Classification    = $Classification
    }

    $FailureJson = $FailureRecord |
        ConvertTo-Json -Depth 10

    Add-Content `
        -LiteralPath $FailureLog `
        -Value $FailureJson `
        -Encoding UTF8
}

# ====================================================================
# GET STACK
# ====================================================================

function Get-MainStack {

    $Result = & aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --output json `
        2>&1

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {

        return $null
    }

    try {

        return (
            ($Result -join "`n") |
            ConvertFrom-Json
        )
    }
    catch {

        Write-MonitorLog `
            "WARNING: CloudFormation stack JSON could not be parsed."

        return $null
    }
}

# ====================================================================
# GET STACK RESOURCES
# ====================================================================

function Get-StackResources {

    param(
        [string]$TargetStack
    )

    $Result = & aws cloudformation describe-stack-resources `
        --stack-name $TargetStack `
        --region $Region `
        --output json `
        2>&1

    if ($LASTEXITCODE -ne 0) {

        return $null
    }

    try {

        return (
            ($Result -join "`n") |
            ConvertFrom-Json
        )
    }
    catch {

        return $null
    }
}

# ====================================================================
# GET STACK EVENTS
# ====================================================================

function Get-StackEvents {

    param(
        [string]$TargetStack
    )

    $Result = & aws cloudformation describe-stack-events `
        --stack-name $TargetStack `
        --region $Region `
        --output json `
        2>&1

    if ($LASTEXITCODE -ne 0) {

        return $null
    }

    try {

        return (
            ($Result -join "`n") |
            ConvertFrom-Json
        )
    }
    catch {

        return $null
    }
}

# ====================================================================
# MAIN MONITOR LOOP
# ====================================================================

while ($true) {

    # ================================================================
    # MAXIMUM RUNTIME CHECK
    # ================================================================

    if ($MaximumRuntimeMinutes -gt 0) {

        $Runtime = (
            New-TimeSpan `
                -Start $StartTime `
                -End (Get-Date)
        )

        if ($Runtime.TotalMinutes -ge $MaximumRuntimeMinutes) {

            Write-MonitorLog ""

            Write-MonitorLog `
                "Maximum monitor runtime reached."

            Write-MonitorLog `
                "Stopping CloudFormation monitor."

            break
        }
    }

    # ================================================================
    # DISCOVER MAIN STACK
    # ================================================================

    $MainJson = Get-MainStack

    if ($null -eq $MainJson) {

        # ------------------------------------------------------------
        # Stack does not exist yet.
        #
        # This is expected when Terraform has not yet created the
        # CloudFormation stack.
        # ------------------------------------------------------------

        if (-not $StackDiscovered) {

            Write-MonitorLog `
                "Waiting for CloudFormation stack '$StackName'..."

            Start-Sleep `
                -Seconds $PollingIntervalSeconds

            continue
        }

        # ------------------------------------------------------------
        # Stack was previously discovered but is now unavailable.
        #
        # This can happen during deletion or cleanup.
        # ------------------------------------------------------------

        Write-MonitorLog ""

        Write-MonitorLog `
            "MainStack is no longer queryable."

        Write-MonitorLog `
            "CloudFormation may have entered deletion/cleanup."

        break
    }

    # ================================================================
    # MAIN STACK DISCOVERED
    # ================================================================

    if (-not $StackDiscovered) {

        $StackDiscovered = $true

        Write-Section "MAIN CLOUDFORMATION STACK DETECTED"

        Write-MonitorLog "Stack:"
        Write-MonitorLog $StackName
    }

    # ================================================================
    # READ MAIN STACK INFORMATION
    # ================================================================

    $MainStack = $MainJson.Stacks[0]

    $MainStatus = [string]$MainStack.StackStatus

    $MainReason = [string]$MainStack.StackStatusReason

    $MainStackId = [string]$MainStack.StackId

    # ================================================================
    # STATUS CHANGE DETECTION
    # ================================================================

    if ($MainStatus -ne $LastMainStatus) {

        Write-MonitorLog ""

        Write-MonitorLog `
            "------------------------------------------------------------"

        Write-MonitorLog `
            "CLOUDFORMATION STATUS CHANGE"

        Write-MonitorLog `
            "------------------------------------------------------------"

        Write-MonitorLog "Stack:"
        Write-MonitorLog $StackName

        Write-MonitorLog "Stack ID:"
        Write-MonitorLog $MainStackId

        Write-MonitorLog "Status:"
        Write-MonitorLog $MainStatus

        if ([string]::IsNullOrWhiteSpace($MainReason)) {

            Write-MonitorLog "Reason:"
            Write-MonitorLog "No status reason."

        }
        else {

            Write-MonitorLog "Reason:"
            Write-MonitorLog $MainReason
        }

        Write-MonitorLog `
            "------------------------------------------------------------"

        $LastMainStatus = $MainStatus
    }

    # ================================================================
    # SAVE MAIN STACK SNAPSHOT
    # ================================================================

    $MainJson |
        ConvertTo-Json -Depth 30 |
        Set-Content `
            -LiteralPath $MainStackSnapshot `
            -Encoding UTF8

    # ================================================================
    # GET MAIN STACK RESOURCES
    # ================================================================

    $ResourcesJson = Get-StackResources `
        -TargetStack $StackName

    if ($null -ne $ResourcesJson) {

        $ResourcesJson |
            ConvertTo-Json -Depth 30 |
            Set-Content `
                -LiteralPath $MainResourcesSnapshot `
                -Encoding UTF8

        # ============================================================
        # DETECT FAILED RESOURCES
        # ============================================================

        foreach ($Resource in $ResourcesJson.StackResources) {

            $ResourceStatus = [string]$Resource.ResourceStatus

            if (
                $ResourceStatus -match
                "FAILED|ROLLBACK|DELETE_FAILED|CANCELLED"
            ) {

                # ----------------------------------------------------
                # Convert resource information into an event-like
                # object so it can use the same diagnostic processor.
                # ----------------------------------------------------

                $ResourceEvent = [PSCustomObject]@{

                    EventId =
                        "RESOURCE-$($Resource.LogicalResourceId)-$ResourceStatus"

                    Timestamp =
                        (
                            Get-Date
                        ).ToUniversalTime().ToString(
                            "yyyy-MM-ddTHH:mm:ssZ"
                        )

                    LogicalResourceId =
                        $Resource.LogicalResourceId

                    ResourceType =
                        $Resource.ResourceType

                    ResourceStatus =
                        $Resource.ResourceStatus

                    ResourceStatusReason =
                        $Resource.ResourceStatusReason

                    PhysicalResourceId =
                        $Resource.PhysicalResourceId
                }

                Process-CloudFormationEvent `
                    -Event $ResourceEvent `
                    -StackContext "MainStack Resource Snapshot"
            }

            # ========================================================
            # DISCOVER NESTED STACKS
            # ========================================================

            if (
                $Resource.ResourceType `
                -eq "AWS::CloudFormation::Stack"
            ) {

                $NestedLogicalId =
                    [string]$Resource.LogicalResourceId

                $NestedPhysicalId =
                    [string]$Resource.PhysicalResourceId

                $NestedStatus =
                    [string]$Resource.ResourceStatus

                $NestedReason =
                    [string]$Resource.ResourceStatusReason

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $NestedPhysicalId
                    )
                ) {

                    if (
                        -not $NestedStacks.ContainsKey(
                            $NestedPhysicalId
                        )
                    ) {

                        $NestedStacks[$NestedPhysicalId] = @{
                            LogicalId = $NestedLogicalId
                            Status    = $NestedStatus
                        }

                        Write-MonitorLog ""

                        Write-MonitorLog `
                            "------------------------------------------------------------"

                        Write-MonitorLog `
                            "NESTED CLOUDFORMATION STACK DISCOVERED"

                        Write-MonitorLog `
                            "------------------------------------------------------------"

                        Write-MonitorLog "Logical ID:"
                        Write-MonitorLog $NestedLogicalId

                        Write-MonitorLog "Physical Stack:"
                        Write-MonitorLog $NestedPhysicalId

                        Write-MonitorLog "Status:"
                        Write-MonitorLog $NestedStatus
                    }
                }
            }
        }
    }

    # ================================================================
    # MAIN STACK EVENTS
    # ================================================================

    $MainEventsJson = Get-StackEvents `
        -TargetStack $StackName

    if ($null -ne $MainEventsJson) {

        $MainEventsJson |
            ConvertTo-Json -Depth 30 |
            Set-Content `
                -LiteralPath $MainEventsSnapshot `
                -Encoding UTF8

        foreach ($Event in $MainEventsJson.StackEvents) {

            Process-CloudFormationEvent `
                -Event $Event `
                -StackContext "MainStack"
        }
    }

    # ================================================================
    # NESTED STACK EVENTS
    # ================================================================

    foreach ($NestedStackId in @($NestedStacks.Keys)) {

        $NestedInfo =
            $NestedStacks[$NestedStackId]

        $NestedLogicalId =
            $NestedInfo.LogicalId

        $NestedEventsJson =
            Get-StackEvents `
                -TargetStack $NestedStackId

        if ($null -eq $NestedEventsJson) {

            Write-MonitorLog `
                "WARNING: Nested stack events unavailable for $NestedLogicalId."

            continue
        }

        foreach (
            $NestedEvent
            in $NestedEventsJson.StackEvents
        ) {

            Process-CloudFormationEvent `
                -Event $NestedEvent `
                -StackContext "Nested Stack: $NestedLogicalId"
        }
    }

    # ================================================================
    # TERMINAL STATE HANDLING
    # ================================================================

    switch ($MainStatus) {

        "CREATE_COMPLETE" {

            Write-MonitorLog ""

            Write-MonitorLog `
                "MainStack reached CREATE_COMPLETE."

            if (-not $ContinueAfterSuccess) {

                Write-MonitorLog `
                    "Stopping monitor because deployment succeeded."

                break
            }
        }

        "UPDATE_COMPLETE" {

            Write-MonitorLog ""

            Write-MonitorLog `
                "MainStack reached UPDATE_COMPLETE."

            if (-not $ContinueAfterSuccess) {

                Write-MonitorLog `
                    "Stopping monitor because deployment succeeded."

                break
            }
        }

        "CREATE_FAILED"
        {
            Write-MonitorLog ""

            Write-MonitorLog `
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

            Write-MonitorLog `
                "TERMINAL CLOUDFORMATION FAILURE"

            Write-MonitorLog `
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

            Write-MonitorLog "Stack:"
            Write-MonitorLog $StackName

            Write-MonitorLog "Status:"
            Write-MonitorLog $MainStatus

            Write-MonitorLog "Reason:"
            Write-MonitorLog $MainReason

            # Give final events a chance to arrive.
            Start-Sleep -Seconds 5

            break
        }

        "UPDATE_FAILED"
        {
            Write-MonitorLog ""

            Write-MonitorLog `
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

            Write-MonitorLog `
                "TERMINAL CLOUDFORMATION FAILURE"

            Write-MonitorLog `
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

            Write-MonitorLog "Stack:"
            Write-MonitorLog $StackName

            Write-MonitorLog "Status:"
            Write-MonitorLog $MainStatus

            Write-MonitorLog "Reason:"
            Write-MonitorLog $MainReason

            Start-Sleep -Seconds 5

            break
        }

        "ROLLBACK_FAILED"
        {
            Write-MonitorLog ""

            Write-MonitorLog `
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

            Write-MonitorLog `
                "CLOUDFORMATION ROLLBACK FAILED"

            Write-MonitorLog `
                "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

            Write-MonitorLog "Reason:"
            Write-MonitorLog $MainReason

            Start-Sleep -Seconds 5

            break
        }

        "ROLLBACK_COMPLETE"
        {
            Write-MonitorLog ""

            Write-MonitorLog `
                "MainStack reached ROLLBACK_COMPLETE."

            Start-Sleep -Seconds 5

            break
        }

        "DELETE_FAILED"
        {
            Write-MonitorLog ""

            Write-MonitorLog `
                "CLOUDFORMATION DELETE_FAILED."

            Write-MonitorLog "Reason:"
            Write-MonitorLog $MainReason

            Start-Sleep -Seconds 5

            break
        }

        "DELETE_COMPLETE"
        {
            Write-MonitorLog ""

            Write-MonitorLog `
                "MainStack reached DELETE_COMPLETE."

            break
        }
    }

    # ================================================================
    # NEXT POLLING CYCLE
    # ================================================================

    Start-Sleep `
        -Seconds $PollingIntervalSeconds
}

# ====================================================================
# FINAL SUMMARY
# ====================================================================

Write-Section "CLOUDFORMATION LIVE MONITOR STOPPED"

Write-MonitorLog "Stack:"
Write-MonitorLog $StackName

Write-MonitorLog "Region:"
Write-MonitorLog $Region

Write-MonitorLog ""

Write-MonitorLog "Diagnostic files:"

Write-MonitorLog $MonitorLog
Write-MonitorLog $MainStackSnapshot
Write-MonitorLog $MainResourcesSnapshot
Write-MonitorLog $MainEventsSnapshot
Write-MonitorLog $FailureLog

Write-MonitorLog ""

Write-MonitorLog "Monitor completed."

# ====================================================================
# IMPORTANT
# ====================================================================
#
# This script intentionally exits successfully when the monitor
# itself completed.
#
# Terraform's exit code must be handled by the GitHub Actions
# workflow, NOT by this diagnostic process.
#
# ====================================================================

exit 0

