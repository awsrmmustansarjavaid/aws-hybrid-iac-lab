#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 DEPLOYMENT DIAGNOSIS REPORT GENERATOR
====================================================================

 File:
   deployment-monitor-systam/Generate-Report.ps1

 PURPOSE
 -------------------------------------------------------------------
 Compare:

   Terraform result
       +
   CloudFormation events
       +
   CloudFormation failure reason
       +
   Operation ID
       +
   Nested stack information

 and produce:

   diagnosis.json
   deployment-summary.md

 IMPORTANT
 -------------------------------------------------------------------
 This script does not change AWS infrastructure.

====================================================================
#>

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

$ErrorActionPreference = "Continue"

$OutputDirectory =
    [System.IO.Path]::GetFullPath(
        $OutputDirectory
    )

# ====================================================================
# FILES
# ====================================================================

$FailuresFile =
    Join-Path `
        $OutputDirectory `
        "cloudformation-failures.jsonl"

$EventsFile =
    Join-Path `
        $OutputDirectory `
        "cloudformation-events.jsonl"

$OperationsFile =
    Join-Path `
        $OutputDirectory `
        "cloudformation-operations.jsonl"

$TerraformJsonl =
    Join-Path `
        $OutputDirectory `
        "terraform.jsonl"

$TerraformStderr =
    Join-Path `
        $OutputDirectory `
        "terraform-stderr.log"

$CFNMetadata =
    Join-Path `
        $OutputDirectory `
        "cloudformation-metadata.json"

$ContextFile =
    Join-Path `
        $OutputDirectory `
        "deployment-context.json"

$DiagnosisJson =
    Join-Path `
        $OutputDirectory `
        "diagnosis.json"

$SummaryMarkdown =
    Join-Path `
        $OutputDirectory `
        "deployment-summary.md"

# ====================================================================
# HELPERS
# ====================================================================

function Read-JsonLines {

    param(
        [string]$Path
    )

    $Items = @()

    if (-not (Test-Path -LiteralPath $Path)) {

        return $Items
    }

    foreach (
        $Line
        in Get-Content -LiteralPath $Path
    ) {

        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }

        try {

            $Items += (
                $Line | ConvertFrom-Json
            )
        }
        catch {

            # Ignore malformed/non-JSON lines.
        }
    }

    return $Items
}

# ====================================================================
# LOAD DATA
# ====================================================================

$Failures =
    Read-JsonLines `
        -Path $FailuresFile

$Events =
    Read-JsonLines `
        -Path $EventsFile

$Operations =
    Read-JsonLines `
        -Path $OperationsFile

$TerraformMessages =
    Read-JsonLines `
        -Path $TerraformJsonl

$TerraformErrors =
    if (Test-Path -LiteralPath $TerraformStderr) {
        Get-Content `
            -LiteralPath $TerraformStderr
    }
    else {
        @()
    }

$Metadata =
    if (Test-Path -LiteralPath $CFNMetadata) {

        try {

            Get-Content `
                -LiteralPath $CFNMetadata `
                -Raw |
            ConvertFrom-Json
        }
        catch {
            $null
        }

    }
    else {
        $null
    }

$Context =
    if (Test-Path -LiteralPath $ContextFile) {

        try {

            Get-Content `
                -LiteralPath $ContextFile `
                -Raw |
            ConvertFrom-Json
        }
        catch {
            $null
        }

    }
    else {
        $null
    }

# ====================================================================
# FIND PRIMARY FAILURE
# ====================================================================

$PrimaryFailure = $null

if ($Failures.Count -gt 0) {

    # ---------------------------------------------------------------
    # Prefer the earliest detected failure.
    # ---------------------------------------------------------------

    $PrimaryFailure =
        $Failures |
        Sort-Object {
            try {
                [DateTime]$_.Timestamp
            }
            catch {
                [DateTime]::MaxValue
            }
        } |
        Select-Object -First 1
}

# ====================================================================
# FALLBACK: SEARCH EVENTS DIRECTLY
# ====================================================================

if ($null -eq $PrimaryFailure) {

    $FailedEvents =
        $Events |
        Where-Object {
            $_.ResourceStatus -match `
                "CREATE_FAILED|UPDATE_FAILED|DELETE_FAILED|ROLLBACK_FAILED"
        }

    if ($FailedEvents.Count -gt 0) {

        $Event =
            $FailedEvents |
            Sort-Object {
                try {
                    [DateTime]$_.Timestamp
                }
                catch {
                    [DateTime]::MaxValue
                }
            } |
            Select-Object -First 1

        $PrimaryFailure = [PSCustomObject]@{

            SourceStack =
                $Event.SourceStack

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
                $Event.ResourceStatusReason

            Category =
                "CLOUDFORMATION RESOURCE FAILURE"
        }
    }
}

# ====================================================================
# FIND TERRAFORM ERROR MESSAGES
# ====================================================================

$TerraformErrorMessages = @()

foreach ($Message in $TerraformMessages) {

    $Text = ""

    if ($Message."@message") {

        $Text =
            [string]$Message."@message"
    }
    elseif ($Message.message) {

        $Text =
            [string]$Message.message
    }

    if (
        -not [string]::IsNullOrWhiteSpace($Text) `
        -and
        $Text -match `
            "error|failed|failure|denied|unauthorized"
    ) {

        $TerraformErrorMessages += $Text
    }
}

foreach ($Line in $TerraformErrors) {

    if (
        $Line -match `
            "error|failed|failure|denied|unauthorized"
    ) {

        $TerraformErrorMessages +=
            [string]$Line
    }
}

# ====================================================================
# CORRELATE TERRAFORM WITH CLOUDFORMATION
# ====================================================================

$TerraformCorrelation = @()

if ($null -ne $PrimaryFailure) {

    $SearchTerms = @()

    if ($PrimaryFailure.LogicalResourceId) {

        $SearchTerms +=
            [string]$PrimaryFailure.LogicalResourceId
    }

    if ($PrimaryFailure.ResourceType) {

        $SearchTerms +=
            [string]$PrimaryFailure.ResourceType
    }

    if ($PrimaryFailure.Reason) {

        # -----------------------------------------------------------
        # Search useful words from the CloudFormation reason.
        # -----------------------------------------------------------

        $Words =
            [regex]::Matches(
                [string]$PrimaryFailure.Reason,
                "[A-Za-z0-9:_/-]{4,}"
            )

        foreach ($Word in $Words) {

            $SearchTerms +=
                $Word.Value
        }
    }

    $SearchTerms =
        $SearchTerms |
        Select-Object -Unique

    foreach ($Message in $TerraformErrorMessages) {

        foreach ($Term in $SearchTerms) {

            if (
                $Message `
                -and
                $Message -match `
                    [regex]::Escape($Term)
            ) {

                $TerraformCorrelation += $Message

                break
            }
        }
    }
}

$TerraformCorrelation =
    $TerraformCorrelation |
    Select-Object -Unique

# ====================================================================
# DETERMINE ROOT CAUSE
# ====================================================================

$DiagnosisStatus = "UNKNOWN"

$RootCauseStatement = ""

$Confidence = "LOW"

if (
    $TerraformExitCode -ne 0 `
    -and
    $null -ne $PrimaryFailure
) {

    $DiagnosisStatus =
        "CLOUDFORMATION_FAILURE_CONFIRMED"

    $Confidence =
        "HIGH"

    $RootCauseStatement =
        "Terraform failed because the CloudFormation deployment encountered a confirmed resource-level failure. The CloudFormation failure is considered the primary infrastructure error; Terraform's non-zero exit code is the downstream deployment result."

}
elseif (
    $TerraformExitCode -ne 0 `
    -and
    $null -eq $PrimaryFailure
) {

    $DiagnosisStatus =
        "TERRAFORM_FAILURE_CONFIRMED_CFN_ROOT_CAUSE_NOT_CAPTURED"

    $Confidence =
        "MEDIUM"

    $RootCauseStatement =
        "Terraform returned a non-zero exit code, but this monitoring run did not capture a confirmed CloudFormation resource failure. The Terraform error is confirmed, but a CloudFormation root cause cannot be established from the captured evidence."

}
elseif (
    $TerraformExitCode -eq 0 `
    -and
    $null -ne $PrimaryFailure
) {

    $DiagnosisStatus =
        "INCONSISTENT_RESULTS"

    $Confidence =
        "MEDIUM"

    $RootCauseStatement =
        "Terraform returned success while CloudFormation diagnostics contain a failure event. Further investigation is required because the two signals do not agree."
}
else {

    $DiagnosisStatus =
        "SUCCESS"

    $Confidence =
        "HIGH"

    $RootCauseStatement =
        "Terraform completed successfully and no CloudFormation resource failure was captured."
}

# ====================================================================
# BUILD TIMELINE
# ====================================================================

$Timeline = @()

if ($Context) {

    if ($Context.StartTimeUtc) {

        $Timeline += [ordered]@{
            Time =
                $Context.StartTimeUtc

            Event =
                "Deployment orchestration started"
        }
    }

    if ($Context.TerraformFinishedUtc) {

        $Timeline += [ordered]@{
            Time =
                $Context.TerraformFinishedUtc

            Event =
                "Terraform process finished with exit code $TerraformExitCode"
        }
    }
}

if ($PrimaryFailure) {

    $Timeline += [ordered]@{
        Time =
            $PrimaryFailure.Timestamp

        Event =
            "First CloudFormation resource failure detected: $($PrimaryFailure.LogicalResourceId)"
    }
}

if ($Metadata) {

    if ($Metadata.MonitorFinishedUtc) {

        $Timeline += [ordered]@{
            Time =
                $Metadata.MonitorFinishedUtc

            Event =
                "CloudFormation monitor finished"
        }
    }
}

$Timeline =
    $Timeline |
    Sort-Object {
        try {
            [DateTime]$_.Time
        }
        catch {
            [DateTime]::MaxValue
        }
    }

# ====================================================================
# OPERATION IDS
# ====================================================================

$OperationIds =
    $Operations |
    Select-Object `
        StackName,
        OperationId,
        OperationType,
        DetectedAt

# ====================================================================
# BUILD DIAGNOSIS
# ====================================================================

$Diagnosis = [ordered]@{

    DiagnosisVersion =
        "1.0"

    DeploymentId =
        $DeploymentId

    GeneratedAtUtc =
        (
            Get-Date
        ).ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    Environment = [ordered]@{

        Region =
            $Region

        RootStack =
            $StackName

        GitHubRunId =
            $env:GITHUB_RUN_ID

        GitHubRepository =
            $env:GITHUB_REPOSITORY

        GitHubSha =
            $env:GITHUB_SHA
    }

    Terraform = [ordered]@{

        ExitCode =
            $TerraformExitCode

        Status =
            if ($TerraformExitCode -eq 0) {
                "SUCCESS"
            }
            else {
                "FAILED"
            }

        ErrorMessages =
            $TerraformErrorMessages |
            Select-Object -Unique
    }

    CloudFormation = [ordered]@{

        FinalStackStatus =
            if ($Metadata) {
                $Metadata.FinalRootStatus
            }
            else {
                $null
            }

        FirstFailure =
            $PrimaryFailure

        OperationIds =
            $OperationIds

        FailureCount =
            $Failures.Count
    }

    Correlation = [ordered]@{

        Status =
            $DiagnosisStatus

        Confidence =
            $Confidence

        RootCauseStatement =
            $RootCauseStatement

        TerraformMatches =
            $TerraformCorrelation
    }

    Timeline =
        $Timeline

    EvidenceFiles = @(
        "deployment-context.json"
        "terraform.jsonl"
        "terraform-stderr.log"
        "cloudformation-monitor.log"
        "cloudformation-events.jsonl"
        "cloudformation-failures.jsonl"
        "cloudformation-operations.jsonl"
        "cloudformation-metadata.json"
        "cloudformation-latest-stack.json"
        "cloudformation-latest-events.json"
        "nested-stacks.json"
    )
}

# ====================================================================
# SAVE JSON REPORT
# ====================================================================

$Diagnosis |
    ConvertTo-Json `
        -Depth 50 |
    Set-Content `
        -LiteralPath $DiagnosisJson `
        -Encoding UTF8

# ====================================================================
# MARKDOWN REPORT
# ====================================================================

$Report = New-Object System.Collections.Generic.List[string]

$Report.Add("# AWS Hybrid IaC Lab - Deployment Diagnosis")

$Report.Add("")

$Report.Add("## Deployment")

$Report.Add("")

$Report.Add("| Field | Value |")
$Report.Add("|---|---|")
$Report.Add("| Deployment ID | `$DeploymentId` |")
$Report.Add("| Region | `$Region` |")
$Report.Add("| Root Stack | `$StackName` |")
$Report.Add("| Terraform Exit Code | `$TerraformExitCode` |")
$Report.Add("| Diagnosis | `$DiagnosisStatus` |")
$Report.Add("| Confidence | `$Confidence` |")

$Report.Add("")

$Report.Add("## Root Cause Statement")

$Report.Add("")

$Report.Add("> $RootCauseStatement")

$Report.Add("")

if ($PrimaryFailure) {

    $Report.Add("## Primary CloudFormation Failure")

    $Report.Add("")

    $Report.Add("| Field | Value |")
    $Report.Add("|---|---|")

    $Report.Add(
        "| Stack | $($PrimaryFailure.SourceStack) |"
    )

    $Report.Add(
        "| Operation ID | $($PrimaryFailure.OperationId) |"
    )

    $Report.Add(
        "| Logical Resource | $($PrimaryFailure.LogicalResourceId) |"
    )

    $Report.Add(
        "| Resource Type | $($PrimaryFailure.ResourceType) |"
    )

    $Report.Add(
        "| Physical Resource | $($PrimaryFailure.PhysicalResourceId) |"
    )

    $Report.Add(
        "| Status | $($PrimaryFailure.ResourceStatus) |"
    )

    $Report.Add(
        "| Classification | $($PrimaryFailure.Category) |"
    )

    $Report.Add(
        "| Timestamp | $($PrimaryFailure.Timestamp) |"
    )

    $Report.Add("")

    $Report.Add("### Exact CloudFormation Reason")

    $Report.Add("")

    $Report.Add(
        "```text"
    )

    $Report.Add(
        [string]$PrimaryFailure.Reason
    )

    $Report.Add(
        "```"
    )

}
else {

    $Report.Add("## Primary CloudFormation Failure")

    $Report.Add("")

    $Report.Add(
        "No confirmed CloudFormation resource failure was captured."
    )
}

$Report.Add("")

$Report.Add("## Terraform / CloudFormation Correlation")

$Report.Add("")

if ($TerraformCorrelation.Count -gt 0) {

    $Report.Add(
        "Terraform output contains messages correlated with the CloudFormation failure:"
    )

    $Report.Add("")

    foreach ($Message in $TerraformCorrelation) {

        $Report.Add(
            "- `$Message`"
        )
    }

}
else {

    $Report.Add(
        "No direct Terraform message could be matched to the primary CloudFormation failure."
    )
}

$Report.Add("")

$Report.Add("## Operation IDs")

$Report.Add("")

if ($OperationIds.Count -gt 0) {

    $Report.Add("| Stack | Operation Type | Operation ID | Detected |")
    $Report.Add("|---|---|---|---|")

    foreach ($Operation in $OperationIds) {

        $Report.Add(
            "| $($Operation.StackName) | $($Operation.OperationType) | `$($Operation.OperationId)` | $($Operation.DetectedAt) |"
        )
    }

}
else {

    $Report.Add(
        "No CloudFormation Operation IDs were captured."
    )
}

$Report.Add("")

$Report.Add("## Timeline")

$Report.Add("")

if ($Timeline.Count -gt 0) {

    $Report.Add("| Time | Event |")
    $Report.Add("|---|---|")

    foreach ($Item in $Timeline) {

        $Report.Add(
            "| $($Item.Time) | $($Item.Event) |"
        )
    }

}
else {

    $Report.Add(
        "No timeline events were captured."
    )
}

$Report.Add("")

$Report.Add("## Interpretation")

$Report.Add("")

if ($DiagnosisStatus -eq "CLOUDFORMATION_FAILURE_CONFIRMED") {

    $Report.Add(
        "The evidence indicates that the primary infrastructure failure occurred inside CloudFormation."
    )

    $Report.Add("")

    $Report.Add(
        "Terraform's non-zero exit code is the deployment-level consequence of the CloudFormation failure."
    )

    $Report.Add("")

    $Report.Add(
        "The earliest resource-level CloudFormation failure should be investigated before later rollback events."
    )

}
elseif (
    $DiagnosisStatus `
    -eq `
    "TERRAFORM_FAILURE_CONFIRMED_CFN_ROOT_CAUSE_NOT_CAPTURED"
) {

    $Report.Add(
        "Terraform definitely failed, but this diagnostic run did not capture enough CloudFormation evidence to establish CloudFormation as the root cause."
    )

}
elseif (
    $DiagnosisStatus `
    -eq `
    "INCONSISTENT_RESULTS"
) {

    $Report.Add(
        "Terraform and CloudFormation signals disagree. Review the complete raw evidence before declaring the deployment successful."
    )

}
else {

    $Report.Add(
        "Terraform and CloudFormation diagnostics indicate a successful deployment."
    )
}

$Report.Add("")

$Report.Add("## Evidence Files")

$Report.Add("")

foreach ($File in $Diagnosis.EvidenceFiles) {

    $FullPath =
        Join-Path `
            $OutputDirectory `
            $File

    if (Test-Path -LiteralPath $FullPath) {

        $Report.Add(
            "- `$File` - available"
        )

    }
    else {

        $Report.Add(
            "- `$File` - not generated"
        )
    }
}

$Report |
    Set-Content `
        -LiteralPath $SummaryMarkdown `
        -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT DIAGNOSIS GENERATED" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Diagnosis:"
Write-Host $DiagnosisStatus

Write-Host ""
Write-Host "Confidence:"
Write-Host $Confidence

Write-Host ""
Write-Host "Report:"
Write-Host $SummaryMarkdown

Write-Host ""
Write-Host "JSON:"
Write-Host $DiagnosisJson

exit 0