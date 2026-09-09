# ============================================================
# AWS HYBRID IaC LAB
# POWERSHELL LAUNCHER
# ============================================================
#
# File:
#   scripts\Start-AWSLab.ps1
#
# Purpose:
#   1. Open a NEW PowerShell window
#   2. Automatically enter the local GitHub repository
#   3. Allow PowerShell scripts to run in that session
#   4. Keep ExecutionPolicy changes temporary
#
# ============================================================


# ============================================================
# 1. LOCAL GITHUB REPOSITORY DIRECTORY
# ============================================================
#
# CHANGE ONLY THIS VARIABLE IF YOU MOVE YOUR REPOSITORY
#
# ============================================================

$LocalRepo = "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"


# ============================================================
# 2. VERIFY REPOSITORY DIRECTORY
# ============================================================

if (-not (Test-Path -LiteralPath $LocalRepo -PathType Container)) {

    Add-Type -AssemblyName PresentationFramework

    [System.Windows.MessageBox]::Show(
        "AWS Hybrid IaC Lab repository was not found.`n`nPath:`n$LocalRepo",
        "AWS Lab Launcher - Error",
        "OK",
        "Error"
    )

    exit 1
}


# ============================================================
# 3. START A NEW POWERSHELL WINDOW
# ============================================================
#
# -NoExit
#       Keeps the new PowerShell window open.
#
# -ExecutionPolicy Bypass
#       Allows your local scripts to run without requiring you
#       to manually bypass the execution policy.
#
# -Command
#       Changes directory to your GitHub repository.
#
# ============================================================

$Command = @"
Set-Location -LiteralPath '$LocalRepo'
Clear-Host

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          AWS HYBRID IaC LAB - POWERSHELL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository:" -ForegroundColor Yellow
Write-Host "$LocalRepo" -ForegroundColor Green
Write-Host ""
Write-Host "Execution Policy:" -ForegroundColor Yellow
Write-Host "Bypass (Current Session Only)" -ForegroundColor Green
Write-Host ""
Write-Host "Current Directory:" -ForegroundColor Yellow
Write-Host (Get-Location) -ForegroundColor Green
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
"@


# ============================================================
# 4. LAUNCH POWERSHELL
# ============================================================

Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList "-NoProfile", "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $Command

