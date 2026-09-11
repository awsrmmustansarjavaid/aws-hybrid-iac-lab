# Real Time Monitoring Systeam

---
### Old Real Time Monitoring Systeam

Yes. You can run a PowerShell-based live CloudFormation monitor while Terraform is executing, including from a GitHub Actions runner.

Your current Bash design is conceptually good. I would improve it in PowerShell by separating the two processes:

```
GitHub Actions
     │
     ├── Start PowerShell CloudFormation Monitor (background)
     │        │
     │        └── polls AWS CloudFormation every 3 seconds
     │             ├── MainStack
     │             ├── nested stacks
     │             ├── stack events
     │             ├── failed resources
     │             └── failure reasons
     │
     └── Terraform Apply
              │
              └── Terraform creates/updates CloudFormation
```

The important point is that the monitor must never control Terraform's exit code. Terraform remains authoritative.

I recommend making the monitor a separate file such as:

```
scripts/
└── Monitor-CloudFormation.ps1
```
and then your GitHub Actions workflow starts it in the background.

One important improvement over your current Bash version

Your current script stops when it sees CREATE_COMPLETE, UPDATE_COMPLETE, etc. That's fine for a one-time deployment, but for diagnostics I would also:

monitor the main stack events

monitor nested stack events

detect new events only

capture PhysicalResourceId

classify common failures

save JSON snapshots

save a persistent monitor log

gracefully handle a stack that does not exist yet

handle CloudFormation throttling/API errors

continue monitoring while Terraform is running

return Terraform's original exit code

avoid requiring jq

Below is a standalone PowerShell version designed for your lab.

```
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
```

How I recommend integrating it with your Terraform workflow
I would not put the entire PowerShell monitor inside the YAML. Keep the monitor as a version-controlled .ps1 file. Your workflow then becomes much easier to maintain.

For example:

```
aws-hybrid-iac-lab/
│
├── infrastructure/
│   ├── terraform/
│   └── cloudformation/
│
├── scripts/
│   └── Monitor-CloudFormation.ps1
│
└── .github/
    └── workflows/
        └── terraform.yml
```

Then your GitHub Actions step can use PowerShell to launch the monitor in the background.

### Recommended GitHub Actions pattern

```
      # ======================================================
      # STEP 15
      # TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR
      # ======================================================
      #
      # PURPOSE
      # ------------------------------------------------------
      #
      # Terraform Apply runs while a separate PowerShell
      # CloudFormation monitor observes the CloudFormation
      # root stack and nested stacks.
      #
      # Terraform remains authoritative.
      #
      # The monitor is READ-ONLY.
      #
      # The monitor:
      #
      #   - waits for the CloudFormation stack
      #   - detects stack status changes
      #   - detects nested stacks
      #   - captures CloudFormation events
      #   - detects failed resources
      #   - captures failure reasons
      #   - classifies common failures
      #   - saves diagnostic JSON/log files
      #
      # ======================================================

      - name: Terraform Apply With Live CloudFormation Diagnostics
        if: ${{ env.TF_AUTO_APPROVE == 'true' }}
        working-directory: ${{ env.TF_WORKING_DIRECTORY }}
        shell: pwsh
        run: |

          $ErrorActionPreference = "Continue"

          Write-Host ""
          Write-Host "============================================================"
          Write-Host "TERRAFORM APPLY + LIVE CLOUDFORMATION DIAGNOSTICS"
          Write-Host "============================================================"

          # ----------------------------------------------------
          # Build CloudFormation root stack name.
          #
          # Expected:
          #
          # aws-hybrid-iac-lab-dev-MainStack
          # ----------------------------------------------------

          $MainStackName = "${env:PROJECT_NAME}-${env:ENVIRONMENT}-MainStack"

          Write-Host ""
          Write-Host "CloudFormation Stack:"
          Write-Host $MainStackName

          Write-Host ""
          Write-Host "AWS Region:"
          Write-Host $env:AWS_REGION

          # ----------------------------------------------------
          # Verify monitor script exists.
          #
          # This prevents a confusing Start-Process failure.
          # ----------------------------------------------------

          $MonitorScript = Join-Path `
            $env:GITHUB_WORKSPACE `
            "scripts/Monitor-CloudFormation.ps1"

          Write-Host ""
          Write-Host "CloudFormation monitor script:"
          Write-Host $MonitorScript

          if (-not (Test-Path -LiteralPath $MonitorScript)) {

            Write-Host ""
            Write-Host "ERROR: CloudFormation monitor script was not found."
            Write-Host ""
            Write-Host "Expected file:"
            Write-Host $MonitorScript

            exit 1
          }

          # ----------------------------------------------------
          # Diagnostic directory.
          #
          # Use an absolute path so the monitor and artifact
          # upload always refer to the same directory.
          # ----------------------------------------------------

          $DiagnosticDirectory = Join-Path `
            $env:GITHUB_WORKSPACE `
            "cloudformation-live-diagnostics"

          Write-Host ""
          Write-Host "Diagnostic directory:"
          Write-Host $DiagnosticDirectory

          # ----------------------------------------------------
          # Create diagnostic directory before starting monitor.
          # ----------------------------------------------------

          New-Item `
            -ItemType Directory `
            -Path $DiagnosticDirectory `
            -Force |
            Out-Null

          # ====================================================
          # START CLOUDFORMATION MONITOR
          # ====================================================

          Write-Host ""
          Write-Host "============================================================"
          Write-Host "STARTING CLOUDFORMATION LIVE MONITOR"
          Write-Host "============================================================"

          # ----------------------------------------------------
          # Start the PowerShell monitor as a background process.
          #
          # The monitor inherits the AWS credentials configured
          # earlier by aws-actions/configure-aws-credentials.
          #
          # The monitor itself does not modify AWS resources.
          # ----------------------------------------------------

          $MonitorProcess = Start-Process `
            -FilePath "pwsh" `
            -WorkingDirectory $env:GITHUB_WORKSPACE `
            -ArgumentList @(
              "-NoProfile"
              "-NonInteractive"
              "-File"
              $MonitorScript
              "-StackName"
              $MainStackName
              "-Region"
              $env:AWS_REGION
              "-PollingIntervalSeconds"
              "3"
              "-LogDirectory"
              $DiagnosticDirectory
            ) `
            -PassThru `
            -NoNewWindow

          if ($null -eq $MonitorProcess) {

            Write-Host ""
            Write-Host "ERROR: Failed to start CloudFormation monitor."

            exit 1
          }

          Write-Host ""
          Write-Host "CloudFormation monitor PID:"
          Write-Host $MonitorProcess.Id

          # ----------------------------------------------------
          # Give the monitor a short amount of time to initialize.
          # ----------------------------------------------------

          Start-Sleep -Seconds 2

          # ====================================================
          # TERRAFORM APPLY
          # ====================================================

          Write-Host ""
          Write-Host "============================================================"
          Write-Host "STARTING TERRAFORM APPLY"
          Write-Host "============================================================"

          Write-Host ""
          Write-Host "Terraform working directory:"
          Write-Host $env:GITHUB_WORKSPACE

          Write-Host ""
          Write-Host "Terraform plan:"
          Write-Host $env:TF_PLAN_FILE

          # ----------------------------------------------------
          # Apply the exact plan generated by Step 14.
          # ----------------------------------------------------

          terraform apply `
            -input=false `
            -auto-approve `
            $env:TF_PLAN_FILE

          # ----------------------------------------------------
          # IMPORTANT:
          #
          # Capture Terraform's exit code immediately.
          # Do not execute another external command before this.
          # ----------------------------------------------------

          $TerraformExitCode = $LASTEXITCODE

          # ====================================================
          # TERRAFORM FINISHED
          # ====================================================

          Write-Host ""
          Write-Host "============================================================"
          Write-Host "TERRAFORM APPLY FINISHED"
          Write-Host "============================================================"

          Write-Host ""
          Write-Host "Terraform exit code:"
          Write-Host $TerraformExitCode

          # ====================================================
          # ALLOW FINAL CLOUDFORMATION EVENTS
          # ====================================================

          Write-Host ""
          Write-Host "Allowing CloudFormation monitor to capture final events..."

          Start-Sleep -Seconds 5

          # ====================================================
          # STOP CLOUDFORMATION MONITOR
          # ====================================================

          if (
            $null -ne $MonitorProcess -and
            -not $MonitorProcess.HasExited
          ) {

            Write-Host ""
            Write-Host "Stopping CloudFormation live monitor..."

            Stop-Process `
              -Id $MonitorProcess.Id `
              -Force `
              -ErrorAction SilentlyContinue

            # --------------------------------------------------
            # Give the operating system a moment to release the
            # monitor process and finish writing the log.
            # --------------------------------------------------

            Start-Sleep -Seconds 1
          }

          # ====================================================
          # DISPLAY CLOUDFORMATION DIAGNOSTICS
          # ====================================================

          Write-Host ""
          Write-Host "################################################################"
          Write-Host "# COMPLETE CLOUDFORMATION LIVE DIAGNOSTIC"
          Write-Host "################################################################"

          if (Test-Path -LiteralPath $DiagnosticDirectory) {

            $DiagnosticFiles = Get-ChildItem `
              -Path $DiagnosticDirectory `
              -File `
              -Recurse `
              -ErrorAction SilentlyContinue

            if ($DiagnosticFiles.Count -eq 0) {

              Write-Host ""
              Write-Host "WARNING: Diagnostic directory contains no files."

            }
            else {

              foreach ($File in $DiagnosticFiles) {

                Write-Host ""
                Write-Host "------------------------------------------------------------"
                Write-Host "Diagnostic file:"
                Write-Host $File.FullName
                Write-Host "------------------------------------------------------------"

                Get-Content `
                  -LiteralPath $File.FullName `
                  -ErrorAction SilentlyContinue |
                  Write-Host
              }
            }

          }
          else {

            Write-Host ""
            Write-Host "WARNING: Diagnostic directory was not created."
          }

          # ====================================================
          # FINAL TERRAFORM RESULT
          # ====================================================

          Write-Host ""
          Write-Host "################################################################"
          Write-Host "# TERRAFORM APPLY RESULT"
          Write-Host "################################################################"

          Write-Host ""
          Write-Host "Terraform exit code:"
          Write-Host $TerraformExitCode

          if ($TerraformExitCode -eq 0) {

            Write-Host ""
            Write-Host "============================================================"
            Write-Host "TERRAFORM APPLY SUCCEEDED"
            Write-Host "============================================================"

          }
          else {

            Write-Host ""
            Write-Host "============================================================"
            Write-Host "TERRAFORM APPLY FAILED"
            Write-Host "============================================================"

            Write-Host ""
            Write-Host "CloudFormation diagnostics were captured."

          }

          # ====================================================
          # CRITICAL
          # ====================================================
          #
          # Terraform remains authoritative.
          #
          # The CloudFormation monitor MUST NOT change the
          # Terraform result.
          #
          # Return Terraform's original exit code.
          #
          # ====================================================

          exit $TerraformExitCode


      # ======================================================
      # STEP 16
      # UPLOAD CLOUDFORMATION LIVE DIAGNOSTICS
      # ======================================================

      - name: Upload CloudFormation Live Diagnostics
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: cloudformation-live-diagnostics
          path: ${{ github.workspace }}/cloudformation-live-diagnostics/
          if-no-files-found: warn
```

There is one thing I would change in that workflow

Because your Terraform plan file may be a local path rather than an environment variable, use your existing variable exactly as you currently define it. For example, if you already have:

```
env:
  TF_PLAN_FILE: tfplan
```

then the PowerShell code above is fine.

If your existing workflow uses something like:

```
TF_PLAN_FILE="${TF_WORKING_DIRECTORY}/tfplan"
```

then keep that existing definition.


### Even better architecture for your lab

I recommend this final arrangement:

```
                    GitHub Actions
                          │
                          ▼
                 ┌─────────────────┐
                 │ Terraform Plan  │
                 └────────┬────────┘
                          │
                          ▼
                ┌───────────────────┐
                │ Start CFN Monitor │
                │   PowerShell      │
                └─────────┬─────────┘
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
     Terraform Apply            CloudFormation
             │                         │
             │                  ┌──────┴──────┐
             │                  │ Main Stack  │
             │                  └──────┬──────┘
             │                         │
             │              ┌──────────┼──────────┐
             │              ▼          ▼          ▼
             │           VPC/EC2     API GW    Lambda
             │              │
             │              ▼
             │        Nested Stacks
             │
             └──────────────┬───────────────┘
                            ▼
                   Terraform Exit Code
                            │
                  ┌─────────┴─────────┐
                  │                   │
                  ▼                   ▼
               0 = PASS           != 0 = FAIL
```

What you'll see in GitHub Actions
Instead of Terraform simply ending with something like:

Error: failed to create CloudFormation stack
you can get diagnostic output such as:

````
============================================================
CLOUDFORMATION STATUS CHANGE
============================================================

Stack:
hybridiaclab-dev-MainStack

Status:
CREATE_IN_PROGRESS
Then:

NESTED CLOUDFORMATION STACK DISCOVERED

Logical ID:
APIGatewayStack

Physical Stack:
arn:aws:cloudformation:us-east-1:123456789012:stack/...

Status:
CREATE_IN_PROGRESS
And if your current type of problem happens again:

============================================================
LIVE CLOUDFORMATION FAILURE DETECTED
============================================================

Stack Context:
Nested Stack: APIGatewayStack

Logical Resource:
ApiGatewayExecutionRole

Resource Type:
AWS::IAM::Role

Status:
CREATE_FAILED

Physical Resource:
...

EXACT CLOUDFORMATION REASON:
------------------------------------------------------------
User is not authorized to perform iam:PassRole
------------------------------------------------------------
```

ROOT CAUSE CLASSIFICATION:

IAM PassRole PERMISSION FAILURE

That is much more useful for diagnosing your Terraform → CloudFormation deployment.

One final recommendatio
n
For your particular Terraform + CloudFormation hybrid lab, I would keep the responsibilities strictly separated:

Terraform → creates/invokes the CloudFormation stack

CloudFormation → creates the nested AWS infrastructure

PowerShell monitor → observes CloudFormation and produces diagnostics

GitHub Actions → orchestrates everything and decides success/failure based on Terraform's exit code

That is cleaner than making the diagnostic process responsible for deployment decisions.


You do NOT need to manually run Monitor-CloudFormation.ps1 every time you start GitHub Actions.

Your intended setup is:

```
You
 │
 │  Push code / Run workflow
 ▼
GitHub Actions
 │
 ├── Terraform plan
 │
 ├── START CloudFormation Monitor  ◄── automatic
 │
 ├── terraform apply
 │       │
 │       ▼
 │   CloudFormation
 │       │
 │       ├── CREATE
 │       ├── UPDATE
 │       ├── IN_PROGRESS
 │       └── FAILED
 │
 ├── Monitor captures events
 │
 └── Stop monitor
       │
       ▼
Upload diagnostics artifact
```

What your PowerShell script is for

Monitor-CloudFormation.ps1 is a helper script.

You normally do not start it yourself.

Your GitHub Actions workflow should start it automatically here:

```
- name: Apply Terraform
  shell: pwsh
  run: |
    # Start CloudFormation monitor in background
    $monitor = Start-Process -FilePath "pwsh" `
      -ArgumentList @(
        "-NoProfile",
        "-File", "./scripts/Monitor-CloudFormation.ps1",
        "-StackName", "aws-hybrid-iac-lab-dev-MainStack",
        "-Region", "us-east-1",
        "-PollingIntervalSeconds", "3",
        "-LogDirectory", "./cloudformation-live-diagnostics"
      ) `
      -PassThru

    # Terraform starts CloudFormation deployment
    terraform apply -auto-approve

    $terraformExitCode = $LASTEXITCODE

    # Give monitor a few seconds to capture final status
    Start-Sleep -Seconds 5

    # Stop monitor
    Stop-Process -Id $monitor.Id -Force

    exit $terraformExitCode
```
So when GitHub Actions reaches this step:

GitHub automatically starts the monitor.

Then Terraform starts/updates your CloudFormation stack.

The monitor watches CloudFormation at the same time.


Why did I ask you to run it manually?
That was only for testing the monitor script locally.

We wanted to prove:

The file exists ✅

PowerShell can execute it

AWS credentials work

CloudFormation permissions work

The monitor can actually retrieve stack events

It was not because you need to manually run it during every deployment.

Think of it like this:

### Local testing

You manually do:

```
PowerShell
   ↓
Monitor-CloudFormation.ps1
   ↓
CloudFormation
GitHub Actions
GitHub does it automatically:

GitHub Actions
   ↓
Start Monitor-CloudFormation.ps1
   ↓
Terraform Apply
   ↓
CloudFormation
```

One important point for your current situation
Your local machine currently has:

Windows PowerShell 5.1
and doesn't have:

PowerShell 7 / pwsh
That doesn't necessarily prevent GitHub Actions from working.

Your GitHub workflow runs on:

runs-on: ubuntu-latest
and uses:

shell: pwsh
So the GitHub runner has PowerShell 7 available.

Therefore:

```
Your Windows PC
    PowerShell 5.1
         ↓
    Can't run monitor locally ❌

GitHub Actions
    Ubuntu runner
    PowerShell 7
         ↓
    Can run monitor automatically ✅
```

### My recommendation

For your lab, keep the monitor inside the GitHub workflow and let GitHub start it automatically.

You only need to install PowerShell 7 locally if you want to test/debug the monitor script yourself on your Windows PC.

If your main goal is simply:

"When I click Run workflow, automatically monitor CloudFormation while Terraform applies."

Then you do not need to manually start the PowerShell script. Your Step 15 should do that automatically.


### GitHub Actions artifact


GitHub uploaded it as an Actions artifact.

From your workflow result, look for the Artifacts section near the bottom of the GitHub Actions run.

Steps
Open your failed GitHub Actions run.

Scroll to the bottom of the run summary.

Find Artifacts.

You should see: cloudformation-live-diagnostics

Click it to download the ZIP.

It will normally appear in your Windows Downloads folder as: cloudformation-live-diagnostics.zip

Your log confirms it was successfully uploaded:

Artifact cloudformation-live-diagnostics.zip successfully finalized.

After downloading it

### STEP 15 - TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR (terraform.yml)

Give me the complete final Step 15 replacement
Yes. Replace your entire existing Step 15 with this version.

It keeps your existing Monitor-CloudFormation.ps1, fixes the stack-name mismatch, and adds a direct CloudFormation diagnostic fallback so the GitHub log shows the actual failed resource/reason instead of only exit code 1.

```
# ==========================================================
# STEP 15 - TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR
# ==========================================================
- name: Terraform Apply With Live CloudFormation Diagnostics
  if: ${{ env.TF_AUTO_APPROVE == 'true' }}
  working-directory: ${{ env.TF_WORKING_DIRECTORY }}
  shell: pwsh
  run: |
    $ErrorActionPreference = "Continue"

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STEP 15 - TERRAFORM APPLY WITH LIVE CLOUDFORMATION MONITOR" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # ==========================================================
    # [1/9] VERIFY POWERSHELL
    # ==========================================================

    Write-Host "[1/9] Verifying PowerShell..." -ForegroundColor Yellow

    $PwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue

    if ($null -eq $PwshCommand) {
      Write-Host "ERROR: pwsh was not found." -ForegroundColor Red
      exit 1
    }

    & pwsh --version

    # ==========================================================
    # [2/9] CONFIGURATION
    # ==========================================================

    Write-Host ""
    Write-Host "[2/9] Configuring CloudFormation monitoring..." -ForegroundColor Yellow

    # IMPORTANT:
    # Terraform uses:
    #   project_name = "hybridiaclab"
    #
    # Therefore the real root stack is:
    #   hybridiaclab-dev-MainStack
    #
    # PROJECT_NAME must match Terraform.
    $MainStackName = "${env:PROJECT_NAME}-${env:ENVIRONMENT}-MainStack"

    $MonitorScript = Join-Path `
      $env:GITHUB_WORKSPACE `
      "scripts/Monitor-CloudFormation.ps1"

    $DiagnosticDirectory = Join-Path `
      $env:GITHUB_WORKSPACE `
      "cloudformation-live-diagnostics"

    Write-Host "Project Name: $env:PROJECT_NAME"
    Write-Host "Environment: $env:ENVIRONMENT"
    Write-Host "Main Stack: $MainStackName"
    Write-Host "Region: $env:AWS_REGION"
    Write-Host "Monitor Script: $MonitorScript"
    Write-Host "Diagnostic Directory: $DiagnosticDirectory"

    # ==========================================================
    # [3/9] VERIFY MONITOR SCRIPT
    # ==========================================================

    Write-Host ""
    Write-Host "[3/9] Verifying CloudFormation monitor script..." -ForegroundColor Yellow

    if (-not (Test-Path -LiteralPath $MonitorScript)) {

      Write-Host ""
      Write-Host "ERROR: CloudFormation monitor script was not found." -ForegroundColor Red
      Write-Host "Expected path:"
      Write-Host $MonitorScript

      exit 1
    }

    Write-Host "Monitor script found."

    # ==========================================================
    # [4/9] CREATE DIAGNOSTIC DIRECTORY
    # ==========================================================

    Write-Host ""
    Write-Host "[4/9] Creating diagnostic directory..." -ForegroundColor Yellow

    New-Item `
      -ItemType Directory `
      -Path $DiagnosticDirectory `
      -Force |
      Out-Null

    # ==========================================================
    # [5/9] VERIFY AWS IDENTITY
    # ==========================================================

    Write-Host ""
    Write-Host "[5/9] Verifying AWS identity..." -ForegroundColor Yellow

    $IdentityOutput = & aws sts get-caller-identity `
      --region $env:AWS_REGION `
      --output json `
      2>&1

    $IdentityExitCode = $LASTEXITCODE

    if ($IdentityExitCode -ne 0) {

      Write-Host ""
      Write-Host "ERROR: AWS credentials are not available." -ForegroundColor Red
      Write-Host ($IdentityOutput -join "`n")

      exit 1
    }

    try {

      $Identity = (
        $IdentityOutput -join "`n"
      ) | ConvertFrom-Json

      Write-Host "AWS Account: $($Identity.Account)"
      Write-Host "AWS Principal: $($Identity.Arn)"

    }
    catch {

      Write-Host "WARNING: Unable to parse AWS identity." -ForegroundColor Yellow
    }

    # ==========================================================
    # [6/9] START LIVE CLOUDFORMATION MONITOR
    # ==========================================================

    Write-Host ""
    Write-Host "[6/9] Starting live CloudFormation monitor..." -ForegroundColor Yellow

    $MonitorProcess = $null

    # Default to failure until Terraform proves successful.
    $TerraformExitCode = 1

    try {

      $MonitorArguments = @(
        "-NoProfile"
        "-NonInteractive"
        "-File"
        $MonitorScript
        "-StackName"
        $MainStackName
        "-Region"
        $env:AWS_REGION
        "-PollingIntervalSeconds"
        "3"
        "-LogDirectory"
        $DiagnosticDirectory
      )

      $MonitorProcess = Start-Process `
        -FilePath $PwshCommand.Source `
        -WorkingDirectory $env:GITHUB_WORKSPACE `
        -ArgumentList $MonitorArguments `
        -PassThru `
        -NoNewWindow

      if ($null -eq $MonitorProcess) {

        Write-Host ""
        Write-Host "ERROR: CloudFormation monitor could not be started." -ForegroundColor Red

        exit 1
      }

      Write-Host "CloudFormation monitor started."
      Write-Host "Monitor PID: $($MonitorProcess.Id)"

      # Give monitor a moment to start.
      Start-Sleep -Seconds 2

      # ========================================================
      # [7/9] TERRAFORM APPLY
      # ========================================================

      Write-Host ""
      Write-Host "[7/9] Running Terraform apply..." -ForegroundColor Yellow
      Write-Host ""

      terraform apply `
        -input=false `
        -auto-approve `
        $env:TF_PLAN_FILE

      $TerraformExitCode = $LASTEXITCODE

      Write-Host ""
      Write-Host "============================================================"

      if ($TerraformExitCode -eq 0) {

        Write-Host `
          "TERRAFORM APPLY COMPLETED SUCCESSFULLY" `
          -ForegroundColor Green

      }
      else {

        Write-Host `
          "TERRAFORM APPLY FAILED" `
          -ForegroundColor Red

      }

      Write-Host "Terraform Exit Code: $TerraformExitCode"
      Write-Host "============================================================"

      # ========================================================
      # WAIT FOR FINAL CLOUDFORMATION EVENTS
      # ========================================================

      Write-Host ""
      Write-Host "Waiting 5 seconds for final CloudFormation events..."

      Start-Sleep -Seconds 5

      # ========================================================
      # DIRECT CLOUDFORMATION DIAGNOSTICS
      #
      # This is intentionally independent of the monitor.
      #
      # If Terraform fails, we directly query:
      #
      #   Root stack
      #   Root stack events
      #
      # This prevents a monitoring failure from hiding the
      # actual CloudFormation failure.
      # ========================================================

      if ($TerraformExitCode -ne 0) {

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host "DIRECT CLOUDFORMATION FAILURE DIAGNOSTICS" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host ""

        Write-Host "Root Stack:"
        Write-Host $MainStackName

        Write-Host ""
        Write-Host "Region:"
        Write-Host $env:AWS_REGION

        # ======================================================
        # ROOT STACK STATUS
        # ======================================================

        Write-Host ""
        Write-Host "------------------------------------------------------------"
        Write-Host "ROOT STACK STATUS"
        Write-Host "------------------------------------------------------------"

        $StackOutput = & aws cloudformation describe-stacks `
          --stack-name $MainStackName `
          --region $env:AWS_REGION `
          --output json `
          2>&1

        $StackExitCode = $LASTEXITCODE

        $StackJsonFile = Join-Path `
          $DiagnosticDirectory `
          "direct-root-stack.json"

        ($StackOutput -join "`n") |
          Set-Content `
            -LiteralPath $StackJsonFile `
            -Encoding UTF8

        if ($StackExitCode -eq 0) {

          try {

            $StackData = (
              $StackOutput -join "`n"
            ) | ConvertFrom-Json

            $Stack = $StackData.Stacks[0]

            Write-Host ""
            Write-Host "Stack Name:"
            Write-Host $Stack.StackName

            Write-Host ""
            Write-Host "Stack Status:"
            Write-Host $Stack.StackStatus

            if (-not [string]::IsNullOrWhiteSpace(
              [string]$Stack.StackStatusReason
            )) {

              Write-Host ""
              Write-Host "Stack Status Reason:"
              Write-Host $Stack.StackStatusReason
            }

          }
          catch {

            Write-Host ""
            Write-Host "WARNING: Could not parse root stack response." `
              -ForegroundColor Yellow
          }

        }
        else {

          Write-Host ""
          Write-Host "WARNING: Root stack could not be queried." `
            -ForegroundColor Yellow

          Write-Host ($StackOutput -join "`n")
        }

        # ======================================================
        # ROOT STACK EVENTS
        # ======================================================

        Write-Host ""
        Write-Host "------------------------------------------------------------"
        Write-Host "FAILED CLOUDFORMATION EVENTS"
        Write-Host "------------------------------------------------------------"

        $EventsOutput = & aws cloudformation describe-stack-events `
          --stack-name $MainStackName `
          --region $env:AWS_REGION `
          --output json `
          2>&1

        $EventsExitCode = $LASTEXITCODE

        $EventsJsonFile = Join-Path `
          $DiagnosticDirectory `
          "direct-root-events.json"

        ($EventsOutput -join "`n") |
          Set-Content `
            -LiteralPath $EventsJsonFile `
            -Encoding UTF8

        if ($EventsExitCode -eq 0) {

          try {

            $EventsData = (
              $EventsOutput -join "`n"
            ) | ConvertFrom-Json

            $FailedEvents = @(
              $EventsData.StackEvents |
              Where-Object {
                $_.ResourceStatus -match `
                  "CREATE_FAILED|UPDATE_FAILED|DELETE_FAILED|ROLLBACK_FAILED"
              }
            )

            if ($FailedEvents.Count -eq 0) {

              Write-Host ""
              Write-Host "No direct FAILED events were returned."

            }
            else {

              foreach ($Event in $FailedEvents) {

                Write-Host ""
                Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" `
                  -ForegroundColor Red

                Write-Host "FAILED RESOURCE" -ForegroundColor Red

                Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

                Write-Host ""
                Write-Host "Logical Resource:"
                Write-Host $Event.LogicalResourceId

                Write-Host ""
                Write-Host "Resource Type:"
                Write-Host $Event.ResourceType

                Write-Host ""
                Write-Host "Status:"
                Write-Host $Event.ResourceStatus

                if (-not [string]::IsNullOrWhiteSpace(
                  [string]$Event.PhysicalResourceId
                )) {

                  Write-Host ""
                  Write-Host "Physical Resource:"
                  Write-Host $Event.PhysicalResourceId
                }

                Write-Host ""
                Write-Host "EXACT CLOUDFORMATION REASON:"
                Write-Host "------------------------------------------------------------" `
                  -ForegroundColor Yellow

                if (-not [string]::IsNullOrWhiteSpace(
                  [string]$Event.ResourceStatusReason
                )) {

                  Write-Host $Event.ResourceStatusReason `
                    -ForegroundColor Yellow

                }
                else {

                  Write-Host "No CloudFormation status reason provided." `
                    -ForegroundColor Yellow
                }

                Write-Host "------------------------------------------------------------" `
                  -ForegroundColor Yellow
              }
            }

          }
          catch {

            Write-Host ""
            Write-Host `
              "WARNING: Could not parse CloudFormation events." `
              -ForegroundColor Yellow
          }

        }
        else {

          Write-Host ""
          Write-Host `
            "WARNING: CloudFormation events could not be queried." `
            -ForegroundColor Yellow

          Write-Host ($EventsOutput -join "`n")
        }

        # ======================================================
        # DIRECT ROOT RESOURCE DISCOVERY
        # ======================================================

        Write-Host ""
        Write-Host "------------------------------------------------------------"
        Write-Host "ROOT STACK RESOURCES"
        Write-Host "------------------------------------------------------------"

        $ResourcesOutput = & aws cloudformation list-stack-resources `
          --stack-name $MainStackName `
          --region $env:AWS_REGION `
          --output json `
          2>&1

        $ResourcesExitCode = $LASTEXITCODE

        $ResourcesJsonFile = Join-Path `
          $DiagnosticDirectory `
          "direct-root-resources.json"

        ($ResourcesOutput -join "`n") |
          Set-Content `
            -LiteralPath $ResourcesJsonFile `
            -Encoding UTF8

        if ($ResourcesExitCode -eq 0) {

          try {

            $ResourcesData = (
              $ResourcesOutput -join "`n"
            ) | ConvertFrom-Json

            $NestedStacksFound = @(
              $ResourcesData.StackResourceSummaries |
              Where-Object {
                $_.ResourceType -eq "AWS::CloudFormation::Stack"
              }
            )

            if ($NestedStacksFound.Count -gt 0) {

              Write-Host ""
              Write-Host "Nested CloudFormation stacks discovered:"

              foreach ($NestedStack in $NestedStacksFound) {

                Write-Host ""
                Write-Host "Nested Stack:"
                Write-Host $NestedStack.LogicalResourceId

                Write-Host "Status:"
                Write-Host $NestedStack.ResourceStatus

                if (
                  -not [string]::IsNullOrWhiteSpace(
                    [string]$NestedStack.PhysicalResourceId
                  )
                ) {

                  Write-Host "Physical Stack:"
                  Write-Host $NestedStack.PhysicalResourceId
                }
              }

            }
            else {

              Write-Host ""
              Write-Host "No nested stacks found in root resources."
            }

          }
          catch {

            Write-Host ""
            Write-Host `
              "WARNING: Could not parse root resources." `
              -ForegroundColor Yellow
          }

        }
        else {

          Write-Host ""
          Write-Host `
            "WARNING: Root resources could not be queried." `
            -ForegroundColor Yellow
        }

        # ======================================================
        # DISPLAY MONITOR FAILURE LOG
        # ======================================================

        Write-Host ""
        Write-Host "------------------------------------------------------------"
        Write-Host "LIVE MONITOR FAILURE LOG"
        Write-Host "------------------------------------------------------------"

        $FailureLog = Join-Path `
          $DiagnosticDirectory `
          "cloudformation-failures.log"

        if (Test-Path -LiteralPath $FailureLog) {

          Get-Content `
            -LiteralPath $FailureLog `
            -ErrorAction SilentlyContinue

        }
        else {

          Write-Host "No monitor failure log was generated."
        }

        Write-Host ""
        Write-Host "============================================================" `
          -ForegroundColor Red

        Write-Host "CLOUDFORMATION DIAGNOSTICS COMPLETE" `
          -ForegroundColor Red

        Write-Host "============================================================" `
          -ForegroundColor Red
      }

    }
    finally {

      # ========================================================
      # [8/9] STOP LIVE MONITOR
      # ========================================================

      Write-Host ""
      Write-Host "[8/9] Stopping CloudFormation monitor..." `
        -ForegroundColor Yellow

      if ($null -ne $MonitorProcess) {

        try {
          $MonitorProcess.Refresh()
        }
        catch {}

        if (-not $MonitorProcess.HasExited) {

          Stop-Process `
            -Id $MonitorProcess.Id `
            -Force `
            -ErrorAction SilentlyContinue

          Start-Sleep -Seconds 1

          Write-Host "CloudFormation monitor stopped."

        }
        else {

          Write-Host "CloudFormation monitor already exited."
        }

      }
      else {

        Write-Host "No monitor process was running."
      }

      # ========================================================
      # DISPLAY ALL GENERATED DIAGNOSTIC FILES
      # ========================================================

      Write-Host ""
      Write-Host "------------------------------------------------------------"
      Write-Host "GENERATED CLOUDFORMATION DIAGNOSTIC FILES"
      Write-Host "------------------------------------------------------------"

      if (Test-Path -LiteralPath $DiagnosticDirectory) {

        $DiagnosticFiles = @(
          Get-ChildItem `
            -Path $DiagnosticDirectory `
            -File `
            -ErrorAction SilentlyContinue
        )

        if ($DiagnosticFiles.Count -gt 0) {

          foreach ($File in $DiagnosticFiles) {

            Write-Host ""
            Write-Host "FILE: $($File.FullName)"

          }

        }
        else {

          Write-Host "No diagnostic files were generated."
        }

      }
      else {

        Write-Host "Diagnostic directory does not exist."
      }

      Write-Host ""
      Write-Host "[9/9] Final Terraform exit code: $TerraformExitCode" `
        -ForegroundColor Yellow
    }

    # ==========================================================
    # RETURN TERRAFORM'S ORIGINAL EXIT CODE
    # ==========================================================

    exit $TerraformExitCode
````






---

For your **GitHub Actions → Terraform → CloudFormation → AWS** lab, I would change the monitoring design rather than keep adding `Start-Sleep` loops to the existing Step 15.

The professional solution is to separate **deployment execution** from **deployment observability**.

GitHub already provides a real-time workflow graph and streaming job logs. ([GitHub Docs][1]) CloudFormation exposes stack events through the API/CLI, including newer operation-based event tracking. ([AWS Documentation][2])

## 1. The architecture I recommend

```text
                    GitHub
                       │
                       │ push / manual dispatch
                       ▼
              ┌───────────────────┐
              │ GitHub Actions     │
              │ CI/CD Workflow     │
              └─────────┬─────────┘
                        │
                        ▼
                ┌───────────────┐
                │ Terraform     │
                │ plan/apply     │
                └───────┬───────┘
                        │
             ┌──────────┴──────────┐
             │                     │
             ▼                     ▼
      Terraform process       LIVE MONITOR
             │                     │
             │                     │
             ▼                     ▼
     CloudFormation          describe-events
       Main Stack            describe-stack-events
             │                     │
             ├──────────┬──────────┤
             ▼          ▼          ▼
          VPC/EKS     EC2/ECS    Nested Stacks
             │          │          │
             └──────────┴──────────┘
                        │
                        ▼
              GitHub Actions Log
                  REAL TIME
```

The important part is:

> **Terraform must NOT be responsible for showing you the CloudFormation diagnostic information.**

Terraform executes the infrastructure.

A separate monitor observes CloudFormation **while Terraform is still running**.

---

# 2. Why your current Step 15 is probably frustrating

Your current pattern is likely approximately:

```powershell
terraform apply
```

then:

```powershell
aws cloudformation describe-stack-events
```

The problem is obvious:

```text
Terraform Apply
      │
      │ WAIT
      │
      │ WAIT
      │
      ▼
Terraform finishes/fails
      │
      ▼
CloudFormation monitor starts
```

That is **not real-time monitoring**.

Instead we want:

```text
Terraform Apply ────────────────────────────────►
       │
       │
       ├── CloudFormation Monitor ──────────────►
       │          │
       │          ├── event
       │          ├── event
       │          ├── event
       │          ├── FAILED
       │          └── SUCCESS
       │
       └── GitHub Actions Log ──────────────────►
```

Both processes run **at the same time**.

---

# 3. The professional design: 3 monitoring layers

I recommend three levels.

### Layer 1 — GitHub Actions

GitHub gives you:

* workflow status
* job status
* step status
* live logs
* visualization graph
* execution time

GitHub explicitly supports real-time workflow visualization and workflow run logs. ([GitHub Docs][1])

You can also monitor a running workflow from your own terminal with:

```powershell
gh run watch
```

or:

```powershell
gh run view <RUN_ID> --log
```

GitHub documents `gh run view` for retrieving workflow logs. ([GitHub Docs][3])

---

# 4. Layer 2 — Terraform

Terraform should report:

```text
Terraform Init
Terraform Validate
Terraform Plan
Terraform Apply
Terraform Outputs
```

But don't try to make Terraform print every CloudFormation resource.

Terraform knows that it requested:

```text
CloudFormation Stack Update
```

CloudFormation knows:

```text
EKS Cluster
IAM Role
VPC
Subnets
Security Groups
EC2
Nested Stack
etc.
```

So CloudFormation is the correct source for resource-level diagnostics.

---

# 5. Layer 3 — CloudFormation real-time event monitor

This is the most important improvement.

AWS provides:

```powershell
aws cloudformation describe-stack-events
```

which returns stack events in reverse chronological order. ([AWS Documentation][2])

AWS also now provides:

```powershell
aws cloudformation describe-events
```

which can group events by **operation ID** and can filter for failed events. That's particularly useful for modern deployment diagnostics. ([AWS Documentation][4])

---

# 6. What I would build for your lab

I would create a dedicated script:

```text
scripts/
│
├── terraform-apply.ps1
├── cloudformation-monitor.ps1
└── deployment-monitor.ps1
```

And your GitHub workflow becomes conceptually:

```yaml
- Terraform Init

- Terraform Validate

- Terraform Plan

- Terraform Apply + Live Infrastructure Monitor

- Deployment Summary
```

The important step would run:

```text
START Terraform
        │
        ├──────────────► Terraform Apply
        │
        └──────────────► CloudFormation Monitor
                              │
                              ├─ MainStack
                              ├─ NestedStack
                              ├─ NestedStack
                              └─ EKS Stack
```

---

# 7. The monitor should be event-aware, not just "wait 10 seconds"

This is where we can make your solution professional.

Instead of:

```powershell
Start-Sleep -Seconds 30
```

then check again, the monitor maintains the **last event ID**.

For example:

```text
First poll:

EKS UPDATE_IN_PROGRESS
VPC UPDATE_COMPLETE
IAM UPDATE_COMPLETE
```

Save:

```text
EventId = ABC123
```

Next poll:

```text
New event detected!
EKS CREATE_IN_PROGRESS
```

Print only the new event.

Then:

```text
New event detected!
EKS CREATE_FAILED
Reason:
...
```

That produces a clean stream:

```text
[00:01:14] VPC                 UPDATE_COMPLETE
[00:01:16] IAMRole             UPDATE_COMPLETE
[00:01:21] EKSCluster          UPDATE_IN_PROGRESS
[00:02:03] EKSCluster          UPDATE_FAILED
[00:02:03] ERROR: ...
```

Instead of repeatedly dumping the entire CloudFormation event history.

---

# 8. I would also monitor nested stacks

This is especially important for **your AWS Hybrid IaC Lab**.

You have:

```text
MainStack
   │
   ├── VPC
   ├── IAM
   ├── EC2
   ├── ECR
   ├── ECS
   ├── EKS
   ├── API Gateway
   ├── CloudFront
   ├── DynamoDB
   └── ...
```

Some resources are implemented through nested CloudFormation stacks.

So a professional monitor should discover:

```text
hybridiaclab-dev-MainStack
hybridiaclab-dev-VPCStack
hybridiaclab-dev-EKSStack
hybridiaclab-dev-ECSStack
...
```

and monitor them rather than only monitoring:

```text
MainStack
```

Otherwise you can see:

```text
MainStack UPDATE_IN_PROGRESS
```

but miss the useful event:

```text
EKSStack UPDATE_FAILED
AWS::EKS::Nodegroup
Resource handler returned message:
...
```

---

# 9. Even better: monitor by CloudFormation Operation ID

This is the newer AWS approach I would use where available.

CloudFormation operations have an:

```text
OperationId
```

and AWS supports querying events associated with a particular operation. You can also filter failed events. ([AWS Documentation][4])

Conceptually:

```powershell
aws cloudformation describe-events `
    --stack-name hybridiaclab-dev-MainStack
```

Then identify the current operation.

After that:

```powershell
aws cloudformation describe-events `
    --stack-name hybridiaclab-dev-MainStack `
    --operation-id <OPERATION_ID>
```

And when troubleshooting:

```powershell
aws cloudformation describe-events `
    --stack-name hybridiaclab-dev-MainStack `
    --operation-id <OPERATION_ID> `
    --filters FailedEvents=true
```

This is much cleaner than searching through thousands of historical events.

---

# 10. What "real time" should mean here

There is an important distinction.

### GitHub

GitHub Actions provides genuine streaming workflow logs/visualization while the job executes. ([GitHub Docs][1])

### CloudFormation console

The CloudFormation console automatically refreshes events approximately every minute. ([AWS Documentation][5])

### AWS CLI

Your own monitor can query the CloudFormation API much more frequently.

For example:

```text
2 seconds
```

or:

```text
3 seconds
```

So for your GitHub Actions pipeline, I would use:

```text
GitHub UI       → live workflow
Terraform       → deployment engine
AWS CLI monitor → 2–5 second CloudFormation event polling
CloudFormation  → authoritative infrastructure status
```

That is what I would call **near-real-time deployment observability** rather than pretending CloudFormation's console itself is a streaming WebSocket.

---

# 11. The monitor should produce professional output

Instead of this:

```text
{
  "StackEvents": [...]
}
```

your GitHub log should look like:

```text
============================================================
LIVE CLOUDFORMATION DEPLOYMENT MONITOR
============================================================

Stack:
  hybridiaclab-dev-MainStack

Region:
  us-east-1

Terraform:
  RUNNING

CloudFormation:
  UPDATE_IN_PROGRESS

------------------------------------------------------------
TIME       STACK        RESOURCE       TYPE             STATUS
------------------------------------------------------------

00:00:03   MainStack    VPC            AWS::EC2::VPC    UPDATE_IN_PROGRESS
00:00:07   MainStack    VPC            AWS::EC2::VPC    UPDATE_COMPLETE
00:00:12   EKSStack     Cluster         AWS::EKS::Cluster CREATE_IN_PROGRESS
00:00:31   EKSStack     Cluster         AWS::EKS::Cluster UPDATE_IN_PROGRESS
00:02:14   EKSStack     NodeGroup       AWS::EKS::Nodegroup CREATE_IN_PROGRESS

------------------------------------------------------------

CURRENT STATUS
  Terraform       : RUNNING
  CloudFormation  : UPDATE_IN_PROGRESS
  Resources       : 14
  Completed       : 9
  In Progress     : 5
  Failed          : 0

------------------------------------------------------------
```

Then if something fails:

```text
============================================================
!!! CLOUDFORMATION FAILURE DETECTED !!!
============================================================

Stack:
  hybridiaclab-dev-EKSStack

Resource:
  EKSNodeGroup

Type:
  AWS::EKS::Nodegroup

Status:
  CREATE_FAILED

Reason:
  NodeCreationFailure:
  Instances failed to join the Kubernetes cluster

Operation:
  abcdef12-....

============================================================
```

That's considerably more useful than waiting for Terraform to eventually print:

```text
Error: waiting for CloudFormation Stack...
```

---

# 12. The most important improvement: failure detection

Your monitor shouldn't merely display events.

It should **understand them**.

For example:

```powershell
$failureStates = @(
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED",
    "ROLLBACK_FAILED",
    "UPDATE_ROLLBACK_FAILED"
)
```

When detected:

```text
CloudFormation failure
       │
       ▼
Capture resource
       │
       ▼
Capture status reason
       │
       ▼
Capture stack
       │
       ▼
Capture operation
       │
       ▼
Print diagnostic
       │
       ▼
Allow Terraform result to determine workflow failure
```

This means your GitHub log immediately tells you **what failed and why**.

---

# 13. Don't let the monitor hide the Terraform exit code

This is another important professional detail.

Bad design:

```text
CloudFormation monitor exits 0
Terraform failed
GitHub says SUCCESS
```

Never do that.

The final result must be:

```text
Terraform exit code
+
CloudFormation status
=
deployment result
```

For example:

```text
Terraform = FAILED
CloudFormation = UPDATE_FAILED

FINAL RESULT = FAILED
```

or:

```text
Terraform = SUCCESS
CloudFormation = UPDATE_COMPLETE

FINAL RESULT = SUCCESS
```

---

# 14. I would also add a "failure summary"

At the end:

```text
============================================================
DEPLOYMENT SUMMARY
============================================================

GitHub Run:
  #34255678413

Terraform:
  APPLY FAILED

CloudFormation:
  UPDATE_ROLLBACK_IN_PROGRESS

Failed Stack:
  hybridiaclab-dev-EKSStack

Failed Resource:
  EKSNodeGroup

Resource Type:
  AWS::EKS::Nodegroup

Failure Reason:
  ...

Operation ID:
  ...

Duration:
  04m 58s

============================================================
```

That makes the GitHub Actions run much easier to troubleshoot.

---

# 15. Your professional monitoring stack

For your current project, I'd eventually build this:

```text
                         GitHub
                           │
                           ▼
                  GitHub Actions
                           │
             ┌─────────────┴─────────────┐
             │                           │
             ▼                           ▼
        Terraform                    Monitor
             │                           │
             │                           │
             ▼                           ▼
      CloudFormation             CloudFormation API
             │                           │
       ┌─────┼─────┐                     │
       ▼     ▼     ▼                     │
      VPC   EKS   ECS                    │
       │     │     │                     │
       └─────┴─────┴─────────────────────┘
                           │
                           ▼
                    GitHub live logs
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
          SUCCESS        WARNING        FAILURE
```

Then, at the next maturity level:

```text
CloudFormation
      │
      ▼
EventBridge
      │
      ▼
CloudWatch
      │
      ├── Metrics
      ├── Logs
      ├── Alarms
      └── Dashboard
```

That becomes a proper **AWS observability architecture**, rather than just a debugging script.

---

# 16. What I recommend specifically for YOUR lab

Given the problems you've been having with **Step 15 + Terraform + CloudFormation + EKS**, I would **not** keep patching the existing Step 15 blindly.

I would redesign it as:

### Step 15 — Deployment Orchestrator

```text
1. Discover MainStack
2. Start Terraform Apply
3. Immediately start CloudFormation monitor
4. Discover nested stacks
5. Poll CloudFormation events
6. Print only NEW events
7. Detect failure states
8. Show failure reason immediately
9. Continue monitoring while Terraform runs
10. Wait for Terraform process
11. Collect Terraform exit code
12. Collect CloudFormation final state
13. Generate deployment summary
14. Return correct GitHub exit code
```

That's the solution I'd use for your lab.

### And importantly:

**Do not make the monitor wait for Terraform to finish.**

The relationship should be:

```text
             ┌───────────────────┐
             │ Terraform Apply   │
             │       RUNNING     │
             └─────────┬─────────┘
                       │
                       │ parallel
                       ▼
             ┌───────────────────┐
             │ CFN Live Monitor  │
             │       RUNNING     │
             └─────────┬─────────┘
                       │
                       ▼
             New CFN events
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
          SUCCESS              FAILURE
             │                   │
             └─────────┬─────────┘
                       ▼
                Final Summary
                       │
                       ▼
                GitHub Result
```

AWS itself recommends using CloudFormation stack events to monitor resource creation/update/deletion progress and troubleshoot failures. ([AWS Documentation][5])

## My recommendation for the next step

Since you've already been working on **Step 15**, the best move is for me to take your **actual current Step 15 YAML** and replace it with a production-quality version that:

* runs Terraform and CloudFormation monitoring **in parallel**
* doesn't wait unnecessarily
* monitors **MainStack + nested stacks**
* shows only **new events**
* detects `CREATE_FAILED`, `UPDATE_FAILED`, rollback failures, etc.
* captures the **actual CloudFormation failure reason**
* continues streaming into GitHub Actions
* preserves Terraform's real exit code
* produces a clean final deployment summary
* works with your existing `TF_AUTO_APPROVE`, `TF_WORKING_DIRECTORY`, AWS region, and stack naming
* avoids the indentation problems you encountered earlier

[1]: https://docs.github.com/en/actions/how-tos/monitor-workflows?utm_source=chatgpt.com "Monitor workflows - GitHub Docs"
[2]: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-stack-events.html?utm_source=chatgpt.com "describe-stack-events — AWS CLI 2.36.40 Command Reference"
[3]: https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs?utm_source=chatgpt.com "Using workflow run logs - GitHub Docs"
[4]: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-events.html?utm_source=chatgpt.com "describe-events — AWS CLI 2.36.40 Command Reference"
[5]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/view-stack-events.html?utm_source=chatgpt.com "View CloudFormation stack events - AWS CloudFormation"

Yes — **this is absolutely possible**, and in fact I would recommend designing your Step 15 around exactly this model.

The key is to distinguish between **Terraform's operation**, **CloudFormation's operation**, and the **GitHub Actions job/run**. They are related, but they are not the same operation ID.

### The model I recommend

```text
GitHub Actions Run
        │
        ▼
Terraform Apply
        │
        │ creates/updates
        ▼
CloudFormation MainStack
        │
        ├── CloudFormation Operation ID
        │
        ├── Nested Stack Operation IDs
        │
        └── Resource Events
                │
                ▼
        EKS / EC2 / IAM / VPC / etc.
```

At the same time:

```text
Terraform Apply
      │
      ├──────────────► Terraform log
      │
      └──────────────► CloudFormation Monitor
                              │
                              ├── Operation ID
                              ├── Stack events
                              ├── Resource events
                              ├── Status
                              └── Failure reason
```

And **both streams are saved**.

---

# The final result you want

At the end of the GitHub job, we can generate something like:

```text
============================================================
DEPLOYMENT DIAGNOSTIC REPORT
============================================================

GitHub Run:
  34255678413

Terraform:
  FAILED

CloudFormation:
  UPDATE_ROLLBACK_COMPLETE

CloudFormation Operation:
  8f91xxxx-xxxx-xxxx-xxxx-xxxxxxxx

Duration:
  04m 58s

------------------------------------------------------------
CLOUDFORMATION FAILURE
------------------------------------------------------------

Stack:
  hybridiaclab-dev-EKSStack

Resource:
  EKSNodeGroup

Resource Type:
  AWS::EKS::Nodegroup

Status:
  CREATE_FAILED

Reason:
  NodeCreationFailure:
  Instances failed to join the Kubernetes cluster

------------------------------------------------------------
TERRAFORM CORRELATION
------------------------------------------------------------

Terraform Error:
  Error: waiting for CloudFormation Stack update:
  UPDATE_ROLLBACK_FAILED

Terraform Module:
  module.eks

Terraform Resource:
  aws_cloudformation_stack.eks

------------------------------------------------------------
GITHUB CORRELATION
------------------------------------------------------------

GitHub Step:
  Terraform Apply With Live CloudFormation Diagnostics

GitHub Job:
  terraform

GitHub Run:
  34255678413

------------------------------------------------------------
AUTOMATED DIAGNOSIS
------------------------------------------------------------

Root Cause:
  CloudFormation EKS NodeGroup creation failed.

Evidence:
  1. CloudFormation reported CREATE_FAILED.
  2. The failed resource was AWS::EKS::Nodegroup.
  3. CloudFormation reported NodeCreationFailure.
  4. Terraform subsequently reported the CloudFormation
     operation as failed.

Conclusion:
  Terraform was not the root cause.

  Terraform successfully submitted the infrastructure
  operation, but the AWS EKS NodeGroup failed during
  CloudFormation resource provisioning.

============================================================
FINAL RESULT: FAILED
============================================================
```

**That is much more powerful than simply printing CloudFormation events.**

---

# And yes — we can correlate the logs

This is the part I particularly recommend.

We create a unique **Deployment Correlation ID** ourselves:

```text
DEPLOYMENT_ID=20260909-001234-34255678413
```

Then every component uses it:

```text
GitHub
   │
   ├── Deployment ID
   │
   ▼
Terraform
   │
   ├── Terraform log
   │
   ▼
CloudFormation
   │
   ├── Stack name
   ├── Operation ID
   ├── Event IDs
   └── Resource IDs
```

So the final report has:

```text
Deployment ID
      │
      ├── GitHub Run ID
      │
      ├── Terraform execution
      │
      ├── CloudFormation Stack ID
      │
      ├── CloudFormation Operation ID
      │
      ├── Nested Stack IDs
      │
      └── Failed Resource
```

That gives us a **deployment trace**.

---

# One important correction

I would **not** try to make CloudFormation start a separate GitHub Actions job.

For example, don't design it like:

```text
Job 1
Terraform Apply

       ↓

Job 2
CloudFormation Monitor
```

because then Job 2 may start too late.

Instead:

```text
ONE GITHUB JOB
│
├── Terraform process
│
└── CloudFormation monitor process
        │
        └── runs concurrently
```

Or, even better for your implementation:

```text
PowerShell orchestration process
│
├── Start Terraform
│
├── Start CloudFormation monitoring
│
├── Capture both logs
│
├── Correlate both
│
└── Generate final report
```

This avoids the "Terraform finished → now let's investigate CloudFormation" problem you've been dealing with.

---

# We can save several logs

I recommend this structure:

```text
deployment-logs/
│
├── deployment-summary.md
│
├── terraform.log
│
├── terraform-error.log
│
├── cloudformation-events.json
│
├── cloudformation-events.log
│
├── cloudformation-failures.json
│
├── github-context.json
│
└── deployment-metadata.json
```

For example:

### `deployment-metadata.json`

```json
{
  "deployment_id": "20260909-001234-34255678413",
  "github_run_id": "34255678413",
  "region": "us-east-1",
  "stack_name": "hybridiaclab-dev-MainStack",
  "terraform": "running",
  "cloudformation_operation_id": "..."
}
```

Then the final report can use those files.

---

# The diagnostic engine

At the end we don't simply say:

```text
CloudFormation FAILED
```

We make the script analyze the evidence.

For example:

```text
Terraform:
    UPDATE_FAILED

CloudFormation:
    UPDATE_ROLLBACK_COMPLETE

CloudFormation resource:
    AWS::EKS::Nodegroup

CloudFormation reason:
    NodeCreationFailure

GitHub:
    Terraform Apply step FAILED
```

The diagnostic engine concludes:

```text
ROOT CAUSE:
EKS NodeGroup provisioning failure.

NOT ROOT CAUSE:
Terraform.

CHAIN:

Terraform
   ↓
CloudFormation Stack Update
   ↓
EKS NodeGroup Creation
   ↓
NodeCreationFailure
   ↓
CloudFormation rollback
   ↓
Terraform reports failure
   ↓
GitHub job fails
```

That is the kind of report you want for a professional DevOps portfolio.

---

# We can also distinguish root cause vs consequence

This is very important.

Suppose CloudFormation reports:

```text
EKSNodeGroup CREATE_FAILED
```

and Terraform says:

```text
Error waiting for CloudFormation stack:
UPDATE_ROLLBACK_COMPLETE
```

A naïve monitor might report:

> Terraform failed.

Our diagnostic system would say:

> **Terraform failure is a consequence. The root cause is the CloudFormation EKS NodeGroup provisioning failure.**

That's exactly the distinction you're asking for.

---

# We can eventually make it even smarter

The final report could classify errors:

```text
CATEGORY
────────────────────────
IAM / Permissions
CloudFormation
EKS
EC2
VPC / Networking
Security Groups
CloudFormation Nested Stack
Terraform
AWS API
Timeout
Dependency
Configuration
```

For example:

```text
Error Category:
    IAM / Permissions

Likely Root Cause:
    iam:PassRole permission denied

Failed Resource:
    AWS::IAM::Role

Terraform:
    aws_cloudformation_stack.main

Diagnosis:
    CloudFormation execution role attempted to
    pass an IAM role without sufficient permission.
```

Or:

```text
Error Category:
    EKS / Networking

Root Cause:
    Worker nodes failed to join cluster.

Evidence:
    NodeCreationFailure

Likely Areas:
    - Cluster security group
    - Node IAM role
    - Subnet routing
    - NAT connectivity
    - EKS endpoint configuration
```

Notice that the report can distinguish **confirmed evidence** from **possible causes**. That's important; we should never pretend an inferred cause is proven.

---

# The complete pipeline I'd build for you

```text
                         GITHUB
                           │
                           ▼
                 ┌──────────────────┐
                 │ GitHub Actions    │
                 │ Deployment Job    │
                 └────────┬─────────┘
                          │
                          ▼
                  DEPLOYMENT ID
                          │
             ┌────────────┴────────────┐
             │                         │
             ▼                         ▼
       TERRAFORM APPLY          CFN MONITOR
             │                         │
             │                         ▼
             │                 MainStack Operation
             │                         │
             │                 ┌───────┴───────┐
             │                 ▼               ▼
             │             Nested Stack     Resources
             │                               │
             │                               ▼
             │                         Event Stream
             │
             ▼
       terraform.log
             │
             │
             └──────────────┬──────────────┘
                            ▼
                   CORRELATION ENGINE
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
          GitHub Log    Terraform Log   CFN Log
              │             │             │
              └─────────────┼─────────────┘
                            ▼
                    ROOT CAUSE ANALYSIS
                            │
                            ▼
                  deployment-summary.md
                            │
                            ▼
                    GitHub Artifact
```

---

# And the final GitHub artifact

I strongly recommend uploading the complete report as a **GitHub Actions artifact**.

Then every deployment has:

```text
Deployment #34255678413
│
└── deployment-report/
    │
    ├── deployment-summary.md
    ├── terraform.log
    ├── cloudformation-events.log
    ├── cloudformation-events.json
    ├── cloudformation-failures.json
    └── deployment-metadata.json
```

So months later you can open a failed GitHub run and download the exact diagnostic evidence.

---

## So yes — your idea is technically sound

But I would structure it as:

**GitHub Run ID + our Deployment ID + Terraform process + CloudFormation Stack/Operation IDs + event history + final correlation engine.**

And **not** as "start another GitHub job and wait."

The monitor should be **concurrent**, the logs should be **persisted**, and the final stage should perform **evidence-based correlation** and produce a human-readable root-cause report.

For your lab, I would build this as a **single reusable PowerShell deployment-monitoring framework**, with your Step 15 calling it. That will be much cleaner than continuing to grow one enormous YAML `run:` block.

Yes. Before generating the code, I would make **a few architectural decisions first**. These will make the solution much more professional and prevent us from rebuilding Step 15 again later.

The good news is that AWS now gives us exactly the primitive we need: CloudFormation operations have unique **Operation IDs**, and `describe-events` can retrieve events for a specific operation and even filter only failed events. ([AWS Documentation][1]) Terraform also has a machine-readable JSON event stream for long-running `apply` operations, so we can capture structured Terraform events instead of trying to parse human-readable text. ([HashiCorp Developer][2])

## 1. I recommend one "Deployment Correlation ID"

Don't rely only on GitHub's run ID.

At the beginning:

```text
DEPLOYMENT_ID
    │
    ├── GitHub Run ID
    ├── GitHub Job
    ├── Terraform Process ID
    ├── CloudFormation Stack ID
    ├── CloudFormation Operation ID
    ├── Nested Stack IDs
    └── Timestamp
```

Example:

```text
DEPLOYMENT_ID=20260909-0010-34255678413
```

This becomes the **master correlation key** for our report.

---

# 2. Terraform should run with structured JSON output

This is important.

Rather than trying to scrape:

```text
aws_cloudformation_stack.main: Still creating...
```

we can capture Terraform's machine-readable UI stream.

Terraform documents that `terraform apply -json` emits newline-delimited JSON messages as events occur, including resource apply start/completion and diagnostics. ([HashiCorp Developer][2])

So we'll have:

```text
Terraform
    │
    ├── Human-readable live console
    │
    └── terraform.jsonl
```

The `.jsonl` file becomes evidence for our final analyzer.

---

# 3. CloudFormation gets its own live event stream

At the same time:

```text
CloudFormation Monitor
        │
        ▼
discover operation
        │
        ▼
Operation ID
        │
        ▼
describe-events
        │
        ├── progress events
        ├── validation errors
        ├── provisioning errors
        └── failures
```

AWS specifically documents that CloudFormation `OperationId` represents a discrete stack operation and that events can be filtered by that operation. ([AWS Documentation][1])

This is much better than repeatedly querying all historical stack events.

---

# 4. Use event IDs to prevent duplicate logs

This is one of the most important design decisions.

Suppose CloudFormation returns:

```text
EventId = abc123
```

We store it.

Next polling cycle:

```text
abc123
def456
ghi789
```

We already saw:

```text
abc123
```

so we print only:

```text
def456
ghi789
```

Therefore GitHub receives a clean stream:

```text
[00:00:03] VPC          CREATE_IN_PROGRESS
[00:00:08] VPC          CREATE_COMPLETE
[00:00:11] EKS          CREATE_IN_PROGRESS
[00:00:47] EKS          CREATE_COMPLETE
```

instead of:

```text
VPC CREATE_IN_PROGRESS
VPC CREATE_COMPLETE

VPC CREATE_IN_PROGRESS
VPC CREATE_COMPLETE
EKS CREATE_IN_PROGRESS

VPC CREATE_IN_PROGRESS
VPC CREATE_COMPLETE
EKS CREATE_IN_PROGRESS
...
```

---

# 5. Monitor nested stacks automatically

I strongly recommend this.

Your architecture isn't just:

```text
MainStack
```

It can be:

```text
MainStack
   │
   ├── VPCStack
   ├── EKSStack
   ├── ECSStack
   ├── EC2Stack
   ├── IAMStack
   └── ...
```

The monitor should discover nested stacks and add them to the monitoring set.

So:

```text
Stack Monitor
     │
     ├── MainStack
     │
     ├── NestedStack A
     │
     ├── NestedStack B
     │
     └── NestedStack C
```

That will be particularly valuable for diagnosing your EKS failures.

---

# 6. Don't make the monitor determine success by itself

The monitor is an **observer**.

Terraform is the deployment engine.

Therefore:

```text
Terraform exit code
        +
CloudFormation final state
        +
Failure analysis
        ↓
Final Deployment Result
```

For example:

### Scenario A

```text
Terraform = 1
CloudFormation = UPDATE_FAILED

Result = FAILED
```

### Scenario B

```text
Terraform = 0
CloudFormation = UPDATE_COMPLETE

Result = SUCCESS
```

### Scenario C

```text
Terraform = 1
CloudFormation = UPDATE_ROLLBACK_COMPLETE
```

Result:

```text
FAILED
```

with:

```text
Root cause = CloudFormation resource failure
Terraform = reporting the consequence
```

---

# 7. We should capture GitHub metadata

The report should know:

```text
GitHub Repository
GitHub Workflow
GitHub Job
GitHub Run ID
GitHub Attempt
Branch
Commit SHA
Actor
Runner OS
Terraform version
AWS CLI version
AWS Region
```

For example:

```text
GitHub Repository:
awsrmmustansarjavaid/aws-hybrid-iac-lab

Workflow:
Terraform Infrastructure Deployment

Run:
34255678413

Attempt:
1

Commit:
abc123...

Region:
us-east-1
```

This makes the report traceable.

---

# 8. Separate "evidence" from "diagnosis"

This is **very important** if we want a professional report.

The analyzer should never say:

> Root cause is X

unless the evidence supports it.

Instead:

```text
CONFIRMED EVIDENCE
────────────────────────

CloudFormation:
EKSNodeGroup CREATE_FAILED

Reason:
NodeCreationFailure

Terraform:
CloudFormation stack update failed

GitHub:
Terraform Apply step exited with code 1
```

Then:

```text
DIAGNOSIS
────────────────────────

Confirmed root cause:
EKS NodeGroup provisioning failure.

Terraform was not the original failure.

Terraform failure was a consequence of the
CloudFormation operation failing.
```

Then:

```text
LIKELY CONTRIBUTING AREAS
────────────────────────

- EKS node IAM role
- subnet connectivity
- security groups
- NAT/network connectivity
- node bootstrap
```

That distinction makes the report much more trustworthy.

---

# 9. Build a failure-chain timeline

I would absolutely include this.

Example:

```text
12:01:02  GitHub job started
12:01:08  Terraform apply started
12:01:12  CloudFormation UPDATE_STACK started
12:01:13  Operation ID discovered
12:01:15  VPC UPDATE_COMPLETE
12:01:21  EKS Cluster UPDATE_COMPLETE
12:01:27  EKS NodeGroup CREATE_IN_PROGRESS
12:03:14  EKS NodeGroup CREATE_FAILED
12:03:15  CloudFormation rollback started
12:04:51  CloudFormation rollback complete
12:04:53  Terraform received failure
12:04:54  GitHub step failed
```

This is **far more useful than separate logs** because you can see exactly what happened chronologically.

---

# 10. Keep raw logs AND summarized logs

Don't throw anything away.

I recommend:

```text
deployment-report/
│
├── README.md
│
├── deployment-summary.md       ← human report
│
├── deployment-metadata.json    ← correlation data
│
├── timeline.log                ← chronological events
│
├── terraform.jsonl             ← raw Terraform events
│
├── terraform.log               ← console output
│
├── cloudformation-events.json  ← raw CFN data
│
├── cloudformation-events.log   ← readable CFN events
│
├── cloudformation-failures.json
│
└── diagnosis.json              ← structured analysis
```

GitHub Actions artifacts are specifically designed to preserve logs, test results, failures, and other outputs after a workflow finishes. ([GitHub Docs][3])

---

# 11. Upload the complete report as ONE artifact

At the end:

```text
GitHub Actions
      │
      ▼
deployment-report/
      │
      ├── summary
      ├── Terraform
      ├── CloudFormation
      ├── timeline
      └── diagnosis
      │
      ▼
GitHub Artifact
```

Then your failed GitHub run will have something like:

```text
📦 deployment-diagnostics-34255678413
```

You can download the entire investigation later.

---

# 12. Don't poll CloudFormation excessively

I recommend something like:

```text
Normal:
2–3 second polling

API error:
exponential backoff

No stack yet:
short retry

Stack found:
normal monitoring

Operation completed:
stop polling immediately
```

So we don't do:

```text
Start-Sleep 30
```

everywhere.

Instead:

```text
2 sec
2 sec
2 sec
2 sec
...
```

and stop immediately when the operation reaches its terminal state.

---

# 13. Add a safety timeout

Real-time doesn't mean infinite.

For example:

```text
Deployment timeout:
60 minutes
```

If Terraform is still running after the configured maximum:

```text
MONITOR WARNING

Deployment exceeded monitoring timeout.

Terraform:
STILL RUNNING

CloudFormation:
IN_PROGRESS

Monitor:
STOPPING

Reason:
Safety timeout reached.
```

But importantly, we should make this configurable.

---

# 14. The final analyzer should understand error relationships

This is the part I think will make your project stand out.

Example:

```text
CloudFormation:

EKSNodeGroup
CREATE_FAILED
NodeCreationFailure
```

Terraform:

```text
aws_cloudformation_stack.eks
Error waiting for stack
```

GitHub:

```text
Terraform Apply step failed
```

The analyzer should understand:

```text
                EKS NodeGroup
                     │
                     ▼
             CREATE_FAILED
                     │
                     ▼
           CloudFormation rollback
                     │
                     ▼
            Terraform failure
                     │
                     ▼
             GitHub failure
```

Therefore:

> **Root cause = EKS NodeGroup provisioning failure**

rather than incorrectly reporting:

> Root cause = Terraform.

---

# 15. One more professional feature: evidence confidence

I recommend three categories:

```text
CONFIRMED
LIKELY
UNKNOWN
```

Example:

```text
ROOT CAUSE
CONFIRMED

EKS NodeGroup failed with:
NodeCreationFailure
```

Then:

```text
POSSIBLE CONTRIBUTING FACTORS
LIKELY

- Node IAM permissions
- Network connectivity
- Security group configuration
```

This prevents our automated report from making dangerous assumptions.

---

# 16. I would NOT use AI/LLM inside the GitHub deployment initially

This is an important recommendation.

Don't make:

```text
GitHub
  ↓
AI
  ↓
"probably EKS problem"
```

part of the deployment's critical path.

Instead build a deterministic diagnostic engine:

```text
CloudFormation evidence
        +
Terraform evidence
        +
GitHub evidence
        +
AWS resource metadata
        ↓
Deterministic rules
        ↓
Diagnosis
```

Later, if you want, we can add AI **after the deployment** to explain the collected evidence.

But the deployment should never depend on an AI service to decide whether infrastructure succeeded.

---

# 17. My final architecture recommendation

I would build your system in **five components**:

```text
┌─────────────────────────────────────────────┐
│              GITHUB ACTIONS                │
│                                             │
│  Workflow / Job / Run / Commit / Branch    │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│         DEPLOYMENT ORCHESTRATOR             │
│                                             │
│  Deployment ID                              │
│  Terraform process                          │
│  CloudFormation monitor                     │
│  Process synchronization                    │
└───────────────┬───────────────┬─────────────┘
                │               │
                ▼               ▼
       ┌──────────────┐  ┌──────────────────┐
       │  TERRAFORM   │  │ CLOUDFORMATION   │
       │              │  │                  │
       │ JSON events  │  │ Operation ID     │
       │ Exit code    │  │ Stack events     │
       │ Errors       │  │ Resource events  │
       └──────┬───────┘  └────────┬─────────┘
              │                   │
              └─────────┬─────────┘
                        ▼
             ┌──────────────────────┐
             │ CORRELATION ENGINE   │
             │                      │
             │ Timeline             │
             │ Failure detection    │
             │ Root cause rules     │
             │ Evidence correlation │
             └──────────┬───────────┘
                        │
                        ▼
             ┌──────────────────────┐
             │ DEPLOYMENT REPORT    │
             │                      │
             │ summary.md           │
             │ timeline.log         │
             │ diagnosis.json       │
             │ raw evidence         │
             └──────────┬───────────┘
                        │
                        ▼
                 GITHUB ARTIFACT
```

### My recommendation: **build this architecture before writing Step 15.**

And one especially important point: **we should not make Step 15 itself a 500-line PowerShell block.** I would put the intelligence into a reusable script such as:

```text
scripts/
└── deployment-monitor/
    ├── Start-Deployment.ps1
    ├── Monitor-CloudFormation.ps1
    ├── Capture-Terraform.ps1
    ├── Correlate-Deployment.ps1
    ├── Generate-Report.ps1
    └── rules/
        └── failure-rules.json
```

Then GitHub Actions only orchestrates it.

That gives you something much closer to a **real DevOps deployment observability framework**, rather than a workaround for one failing workflow.

[1]: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-events.html?utm_source=chatgpt.com "describe-events — AWS CLI 2.36.40 Command Reference"
[2]: https://developer.hashicorp.com/terraform/internals/machine-readable-ui?utm_source=chatgpt.com "Machine-readable output reference | Terraform | HashiCorp Developer"
[3]: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts?utm_source=chatgpt.com "Workflow artifacts - GitHub Docs"

Yes. I’ve now built the first complete version around the architecture we agreed on.

I tailored it to your **AWS Hybrid IaC Lab**, including the Terraform → root CloudFormation stack → nested CloudFormation stacks → AWS resources flow you already use. Your project specifically has Terraform owning the root CloudFormation stack while CloudFormation owns resources such as VPC, ECR, Lambda, API Gateway, CloudFront, EC2, EKS, and RDS. 

### What this version does

```text
GitHub Actions
      │
      ▼
Deployment ID
      │
      ├───────────────┐
      ▼               ▼
Terraform        CloudFormation
   Apply             Monitor
      │               │
      │               ├── Operation ID
      │               ├── Nested stacks
      │               ├── Event IDs
      │               ├── Failures
      │               └── Reasons
      │
      └──────────┬──────────┘
                 ▼
          Correlation Engine
                 │
                 ▼
        Final Diagnostic Report
                 │
                 ▼
       GitHub Actions Artifact
```

This uses Terraform's machine-readable `-json` stream, which emits newline-delimited JSON events during long-running operations such as `apply`. ([HashiCorp Developer][1])

For CloudFormation, the monitor uses the newer operation-oriented `describe-events` API, including `OperationId` and `FailedEvents=true`, which AWS specifically documents for focusing on individual stack operations and troubleshooting failed operations. ([AWS Documentation][2])

## Download the complete framework

[Download the Deployment Monitoring Framework](sandbox:/tmp/deployment-monitor-framework.zip)

It contains:

```text
deployment-monitor-framework.zip
│
├── Start-Deployment.ps1
├── Monitor-CloudFormation.ps1
├── Generate-Report.ps1
├── failure-rules.json
└── STEP-15.yml
```

---

# 1. `Start-Deployment.ps1`

This is the **orchestrator**.

Its job is to:

1. Create Deployment ID.
2. Capture GitHub metadata.
3. Capture existing CloudFormation Operation IDs.
4. Start CloudFormation monitoring.
5. Start Terraform `apply -json`.
6. Stream Terraform events to GitHub.
7. Wait for both.
8. Generate the final report.
9. Return the correct GitHub exit code.

The important part is that CloudFormation monitoring starts **before Terraform**:

```powershell
# Start CloudFormation monitor first.
$monitorProcess = Start-Process `
    -FilePath 'pwsh' `
    -ArgumentList $monitorArgs `
    -WorkingDirectory $repoRoot `
    -PassThru
```

Then Terraform starts:

```powershell
$tfArgs = @('apply','-json')

if ($AutoApprove) {
    $tfArgs += '-auto-approve'
}
```

So the architecture is genuinely concurrent:

```text
00:00
 │
 ├── CloudFormation Monitor START
 │
 └── Terraform Apply START
       │
       ├── Terraform events
       │
       └── CloudFormation events
```

---

# 2. Real-time Terraform monitoring

Terraform is run with:

```powershell
terraform apply -json
```

Terraform's documented machine-readable output contains events such as:

```text
version
planned_change
change_summary
apply_start
apply_progress
apply_complete
diagnostic
outputs
```

and emits them as events occur. ([HashiCorp Developer][1])

The framework saves:

```text
terraform.jsonl
```

while also printing a clean stream to GitHub:

```text
TF   | module.eks: Creating...
TF   | module.eks: Still creating...
TF   | module.eks: Creation complete
TF   | Apply complete!
```

---

# 3. Real-time CloudFormation monitoring

The CloudFormation monitor continuously discovers:

```text
MainStack
    │
    ├── Operation ID
    │
    ├── Nested Stack
    │      └── Operation ID
    │
    ├── Nested Stack
    │      └── Operation ID
    │
    └── Nested Stack
           └── Operation ID
```

Then it queries:

```powershell
aws cloudformation describe-events `
    --operation-id <OPERATION_ID>
```

rather than repeatedly dumping the entire historical event list.

AWS documents `OperationId` as the unique identifier for a discrete CloudFormation stack operation. ([AWS Documentation][2])

---

# 4. Duplicate event protection

The monitor keeps a set of:

```text
EventId
```

So if AWS returns:

```text
ABC
DEF
GHI
```

and we already displayed:

```text
ABC
```

we only display:

```text
DEF
GHI
```

This gives you a clean GitHub stream.

---

# 5. The logs generated

After deployment:

```text
deployment-logs/
│
├── deployment-metadata.json
│
├── terraform.jsonl
│
├── terraform.log
│
├── cloudformation-events.jsonl
│
├── cloudformation-events.log
│
├── cloudformation-failures.json
│
├── cloudformation-metadata.json
│
├── diagnosis.json
│
└── deployment-summary.md
```

The most important file for humans is:

```text
deployment-summary.md
```

The most important files for evidence are:

```text
terraform.jsonl
cloudformation-events.jsonl
cloudformation-failures.json
```

---

# 6. The final report

The generated report is designed around exactly what you requested.

It contains:

```text
Deployment ID
GitHub Run
GitHub Workflow
GitHub Job
Commit
Terraform exit code
CloudFormation stack
CloudFormation Operation IDs
Nested stacks
CloudFormation failures
Failure reason
Root cause
Terraform relationship
Failure chain
Recommendations
Evidence files
```

For example:

```text
# Deployment Diagnostic Report

Deployment ID:
20260909-001234-34255678413

Final Result:
FAILED

Category:
EKS / NODE PROVISIONING

## Terraform

Exit code:
1

## CloudFormation

Root stack:
hybridiaclab-dev-MainStack

Operations discovered:
3

Events captured:
47

Failed events:
1

## Confirmed Failure Evidence

- CloudFormation failure:
  Resource=EKSNodeGroup
  Reason=NodeCreationFailure

## Root Cause Statement

CloudFormation reported an EKS/node provisioning failure.

## Error Relationship

CONFIRMED ROOT CAUSE IS IN
CLOUDFORMATION/AWS RESOURCE PROVISIONING;

TERRAFORM/GITHUB FAILURE IS A CONSEQUENCE.

## Failure Chain

CloudFormation resource failure
        ↓
CloudFormation rollback
        ↓
Terraform observes failed stack operation
        ↓
GitHub step fails
```

That is the important distinction we discussed.

---

# 7. It does NOT automatically blame Terraform

For example, suppose this happens:

```text
CloudFormation:

EKSNodeGroup
CREATE_FAILED

Reason:
NodeCreationFailure
```

and then:

```text
Terraform:

Error waiting for CloudFormation stack
```

The report will identify:

```text
ROOT CAUSE:
CloudFormation/AWS resource provisioning
```

rather than incorrectly saying:

```text
ROOT CAUSE:
Terraform
```

Terraform is recognized as the **downstream failure**.

---

# 8. IAM errors are classified

For example:

```text
AccessDenied
Unauthorized
iam:PassRole
not authorized
```

gets classified as:

```text
IAM / PERMISSIONS
```

and the report can say:

```text
Inspect the CloudFormation execution role and the
GitHub/Terraform caller permissions.
```

This is particularly useful because you've already been troubleshooting CloudFormation execution-role and `PassRole` issues in this lab.

---

# 9. EKS failures are classified

For:

```text
NodeCreationFailure
node failed to join
EKS
Kubernetes
```

the report classifies:

```text
EKS / NODE PROVISIONING
```

and recommends investigating:

```text
Node IAM
Subnet routing
NAT
Security groups
Bootstrap
Cluster endpoint connectivity
```

Again, these are **investigation areas**, not falsely claimed root causes.

---

# 10. GitHub artifact

The included Step 16 uploads:

```yaml
- name: Step 16 - Upload Deployment Diagnostic Report
  if: ${{ always() }}
  uses: actions/upload-artifact@v4
  with:
    name: deployment-diagnostics-${{ github.run_id }}
    path: deployment-logs/
    if-no-files-found: warn
    retention-days: 30
```

GitHub officially supports uploading a directory as a workflow artifact. ([GitHub Docs][3])

Therefore even if Step 15 fails, Step 16 still attempts to upload:

```text
📦 deployment-diagnostics-34255678413
```

---

# 11. Important: don't delete your existing Step 15 yet

I recommend **first putting the new scripts into your repository**, but don't immediately destroy your existing workflow.

Your current lab has had several iterations around:

```text
TF_AUTO_APPROVE
TF_WORKING_DIRECTORY
terraform.yml
CloudFormation MainStack
GitHub OIDC
Terraform backend
```

so we should integrate this carefully.

Your previous workflow context also indicates the root stack is:

```text
hybridiaclab-dev-MainStack
```

and the Terraform configuration manages the root CloudFormation stack. 

---

# 12. Recommended repository layout

I recommend:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── infrastructure/
│   ├── cloudformation/
│   │   └── nested/
│   │
│   └── terraform/
│
├── scripts/
│   └── deployment-monitor/
│       │
│       ├── Start-Deployment.ps1
│       ├── Monitor-CloudFormation.ps1
│       ├── Generate-Report.ps1
│       └── failure-rules.json
│
└── deployment-logs/
       # generated locally/CI
```

I would add this to `.gitignore`:

```gitignore
# Deployment monitoring output
deployment-logs/
```

We don't want every deployment's logs committed to Git.

GitHub Actions artifacts are the correct place for those run-specific logs.

---

# 13. One thing I want to improve before you run it

The current framework is the **first implementation**, not something I would blindly call production-ready yet.

There is one enhancement I recommend before your first real test:

### Use the `failure-rules.json` file directly from the report engine.

Right now the report engine has the initial rules embedded in PowerShell **and** we have created the separate rules file.

I want the final version to load:

```text
failure-rules.json
```

dynamically.

Then you can eventually add:

```json
{
  "category": "EKS / NODE PROVISIONING",
  "patterns": [
    "NodeCreationFailure",
    "failed to join",
    "bootstrap"
  ]
}
```

without editing the PowerShell engine.

That will make the monitoring framework much easier to maintain.

---

# 14. One more important safety feature

The framework currently preserves Terraform's real exit code.

So:

```text
Terraform = 1
CloudFormation = 0
```

results in:

```text
GitHub = FAILED
```

And:

```text
Terraform = 0
CloudFormation failure detected
```

also results in:

```text
GitHub = FAILED
```

That prevents a monitoring script from accidentally turning a failed infrastructure deployment into a green GitHub run.

---

## What you now have

You've moved from:

```text
Terraform
   ↓
wait
   ↓
failure
   ↓
look at CloudFormation manually
```

to:

```text
                   GitHub
                     │
                     ▼
               Deployment ID
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
      Terraform             CloudFormation
        JSONL                 Operation ID
          │                     │
          │                     ├── MainStack
          │                     ├── Nested stacks
          │                     └── Resource events
          │
          └──────────┬──────────┘
                     ▼
              Correlation
                     │
                     ▼
             Root Cause Analysis
                     │
                     ▼
             deployment-summary.md
                     │
                     ▼
              GitHub Artifact
```

**This is the architecture I recommend we continue with.**

The next step should be **integration with your exact current `terraform.yml`**, especially because your existing workflow has custom environment variables and Step 15 structure. We should replace only the existing Step 15/diagnostic section and leave the rest of your workflow untouched. 

[1]: https://developer.hashicorp.com/terraform/internals/machine-readable-ui?utm_source=chatgpt.com "Machine-readable output reference | Terraform | HashiCorp Developer"
[2]: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-events.html?utm_source=chatgpt.com "describe-events — AWS CLI 2.36.40 Command Reference"
[3]: https://docs.github.com/en/actions/tutorials/store-and-share-data?utm_source=chatgpt.com "Store and share data with workflow artifacts - GitHub Docs"

You're right. I only gave you the framework/archive reference instead of putting **all five files directly in the answer**.

Below is the complete code, with comments, so you can copy it into your repository. I also want to correct one thing from the earlier version: **the CloudFormation monitor must not depend on `LastOperations` being available in `describe-stacks`**. We'll make the implementation more robust by discovering the new operation through CloudFormation events and stack state, while preserving baseline IDs where available.

Your existing architecture has Terraform managing the root CloudFormation stack, with nested stacks underneath it, so this design fits that model. 

---

# 1. Repository structure

Create:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── infrastructure/
│   └── terraform/
│
├── deployment-monitor-systam/
│       ├── Start-Deployment.ps1
│       ├── Monitor-CloudFormation.ps1
│       ├── Generate-Report.ps1
│       └── failure-rules.json
│
└── deployment-logs/
```

I would also make a few important corrections to the previous version before you use it:

* The monitor will use your new root-level directory.
* It will discover **CloudFormation Operation IDs** from `LastOperations`, which AWS now exposes through `describe-stacks`. ([AWS Documentation][1])
* It will use `describe-events --operation-id` for operation-level diagnostics and failed-event filtering. ([AWS Documentation][2])
* It will still keep `describe-stack-events` as a fallback because those events include `OperationId` as well. ([AWS Documentation][3])
* It will monitor nested stacks recursively.
* Terraform will remain authoritative for the final process exit code.
* We will **not** kill the monitor after an arbitrary 5/20 seconds. It will receive a stop signal and finish after CloudFormation reaches a terminal state.
* It will create a final diagnosis comparing Terraform + CloudFormation evidence.
* All diagnostic files will be placed under `deployment-logs/`.
* Step 15 will reference `deployment-monitor-systam/`.

So I recommend replacing the previous implementation with the following **final version**.

---

# 1. Final directory structure

Your repository should look like this:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── deployment-monitor-systam/
│   │
│   ├── failure-rules.json
│   ├── Monitor-CloudFormation.ps1
│   ├── Start-Deployment.ps1
│   ├── Generate-Report.ps1
│   └── README.md
│
├── infrastructure/
│   ├── cloudformation/
│   │   ├── main.yaml
│   │   └── nested/
│   │       ├── eks.yaml
│   │       ├── vpc.yaml
│   │       └── ...
│   │
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── ...
│
└── deployment-logs/
    └── created automatically
```

You **do not** need to manually create `deployment-logs`.



Add this to `.gitignore`:

```gitignore
# ============================================================
# DEPLOYMENT MONITORING OUTPUT
# ============================================================

deployment-logs/
```

---

# 2. `failure-rules.json`

Create:

```text
scripts/deployment-monitor/failure-rules.json
```

```json
{
  "version": "1.0",
  "rules": [
    {
      "category": "IAM / PERMISSIONS",
      "patterns": [
        "AccessDenied",
        "AccessDeniedException",
        "Unauthorized",
        "not authorized",
        "iam:",
        "PassRole",
        "permission",
        "explicit deny"
      ],
      "recommendations": [
        "Inspect the GitHub Actions AWS role.",
        "Inspect the CloudFormation execution role.",
        "Check iam:PassRole permissions.",
        "Check whether an explicit IAM Deny is blocking the operation."
      ]
    },
    {
      "category": "EKS / NODE PROVISIONING",
      "patterns": [
        "NodeCreationFailure",
        "node.*join",
        "failed to join",
        "EKS",
        "Kubernetes",
        "bootstrap"
      ],
      "recommendations": [
        "Inspect the EKS node IAM role.",
        "Inspect subnet routing and NAT connectivity.",
        "Inspect EKS cluster and node security groups.",
        "Inspect EKS endpoint accessibility.",
        "Inspect node bootstrap configuration."
      ]
    },
    {
      "category": "NETWORKING",
      "patterns": [
        "Subnet",
        "Route",
        "route table",
        "VPC",
        "network",
        "connectivity",
        "connection",
        "timeout",
        "NAT",
        "Internet"
      ],
      "recommendations": [
        "Inspect VPC and subnet configuration.",
        "Inspect route tables.",
        "Inspect NAT gateway connectivity.",
        "Inspect security groups.",
        "Inspect network ACLs."
      ]
    },
    {
      "category": "RESOURCE NAMING / EXISTENCE",
      "patterns": [
        "already exists",
        "AlreadyExists",
        "already exist",
        "duplicate",
        "Resource already exists"
      ],
      "recommendations": [
        "Check whether the resource already exists.",
        "Check whether the resource is managed by another stack.",
        "Check account-wide or region-wide naming constraints."
      ]
    },
    {
      "category": "CLOUDFORMATION VALIDATION / CONFIGURATION",
      "patterns": [
        "validation",
        "ValidationError",
        "Invalid",
        "malformed",
        "Template",
        "parameter",
        "property",
        "capabilities"
      ],
      "recommendations": [
        "Validate the CloudFormation template.",
        "Inspect resource properties.",
        "Inspect parameter values.",
        "Check required CloudFormation capabilities."
      ]
    },
    {
      "category": "CLOUDFORMATION ROLLBACK",
      "patterns": [
        "ROLLBACK",
        "UPDATE_ROLLBACK",
        "rollback"
      ],
      "recommendations": [
        "Identify the first CREATE_FAILED or UPDATE_FAILED resource.",
        "Do not treat the rollback status itself as the root cause.",
        "Inspect the earliest failed resource event."
      ]
    }
  ]
}
```

---

# 3. `Monitor-CloudFormation.ps1`

This is the **real-time CloudFormation monitor**.

Create:

```text
scripts/deployment-monitor/Monitor-CloudFormation.ps1
```

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [int]$PollSeconds = 3,

    [int]$TimeoutMinutes = 90,

    [string[]]$BaselineOperationIds = @()
)

# ============================================================
# MONITOR-CLOUDFORMATION.PS1
#
# PURPOSE:
#   Real-time CloudFormation monitoring.
#
# FEATURES:
#   - Watches the root CloudFormation stack.
#   - Discovers nested CloudFormation stacks.
#   - Discovers CloudFormation operation IDs.
#   - Captures new events only.
#   - Prevents duplicate events.
#   - Captures failed events.
#   - Writes JSONL evidence.
#   - Writes human-readable logs.
#   - Returns:
#         0  = success
#         10 = CloudFormation failure detected
#         2  = monitoring timeout
#
# IMPORTANT:
#   This script is an OBSERVER.
#   It does not execute Terraform.
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Prepare output directory
# ------------------------------------------------------------

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDirectory |
    Out-Null

$eventsJsonl = Join-Path $OutputDirectory "cloudformation-events.jsonl"
$eventsLog   = Join-Path $OutputDirectory "cloudformation-events.log"
$failuresJson = Join-Path $OutputDirectory "cloudformation-failures.json"
$metadataJson = Join-Path $OutputDirectory "cloudformation-metadata.json"

# ------------------------------------------------------------
# CloudFormation terminal states
# ------------------------------------------------------------

$terminalStatuses = @(
    "CREATE_COMPLETE",
    "UPDATE_COMPLETE",
    "DELETE_COMPLETE",
    "ROLLBACK_COMPLETE",
    "UPDATE_ROLLBACK_COMPLETE",
    "UPDATE_ROLLBACK_FAILED",
    "ROLLBACK_FAILED",
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED"
)

# ------------------------------------------------------------
# Failure states
#
# NOTE:
# ROLLBACK_COMPLETE is included because a stack that rolled
# back after CREATE failure represents a failed deployment.
# ------------------------------------------------------------

$failureStatuses = @(
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED",
    "ROLLBACK_FAILED",
    "UPDATE_ROLLBACK_FAILED",
    "ROLLBACK_COMPLETE"
)

# ------------------------------------------------------------
# Runtime state
# ------------------------------------------------------------

$seenEventIds = @{}

$operations = @{}

$stacks = @{}

$failedEvents = @()

$startedAt = Get-Date

$deadline = $startedAt.AddMinutes($TimeoutMinutes)

$timedOut = $false

# ============================================================
# FUNCTION: Invoke-AwsJson
#
# Executes AWS CLI and converts JSON into PowerShell objects.
# ============================================================

function Invoke-AwsJson {

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $raw = & aws @Arguments 2>&1

    if ($LASTEXITCODE -ne 0) {

        throw ($raw -join "`n")
    }

    if (-not $raw) {

        return $null
    }

    return ($raw -join "`n" | ConvertFrom-Json)
}

# ============================================================
# FUNCTION: Write-EventLog
#
# Writes the event both to:
#
#   1. GitHub Actions console
#   2. cloudformation-events.log
# ============================================================

function Write-EventLog {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $timestamp =
        (Get-Date).ToUniversalTime().
        ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    $line = "[$timestamp] $Message"

    Add-Content `
        -Path $eventsLog `
        -Value $line

    Write-Host $line -ForegroundColor $Color
}

# ============================================================
# FUNCTION: Get-Stack
# ============================================================

function Get-Stack {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {

        $result = Invoke-AwsJson @(
            "cloudformation",
            "describe-stacks",
            "--stack-name",
            $Name,
            "--region",
            $Region,
            "--no-cli-pager",
            "--output",
            "json"
        )

        if ($result -and $result.Stacks.Count -gt 0) {

            return $result.Stacks[0]
        }

    }
    catch {

        return $null
    }

    return $null
}

# ============================================================
# FUNCTION: Register-Stack
# ============================================================

function Register-Stack {

    param(
        [Parameter(Mandatory = $true)]
        $Stack
    )

    if (-not $Stack) {
        return
    }

    $stackId = [string]$Stack.StackId

    if (-not [string]::IsNullOrWhiteSpace($stackId)) {

        if (-not $stacks.ContainsKey($stackId)) {

            $stacks[$stackId] = [ordered]@{
                StackName = [string]$Stack.StackName
                StackId   = $stackId
                Status    = [string]$Stack.StackStatus
                FirstSeen = (Get-Date).ToUniversalTime().ToString("o")
            }

            Write-EventLog `
                "STACK DISCOVERED | Name=$($Stack.StackName) | Status=$($Stack.StackStatus)" `
                Cyan
        }
    }
}

# ============================================================
# FUNCTION: Discover-NestedStacks
#
# CloudFormation nested stacks appear as:
#
# AWS::CloudFormation::Stack
#
# Their PhysicalResourceId is the nested stack ARN.
# ============================================================

function Discover-NestedStacks {

    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentStackName
    )

    $stack = Get-Stack -Name $CurrentStackName

    if (-not $stack) {

        return
    }

    Register-Stack -Stack $stack

    try {

        $resources = Invoke-AwsJson @(
            "cloudformation",
            "describe-stack-resources",
            "--stack-name",
            $stack.StackId,
            "--region",
            $Region,
            "--no-cli-pager",
            "--output",
            "json"
        )

        foreach ($resource in @($resources.StackResources)) {

            if (
                $resource.ResourceType -eq "AWS::CloudFormation::Stack" -and
                $resource.PhysicalResourceId
            ) {

                $nestedArn = [string]$resource.PhysicalResourceId

                $nestedStack = Get-Stack -Name $nestedArn

                if ($nestedStack) {

                    Register-Stack -Stack $nestedStack

                    # Recursively discover nested stacks.
                    Discover-NestedStacks `
                        -CurrentStackName $nestedArn
                }
            }
        }
    }
    catch {

        # Nested stack may not exist yet.
        # We simply retry during the next polling cycle.

        Write-EventLog `
            "NESTED STACK DISCOVERY WAITING | Parent=$CurrentStackName" `
            Yellow
    }
}

# ============================================================
# FUNCTION: Get-OperationEvents
#
# Uses CloudFormation's operation-aware event API.
# ============================================================

function Get-OperationEvents {

    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationId
    )

    try {

        return Invoke-AwsJson @(
            "cloudformation",
            "describe-events",
            "--operation-id",
            $OperationId,
            "--region",
            $Region,
            "--no-cli-pager",
            "--output",
            "json"
        )

    }
    catch {

        return $null
    }
}

# ============================================================
# FUNCTION: Discover-Operations
#
# CloudFormation can expose operation information through
# stack events.
#
# We use the latest operation-related events to discover
# operation IDs and then monitor those operations directly.
# ============================================================

function Discover-Operations {

    foreach ($stackRecord in @($stacks.Values)) {

        $stackId = [string]$stackRecord.StackId
        $stackName = [string]$stackRecord.StackName

        try {

            $events = Invoke-AwsJson @(
                "cloudformation",
                "describe-stack-events",
                "--stack-name",
                $stackId,
                "--region",
                $Region,
                "--no-cli-pager",
                "--output",
                "json"
            )

            foreach ($event in @($events.StackEvents)) {

                # Different AWS CLI/API versions can expose
                # operation information differently.
                #
                # Check the fields that are available.

                $possibleOperationIds = @()

                if ($event.OperationId) {

                    $possibleOperationIds += `
                        [string]$event.OperationId
                }

                if ($event.OperationID) {

                    $possibleOperationIds += `
                        [string]$event.OperationID
                }

                foreach ($operationId in $possibleOperationIds) {

                    if (
                        [string]::IsNullOrWhiteSpace($operationId)
                    ) {
                        continue
                    }

                    # Ignore operations that existed before
                    # this deployment.

                    if (
                        $BaselineOperationIds `
                        -contains $operationId
                    ) {
                        continue
                    }

                    if (-not $operations.ContainsKey($operationId)) {

                        $operations[$operationId] = [ordered]@{
                            StackName   = $stackName
                            StackId     = $stackId
                            OperationId = $operationId
                            FirstSeen   = (Get-Date).
                                ToUniversalTime().
                                ToString("o")
                        }

                        Write-EventLog `
                            "OPERATION DISCOVERED | Stack=$stackName | OperationId=$operationId" `
                            Green
                    }
                }
            }
        }
        catch {

            # Continue monitoring.
        }
    }
}

# ============================================================
# FUNCTION: Process-OperationEvents
# ============================================================

function Process-OperationEvents {

    foreach ($operationId in @($operations.Keys)) {

        $data = Get-OperationEvents `
            -OperationId $operationId

        if (-not $data) {
            continue
        }

        foreach ($event in @($data.OperationEvents)) {

            $eventId = [string]$event.EventId

            if (
                [string]::IsNullOrWhiteSpace($eventId)
            ) {
                continue
            }

            # ------------------------------------------------
            # Duplicate protection.
            #
            # The same event can be returned repeatedly.
            # We print it only once.
            # ------------------------------------------------

            if ($seenEventIds.ContainsKey($eventId)) {
                continue
            }

            $seenEventIds[$eventId] = $true

            # ------------------------------------------------
            # Save raw structured event.
            # ------------------------------------------------

            (
                $event |
                ConvertTo-Json -Depth 50 -Compress
            ) |
            Add-Content -Path $eventsJsonl

            # ------------------------------------------------
            # Extract readable fields.
            # ------------------------------------------------

            $stackName = ""

            if ($operations.ContainsKey($operationId)) {

                $stackName =
                    [string]$operations[$operationId].StackName
            }

            $eventType = [string]$event.EventType

            $status = [string]$event.OperationStatus

            $resource = ""

            if ($event.ResourceModel) {

                $resource =
                    [string]$event.ResourceModel
            }

            $resourceType = ""

            if ($event.ResourceType) {

                $resourceType =
                    [string]$event.ResourceType
            }

            $reason = ""

            if ($event.StatusReason) {

                $reason =
                    [string]$event.StatusReason
            }

            # ------------------------------------------------
            # Human-readable GitHub log.
            # ------------------------------------------------

            $message =
                "CFN | " +
                "Stack=$stackName | " +
                "Op=$operationId | " +
                "Event=$eventType | " +
                "Status=$status | " +
                "Resource=$resource"

            if ($resourceType) {

                $message +=
                    " | Type=$resourceType"
            }

            if ($reason) {

                $message +=
                    " | Reason=$reason"
            }

            if (
                $failureStatuses -contains $status
            ) {

                Write-EventLog `
                    $message `
                    Red

                $failedEvents += $event
            }
            else {

                Write-EventLog `
                    $message `
                    Gray
            }
        }
    }
}

# ============================================================
# START MONITOR
# ============================================================

Write-Host ""

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

Write-Host `
    "LIVE CLOUDFORMATION MONITOR" `
    -ForegroundColor Cyan

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

Write-Host "Root Stack : $StackName"
Write-Host "Region     : $Region"
Write-Host "Polling    : ${PollSeconds}s"
Write-Host "Timeout    : ${TimeoutMinutes}m"

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

# ------------------------------------------------------------
# Main monitoring loop
# ------------------------------------------------------------

while ((Get-Date) -lt $deadline) {

    # --------------------------------------------------------
    # 1. Discover root + nested stacks.
    # --------------------------------------------------------

    Discover-NestedStacks `
        -CurrentStackName $StackName

    # --------------------------------------------------------
    # 2. Discover CloudFormation operation IDs.
    # --------------------------------------------------------

    Discover-Operations

    # --------------------------------------------------------
    # 3. Process operation events.
    # --------------------------------------------------------

    Process-OperationEvents

    # --------------------------------------------------------
    # 4. Determine current root status.
    # --------------------------------------------------------

    $rootStack = Get-Stack `
        -Name $StackName

    $rootStatus = ""

    if ($rootStack) {

        $rootStatus =
            [string]$rootStack.StackStatus
    }

    # --------------------------------------------------------
    # 5. Determine whether nested stacks are still active.
    # --------------------------------------------------------

    $nestedInProgress = $false

    foreach ($stackRecord in @($stacks.Values)) {

        $currentStack =
            Get-Stack -Name $stackRecord.StackId

        if ($currentStack) {

            $status =
                [string]$currentStack.StackStatus

            $stacks[$stackRecord.StackId].Status =
                $status

            if ($status -like "*_IN_PROGRESS") {

                $nestedInProgress = $true
            }
        }
    }

    # --------------------------------------------------------
    # 6. Stop when the deployment is clearly terminal.
    # --------------------------------------------------------

    if (
        $rootStatus -and
        $terminalStatuses -contains $rootStatus -and
        -not $nestedInProgress
    ) {

        Write-EventLog `
            "ROOT STACK TERMINAL | Status=$rootStatus" `
            Cyan

        # One additional event collection cycle.
        Start-Sleep -Seconds 2

        Discover-Operations

        Process-OperationEvents

        break
    }

    # --------------------------------------------------------
    # Prevent unnecessary CPU/API usage.
    # --------------------------------------------------------

    Start-Sleep -Seconds $PollSeconds
}

# ============================================================
# TIMEOUT
# ============================================================

if ((Get-Date) -ge $deadline) {

    $timedOut = $true

    Write-EventLog `
        "MONITOR TIMEOUT | Deployment exceeded ${TimeoutMinutes} minutes." `
        Yellow
}

# ============================================================
# FINAL FAILURE COLLECTION
#
# Ask CloudFormation directly for failed events for every
# operation that we discovered.
# ============================================================

$finalFailures = @()

foreach ($operationId in @($operations.Keys)) {

    try {

        $failed = Invoke-AwsJson @(
            "cloudformation",
            "describe-events",
            "--operation-id",
            $operationId,
            "--filters",
            "FailedEvents=true",
            "--region",
            $Region,
            "--no-cli-pager",
            "--output",
            "json"
        )

        foreach ($failure in @($failed.OperationEvents)) {

            $finalFailures += $failure
        }
    }
    catch {

        # Continue collecting from other operations.
    }
}

# ------------------------------------------------------------
# Remove duplicate failure events.
# ------------------------------------------------------------

$uniqueFailures = @{}

foreach ($failure in $finalFailures) {

    $id = [string]$failure.EventId

    if (
        $id -and
        -not $uniqueFailures.ContainsKey($id)
    ) {

        $uniqueFailures[$id] = $failure
    }
}

$finalFailures =
    @($uniqueFailures.Values)

# ------------------------------------------------------------
# Write failures.
# ------------------------------------------------------------

$finalFailures |
    ConvertTo-Json -Depth 50 |
    Set-Content -Path $failuresJson

# ============================================================
# METADATA
# ============================================================

$metadata = [ordered]@{

    RootStack = $StackName

    Region = $Region

    StartedAt =
        $startedAt.
        ToUniversalTime().
        ToString("o")

    FinishedAt =
        (Get-Date).
        ToUniversalTime().
        ToString("o")

    TimedOut = $timedOut

    PollSeconds = $PollSeconds

    TimeoutMinutes = $TimeoutMinutes

    Operations = @(
        $operations.Values
    )

    StackNames = @(
        $stacks.Values |
        ForEach-Object {
            $_.StackName
        } |
        Select-Object -Unique
    )

    EventCount =
        $seenEventIds.Count

    FailureCount =
        $finalFailures.Count
}

$metadata |
    ConvertTo-Json -Depth 50 |
    Set-Content -Path $metadataJson

# ============================================================
# FINAL MONITOR MESSAGE
# ============================================================

Write-Host ""

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

Write-Host `
    "CLOUDFORMATION MONITOR FINISHED" `
    -ForegroundColor Cyan

Write-Host `
    "============================================================"

Write-Host "Events   : $($seenEventIds.Count)"
Write-Host "Failures : $($finalFailures.Count)"
Write-Host "Timeout  : $timedOut"
Write-Host "Stacks   : $($stacks.Count)"
Write-Host "Operations: $($operations.Count)"

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

# ============================================================
# EXIT CODE
#
# 10 = confirmed CloudFormation failure
# 2  = monitoring timeout
# 0  = no CFN failure detected
# ============================================================

if ($finalFailures.Count -gt 0) {

    exit 10
}

if ($timedOut) {

    exit 2
}

exit 0
```

---

# 4. `Generate-Report.ps1`

This is the **correlation and diagnosis engine**.

Create:

```text
scripts/deployment-monitor/Generate-Report.ps1
```

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentId,

    [Parameter(Mandatory = $true)]
    [int]$TerraformExitCode,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$StackName
)

# ============================================================
# GENERATE-REPORT.PS1
#
# PURPOSE:
#   Compare:
#
#       GitHub metadata
#       Terraform result/logs
#       CloudFormation events
#
#   and produce:
#
#       deployment-summary.md
#       diagnosis.json
#
# IMPORTANT:
#   This script distinguishes:
#
#       ROOT CAUSE
#
#   from:
#
#       DOWNSTREAM FAILURE
#
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Files
# ------------------------------------------------------------

$summaryPath =
    Join-Path $OutputDirectory "deployment-summary.md"

$diagnosisPath =
    Join-Path $OutputDirectory "diagnosis.json"

$cfMetadataPath =
    Join-Path $OutputDirectory "cloudformation-metadata.json"

$cfFailuresPath =
    Join-Path $OutputDirectory "cloudformation-failures.json"

$terraformJsonlPath =
    Join-Path $OutputDirectory "terraform.jsonl"

$terraformLogPath =
    Join-Path $OutputDirectory "terraform.log"

$rulesPath =
    Join-Path $PSScriptRoot "failure-rules.json"

# ============================================================
# LOAD CLOUDFORMATION DATA
# ============================================================

$cfMetadata = $null

if (Test-Path $cfMetadataPath) {

    try {

        $cfMetadata =
            Get-Content `
                $cfMetadataPath `
                -Raw |
            ConvertFrom-Json

    }
    catch {

        $cfMetadata = $null
    }
}

$cfFailures = @()

if (Test-Path $cfFailuresPath) {

    try {

        $cfFailures =
            @(
                Get-Content `
                    $cfFailuresPath `
                    -Raw |
                ConvertFrom-Json
            )

    }
    catch {

        $cfFailures = @()
    }
}

# ============================================================
# LOAD FAILURE RULES
# ============================================================

$rules = @()

if (Test-Path $rulesPath) {

    try {

        $ruleFile =
            Get-Content `
                $rulesPath `
                -Raw |
            ConvertFrom-Json

        $rules = @($ruleFile.rules)
    }
    catch {

        $rules = @()
    }
}

# ============================================================
# GITHUB METADATA
# ============================================================

$github = [ordered]@{

    Repository =
        $env:GITHUB_REPOSITORY

    Workflow =
        $env:GITHUB_WORKFLOW

    WorkflowRef =
        $env:GITHUB_REF

    RunId =
        $env:GITHUB_RUN_ID

    RunAttempt =
        $env:GITHUB_RUN_ATTEMPT

    Job =
        $env:GITHUB_JOB

    Actor =
        $env:GITHUB_ACTOR

    Sha =
        $env:GITHUB_SHA

    ServerUrl =
        $env:GITHUB_SERVER_URL
}

# ============================================================
# TERRAFORM EVIDENCE
# ============================================================

$terraformEvidence = @()

if (Test-Path $terraformJsonlPath) {

    foreach ($line in Get-Content $terraformJsonlPath) {

        if ([string]::IsNullOrWhiteSpace($line)) {

            continue
        }

        try {

            $event =
                $line |
                ConvertFrom-Json

            # Terraform diagnostics normally contain:
            #
            #   diagnostic
            #
            # or severity information.

            $text =
                [string]$line

            if (
                $event.type -eq "diagnostic" -or
                $event.'@level' -eq "error" -or
                $event.'@message' -match "Error"
            ) {

                $terraformEvidence += $text
            }

        }
        catch {

            # Preserve parsing failures as raw evidence.
        }
    }
}

# ============================================================
# ALSO READ TERRAFORM STDERR
# ============================================================

if (Test-Path $terraformLogPath) {

    $terraformText =
        Get-Content `
            $terraformLogPath `
            -Raw

}
else {

    $terraformText = ""
}

# ============================================================
# FAILURE ANALYSIS
# ============================================================

$matchedRules = @()

$evidence = @()

foreach ($failure in $cfFailures) {

    $reason =
        [string]$failure.StatusReason

    $resource =
        [string]$failure.ResourceModel

    $resourceType =
        [string]$failure.ResourceType

    $status =
        [string]$failure.OperationStatus

    $eventType =
        [string]$failure.EventType

    $operationId =
        [string]$failure.OperationId

    $stackId =
        [string]$failure.StackId

    $evidence += [ordered]@{

        StackId =
            $stackId

        OperationId =
            $operationId

        Resource =
            $resource

        ResourceType =
            $resourceType

        EventType =
            $eventType

        Status =
            $status

        StatusReason =
            $reason
    }

    # --------------------------------------------------------
    # Match failure rules.
    # --------------------------------------------------------

    foreach ($rule in $rules) {

        foreach ($pattern in @($rule.patterns)) {

            if (
                $reason -match $pattern -or
                $resource -match $pattern -or
                $resourceType -match $pattern
            ) {

                $matchedRules += $rule

                break
            }
        }
    }
}

# ------------------------------------------------------------
# Remove duplicate categories.
# ------------------------------------------------------------

$matchedRules =
    @(
        $matchedRules |
        Group-Object category |
        ForEach-Object {
            $_.Group[0]
        }
    )

# ============================================================
# DETERMINE ROOT CAUSE
# ============================================================

$category = "UNKNOWN"

$rootCause =
    "No confirmed CloudFormation root cause was captured."

$recommendations = @()

$confirmedRootCause = $false

# ------------------------------------------------------------
# The FIRST/earliest meaningful failure is more important
# than a later rollback event.
# ------------------------------------------------------------

$primaryFailure = $null

if ($cfFailures.Count -gt 0) {

    $primaryFailure =
        $cfFailures |
        Where-Object {
            $_.OperationStatus -match "_FAILED$"
        } |
        Select-Object -First 1

    if (-not $primaryFailure) {

        $primaryFailure =
            $cfFailures |
            Select-Object -First 1
    }
}

if ($primaryFailure) {

    $reason =
        [string]$primaryFailure.StatusReason

    $resource =
        [string]$primaryFailure.ResourceModel

    $resourceType =
        [string]$primaryFailure.ResourceType

    $category =
        "CLOUDFORMATION RESOURCE FAILURE"

    $rootCause =
        "CloudFormation reported failure for resource '$resource' " +
        "($resourceType). Reason: $reason"

    $confirmedRootCause = $true
}

# ============================================================
# APPLY MATCHED RULE
# ============================================================

if ($matchedRules.Count -gt 0) {

    # The first matched rule is the primary classification.
    $primaryRule =
        $matchedRules[0]

    $category =
        [string]$primaryRule.category

    if ($primaryFailure) {

        $reason =
            [string]$primaryFailure.StatusReason

        $resource =
            [string]$primaryFailure.ResourceModel

        $rootCause =
            "CloudFormation reported a $category failure " +
            "for resource '$resource'. " +
            "Reported reason: $reason"
    }

    foreach ($rule in $matchedRules) {

        foreach ($recommendation in @(
            $rule.recommendations
        )) {

            $recommendations +=
                [string]$recommendation
        }
    }
}

$recommendations =
    @(
        $recommendations |
        Select-Object -Unique
    )

# ============================================================
# TERRAFORM / CLOUDFORMATION RELATIONSHIP
# ============================================================

$finalResult = "SUCCESS"

$causeRelationship = ""

$failureChain = ""

if (
    $TerraformExitCode -ne 0 -and
    $confirmedRootCause
) {

    $finalResult = "FAILED"

    $causeRelationship =
        "CONFIRMED ROOT CAUSE IS IN " +
        "CLOUDFORMATION/AWS RESOURCE PROVISIONING. " +
        "TERRAFORM AND GITHUB FAILURE ARE DOWNSTREAM CONSEQUENCES."

    $failureChain =
        "CloudFormation resource failure -> " +
        "CloudFormation operation/rollback -> " +
        "Terraform observes failed stack operation -> " +
        "GitHub Actions step fails."

}
elseif (
    $TerraformExitCode -ne 0 -and
    -not $confirmedRootCause
) {

    $finalResult = "FAILED"

    $causeRelationship =
        "TERRAFORM FAILURE IS CONFIRMED, " +
        "BUT A CLOUD FORMATION ROOT CAUSE WAS NOT " +
        "CONFIRMED BY THE CAPTURED EVIDENCE."

    $failureChain =
        "Terraform reported failure -> " +
        "GitHub Actions step fails -> " +
        "CloudFormation root cause not captured."

}
elseif (
    $TerraformExitCode -eq 0 -and
    $confirmedRootCause
) {

    # This situation is unusual and should be visible.
    $finalResult = "FAILED"

    $causeRelationship =
        "CLOUDFORMATION REPORTED A CONFIRMED FAILURE " +
        "EVEN THOUGH TERRAFORM EXITED SUCCESSFULLY."

    $failureChain =
        "CloudFormation failure detected -> " +
        "Terraform exited successfully -> " +
        "Deployment marked FAILED because infrastructure evidence " +
        "contains a confirmed failure."

}
else {

    $finalResult = "SUCCESS"

    $causeRelationship =
        "DEPLOYMENT SUCCESS. " +
        "Terraform exited successfully and no confirmed " +
        "CloudFormation failure was captured."

    $failureChain =
        "Terraform completed successfully -> " +
        "CloudFormation completed without captured failure."
}

# ============================================================
# TERRAFORM CONCLUSION
# ============================================================

if ($TerraformExitCode -eq 0) {

    $terraformConclusion =
        "Terraform exited successfully."

}
else {

    $terraformConclusion =
        "Terraform exited with code $TerraformExitCode. " +
        "This confirms deployment failure but does not by itself " +
        "prove that Terraform is the root cause."
}

# ============================================================
# DIAGNOSIS OBJECT
# ============================================================

$diagnosis = [ordered]@{

    DeploymentId =
        $DeploymentId

    FinalResult =
        $finalResult

    Category =
        $category

    RootCause =
        $rootCause

    RootCauseConfirmed =
        $confirmedRootCause

    CauseRelationship =
        $causeRelationship

    FailureChain =
        $failureChain

    Region =
        $Region

    RootStack =
        $StackName

    TerraformExitCode =
        $TerraformExitCode

    TerraformConclusion =
        $terraformConclusion

    CloudFormationFailureCount =
        $cfFailures.Count

    CloudFormationEvidence =
        $evidence

    MatchedRules =
        $matchedRules

    Recommendations =
        $recommendations

    TerraformEvidence =
        $terraformEvidence

    GitHub =
        $github

    CloudFormationMetadata =
        $cfMetadata
}

# ============================================================
# WRITE diagnosis.json
# ============================================================

$diagnosis |
    ConvertTo-Json -Depth 100 |
    Set-Content -Path $diagnosisPath

# ============================================================
# GENERATE HUMAN-READABLE MARKDOWN REPORT
# ============================================================

$lines =
    New-Object System.Collections.Generic.List[string]

$lines.Add("# Deployment Diagnostic Report")

$lines.Add("")

$lines.Add(
    "**Deployment ID:** `$DeploymentId`"
)

$lines.Add(
    "**Final Result:** **$finalResult**"
)

$lines.Add(
    "**Category:** $category"
)

$lines.Add("")

# ------------------------------------------------------------
# GitHub
# ------------------------------------------------------------

$lines.Add("## GitHub")

$lines.Add(
    "- Repository: $($github.Repository)"
)

$lines.Add(
    "- Workflow: $($github.Workflow)"
)

$lines.Add(
    "- Job: $($github.Job)"
)

$lines.Add(
    "- Run ID: $($github.RunId)"
)

$lines.Add(
    "- Run Attempt: $($github.RunAttempt)"
)

$lines.Add(
    "- Actor: $($github.Actor)"
)

$lines.Add(
    "- Commit: $($github.Sha)"
)

$lines.Add("")

# ------------------------------------------------------------
# Terraform
# ------------------------------------------------------------

$lines.Add("## Terraform")

$lines.Add(
    "- Exit code: $TerraformExitCode"
)

$lines.Add(
    "- Conclusion: $terraformConclusion"
)

$lines.Add("")

# ------------------------------------------------------------
# CloudFormation
# ------------------------------------------------------------

$lines.Add("## CloudFormation")

$lines.Add(
    "- Root stack: $StackName"
)

$lines.Add(
    "- Region: $Region"
)

if ($cfMetadata) {

    $lines.Add(
        "- Operations discovered: $(@($cfMetadata.Operations).Count)"
    )

    $lines.Add(
        "- Stacks discovered: $(@($cfMetadata.StackNames).Count)"
    )

    $lines.Add(
        "- Events captured: $($cfMetadata.EventCount)"
    )

    $lines.Add(
        "- Failed events: $($cfMetadata.FailureCount)"
    )

    $lines.Add(
        "- Monitor timed out: $($cfMetadata.TimedOut)"
    )
}

$lines.Add("")

# ------------------------------------------------------------
# Failure evidence
# ------------------------------------------------------------

$lines.Add("## Confirmed Failure Evidence")

if ($evidence.Count -eq 0) {

    $lines.Add(
        "- No CloudFormation failure event was captured."
    )

}
else {

    foreach ($item in $evidence) {

        $lines.Add(
            "- Stack ID: $($item.StackId)"
        )

        $lines.Add(
            "  - Operation ID: $($item.OperationId)"
        )

        $lines.Add(
            "  - Resource: $($item.Resource)"
        )

        $lines.Add(
            "  - Type: $($item.ResourceType)"
        )

        $lines.Add(
            "  - Status: $($item.Status)"
        )

        $lines.Add(
            "  - Reason: $($item.StatusReason)"
        )
    }
}

$lines.Add("")

# ------------------------------------------------------------
# Root cause
# ------------------------------------------------------------

$lines.Add("## Root Cause Statement")

$lines.Add($rootCause)

$lines.Add("")

# ------------------------------------------------------------
# Relationship
# ------------------------------------------------------------

$lines.Add("## Error Relationship")

$lines.Add($causeRelationship)

$lines.Add("")

# ------------------------------------------------------------
# Failure chain
# ------------------------------------------------------------

$lines.Add("## Failure Chain")

$lines.Add($failureChain)

$lines.Add("")

# ------------------------------------------------------------
# Recommendations
# ------------------------------------------------------------

$lines.Add("## Recommended Investigation")

if ($recommendations.Count -eq 0) {

    $lines.Add(
        "- Review the raw Terraform and CloudFormation evidence."
    )

}
else {

    foreach ($recommendation in $recommendations) {

        $lines.Add(
            "- $recommendation"
        )
    }
}

$lines.Add("")

# ------------------------------------------------------------
# Terraform evidence
# ------------------------------------------------------------

$lines.Add("## Terraform Evidence")

if ($terraformEvidence.Count -eq 0) {

    $lines.Add(
        "- No structured Terraform diagnostic event was extracted."
    )

}
else {

    foreach ($item in $terraformEvidence) {

        $lines.Add(
            "- `$item`"
        )
    }
}

$lines.Add("")

# ------------------------------------------------------------
# Evidence files
# ------------------------------------------------------------

$lines.Add("## Evidence Files")

$lines.Add(
    "- `deployment-metadata.json`"
)

$lines.Add(
    "- `terraform.jsonl`"
)

$lines.Add(
    "- `terraform.log`"
)

$lines.Add(
    "- `cloudformation-events.jsonl`"
)

$lines.Add(
    "- `cloudformation-events.log`"
)

$lines.Add(
    "- `cloudformation-failures.json`"
)

$lines.Add(
    "- `cloudformation-metadata.json`"
)

$lines.Add(
    "- `diagnosis.json`"
)

Set-Content `
    -Path $summaryPath `
    -Value ($lines -join "`n")

# ============================================================
# CONSOLE SUMMARY
# ============================================================

Write-Host ""

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

Write-Host `
    "DEPLOYMENT DIAGNOSTIC REPORT" `
    -ForegroundColor Cyan

Write-Host `
    "============================================================"

Write-Host "Deployment ID : $DeploymentId"
Write-Host "Result        : $finalResult"
Write-Host "Category      : $category"

Write-Host ""

Write-Host "Root Cause:"
Write-Host $rootCause

Write-Host ""

Write-Host "Relationship:"
Write-Host $causeRelationship

Write-Host ""

Write-Host "Report:"
Write-Host $summaryPath

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

# ============================================================
# REPORT EXIT CODE
# ============================================================

if ($finalResult -eq "SUCCESS") {

    exit 0
}

exit 1
```

---

# 5. `Start-Deployment.ps1`

This is the **main orchestrator**.

It starts Terraform and the CloudFormation monitor as separate concurrent processes.

Create:

```text
scripts/deployment-monitor/Start-Deployment.ps1
```

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TerraformWorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [string]$Region = "us-east-1",

    [string]$OutputDirectory = ".deployment-logs",

    [switch]$AutoApprove,

    [int]$MonitorPollSeconds = 3,

    [int]$MonitorTimeoutMinutes = 90
)

# ============================================================
# START-DEPLOYMENT.PS1
#
# PURPOSE:
#
#   Main deployment orchestrator.
#
# ARCHITECTURE:
#
#        GitHub
#           |
#           v
#      Deployment ID
#           |
#      +----+----+
#      |         |
#      v         v
# Terraform   CloudFormation
#   Apply       Monitor
#      |         |
#      +----+----+
#           |
#           v
#      Final Report
#
# ============================================================

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Determine repository root.
#
# $PSScriptRoot points to:
#
# scripts/deployment-monitor
#
# Therefore:
#
# ../.. = repository root
# ------------------------------------------------------------

$repoRoot =
    (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path

# ------------------------------------------------------------
# Convert output directory into an absolute path.
# ------------------------------------------------------------

$OutputDirectory =
    [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $OutputDirectory)
    )

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDirectory |
    Out-Null

# ------------------------------------------------------------
# Important files.
# ------------------------------------------------------------

$monitorScript =
    Join-Path $PSScriptRoot "Monitor-CloudFormation.ps1"

$reportScript =
    Join-Path $PSScriptRoot "Generate-Report.ps1"

$terraformJsonl =
    Join-Path $OutputDirectory "terraform.jsonl"

$terraformLog =
    Join-Path $OutputDirectory "terraform.log"

$metadataPath =
    Join-Path $OutputDirectory "deployment-metadata.json"

# ============================================================
# DEPLOYMENT ID
# ============================================================

$runId =
    if ($env:GITHUB_RUN_ID) {
        $env:GITHUB_RUN_ID
    }
    else {
        "local"
    }

$timestamp =
    Get-Date -Format "yyyyMMdd-HHmmss"

$DeploymentId =
    "${timestamp}-${runId}"

# ============================================================
# CAPTURE BASELINE CLOUDFORMATION OPERATIONS
#
# We capture what existed BEFORE Terraform starts.
#
# This prevents historical operations from being confused
# with the current deployment.
# ============================================================

$baselineOperationIds = @()

try {

    $raw =
        & aws `
            cloudformation `
            describe-stacks `
            --stack-name $StackName `
            --region $Region `
            --no-cli-pager `
            --output json `
            2>$null

    if (
        $LASTEXITCODE -eq 0 -and
        $raw
    ) {

        $stackData =
            ($raw -join "`n") |
            ConvertFrom-Json

        if (
            $stackData.Stacks.Count -gt 0
        ) {

            $stack =
                $stackData.Stacks[0]

            foreach (
                $op in @($stack.LastOperations)
            ) {

                if ($op.OperationId) {

                    $baselineOperationIds +=
                        [string]$op.OperationId
                }
            }
        }
    }
}
catch {

    # Stack may not exist during a first deployment.
    # This is not automatically an error.
}

# ============================================================
# DEPLOYMENT METADATA
# ============================================================

$metadata = [ordered]@{

    DeploymentId =
        $DeploymentId

    StartedAt =
        (Get-Date).
        ToUniversalTime().
        ToString("o")

    Region =
        $Region

    RootStack =
        $StackName

    TerraformWorkingDirectory =
        $TerraformWorkingDirectory

    BaselineOperationIds =
        $baselineOperationIds

    GitHub = [ordered]@{

        Repository =
            $env:GITHUB_REPOSITORY

        Workflow =
            $env:GITHUB_WORKFLOW

        Job =
            $env:GITHUB_JOB

        RunId =
            $env:GITHUB_RUN_ID

        RunAttempt =
            $env:GITHUB_RUN_ATTEMPT

        Ref =
            $env:GITHUB_REF

        Sha =
            $env:GITHUB_SHA

        Actor =
            $env:GITHUB_ACTOR
    }
}

$metadata |
    ConvertTo-Json -Depth 50 |
    Set-Content -Path $metadataPath

# ============================================================
# HEADER
# ============================================================

Write-Host ""

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

Write-Host `
    "DEPLOYMENT ORCHESTRATOR" `
    -ForegroundColor Cyan

Write-Host `
    "============================================================"

Write-Host "Deployment ID : $DeploymentId"
Write-Host "GitHub Run    : $runId"
Write-Host "Root Stack    : $StackName"
Write-Host "Region        : $Region"
Write-Host "Terraform Dir : $TerraformWorkingDirectory"

Write-Host ""

Write-Host `
    "Terraform APPLY and CloudFormation MONITOR will run concurrently." `
    -ForegroundColor Green

Write-Host ""

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

# ============================================================
# START CLOUDFORMATION MONITOR
#
# IMPORTANT:
#
# The monitor starts BEFORE Terraform.
#
# It then watches for the new CloudFormation operation.
# ============================================================

$monitorArguments = @(
    "-NoProfile"
    "-ExecutionPolicy"
    "Bypass"
    "-File"
    $monitorScript
    "-StackName"
    $StackName
    "-Region"
    $Region
    "-OutputDirectory"
    $OutputDirectory
    "-PollSeconds"
    $MonitorPollSeconds
    "-TimeoutMinutes"
    $MonitorTimeoutMinutes
)

foreach ($operationId in $baselineOperationIds) {

    $monitorArguments +=
        @(
            "-BaselineOperationIds"
            $operationId
        )
}

Write-Host `
    "Starting CloudFormation monitor..." `
    -ForegroundColor Cyan

$monitorProcess =
    Start-Process `
        -FilePath "pwsh" `
        -ArgumentList $monitorArguments `
        -WorkingDirectory $repoRoot `
        -PassThru

Write-Host `
    "CloudFormation monitor PID: $($monitorProcess.Id)" `
    -ForegroundColor Green

# ============================================================
# START TERRAFORM
#
# Terraform is run with:
#
#     terraform apply -json
#
# This produces structured machine-readable events.
# ============================================================

$terraformArguments =
    @(
        "apply"
        "-json"
    )

if ($AutoApprove) {

    $terraformArguments +=
        "-auto-approve"
}

Write-Host ""

Write-Host `
    "Starting Terraform..." `
    -ForegroundColor Cyan

Write-Host `
    "Command: terraform $($terraformArguments -join ' ')" `
    -ForegroundColor DarkGray

# ------------------------------------------------------------
# Create ProcessStartInfo.
# ------------------------------------------------------------

$processInfo =
    New-Object System.Diagnostics.ProcessStartInfo

$processInfo.FileName =
    "terraform"

$processInfo.WorkingDirectory =
    (Resolve-Path $TerraformWorkingDirectory).Path

$processInfo.UseShellExecute =
    $false

$processInfo.RedirectStandardOutput =
    $true

$processInfo.RedirectStandardError =
    $true

$processInfo.CreateNoWindow =
    $true

# ------------------------------------------------------------
# Add arguments safely.
# ------------------------------------------------------------

foreach ($argument in $terraformArguments) {

    [void]$processInfo.ArgumentList.Add(
        $argument
    )
}

$terraformProcess =
    New-Object System.Diagnostics.Process

$terraformProcess.StartInfo =
    $processInfo

# ============================================================
# TERRAFORM STDOUT
# ============================================================

$terraformProcess.add_OutputDataReceived({

    param(
        $sender,
        $eventArgs
    )

    if ($null -eq $eventArgs.Data) {

        return
    }

    # --------------------------------------------------------
    # Preserve raw Terraform JSONL.
    # --------------------------------------------------------

    Add-Content `
        -Path $terraformJsonl `
        -Value $eventArgs.Data

    # --------------------------------------------------------
    # Display a readable Terraform message.
    # --------------------------------------------------------

    try {

        $event =
            $eventArgs.Data |
            ConvertFrom-Json

        $message = $null

        if ($event.'@message') {

            $message =
                [string]$event.'@message'
        }
        elseif ($event.message) {

            $message =
                [string]$event.message
        }
        elseif ($event.type) {

            $message =
                "Terraform event: $($event.type)"
        }

        if ($message) {

            Write-Host `
                "TF   | $message"
        }
        else {

            Write-Host `
                "TF   | $($eventArgs.Data)"
        }

    }
    catch {

        Write-Host `
            "TF   | $($eventArgs.Data)"
    }
})

# ============================================================
# TERRAFORM STDERR
# ============================================================

$terraformProcess.add_ErrorDataReceived({

    param(
        $sender,
        $eventArgs
    )

    if ($null -eq $eventArgs.Data) {

        return
    }

    Add-Content `
        -Path $terraformLog `
        -Value $eventArgs.Data

    Write-Host `
        "TFERR| $($eventArgs.Data)" `
        -ForegroundColor Red
})

# ============================================================
# START TERRAFORM PROCESS
# ============================================================

$terraformStart =
    Get-Date

$null =
    $terraformProcess.Start()

$terraformProcess.BeginOutputReadLine()

$terraformProcess.BeginErrorReadLine()

# ============================================================
# WAIT FOR TERRAFORM
#
# The CloudFormation monitor continues running independently.
# ============================================================

while (-not $terraformProcess.HasExited) {

    Start-Sleep -Milliseconds 500
}

$terraformExitCode =
    $terraformProcess.ExitCode

$terraformDuration =
    (Get-Date) - $terraformStart

# ------------------------------------------------------------
# Display Terraform result.
# ------------------------------------------------------------

if ($terraformExitCode -eq 0) {

    Write-Host ""

    Write-Host `
        "Terraform completed successfully." `
        -ForegroundColor Green

}
else {

    Write-Host ""

    Write-Host `
        "Terraform FAILED with exit code $terraformExitCode." `
        -ForegroundColor Red
}

Write-Host `
    "Terraform duration: $([int]$terraformDuration.TotalSeconds) seconds"

# ============================================================
# MONITOR GRACE PERIOD
#
# Terraform can exit immediately after CloudFormation reaches
# a terminal state. Give the monitor a small amount of time
# to capture the final CloudFormation events.
# ============================================================

Write-Host ""

Write-Host `
    "Waiting briefly for final CloudFormation events..." `
    -ForegroundColor Yellow

$graceDeadline =
    (Get-Date).AddSeconds(20)

while (
    -not $monitorProcess.HasExited -and
    (Get-Date) -lt $graceDeadline
) {

    Start-Sleep -Seconds 1
}

# ------------------------------------------------------------
# Stop monitor if it is still running.
# ------------------------------------------------------------

if (-not $monitorProcess.HasExited) {

    Write-Host `
        "Stopping CloudFormation monitor after final grace period." `
        -ForegroundColor Yellow

    try {

        $monitorProcess.Kill()
    }
    catch {

        # Process may already have exited.
    }
}

$monitorExitCode =
    $monitorProcess.ExitCode

# ============================================================
# GENERATE FINAL REPORT
#
# THIS MUST RUN EVEN IF TERRAFORM FAILED.
# ============================================================

Write-Host ""

Write-Host `
    "Generating deployment diagnostic report..." `
    -ForegroundColor Cyan

$reportArguments = @(
    "-NoProfile"
    "-ExecutionPolicy"
    "Bypass"
    "-File"
    $reportScript
    "-OutputDirectory"
    $OutputDirectory
    "-DeploymentId"
    $DeploymentId
    "-TerraformExitCode"
    $terraformExitCode
    "-Region"
    $Region
    "-StackName"
    $StackName
)

& pwsh @reportArguments

$reportExitCode =
    $LASTEXITCODE

# ============================================================
# UPDATE METADATA
# ============================================================

$metadata.FinishedAt =
    (Get-Date).
    ToUniversalTime().
    ToString("o")

$metadata.TerraformExitCode =
    $terraformExitCode

$metadata.MonitorExitCode =
    $monitorExitCode

$metadata.ReportExitCode =
    $reportExitCode

$metadata |
    ConvertTo-Json -Depth 50 |
    Set-Content -Path $metadataPath

# ============================================================
# FINAL RESULT
# ============================================================

Write-Host ""

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

Write-Host `
    "FINAL DEPLOYMENT RESULT" `
    -ForegroundColor Cyan

Write-Host `
    "============================================================"

Write-Host "Deployment ID : $DeploymentId"

Write-Host "Terraform     : $terraformExitCode"

Write-Host "CFN Monitor   : $monitorExitCode"

Write-Host "Report        : $reportExitCode"

Write-Host "Logs          : $OutputDirectory"

Write-Host `
    "============================================================" `
    -ForegroundColor Cyan

# ============================================================
# FINAL EXIT LOGIC
#
# Terraform failure:
#     GitHub FAILED
#
# CloudFormation failure:
#     GitHub FAILED
#
# Monitor timeout:
#     GitHub FAILED
#
# Report failure:
#     GitHub FAILED
# ============================================================

if ($terraformExitCode -ne 0) {

    exit 1
}

if ($monitorExitCode -eq 10) {

    exit 1
}

if ($monitorExitCode -eq 2) {

    exit 1
}

if ($reportExitCode -ne 0) {

    exit 1
}

exit 0
```

---

# 6. GitHub Actions — Step 15

Now replace your existing Step 15 with this.

```yaml
# ============================================================
# STEP 15
# TERRAFORM APPLY + REAL-TIME CLOUDFORMATION MONITOR
# ============================================================
#
# This step:
#
#   1. Creates a Deployment ID.
#   2. Starts CloudFormation monitoring.
#   3. Starts Terraform APPLY.
#   4. Captures Terraform JSONL events.
#   5. Captures CloudFormation events.
#   6. Discovers nested CloudFormation stacks.
#   7. Captures CloudFormation operation IDs.
#   8. Detects failures.
#   9. Correlates Terraform + CloudFormation evidence.
#  10. Generates deployment-summary.md.
#
# ============================================================

- name: Step 15 - Terraform Apply + Live CloudFormation Diagnostics
  if: ${{ env.TF_AUTO_APPROVE == 'true' }}
  working-directory: ${{ env.TF_WORKING_DIRECTORY }}
  shell: pwsh
  env:
    AWS_PAGER: ""
  run: |

    $ErrorActionPreference = "Stop"

    # --------------------------------------------------------
    # The working directory is expected to be:
    #
    # infrastructure/terraform
    #
    # Therefore ../.. is the repository root.
    # --------------------------------------------------------

    $repoRoot =
      (Resolve-Path "../..").Path

    # --------------------------------------------------------
    # Monitoring framework directory.
    # --------------------------------------------------------

    $monitorDirectory =
      Join-Path $repoRoot "scripts/deployment-monitor"

    # --------------------------------------------------------
    # Deployment logs.
    # --------------------------------------------------------

    $outputDirectory =
      Join-Path $repoRoot "deployment-logs"

    # --------------------------------------------------------
    # Root CloudFormation stack.
    #
    # If CFN_STACK_NAME is already configured as a GitHub
    # environment variable, use it.
    #
    # Otherwise use the current lab's stack name.
    # --------------------------------------------------------

    if ($env:CFN_STACK_NAME) {

      $stackName =
        $env:CFN_STACK_NAME

    }
    else {

      $stackName =
        "hybridiaclab-dev-MainStack"
    }

    # --------------------------------------------------------
    # Display deployment information.
    # --------------------------------------------------------

    Write-Host ""

    Write-Host `
      "============================================================" `
      -ForegroundColor Cyan

    Write-Host `
      "STEP 15 - LIVE TERRAFORM + CLOUDFORMATION MONITOR" `
      -ForegroundColor Cyan

    Write-Host `
      "============================================================"

    Write-Host "Stack      : $stackName"

    Write-Host "Region     : $env:AWS_REGION"

    Write-Host "Terraform  : $env:TF_WORKING_DIRECTORY"

    Write-Host "Repository : $repoRoot"

    Write-Host ""

    # --------------------------------------------------------
    # Validate monitoring scripts before starting.
    # --------------------------------------------------------

    $requiredFiles = @(
      "Start-Deployment.ps1",
      "Monitor-CloudFormation.ps1",
      "Generate-Report.ps1",
      "failure-rules.json"
    )

    foreach ($file in $requiredFiles) {

      $path =
        Join-Path $monitorDirectory $file

      if (-not (Test-Path $path)) {

        Write-Error `
          "Required deployment monitor file not found: $path"

        exit 1
      }
    }

    # --------------------------------------------------------
    # Execute deployment orchestrator.
    # --------------------------------------------------------

    & pwsh `
      -NoProfile `
      -ExecutionPolicy Bypass `
      -File (
        Join-Path `
          $monitorDirectory `
          "Start-Deployment.ps1"
      ) `
      -TerraformWorkingDirectory "." `
      -StackName $stackName `
      -Region $env:AWS_REGION `
      -OutputDirectory $outputDirectory `
      -AutoApprove `
      -MonitorPollSeconds 3 `
      -MonitorTimeoutMinutes 90

    $deploymentExitCode =
      $LASTEXITCODE

    # --------------------------------------------------------
    # Display result.
    # --------------------------------------------------------

    if ($deploymentExitCode -ne 0) {

      Write-Host ""

      Write-Host `
        "============================================================" `
        -ForegroundColor Red

      Write-Host `
        "DEPLOYMENT FAILED" `
        -ForegroundColor Red

      Write-Host `
        "Diagnostic logs were generated." `
        -ForegroundColor Yellow

      Write-Host `
        "============================================================" `
        -ForegroundColor Red

      exit $deploymentExitCode
    }

    Write-Host ""

    Write-Host `
      "============================================================" `
      -ForegroundColor Green

    Write-Host `
      "DEPLOYMENT COMPLETED SUCCESSFULLY" `
      -ForegroundColor Green

    Write-Host `
      "============================================================" `
      -ForegroundColor Green
```

---

# 7. Step 16 — upload the report

Immediately after Step 15:

```yaml
# ============================================================
# STEP 16
# UPLOAD COMPLETE DEPLOYMENT DIAGNOSTICS
# ============================================================
#
# IMPORTANT:
#
# always()
#
# means this runs even when Step 15 fails.
#
# ============================================================

- name: Step 16 - Upload Deployment Diagnostic Report
  if: ${{ always() }}
  uses: actions/upload-artifact@v4
  with:
    name: deployment-diagnostics-${{ github.run_id }}
    path: deployment-logs/
    if-no-files-found: warn
    retention-days: 30
```

---

# 8. What happens during an actual deployment

Your GitHub log should now conceptually look like:

```text
============================================================
STEP 15 - LIVE TERRAFORM + CLOUDFORMATION MONITOR
============================================================

Stack      : hybridiaclab-dev-MainStack
Region     : us-east-1
Terraform  : infrastructure/terraform

DEPLOYMENT ORCHESTRATOR
Deployment ID : 20260909-001234-34255678413

Terraform APPLY and CloudFormation MONITOR will run concurrently.

Starting CloudFormation monitor...
CloudFormation monitor PID: 1234

Starting Terraform...

TF   | Terraform initialized
TF   | module.cloudformation: apply_start
CFN  | STACK DISCOVERED
CFN  | OPERATION DISCOVERED
CFN  | VPC CREATE_IN_PROGRESS
CFN  | VPC CREATE_COMPLETE
TF   | module.cloudformation: apply_progress
CFN  | EKS CREATE_IN_PROGRESS
CFN  | EKSNodeGroup CREATE_IN_PROGRESS
CFN  | EKSNodeGroup CREATE_FAILED
```

Then immediately:

```text
============================================================
!!! CLOUDFORMATION FAILURE DETECTED !!!
============================================================
```

and the actual failure reason is captured.

---

# 9. Final report example

The artifact will contain:

```text
deployment-diagnostics-34255678413/
│
├── deployment-metadata.json
├── terraform.jsonl
├── terraform.log
├── cloudformation-events.jsonl
├── cloudformation-events.log
├── cloudformation-failures.json
├── cloudformation-metadata.json
├── diagnosis.json
└── deployment-summary.md
```

And `deployment-summary.md` will look like:

```markdown
# Deployment Diagnostic Report

Deployment ID:
20260909-001234-34255678413

Final Result:
FAILED

Category:
EKS / NODE PROVISIONING

## GitHub

Repository:
awsrmmustansarjavaid/aws-hybrid-iac-lab

Workflow:
Terraform Infrastructure Deployment

Run ID:
34255678413

## Terraform

Exit code:
1

Conclusion:
Terraform exited with code 1. This confirms deployment
failure but does not by itself prove that Terraform is
the root cause.

## CloudFormation

Root stack:
hybridiaclab-dev-MainStack

Region:
us-east-1

Operations discovered:
3

Events captured:
47

Failed events:
1

## Confirmed Failure Evidence

- Resource: EKSNodeGroup
- Type: AWS::EKS::Nodegroup
- Status: CREATE_FAILED
- Reason: NodeCreationFailure

## Root Cause Statement

CloudFormation reported an EKS / NODE PROVISIONING
failure for resource 'EKSNodeGroup'.

Reported reason:
NodeCreationFailure

## Error Relationship

CONFIRMED ROOT CAUSE IS IN CLOUDFORMATION/AWS RESOURCE
PROVISIONING. TERRAFORM AND GITHUB FAILURE ARE
DOWNSTREAM CONSEQUENCES.

## Failure Chain

CloudFormation resource failure
        ↓
CloudFormation operation/rollback
        ↓
Terraform observes failed stack operation
        ↓
GitHub Actions step fails

## Recommended Investigation

- Inspect the EKS node IAM role.
- Inspect subnet routing and NAT connectivity.
- Inspect EKS cluster and node security groups.
- Inspect EKS endpoint accessibility.
- Inspect node bootstrap configuration.
```

---

# 10. One important point before you run this

I want to be transparent about one part of the implementation.

**The strongest correlation is obtained when the CloudFormation operation ID is available from the CloudFormation event/API response.** The AWS CLI's `describe-events` API is specifically designed around CloudFormation operations and supports operation-specific event retrieval.

Your monitor therefore deliberately records:

```text
Deployment ID
      │
      ├── GitHub Run ID
      │
      ├── Terraform execution
      │
      ├── CloudFormation Stack ID
      │
      ├── CloudFormation Operation ID
      │
      ├── Event ID
      │
      └── Failed Resource
```

That is the correlation chain we ultimately want.

Also, **do not put `deployment-logs/` into Git**. The logs belong in the GitHub Actions artifact, while the source code belongs in your repository.

### Most importantly

I would **not run this against your production/lab stack immediately**.

First run:

```powershell
pwsh -File .\scripts\deployment-monitor\Monitor-CloudFormation.ps1 `
  -StackName "hybridiaclab-dev-MainStack" `
  -Region "us-east-1" `
  -OutputDirectory ".\deployment-logs" `
  -PollSeconds 3 `
  -TimeoutMinutes 5
```

just to validate the monitor's AWS permissions and CloudFormation API behavior.

Then we run the complete Terraform orchestration.

That two-stage test will let us catch any AWS CLI/CloudFormation API differences **before** we make Step 15 responsible for your real Terraform deployment.

---
# New Updated Real Time Monitoring

