# GitHub Actions Step 15

### terraform.yml

### 1. GitHub Actions Step 15

Now your workflow needs to point to:

```
deployment-monitor-systam/
```
not:

```
scripts/deployment-monitor-systam/
```

Replace your current Step 15 with:

```
# ==========================================================
# STEP 15 - TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR
# ==========================================================
- name: Step 15 - Terraform Apply With Live CloudFormation Diagnostics
  if: ${{ env.TF_AUTO_APPROVE == 'true' }}
  working-directory: ${{ env.TF_WORKING_DIRECTORY }}
  shell: pwsh
  env:
    AWS_PAGER: ""
  run: |

    $ErrorActionPreference = "Continue"

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STEP 15 - TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # ==========================================================
    # REPOSITORY ROOT
    # ==========================================================
    #
    # TF_WORKING_DIRECTORY is normally:
    #
    #   infrastructure/terraform
    #
    # Therefore:
    #
    #   ../.. = repository root
    #
    # ==========================================================

    $RepositoryRoot = (
      Resolve-Path "../.."
    ).Path

    Write-Host "Repository root:"
    Write-Host $RepositoryRoot

    # ==========================================================
    # NEW MONITOR DIRECTORY
    # ==========================================================

    $MonitorDirectory = Join-Path `
      $RepositoryRoot `
      "deployment-monitor-systam"

    Write-Host ""
    Write-Host "Deployment monitor directory:"
    Write-Host $MonitorDirectory

    # ==========================================================
    # OUTPUT DIRECTORY
    # ==========================================================

    $OutputDirectory = Join-Path `
      $RepositoryRoot `
      "deployment-logs"

    Write-Host ""
    Write-Host "Deployment diagnostics directory:"
    Write-Host $OutputDirectory

    # ==========================================================
    # VERIFY MONITOR DIRECTORY
    # ==========================================================

    if (
      -not (
        Test-Path `
          -LiteralPath $MonitorDirectory
      )
    ) {

      Write-Host ""
      Write-Host "ERROR: deployment-monitor-systam directory was not found." `
        -ForegroundColor Red

      Write-Host ""
      Write-Host "Expected:"
      Write-Host $MonitorDirectory

      exit 1
    }

    # ==========================================================
    # VERIFY REQUIRED FILES
    # ==========================================================

    $RequiredFiles = @(
      "Monitor-CloudFormation.ps1"
      "Start-Deployment.ps1"
      "Generate-Report.ps1"
      "failure-rules.json"
    )

    foreach ($File in $RequiredFiles) {

      $FullPath = Join-Path `
        $MonitorDirectory `
        $File

      if (
        -not (
          Test-Path `
            -LiteralPath $FullPath
        )
      ) {

        Write-Host ""
        Write-Host "ERROR: Required monitoring file missing:" `
          -ForegroundColor Red

        Write-Host $FullPath

        exit 1
      }

      Write-Host "FOUND: $FullPath"
    }

    # ==========================================================
    # DETERMINE ROOT STACK
    # ==========================================================

    $MainStackName = "${env:PROJECT_NAME}-${env:ENVIRONMENT}-MainStack"

    Write-Host ""
    Write-Host "CloudFormation root stack:"
    Write-Host $MainStackName

    Write-Host ""
    Write-Host "AWS region:"
    Write-Host $env:AWS_REGION

    # ==========================================================
    # DETERMINE TERRAFORM PLAN
    # ==========================================================
    #
    # Keep this aligned with your existing workflow.
    #
    # If your Step 14 creates a different plan filename, change
    # TF_PLAN_FILE in your existing workflow.
    #
    # ==========================================================

    if (
      [string]::IsNullOrWhiteSpace(
        $env:TF_PLAN_FILE
      )
    ) {

      Write-Host ""
      Write-Host "ERROR: TF_PLAN_FILE is not defined." `
        -ForegroundColor Red

      exit 1
    }

    Write-Host ""
    Write-Host "Terraform plan:"
    Write-Host $env:TF_PLAN_FILE

    # ==========================================================
    # START PROFESSIONAL DEPLOYMENT ORCHESTRATOR
    # ==========================================================

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "STARTING DEPLOYMENT MONITORING SYSTEM" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow

    & pwsh `
      -NoProfile `
      -NonInteractive `
      -File `
      (Join-Path $MonitorDirectory "Start-Deployment.ps1") `
      -TerraformWorkingDirectory `
      (Get-Location).Path `
      -StackName `
      $MainStackName `
      -Region `
      $env:AWS_REGION `
      -MonitorDirectory `
      $MonitorDirectory `
      -OutputDirectory `
      $OutputDirectory `
      -TerraformPlanFile `
      $env:TF_PLAN_FILE `
      -AutoApprove `
      -PollSeconds `
      3 `
      -MonitorTimeoutMinutes `
      120

    $DeploymentExitCode = $LASTEXITCODE

    Write-Host ""
    Write-Host "============================================================"

    if ($DeploymentExitCode -eq 0) {

      Write-Host `
        "STEP 15 COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green

    }
    else {

      Write-Host `
        "STEP 15 FAILED" `
        -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Final Terraform/Deployment exit code:"
    Write-Host $DeploymentExitCode

    Write-Host ""
    Write-Host "Diagnostic directory:"
    Write-Host $OutputDirectory

    Write-Host "============================================================"

    # ==========================================================
    # TERRAFORM REMAINS AUTHORITATIVE
    # ==========================================================

    exit $DeploymentExitCode
```

### 2. Step 16 — upload everything

Immediately after Step 15:

```
# ==========================================================
# STEP 16 - UPLOAD COMPLETE DEPLOYMENT DIAGNOSTICS
# ==========================================================
- name: Step 16 - Upload Complete Deployment Diagnostics
  if: ${{ always() }}
  uses: actions/upload-artifact@v4
  with:
    name: deployment-diagnostics-${{ github.run_id }}
    path: |
      ${{ github.workspace }}/deployment-logs/
    if-no-files-found: warn
    retention-days: 30
```

This means the artifact should contain things such as:

deployment-diagnostics-34255678413.zip

```
├── deployment-context.json
│
├── terraform.jsonl
├── terraform-stderr.log
│
├── cloudformation-monitor.log
├── cloudformation-events.jsonl
├── cloudformation-failures.jsonl
├── cloudformation-operations.jsonl
│
├── cloudformation-latest-stack.json
├── cloudformation-latest-events.json
├── cloudformation-metadata.json
├── nested-stacks.json
│
├── diagnosis.json
└── deployment-summary.md
```