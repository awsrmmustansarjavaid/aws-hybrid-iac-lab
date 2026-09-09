#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 CLOUD FORMATION LIVE DEPLOYMENT MONITOR
====================================================================

 File:
   deployment-monitor-systam/Monitor-CloudFormation.ps1

 PURPOSE
 -------------------------------------------------------------------
 Monitor CloudFormation while Terraform is running.

 The monitor is READ-ONLY.

 It does NOT:
   - create resources
   - update resources
   - delete resources
   - execute Terraform
   - modify CloudFormation

 It observes:

   Main CloudFormation stack
          |
          +---- Nested Stack
          |       |
          |       +---- resources
          |
          +---- Nested Stack
          |
          +---- resources

 It captures:

   - stack status
   - nested stack discovery
   - stack events
   - Operation IDs
   - operation events
   - failed events
   - PhysicalResourceId
   - ResourceStatusReason
   - failure classifications
   - raw JSON
   - human-readable logs

 IMPORTANT
 -------------------------------------------------------------------
 Terraform remains authoritative.

 The monitor does not decide whether Terraform succeeded.

====================================================================
 REQUIREMENTS
====================================================================

 PowerShell 7+
 AWS CLI v2
 Valid AWS credentials

 Required AWS permissions:

   cloudformation:DescribeStacks
   cloudformation:DescribeStackEvents
   cloudformation:DescribeStackResources
   cloudformation:DescribeEvents
   sts:GetCallerIdentity

====================================================================
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [string]$OutputDirectory,

    [int]$PollSeconds = 3,

    [int]$TimeoutMinutes = 120,

    [string]$StopFile,

    [string]$DeploymentId
)

# ====================================================================
# INITIALIZATION
# ====================================================================

$ErrorActionPreference = "Continue"

if ([string]::IsNullOrWhiteSpace($DeploymentId)) {

    $DeploymentId = "manual-$(
        (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    )"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {

    $OutputDirectory = Join-Path `
        (Get-Location) `
        "deployment-logs"
}

$OutputDirectory = [System.IO.Path]::GetFullPath(
    $OutputDirectory
)

if (-not (Test-Path -LiteralPath $OutputDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
        Out-Null
}

if ([string]::IsNullOrWhiteSpace($StopFile)) {

    $StopFile = Join-Path `
        $OutputDirectory `
        "monitor.stop"
}

# ====================================================================
# FILES
# ====================================================================

$MonitorLog =
    Join-Path $OutputDirectory "cloudformation-monitor.log"

$EventsJsonl =
    Join-Path $OutputDirectory "cloudformation-events.jsonl"

$FailuresJsonl =
    Join-Path $OutputDirectory "cloudformation-failures.jsonl"

$OperationsJsonl =
    Join-Path $OutputDirectory "cloudformation-operations.jsonl"

$MetadataJson =
    Join-Path $OutputDirectory "cloudformation-metadata.json"

$NestedStacksJson =
    Join-Path $OutputDirectory "nested-stacks.json"

$LatestStackJson =
    Join-Path $OutputDirectory "cloudformation-latest-stack.json"

$LatestEventsJson =
    Join-Path $OutputDirectory "cloudformation-latest-events.json"

# ====================================================================
# RUNTIME STATE
# ====================================================================

$StartTime = Get-Date

$SeenEvents = @{}

$SeenOperations = @{}

$KnownStacks = @{}

$FirstFailure = $null

$LastRootStatus = $null

$LastRootStatusTime = $null

$MonitorTimedOut = $false

$StopRequested = $false

# ====================================================================
# TERMINAL STATES
# ====================================================================

$SuccessStates = @(
    "CREATE_COMPLETE",
    "UPDATE_COMPLETE",
    "IMPORT_COMPLETE"
)

$FailureStates = @(
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED",
    "ROLLBACK_FAILED",
    "UPDATE_ROLLBACK_FAILED"
)

$TerminalStates = @(
    "CREATE_COMPLETE",
    "UPDATE_COMPLETE",
    "IMPORT_COMPLETE",
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED",
    "ROLLBACK_FAILED",
    "UPDATE_ROLLBACK_FAILED",
    "ROLLBACK_COMPLETE",
    "UPDATE_ROLLBACK_COMPLETE",
    "DELETE_COMPLETE",
    "IMPORT_ROLLBACK_COMPLETE",
    "IMPORT_ROLLBACK_FAILED"
)

# ====================================================================
# LOGGING
# ====================================================================

function Write-MonitorLog {

    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Timestamp = (
        Get-Date
    ).ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ss.fffZ"
    )

    $Line =
        "[${Timestamp}] [$Level] $Message"

    Write-Host $Line

    Add-Content `
        -LiteralPath $MonitorLog `
        -Value $Line `
        -Encoding UTF8
}

function Write-Jsonl {

    param(
        [string]$Path,
        [object]$Object
    )

    $Json =
        $Object |
        ConvertTo-Json `
            -Depth 50 `
            -Compress

    Add-Content `
        -LiteralPath $Path `
        -Value $Json `
        -Encoding UTF8
}

# ====================================================================
# AWS CLI JSON HELPER
# ====================================================================

function Invoke-AwsJson {

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = & aws @Arguments 2>&1

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {

        return [PSCustomObject]@{
            Success  = $false
            ExitCode = $ExitCode
            Raw      = ($Output -join "`n")
            Data     = $null
        }
    }

    try {

        $Text = $Output -join "`n"

        if ([string]::IsNullOrWhiteSpace($Text)) {

            return [PSCustomObject]@{
                Success  = $true
                ExitCode = 0
                Raw      = ""
                Data     = $null
            }
        }

        return [PSCustomObject]@{
            Success  = $true
            ExitCode = 0
            Raw      = $Text
            Data     = (
                $Text | ConvertFrom-Json
            )
        }
    }
    catch {

        return [PSCustomObject]@{
            Success  = $false
            ExitCode = 0
            Raw      = ($Output -join "`n")
            Data     = $null
        }
    }
}

# ====================================================================
# FAILURE CLASSIFICATION
# ====================================================================

function Get-FailureClassification {

    param(
        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($Reason)) {

        return [PSCustomObject]@{
            Category = "UNKNOWN"
            Priority = 99
        }
    }

    $RulesFile =
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "deployment-monitor-systam/failure-rules.json"

    # Because this script is already inside deployment-monitor-systam,
    # use the direct local path first.
    $RulesFile =
        Join-Path $PSScriptRoot "failure-rules.json"

    if (-not (Test-Path -LiteralPath $RulesFile)) {

        return [PSCustomObject]@{
            Category = "UNCLASSIFIED"
            Priority = 99
        }
    }

    try {

        $Rules =
            Get-Content `
                -LiteralPath $RulesFile `
                -Raw |
            ConvertFrom-Json

        foreach ($Rule in $Rules.rules) {

            foreach ($Pattern in $Rule.patterns) {

                if ($Reason -match $Pattern) {

                    return [PSCustomObject]@{
                        Category =
                            $Rule.category

                        Priority =
                            [int]$Rule.priority

                        Recommendation =
                            $Rule.recommendation
                    }
                }
            }
        }
    }
    catch {

        return [PSCustomObject]@{
            Category = "RULE_ENGINE_ERROR"
            Priority = 99
        }
    }

    return [PSCustomObject]@{
        Category = "UNCLASSIFIED CLOUDFORMATION FAILURE"
        Priority = 99
    }
}

# ====================================================================
# PROCESS EVENT
# ====================================================================

function Process-Event {

    param(
        [Parameter(Mandatory = $true)]
        [object]$Event,

        [Parameter(Mandatory = $true)]
        [string]$SourceStack
    )

    $EventId =
        [string]$Event.EventId

    if ([string]::IsNullOrWhiteSpace($EventId)) {
        return
    }

    if ($SeenEvents.ContainsKey($EventId)) {
        return
    }

    $SeenEvents[$EventId] = $true

    $ResourceStatus =
        [string]$Event.ResourceStatus

    $IsFailure =
        $ResourceStatus -match `
        "FAILED|ROLLBACK_FAILED|DELETE_FAILED"

    # ---------------------------------------------------------------
    # Save every event.
    # ---------------------------------------------------------------

    $EventRecord = [ordered]@{

        DeploymentId =
            $DeploymentId

        DetectedAt =
            (
                Get-Date
            ).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        SourceStack =
            $SourceStack

        EventId =
            $Event.EventId

        OperationId =
            $Event.OperationId

        StackId =
            $Event.StackId

        StackName =
            $Event.StackName

        Timestamp =
            $Event.Timestamp

        LogicalResourceId =
            $Event.LogicalResourceId

        PhysicalResourceId =
            $Event.PhysicalResourceId

        ResourceType =
            $Event.ResourceType

        ResourceStatus =
            $Event.ResourceStatus

        ResourceStatusReason =
            $Event.ResourceStatusReason

        DetailedStatus =
            $Event.DetailedStatus
    }

    Write-Jsonl `
        -Path $EventsJsonl `
        -Object $EventRecord

    # ---------------------------------------------------------------
    # Display important state changes.
    # ---------------------------------------------------------------

    if (
        $ResourceStatus -match
        "IN_PROGRESS|COMPLETE|FAILED|ROLLBACK"
    ) {

        Write-MonitorLog `
            "$SourceStack | $($Event.LogicalResourceId) | $ResourceStatus"
    }

    # ---------------------------------------------------------------
    # FAILURE PROCESSING
    # ---------------------------------------------------------------

    if (-not $IsFailure) {
        return
    }

    $Reason =
        [string]$Event.ResourceStatusReason

    if ([string]::IsNullOrWhiteSpace($Reason)) {

        $Reason =
            "CloudFormation did not provide a resource status reason."
    }

    $Classification =
        Get-FailureClassification `
            -Reason $Reason

    $FailureRecord = [ordered]@{

        DeploymentId =
            $DeploymentId

        DetectedAt =
            (
                Get-Date
            ).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        SourceStack =
            $SourceStack

        EventId =
            $Event.EventId

        OperationId =
            $Event.OperationId

        Timestamp =
            $Event.Timestamp

        LogicalResourceId =
            $Event.LogicalResourceId

        PhysicalResourceId =
            $Event.PhysicalResourceId

        ResourceType =
            $Event.ResourceType

        ResourceStatus =
            $Event.ResourceStatus

        Reason =
            $Reason

        Category =
            $Classification.Category

        Priority =
            $Classification.Priority

        Recommendation =
            $Classification.Recommendation
    }

    Write-Jsonl `
        -Path $FailuresJsonl `
        -Object $FailureRecord

    # ---------------------------------------------------------------
    # First failure is extremely important.
    #
    # We use the earliest actual resource failure as the strongest
    # root-cause candidate.
    # ---------------------------------------------------------------

    if ($null -eq $FirstFailure) {

        $FirstFailure = $FailureRecord

        Write-MonitorLog ""
        Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-MonitorLog "FIRST CLOUDFORMATION FAILURE DETECTED" "ERROR"
        Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

        Write-MonitorLog `
            "Stack: $SourceStack" `
            "ERROR"

        Write-MonitorLog `
            "OperationId: $($Event.OperationId)" `
            "ERROR"

        Write-MonitorLog `
            "LogicalResourceId: $($Event.LogicalResourceId)" `
            "ERROR"

        Write-MonitorLog `
            "ResourceType: $($Event.ResourceType)" `
            "ERROR"

        Write-MonitorLog `
            "Status: $($Event.ResourceStatus)" `
            "ERROR"

        Write-MonitorLog `
            "EXACT REASON: $Reason" `
            "ERROR"

        Write-MonitorLog `
            "CLASSIFICATION: $($Classification.Category)" `
            "ERROR"

        if ($Classification.Recommendation) {

            Write-MonitorLog `
                "RECOMMENDATION: $($Classification.Recommendation)" `
                "WARN"
        }

        Write-MonitorLog ""
    }
}

# ====================================================================
# DISCOVER OPERATION IDS
# ====================================================================

function Discover-Operations {

    param(
        [string]$TargetStack
    )

    $Result = Invoke-AwsJson @(
        "cloudformation"
        "describe-stacks"
        "--stack-name"
        $TargetStack
        "--region"
        $Region
        "--output"
        "json"
    )

    if (-not $Result.Success) {
        return $null
    }

    $Stack =
        $Result.Data.Stacks[0]

    if ($null -eq $Stack) {
        return $null
    }

    if ($null -eq $Stack.LastOperations) {
        return $Stack
    }

    foreach ($Operation in $Stack.LastOperations) {

        $OperationId =
            [string]$Operation.OperationId

        if (
            [string]::IsNullOrWhiteSpace(
                $OperationId
            )
        ) {
            continue
        }

        if (
            $SeenOperations.ContainsKey(
                $OperationId
            )
        ) {
            continue
        }

        $SeenOperations[$OperationId] = $true

        $OperationRecord = [ordered]@{

            DeploymentId =
                $DeploymentId

            DetectedAt =
                (
                    Get-Date
                ).ToUniversalTime().ToString(
                    "yyyy-MM-ddTHH:mm:ss.fffZ"
                )

            StackName =
                $TargetStack

            OperationId =
                $OperationId

            OperationType =
                $Operation.OperationType
        }

        Write-Jsonl `
            -Path $OperationsJsonl `
            -Object $OperationRecord

        Write-MonitorLog `
            "Operation discovered | Stack=$TargetStack | Type=$($Operation.OperationType) | OperationId=$OperationId"

        # -----------------------------------------------------------
        # Retrieve operation-specific events.
        # -----------------------------------------------------------

        $OperationEvents =
            Invoke-AwsJson @(
                "cloudformation"
                "describe-events"
                "--operation-id"
                $OperationId
                "--region"
                $Region
                "--no-paginate"
                "--output"
                "json"
            )

        if ($OperationEvents.Success) {

            if ($null -ne $OperationEvents.Data.OperationEvents) {

                foreach (
                    $Event
                    in $OperationEvents.Data.OperationEvents
                ) {

                    Process-Event `
                        -Event $Event `
                        -SourceStack $TargetStack
                }
            }
        }
    }

    return $Stack
}

# ====================================================================
# DISCOVER STACK RESOURCES / NESTED STACKS
# ====================================================================

function Discover-NestedStacks {

    param(
        [string]$TargetStack
    )

    $Result = Invoke-AwsJson @(
        "cloudformation"
        "describe-stack-resources"
        "--stack-name"
        $TargetStack
        "--region"
        $Region
        "--output"
        "json"
    )

    if (-not $Result.Success) {
        return
    }

    foreach (
        $Resource
        in $Result.Data.StackResources
    ) {

        if (
            $Resource.ResourceType `
            -ne "AWS::CloudFormation::Stack"
        ) {
            continue
        }

        $NestedStackId =
            [string]$Resource.PhysicalResourceId

        if (
            [string]::IsNullOrWhiteSpace(
                $NestedStackId
            )
        ) {
            continue
        }

        if (
            $KnownStacks.ContainsKey(
                $NestedStackId
            )
        ) {
            continue
        }

        $KnownStacks[$NestedStackId] = @{
            LogicalId =
                [string]$Resource.LogicalResourceId

            ParentStack =
                $TargetStack

            StackId =
                $NestedStackId
        }

        Write-MonitorLog ""
        Write-MonitorLog "NESTED STACK DISCOVERED"
        Write-MonitorLog "  Parent: $TargetStack"
        Write-MonitorLog "  LogicalId: $($Resource.LogicalResourceId)"
        Write-MonitorLog "  StackId: $NestedStackId"

        # -----------------------------------------------------------
        # Immediately discover operations for the nested stack.
        # -----------------------------------------------------------

        Discover-Operations `
            -TargetStack $NestedStackId |
            Out-Null

        # -----------------------------------------------------------
        # Recursively discover additional nested stacks.
        # -----------------------------------------------------------

        Discover-NestedStacks `
            -TargetStack $NestedStackId
    }

    # ---------------------------------------------------------------
    # Save nested-stack inventory.
    # ---------------------------------------------------------------

    $NestedArray = @()

    foreach ($Key in $KnownStacks.Keys) {

        $NestedArray += [ordered]@{

            LogicalId =
                $KnownStacks[$Key].LogicalId

            ParentStack =
                $KnownStacks[$Key].ParentStack

            StackId =
                $KnownStacks[$Key].StackId
        }
    }

    $NestedArray |
        ConvertTo-Json `
            -Depth 20 |
        Set-Content `
            -LiteralPath $NestedStacksJson `
            -Encoding UTF8
}

# ====================================================================
# GET STACK EVENTS
# ====================================================================

function Read-StackEvents {

    param(
        [string]$TargetStack
    )

    $Result = Invoke-AwsJson @(
        "cloudformation"
        "describe-stack-events"
        "--stack-name"
        $TargetStack
        "--region"
        $Region
        "--no-paginate"
        "--output"
        "json"
    )

    if (-not $Result.Success) {
        return
    }

    if ($null -eq $Result.Data.StackEvents) {
        return
    }

    foreach (
        $Event
        in $Result.Data.StackEvents
    ) {

        Process-Event `
            -Event $Event `
            -SourceStack $TargetStack
    }

    $Result.Data |
        ConvertTo-Json `
            -Depth 50 |
        Set-Content `
            -LiteralPath $LatestEventsJson `
            -Encoding UTF8
}

# ====================================================================
# WRITE METADATA
# ====================================================================

function Write-Metadata {

    param(
        [object]$Stack
    )

    $Metadata = [ordered]@{

        DeploymentId =
            $DeploymentId

        MonitorStartUtc =
            $StartTime.ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        LastUpdatedUtc =
            (
                Get-Date
            ).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        Region =
            $Region

        RootStackName =
            $StackName

        RootStackId =
            $Stack.StackId

        RootStackStatus =
            $Stack.StackStatus

        RootStackStatusReason =
            $Stack.StackStatusReason

        FirstFailure =
            $FirstFailure

        KnownNestedStacks =
            @(
                $KnownStacks.Values
            )
    }

    $Metadata |
        ConvertTo-Json `
            -Depth 50 |
        Set-Content `
            -LiteralPath $MetadataJson `
            -Encoding UTF8
}

# ====================================================================
# START
# ====================================================================

Write-MonitorLog ""
Write-MonitorLog "============================================================"
Write-MonitorLog "CLOUDFORMATION LIVE MONITOR STARTED"
Write-MonitorLog "============================================================"

Write-MonitorLog "DeploymentId: $DeploymentId"
Write-MonitorLog "Root Stack: $StackName"
Write-MonitorLog "Region: $Region"
Write-MonitorLog "Poll Seconds: $PollSeconds"
Write-MonitorLog "Timeout Minutes: $TimeoutMinutes"
Write-MonitorLog "Stop File: $StopFile"

# ====================================================================
# AWS IDENTITY
# ====================================================================

$Identity =
    Invoke-AwsJson @(
        "sts"
        "get-caller-identity"
        "--region"
        $Region
        "--output"
        "json"
    )

if (-not $Identity.Success) {

    Write-MonitorLog `
        "AWS identity check failed." `
        "ERROR"

    exit 2
}

Write-MonitorLog `
    "AWS Account: $($Identity.Data.Account)"

Write-MonitorLog `
    "AWS Principal: $($Identity.Data.Arn)"

# ====================================================================
# MAIN LOOP
# ====================================================================

while ($true) {

    # ================================================================
    # TIMEOUT
    # ================================================================

    if ($TimeoutMinutes -gt 0) {

        $Elapsed =
            (
                New-TimeSpan `
                    -Start $StartTime `
                    -End (Get-Date)
            )

        if (
            $Elapsed.TotalMinutes `
            -ge $TimeoutMinutes
        ) {

            $MonitorTimedOut = $true

            Write-MonitorLog `
                "Monitor timeout reached." `
                "ERROR"

            break
        }
    }

    # ================================================================
    # STOP SIGNAL
    # ================================================================

    if (
        Test-Path `
            -LiteralPath $StopFile
    ) {

        if (-not $StopRequested) {

            $StopRequested = $true

            Write-MonitorLog `
                "Stop signal received from deployment orchestrator." `
                "WARN"
        }
    }

    # ================================================================
    # DISCOVER ROOT STACK
    # ================================================================

    $RootStack =
        Discover-Operations `
            -TargetStack $StackName

    if ($null -eq $RootStack) {

        Write-MonitorLog `
            "Root CloudFormation stack not available yet."

        Start-Sleep `
            -Seconds $PollSeconds

        continue
    }

    # ================================================================
    # REGISTER ROOT STACK
    # ================================================================

    if (
        -not $KnownStacks.ContainsKey(
            $RootStack.StackId
        )
    ) {

        $KnownStacks[$RootStack.StackId] = @{
            LogicalId =
                $RootStack.StackName

            ParentStack =
                $null

            StackId =
                $RootStack.StackId
        }

        Write-MonitorLog ""
        Write-MonitorLog `
            "ROOT CLOUDFORMATION STACK DETECTED"

        Write-MonitorLog `
            "StackId: $($RootStack.StackId)"
    }

    # ================================================================
    # STATUS CHANGE
    # ================================================================

    if (
        $RootStack.StackStatus `
        -ne $LastRootStatus
    ) {

        $LastRootStatus =
            $RootStack.StackStatus

        $LastRootStatusTime =
            Get-Date

        Write-MonitorLog ""
        Write-MonitorLog `
            "ROOT STACK STATUS = $($RootStack.StackStatus)"

        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$RootStack.StackStatusReason
            )
        ) {

            Write-MonitorLog `
                "STATUS REASON = $($RootStack.StackStatusReason)"
        }
    }

    # ================================================================
    # SAVE ROOT STACK SNAPSHOT
    # ================================================================

    $RootStack |
        ConvertTo-Json `
            -Depth 50 |
        Set-Content `
            -LiteralPath $LatestStackJson `
            -Encoding UTF8

    # ================================================================
    # READ EVENTS
    # ================================================================

    Read-StackEvents `
        -TargetStack $StackName

    # ================================================================
    # DISCOVER NESTED STACKS
    # ================================================================

    Discover-NestedStacks `
        -TargetStack $StackName

    # ================================================================
    # READ EVENTS FROM ALL KNOWN STACKS
    # ================================================================

    foreach (
        $StackId
        in @($KnownStacks.Keys)
    ) {

        if ($StackId -eq $RootStack.StackId) {
            continue
        }

        Read-StackEvents `
            -TargetStack $StackId
    }

    # ================================================================
    # UPDATE METADATA
    # ================================================================

    Write-Metadata `
        -Stack $RootStack

    # ================================================================
    # TERMINATION LOGIC
    # ================================================================

    $RootTerminal =
        $TerminalStates `
        -contains `
        $RootStack.StackStatus

    if ($StopRequested -and $RootTerminal) {

        Write-MonitorLog ""
        Write-MonitorLog `
            "Terraform has requested monitor shutdown."

        Write-MonitorLog `
            "Root CloudFormation stack is terminal."

        Write-MonitorLog `
            "Final status: $($RootStack.StackStatus)"

        break
    }

    # ---------------------------------------------------------------
    # If CloudFormation itself reached a terminal failure, keep
    # monitoring until Terraform tells us the deployment is finished.
    # ---------------------------------------------------------------

    if (
        $RootStack.StackStatus `
        -in $FailureStates
    ) {

        Write-MonitorLog `
            "CloudFormation entered terminal failure state." `
            "ERROR"
    }

    Start-Sleep `
        -Seconds $PollSeconds
}

# ====================================================================
# FINAL METADATA
# ====================================================================

$FinalStatus = $LastRootStatus

$FinalMetadata = [ordered]@{

    DeploymentId =
        $DeploymentId

    MonitorStartedUtc =
        $StartTime.ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    MonitorFinishedUtc =
        (
            Get-Date
        ).ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    Region =
        $Region

    RootStackName =
        $StackName

    FinalRootStatus =
        $FinalStatus

    MonitorTimedOut =
        $MonitorTimedOut

    StopRequested =
        $StopRequested

    FirstFailure =
        $FirstFailure

    KnownStackCount =
        $KnownStacks.Count
}

$FinalMetadata |
    ConvertTo-Json `
        -Depth 50 |
    Set-Content `
        -LiteralPath $MetadataJson `
        -Encoding UTF8

Write-MonitorLog ""
Write-MonitorLog "============================================================"
Write-MonitorLog "CLOUDFORMATION LIVE MONITOR FINISHED"
Write-MonitorLog "============================================================"

Write-MonitorLog `
    "Final Root Stack Status: $FinalStatus"

Write-MonitorLog `
    "First Failure Captured: $(
        if ($null -ne $FirstFailure) { "YES" } else { "NO" }
    )"

Write-MonitorLog `
    "Known Stacks: $($KnownStacks.Count)"

if ($MonitorTimedOut) {

    exit 2
}

exit 0