# ============================================================
# GITHUB BROWSER LOGIN - FINAL VERSION
# ============================================================
#
# PURPOSE
# -------
# Authenticate GitHub CLI on this Windows PC using the
# GitHub web browser.
#
# BEHAVIOR
# --------
# 1. FIRST checks: gh auth status
#
# 2. If already logged in:
#       Shows a clear ALREADY LOGGED IN message
#       Displays the authenticated account
#       Stops the script
#
# 3. If NOT logged in:
#       Starts GitHub browser authentication
#
# 4. After browser authentication:
#       Verifies the GitHub username
#       Verifies GitHub API access
#       Verifies HTTPS Git configuration
#
# SECURITY
# --------
# [x] No email in script
# [x] No password in script
# [x] No PAT/token in script
# [x] Browser-based authentication
# [x] GitHub handles password/passkey/MFA
#
# REQUIREMENT
# -----------
# GitHub CLI must be installed.
#
# Test:
#     gh --version
#
# ============================================================


# ============================================================
# POWERSHELL SETTINGS
# ============================================================

$ErrorActionPreference = "Stop"


# ============================================================
# CONFIGURATION
# ============================================================

$GitHubUsername = "awsrmmustansarjavaid"

$GitHubHost = "github.com"

$GitProtocol = "https"


# ============================================================
# FUNCTIONS
# ============================================================

function Write-Section {
    param (
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}


function Write-Pass {
    param (
        [string]$Message
    )

    Write-Host "[PASS] $Message" -ForegroundColor Green
}


function Write-Fail {
    param (
        [string]$Message
    )

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}


function Write-Info {
    param (
        [string]$Message
    )

    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}


# ============================================================
# START
# ============================================================

Write-Section "GITHUB BROWSER AUTHENTICATION"

Write-Host ""
Write-Host "Configured GitHub Username : $GitHubUsername" -ForegroundColor Yellow
Write-Host "GitHub Host               : $GitHubHost" -ForegroundColor Yellow
Write-Host "Git Protocol              : $GitProtocol" -ForegroundColor Yellow

Write-Host ""
Write-Host "Authentication Method:" -ForegroundColor White
Write-Host "Browser-based GitHub authentication" -ForegroundColor Green

Write-Host ""
Write-Host "No email, password, or token is stored in this script." -ForegroundColor Green
Write-Host ""


# ============================================================
# STEP 0 - FIRST CHECK GITHUB LOGIN STATUS
# ============================================================

Write-Section "STEP 0 - GITHUB LOGIN STATUS"

Write-Host ""
Write-Host "Running: gh auth status" -ForegroundColor Yellow
Write-Host ""

# IMPORTANT:
# gh auth status returns a non-zero exit code when the user
# is NOT logged in. We temporarily allow that result so that
# PowerShell does not terminate the script.

$PreviousErrorActionPreference = $ErrorActionPreference

$ErrorActionPreference = "Continue"

$AuthStatusOutput = @(
    gh auth status --hostname $GitHubHost 2>&1
)

$AuthStatusExitCode = $LASTEXITCODE

$ErrorActionPreference = $PreviousErrorActionPreference


# ============================================================
# ALREADY LOGGED IN
# ============================================================

if ($AuthStatusExitCode -eq 0) {

    Write-Host ""
    Write-Host "************************************************************" -ForegroundColor Green
    Write-Host "*                                                          *" -ForegroundColor Green
    Write-Host "*              YOU ARE ALREADY LOGGED IN                   *" -ForegroundColor Green
    Write-Host "*                                                          *" -ForegroundColor Green
    Write-Host "************************************************************" -ForegroundColor Green

    Write-Host ""

    $AuthStatusOutput | ForEach-Object {
        Write-Host $_ -ForegroundColor Gray
    }

    Write-Host ""

    # Verify the actual authenticated username.
    $CurrentUsername = ""

    $ErrorActionPreference = "SilentlyContinue"

    $CurrentUsername = gh api user --jq ".login" 2>$null

    $ErrorActionPreference = $PreviousErrorActionPreference

    if (-not [string]::IsNullOrWhiteSpace($CurrentUsername)) {

        Write-Host ""
        Write-Host "Authenticated Account:" -ForegroundColor Cyan
        Write-Host "  $CurrentUsername" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "No new login is required." -ForegroundColor Green
    Write-Host ""
    Write-Host "Script finished." -ForegroundColor Cyan
    Write-Host ""

    exit 0
}


# ============================================================
# NOT LOGGED IN
# ============================================================

Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "YOU ARE NOT CURRENTLY LOGGED IN TO GITHUB." -ForegroundColor Yellow
Write-Host "------------------------------------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "The browser authentication process will now start." -ForegroundColor White
Write-Host ""


# ============================================================
# STEP 1 - CHECK GITHUB CLI
# ============================================================

Write-Section "STEP 1 - CHECK GITHUB CLI"

$GhCommand = Get-Command gh -ErrorAction SilentlyContinue

if (-not $GhCommand) {

    Write-Fail "GitHub CLI (gh) is not installed."

    Write-Host ""
    Write-Host "Install GitHub CLI first:" -ForegroundColor Yellow
    Write-Host "https://cli.github.com/" -ForegroundColor Cyan
    Write-Host ""

    exit 1
}

$GhVersion = gh --version | Select-Object -First 1

Write-Pass "GitHub CLI detected."

Write-Host $GhVersion -ForegroundColor Gray


# ============================================================
# STEP 2 - START BROWSER AUTHENTICATION
# ============================================================

Write-Section "STEP 2 - GITHUB BROWSER LOGIN"

Write-Host ""
Write-Host "GitHub authentication will be completed in your browser." -ForegroundColor White
Write-Host ""
Write-Host "GitHub will handle:" -ForegroundColor White
Write-Host "  - GitHub account authentication" -ForegroundColor Gray
Write-Host "  - Password or passkey" -ForegroundColor Gray
Write-Host "  - MFA / security verification" -ForegroundColor Gray
Write-Host "  - GitHub authorization" -ForegroundColor Gray
Write-Host ""
Write-Host "Your password will NOT be stored in this PowerShell script." -ForegroundColor Green
Write-Host ""

Write-Info "Starting GitHub browser authentication..."

# IMPORTANT:
# --web tells GitHub CLI to use browser/device authentication.
#
# GitHub CLI may ask:
#
#   ? Authenticate Git with your GitHub credentials? (Y/n)
#
# Answer Y.
#
# It may then display a temporary authentication code and
# open GitHub in your default browser.

gh auth login `
    --hostname $GitHubHost `
    --git-protocol $GitProtocol `
    --web

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Fail "GitHub browser authentication failed."

    Write-Host ""
    Write-Host "Please run the script again." -ForegroundColor Yellow
    Write-Host ""

    exit 1
}

Write-Host ""
Write-Pass "GitHub browser authentication completed."


# ============================================================
# STEP 3 - VERIFY GITHUB ACCOUNT
# ============================================================

Write-Section "STEP 3 - VERIFY GITHUB ACCOUNT"

Write-Info "Checking authenticated GitHub username..."

$ErrorActionPreference = "SilentlyContinue"

$AuthenticatedUsername = gh api user --jq ".login" 2>$null

$ApiExitCode = $LASTEXITCODE

$ErrorActionPreference = $PreviousErrorActionPreference


if ($ApiExitCode -ne 0) {

    Write-Fail "Unable to retrieve the authenticated GitHub account."

    exit 1
}


if ([string]::IsNullOrWhiteSpace($AuthenticatedUsername)) {

    Write-Fail "GitHub returned an empty username."

    exit 1
}


Write-Host ""
Write-Host "Authenticated GitHub Username : $AuthenticatedUsername" -ForegroundColor Green


# ============================================================
# STEP 4 - VERIFY EXPECTED USERNAME
# ============================================================

Write-Section "STEP 4 - VERIFY EXPECTED ACCOUNT"

if ($AuthenticatedUsername -ne $GitHubUsername) {

    Write-Host ""
    Write-Fail "GitHub account mismatch."

    Write-Host ""
    Write-Host "Expected account  : $GitHubUsername" -ForegroundColor Yellow
    Write-Host "Authenticated user: $AuthenticatedUsername" -ForegroundColor Red

    Write-Host ""
    Write-Host "The script will stop to prevent using the wrong account." -ForegroundColor Yellow
    Write-Host ""

    exit 1
}

Write-Pass "Correct GitHub account authenticated."


# ============================================================
# STEP 5 - VERIFY GITHUB CLI AUTHENTICATION
# ============================================================

Write-Section "STEP 5 - VERIFY GITHUB CLI"

$ErrorActionPreference = "SilentlyContinue"

$FinalAuthStatus = @(
    gh auth status --hostname $GitHubHost 2>&1
)

$FinalAuthExitCode = $LASTEXITCODE

$ErrorActionPreference = $PreviousErrorActionPreference


if ($FinalAuthExitCode -ne 0) {

    Write-Fail "GitHub CLI authentication verification failed."

    exit 1
}

Write-Pass "GitHub CLI authentication is active."

Write-Host ""

$FinalAuthStatus | ForEach-Object {
    Write-Host $_ -ForegroundColor Gray
}


# ============================================================
# STEP 6 - VERIFY GITHUB API
# ============================================================

Write-Section "STEP 6 - VERIFY GITHUB API ACCESS"

$ErrorActionPreference = "SilentlyContinue"

$ApiLogin = gh api user --jq ".login" 2>$null

$ApiLoginExitCode = $LASTEXITCODE

$ErrorActionPreference = $PreviousErrorActionPreference


if ($ApiLoginExitCode -ne 0) {

    Write-Fail "GitHub API authentication failed."

    exit 1
}


if ($ApiLogin -ne $GitHubUsername) {

    Write-Fail "GitHub API returned an unexpected account."

    exit 1
}

Write-Pass "GitHub API access verified."


# ============================================================
# STEP 7 - VERIFY GIT PROTOCOL
# ============================================================

Write-Section "STEP 7 - VERIFY GIT CONFIGURATION"

$ErrorActionPreference = "SilentlyContinue"

$GitConfig = gh config get git_protocol 2>$null

$ErrorActionPreference = $PreviousErrorActionPreference


if ($GitConfig -eq "https") {

    Write-Pass "Git protocol configured for HTTPS."

}
else {

    Write-Info "Git protocol configuration: $GitConfig"
}


# ============================================================
# FINAL SUCCESS
# ============================================================

Write-Section "GITHUB LOGIN SUCCESSFUL"

Write-Host ""
Write-Host "************************************************************" -ForegroundColor Green
Write-Host "*                                                          *" -ForegroundColor Green
Write-Host "*              GITHUB LOGIN SUCCESSFUL                     *" -ForegroundColor Green
Write-Host "*                                                          *" -ForegroundColor Green
Write-Host "************************************************************" -ForegroundColor Green

Write-Host ""

Write-Host "GitHub Username : $AuthenticatedUsername" -ForegroundColor Green
Write-Host "GitHub Host     : $GitHubHost" -ForegroundColor Green
Write-Host "Git Protocol    : HTTPS" -ForegroundColor Green
Write-Host "Authentication  : Browser" -ForegroundColor Green

Write-Host ""

Write-Host "[PASS] GitHub CLI is authenticated on this PC." -ForegroundColor Green

Write-Host ""

Write-Host "You can now use:" -ForegroundColor White
Write-Host ""
Write-Host "    gh repo list" -ForegroundColor Cyan
Write-Host "    gh repo view" -ForegroundColor Cyan
Write-Host "    gh pr list" -ForegroundColor Cyan
Write-Host "    gh issue list" -ForegroundColor Cyan
Write-Host "    git pull" -ForegroundColor Cyan
Write-Host "    git push" -ForegroundColor Cyan

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "                         DONE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
