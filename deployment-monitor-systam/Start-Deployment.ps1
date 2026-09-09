#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 TERRAFORM + CLOUDFORMATION DEPLOYMENT ORCHESTRATOR
====================================================================

 File:
   deployment-monitor-systam/Start-Deployment.ps1

 PURPOSE
 -------------------------------------------------------------------
 Run Terraform and CloudFormation monitoring concurrently.

 Architecture:

                 Start-Deployment.ps1
                         |
              +----------+----------+
              |                     |
              v                     v
       CloudFormation           Terraform
          Monitor                Apply
              |                     |
              +----------+----------+
                         |
                         v
                   Final Report

 Terraform remains authoritative.

====================================================================
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$TerraformWorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$MonitorDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$TerraformPlanFile = "tfplan",

    [switch]$AutoApprove,

    [int]$PollSeconds = 3,

    [int]$MonitorTimeoutMinutes = 120
)

# ====================================================================
# SETTINGS
# ====================================================================

$ErrorActionPreference = "Continue"

$StartTime = Get-Date

# ====================================================================
# PATHS
# ====================================================================

$TerraformWorkingDirectory =
    [System.IO.Path]::GetFullPath(
        $TerraformWorkingDirectory
    )

$MonitorDirectory =
    [System.IO.Path]::GetFullPath(
        $MonitorDirectory
    )

$OutputDirectory =
    [System.IO.Path]::GetFullPath(
        $OutputDirectory
    )

if (-not (Test-Path -LiteralPath $OutputDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
        Out-Null
}

$MonitorScript =
    Join-Path `
        $MonitorDirectory `
        "Monitor-CloudFormation.ps1"

$ReportScript =
    Join-Path `
        $MonitorDirectory `
        "Generate-Report.ps1"

$StopFile =
    Join-Path `
        $OutputDirectory `
        "monitor.stop"

$TerraformJsonl =
    Join-Path `
        $OutputDirectory `
        "terraform.jsonl"

$TerraformLog =
    Join-Path `
        $OutputDirectory `
        "terraform.log"

$TerraformStdErr =
    Join-Path `
        $OutputDirectory `
        "terraform-stderr.log"

$DeploymentMetadata =
    Join-Path `
        $OutputDirectory `
        "deployment-context.json"

# ====================================================================
# DEPLOYMENT ID
# ====================================================================

$GitHubRunId =
    if ($env:GITHUB_RUN_ID) {
        $env:GITHUB_RUN_ID
    }
    else {
        "local"
    }

$DeploymentId =
    "DEP-$(
        (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    )-$GitHubRunId"

# ====================================================================
# VALIDATION
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "AWS HYBRID IaC LAB DEPLOYMENT ORCHESTRATOR" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Deployment ID:"
Write-Host $DeploymentId

Write-Host ""
Write-Host "Terraform directory:"
Write-Host $TerraformWorkingDirectory

Write-Host ""
Write-Host "Terraform plan:"
Write-Host $TerraformPlanFile

Write-Host ""
Write-Host "CloudFormation stack:"
Write-Host $StackName

Write-Host ""
Write-Host "AWS region:"
Write-Host $Region

Write-Host ""
Write-Host "Monitor directory:"
Write-Host $MonitorDirectory

Write-Host ""
Write-Host "Output directory:"
Write-Host $OutputDirectory

if (-not (Test-Path -LiteralPath $TerraformWorkingDirectory)) {

    Write-Host ""
    Write-Host "ERROR: Terraform working directory does not exist." -ForegroundColor Red

    exit 1
}

if (-not (Test-Path -LiteralPath $MonitorScript)) {

    Write-Host ""
    Write-Host "ERROR: Monitor script does not exist." -ForegroundColor Red
    Write-Host $MonitorScript

    exit 1
}

if (-not (Test-Path -LiteralPath $ReportScript)) {

    Write-Host ""
    Write-Host "ERROR: Report generator does not exist." -ForegroundColor Red
    Write-Host $ReportScript

    exit 1
}

# ====================================================================
# REMOVE OLD STOP SIGNAL
# ====================================================================

if (Test-Path -LiteralPath $StopFile) {

    Remove-Item `
        -LiteralPath $StopFile `
        -Force `
        -ErrorAction SilentlyContinue
}

# ====================================================================
# SAVE DEPLOYMENT CONTEXT
# ====================================================================

$Context = [ordered]@{

    DeploymentId =
        $DeploymentId

    GitHubRunId =
        $env:GITHUB_RUN_ID

    GitHubRunAttempt =
        $env:GITHUB_RUN_ATTEMPT

    GitHubRepository =
        $env:GITHUB_REPOSITORY

    GitHubSha =
        $env:GITHUB_SHA

    GitHubRef =
        $env:GITHUB_REF

    StartTimeUtc =
        $StartTime.ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    Region =
        $Region

    StackName =
        $StackName

    TerraformWorkingDirectory =
        $TerraformWorkingDirectory

    TerraformPlanFile =
        $TerraformPlanFile

    MonitorScript =
        $MonitorScript

    OutputDirectory =
        $OutputDirectory

    PollSeconds =
        $PollSeconds

    MonitorTimeoutMinutes =
        $MonitorTimeoutMinutes
}

$Context |
    ConvertTo-Json `
        -Depth 20 |
    Set-Content `
        -LiteralPath $DeploymentMetadata `
        -Encoding UTF8

# ====================================================================
# START CLOUDFORMATION MONITOR
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "STARTING CLOUDFORMATION LIVE MONITOR" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

$MonitorProcess = $null

try {

    $MonitorArguments = @(
        "-NoProfile"
        "-NonInteractive"
        "-File"
        $MonitorScript
        "-StackName"
        $StackName
        "-Region"
        $Region
        "-OutputDirectory"
        $OutputDirectory
        "-PollSeconds"
        $PollSeconds
        "-TimeoutMinutes"
        $MonitorTimeoutMinutes
        "-StopFile"
        $StopFile
        "-DeploymentId"
        $DeploymentId
    )

    $MonitorProcess =
        Start-Process `
            -FilePath "pwsh" `
            -WorkingDirectory $MonitorDirectory `
            -ArgumentList $MonitorArguments `
            -PassThru `
            -NoNewWindow

    Write-Host ""
    Write-Host "CloudFormation monitor PID:"
    Write-Host $MonitorProcess.Id

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to start CloudFormation monitor." -ForegroundColor Red
    Write-Host $_

    exit 1
}

# ====================================================================
# GIVE MONITOR TIME TO INITIALIZE
# ====================================================================

Start-Sleep -Seconds 2

# ====================================================================
# START TERRAFORM
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "STARTING TERRAFORM APPLY" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

$TerraformArguments = @(
    "apply"
    "-input=false"
)

if ($AutoApprove) {

    $TerraformArguments += "-auto-approve"
}

if (
    -not [string]::IsNullOrWhiteSpace(
        $TerraformPlanFile
    )
) {

    $TerraformArguments += $TerraformPlanFile
}

$TerraformProcess = $null

$TerraformStdOutPath =
    $TerraformJsonl

try {

    $ProcessInfo =
        New-Object `
            System.Diagnostics.ProcessStartInfo

    $ProcessInfo.FileName =
        "terraform"

    $ProcessInfo.WorkingDirectory =
        $TerraformWorkingDirectory

    foreach ($Argument in $TerraformArguments) {

        [void]$ProcessInfo.ArgumentList.Add(
            $Argument
        )
    }

    $ProcessInfo.UseShellExecute =
        $false

    $ProcessInfo.CreateNoWindow =
        $true

    $ProcessInfo.RedirectStandardOutput =
        $true

    $ProcessInfo.RedirectStandardError =
        $true

    $TerraformProcess =
        New-Object `
            System.Diagnostics.Process

    $TerraformProcess.StartInfo =
        $ProcessInfo

    [void]$TerraformProcess.Start()

    Write-Host ""
    Write-Host "Terraform PID:"
    Write-Host $TerraformProcess.Id

}
catch {

    Write-Host ""
    Write-Host "ERROR: Terraform could not be started." -ForegroundColor Red
    Write-Host $_

    # Tell monitor to finish.
    New-Item `
        -ItemType File `
        -Path $StopFile `
        -Force |
        Out-Null

    if ($MonitorProcess) {

        $MonitorProcess.WaitForExit(15000)

        if (-not $MonitorProcess.HasExited) {

            Stop-Process `
                -Id $MonitorProcess.Id `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    exit 1
}

# ====================================================================
# LIVE TERRAFORM OUTPUT LOOP
# ====================================================================

$TerraformStdOutBuffer = New-Object System.Collections.Generic.List[string]

$TerraformStdErrBuffer = New-Object System.Collections.Generic.List[string]

while (-not $TerraformProcess.HasExited) {

    # ---------------------------------------------------------------
    # Read stdout.
    # ---------------------------------------------------------------

    while (-not $TerraformProcess.StandardOutput.EndOfStream) {

        $Line =
            $TerraformProcess.StandardOutput.ReadLine()

        if ($null -eq $Line) {
            break
        }

        $TerraformStdOutBuffer.Add($Line)

        Add-Content `
            -LiteralPath $TerraformJsonl `
            -Value $Line `
            -Encoding UTF8

        # -----------------------------------------------------------
        # Terraform -json produces machine-readable JSONL.
        # Print useful messages to the GitHub console.
        # -----------------------------------------------------------

        try {

            $Json =
                $Line | ConvertFrom-Json

            if ($Json["@message"]) {

                Write-Host `
                    "[Terraform] $($Json["@message"])"
            }
            elseif ($Json.type) {

                Write-Host `
                    "[Terraform] $($Json.type)"
            }
            else {

                Write-Host `
                    "[Terraform] $Line"
            }

        }
        catch {

            Write-Host `
                "[Terraform] $Line"
        }
    }

    # ---------------------------------------------------------------
    # Read stderr.
    # ---------------------------------------------------------------

    while (-not $TerraformProcess.StandardError.EndOfStream) {

        $Line =
            $TerraformProcess.StandardError.ReadLine()

        if ($null -eq $Line) {
            break
        }

        $TerraformStdErrBuffer.Add($Line)

        Add-Content `
            -LiteralPath $TerraformStdErr `
            -Value $Line `
            -Encoding UTF8

        Write-Host `
            "[Terraform STDERR] $Line" `
            -ForegroundColor Yellow
    }

    # ---------------------------------------------------------------
    # Show live CloudFormation log tail when available.
    # ---------------------------------------------------------------

    $CFNLog =
        Join-Path `
            $OutputDirectory `
            "cloudformation-monitor.log"

    if (Test-Path -LiteralPath $CFNLog) {

        $LastLines =
            Get-Content `
                -LiteralPath $CFNLog `
                -Tail 3 `
                -ErrorAction SilentlyContinue

        foreach ($Line in $LastLines) {

            # Deliberately do not print every line continuously.
            # The monitor itself prints live to the GitHub console.
        }
    }

    Start-Sleep -Milliseconds 250
}

# ====================================================================
# READ REMAINING TERRAFORM OUTPUT
# ====================================================================

while (
    -not $TerraformProcess.StandardOutput.EndOfStream
) {

    $Line =
        $TerraformProcess.StandardOutput.ReadLine()

    if ($null -ne $Line) {

        Add-Content `
            -LiteralPath $TerraformJsonl `
            -Value $Line `
            -Encoding UTF8
    }
}

while (
    -not $TerraformProcess.StandardError.EndOfStream
) {

    $Line =
        $TerraformProcess.StandardError.ReadLine()

    if ($null -ne $Line) {

        Add-Content `
            -LiteralPath $TerraformStdErr `
            -Value $Line `
            -Encoding UTF8
    }
}

$TerraformExitCode =
    $TerraformProcess.ExitCode

$TerraformFinishedTime =
    Get-Date

Write-Host ""
Write-Host "============================================================"

if ($TerraformExitCode -eq 0) {

    Write-Host `
        "TERRAFORM EXIT CODE: 0" `
        -ForegroundColor Green
}
else {

    Write-Host `
        "TERRAFORM EXIT CODE: $TerraformExitCode" `
        -ForegroundColor Red
}

Write-Host "============================================================"

# ====================================================================
# UPDATE CONTEXT
# ====================================================================

$Context.TerraformExitCode =
    $TerraformExitCode

$Context.TerraformFinishedUtc =
    $TerraformFinishedTime.ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ss.fffZ"
    )

$Context |
    ConvertTo-Json `
        -Depth 20 |
    Set-Content `
        -LiteralPath $DeploymentMetadata `
        -Encoding UTF8

# ====================================================================
# SIGNAL MONITOR TO STOP
# ====================================================================

Write-Host ""
Write-Host "Signalling CloudFormation monitor to finish..."

New-Item `
    -ItemType File `
    -Path $StopFile `
    -Force |
    Out-Null

# ====================================================================
# WAIT FOR MONITOR
# ====================================================================

Write-Host ""
Write-Host "Waiting for CloudFormation monitor to finish..."

$MonitorWaitSeconds =
    [int](
        $MonitorTimeoutMinutes * 60
    )

$MonitorFinished =
    $MonitorProcess.WaitForExit(
        $MonitorWaitSeconds * 1000
    )

if (-not $MonitorFinished) {

    Write-Host ""
    Write-Host `
        "WARNING: CloudFormation monitor did not finish before timeout." `
        -ForegroundColor Yellow

    Stop-Process `
        -Id $MonitorProcess.Id `
        -Force `
        -ErrorAction SilentlyContinue
}

# ====================================================================
# GENERATE FINAL REPORT
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "GENERATING FINAL DEPLOYMENT DIAGNOSIS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

& pwsh `
    -NoProfile `
    -NonInteractive `
    -File `
    $ReportScript `
    -OutputDirectory `
    $OutputDirectory `
    -DeploymentId `
    $DeploymentId `
    -TerraformExitCode `
    $TerraformExitCode `
    -Region `
    $Region `
    -StackName `
    $StackName

$ReportExitCode =
    $LASTEXITCODE

# ====================================================================
# CLEANUP STOP FILE
# ====================================================================

if (Test-Path -LiteralPath $StopFile) {

    Remove-Item `
        -LiteralPath $StopFile `
        -Force `
        -ErrorAction SilentlyContinue
}

# ====================================================================
# FINAL RESULT
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT ORCHESTRATOR FINISHED" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Deployment ID:"
Write-Host $DeploymentId

Write-Host ""
Write-Host "Terraform Exit Code:"
Write-Host $TerraformExitCode

Write-Host ""
Write-Host "Report Exit Code:"
Write-Host $ReportExitCode

Write-Host ""
Write-Host "Diagnostic Directory:"
Write-Host $OutputDirectory

# ====================================================================
# TERRAFORM REMAINS AUTHORITATIVE
# ====================================================================

exit $TerraformExitCode