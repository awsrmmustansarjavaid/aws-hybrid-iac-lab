# ==========================================================
# FILE: verify-github-ci-cd.ps1
# ==========================================================
#
# PURPOSE:
#   Verify the AWS/GitHub Actions CI/CD configuration for
#   the aws-hybrid-iac-lab project.
#
# IMPORTANT:
#   This script is READ/VERIFY ONLY.
#
#   It does NOT:
#     - create AWS resources
#     - delete AWS resources
#     - detach IAM policies
#     - modify IAM policies
#     - modify trust policies
#     - run terraform apply
#
#   Terraform commands used:
#     - terraform fmt -check
#     - terraform init
#     - terraform validate
#     - terraform plan
#
# ==========================================================

$ErrorActionPreference = "Continue"

# ==========================================================
# CONFIGURATION
# ==========================================================

$ExpectedAccountId = "537236558357"
$ExpectedRegion    = "us-east-1"

# IAM USER
$GitHubIamUserName = "github-ci-cd-user"

# GITHUB ACTIONS OIDC ROLE
$GitHubRoleName = "aws-hybrid-iac-lab-GitHubActions"

# CLOUDFORMATION SERVICE ROLE
$CloudFormationRoleName = "CharlieCafe-CloudFormation-ServiceRole"

# NEW COMBINED CUSTOMER-MANAGED POLICY
$CombinedPolicyName = "github-ci-cd-user-combined-access"

# GITHUB OIDC PROVIDER
$OidcProviderArn =
    "arn:aws:iam::$ExpectedAccountId:oidc-provider/token.actions.githubusercontent.com"

# GITHUB REPOSITORY
$ExpectedRepository =
    "awsrmmustansarjavaid/aws-hybrid-iac-lab"

# IMPORTANT:
# Use ${ExpectedRepository} because ':' immediately follows
# the variable value in the resulting string.
$ExpectedSubjectPattern =
    "repo:${ExpectedRepository}:*"

$ExpectedAudience =
    "sts.amazonaws.com"

# SECRET USED BY THE LAB
$SecretName = "CafeDevDBSM"

# ==========================================================
# PROJECT PATHS
# ==========================================================

# This script lives in:
#
#   project-root\scripts\verify-github-ci-cd.ps1
#
# Therefore PSScriptRoot is:
#
#   project-root\scripts
#
# and the project root is its parent.
#
$ProjectRoot =
    Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {

    $ProjectRoot =
        (Get-Location).Path
}

$WorkflowDirectory =
    Join-Path $ProjectRoot ".github\workflows"

$ReportFile =
    Join-Path `
        $ProjectRoot `
        (
            "github-ci-cd-verification-report-" +
            (Get-Date -Format "yyyyMMdd-HHmmss") +
            ".txt"
        )

# ==========================================================
# RESULT COUNTERS
# ==========================================================

$Passed   = 0
$Warnings = 0
$Errors   = 0

$ReportLines =
    New-Object System.Collections.Generic.List[string]

# ==========================================================
# REPORT FUNCTIONS
# ==========================================================

function Add-ReportLine {

    param(
        [AllowEmptyString()]
        [string]$Message
    )

    if ($null -eq $Message) {
        return
    }

    $ReportLines.Add($Message)
}

function Write-Info {

    param(
        [AllowEmptyString()]
        [string]$Message
    )

    if ($null -eq $Message) {
        return
    }

    Write-Host "[INFO] $Message"

    Add-ReportLine "[INFO] $Message"
}

function Write-Pass {

    param(
        [string]$Message
    )

    $script:Passed++

    Write-Host "[PASS] $Message"

    Add-ReportLine "[PASS] $Message"
}

function Write-Warn {

    param(
        [string]$Message
    )

    $script:Warnings++

    Write-Host "[WARN] $Message"

    Add-ReportLine "[WARN] $Message"
}

function Write-Fail {

    param(
        [string]$Message
    )

    $script:Errors++

    Write-Host "[FAIL] $Message"

    Add-ReportLine "[FAIL] $Message"
}

function Write-TestHeader {

    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "=========================================================="
    Write-Host "TEST: $Title"
    Write-Host "=========================================================="

    Add-ReportLine ""
    Add-ReportLine "=========================================================="
    Add-ReportLine "TEST: $Title"
    Add-ReportLine "=========================================================="
}

# ==========================================================
# AWS JSON HELPER
# ==========================================================

function Get-AwsJson {

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output =
        & aws @Arguments --no-cli-pager 2>&1

    if ($LASTEXITCODE -ne 0) {

        return $null
    }

    try {

        $Text =
            $Output -join "`n"

        return (
            $Text | ConvertFrom-Json
        )
    }
    catch {

        return $null
    }
}

# ==========================================================
# IAM POLICY DOCUMENT DECODER
# ==========================================================

function Get-IamPolicyDocument {

    param(
        [string]$PolicyArn,

        [string]$VersionId
    )

    $Raw =
        & aws iam get-policy-version `
            --policy-arn $PolicyArn `
            --version-id $VersionId `
            --output json `
            --no-cli-pager 2>&1

    if ($LASTEXITCODE -ne 0) {

        return $null
    }

    try {

        $Json =
            ($Raw -join "`n") |
            ConvertFrom-Json

        $DocumentText =
            [string]$Json.PolicyVersion.Document

        # IAM policy documents returned by AWS CLI can be
        # URL encoded.
        if ($DocumentText -match '%[0-9A-Fa-f]{2}') {

            $DocumentText =
                [System.Net.WebUtility]::UrlDecode(
                    $DocumentText
                )
        }

        return (
            $DocumentText |
            ConvertFrom-Json
        )
    }
    catch {

        return $null
    }
}

# ==========================================================
# IAM ACTION CHECK
# ==========================================================

function Test-IamActionAllowed {

    param(
        [Parameter(Mandatory = $true)]
        $PolicyDocument,

        [Parameter(Mandatory = $true)]
        [string]$RequiredAction
    )

    $AllowMatch = $null
    $DenyMatch  = $null

    foreach ($Statement in @($PolicyDocument.Statement)) {

        if ($null -eq $Statement) {
            continue
        }

        $Actions = @()

        if ($null -ne $Statement.Action) {

            $Actions =
                @($Statement.Action)
        }

        foreach ($ActionPattern in $Actions) {

            if (
                [string]::IsNullOrWhiteSpace(
                    [string]$ActionPattern
                )
            ) {
                continue
            }

            # PowerShell -like supports the IAM-style '*'
            # wildcard for the action checks we need here.
            if (
                $RequiredAction -like
                [string]$ActionPattern
            ) {

                if ($Statement.Effect -eq "Deny") {

                    $DenyMatch =
                        [string]$ActionPattern
                }

                if ($Statement.Effect -eq "Allow") {

                    $AllowMatch =
                        [string]$ActionPattern
                }
            }
        }
    }

    if ($null -ne $DenyMatch) {

        return [pscustomobject]@{
            Status  = "ExplicitDeny"
            Pattern = $DenyMatch
        }
    }

    if ($null -ne $AllowMatch) {

        return [pscustomobject]@{
            Status  = "Allowed"
            Pattern = $AllowMatch
        }
    }

    return [pscustomobject]@{
        Status  = "Missing"
        Pattern = ""
    }
}

# ==========================================================
# TRUST POLICY CONDITION HELPER
# ==========================================================

function Get-ConditionValue {

    param(
        $Condition,

        [string]$Operator,

        [string]$Key
    )

    if ($null -eq $Condition) {

        return @()
    }

    $OperatorProperty =
        $Condition.PSObject.Properties[$Operator]

    if ($null -eq $OperatorProperty) {

        return @()
    }

    $KeyProperty =
        $OperatorProperty.Value.PSObject.Properties[$Key]

    if ($null -eq $KeyProperty) {

        return @()
    }

    return @(
        $KeyProperty.Value
    )
}

# ==========================================================
# TRUST POLICY VALIDATION
# ==========================================================

function Test-TrustPolicy {

    param(
        [Parameter(Mandatory = $true)]
        $TrustPolicy
    )

    $Result = [ordered]@{

        OidcProvider = $false

        Action = $false

        Audience = $false

        Subject = $false
    }

    foreach ($Statement in @($TrustPolicy.Statement)) {

        if ($null -eq $Statement) {
            continue
        }

        # --------------------------------------------------
        # OIDC PROVIDER
        # --------------------------------------------------

        $FederatedValues = @()

        if ($null -ne $Statement.Principal) {

            $FederatedProperty =
                $Statement.Principal.PSObject.Properties[
                    "Federated"
                ]

            if ($null -ne $FederatedProperty) {

                $FederatedValues =
                    @($FederatedProperty.Value)
            }
        }

        foreach ($Federated in $FederatedValues) {

            if (
                [string]$Federated -eq
                $OidcProviderArn
            ) {

                $Result.OidcProvider = $true
            }
        }

        # --------------------------------------------------
        # ASSUME ROLE WITH WEB IDENTITY
        # --------------------------------------------------

        foreach ($Action in @($Statement.Action)) {

            if (
                [string]$Action -eq
                "sts:AssumeRoleWithWebIdentity"
            ) {

                $Result.Action = $true
            }
        }

        # --------------------------------------------------
        # AUDIENCE
        #
        # IMPORTANT:
        # The property name contains ':' and '.'
        # so normal PowerShell property syntax is avoided.
        # --------------------------------------------------

        $AudienceValues =
            Get-ConditionValue `
                -Condition $Statement.Condition `
                -Operator "StringEquals" `
                -Key "token.actions.githubusercontent.com:aud"

        foreach ($Audience in $AudienceValues) {

            if (
                [string]$Audience -eq
                $ExpectedAudience
            ) {

                $Result.Audience = $true
            }
        }

        # --------------------------------------------------
        # SUBJECT
        # --------------------------------------------------

        $SubjectValues =
            Get-ConditionValue `
                -Condition $Statement.Condition `
                -Operator "StringLike" `
                -Key "token.actions.githubusercontent.com:sub"

        foreach ($Subject in $SubjectValues) {

            if (
                [string]$Subject -like
                $ExpectedSubjectPattern
            ) {

                $Result.Subject = $true
            }
        }
    }

    return [pscustomobject]$Result
}

# ==========================================================
# TERRAFORM ROOT DISCOVERY
# ==========================================================

function Find-TerraformRoot {

    param(
        [string]$Root
    )

    # ------------------------------------------------------
    # Prefer the known application Terraform directory.
    #
    # Your project contains:
    #
    # infrastructure\terraform
    #
    # and also:
    #
    # infrastructure\bootstrap\terraform-state
    #
    # The first is the main application Terraform root.
    # ------------------------------------------------------

    $PreferredDirectories = @(

        (
            Join-Path `
                $Root `
                "infrastructure\terraform"
        ),

        (
            Join-Path `
                $Root `
                "terraform"
        ),

        (
            Join-Path `
                $Root `
                "infrastructure\iac"
        ),

        (
            Join-Path `
                $Root `
                "iac"
        )
    )

    foreach ($Directory in $PreferredDirectories) {

        if (-not (Test-Path $Directory)) {
            continue
        }

        $TfFiles =
            Get-ChildItem `
                -Path $Directory `
                -Filter "*.tf" `
                -File `
                -ErrorAction SilentlyContinue

        if ($TfFiles.Count -gt 0) {

            return $Directory
        }
    }

    # ------------------------------------------------------
    # FALLBACK:
    # Search recursively for Terraform files.
    # ------------------------------------------------------

    $AllTfFiles =
        Get-ChildItem `
            -Path $Root `
            -Filter "*.tf" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
        Where-Object {

            $_.FullName -notmatch "\\.terraform\\" -and
            $_.FullName -notmatch "\\.git\\"
        }

    if ($AllTfFiles.Count -eq 0) {

        return $null
    }

    $Groups =
        $AllTfFiles |
        Group-Object DirectoryName

    $Candidates = @()

    foreach ($Group in $Groups) {

        $Score =
            $Group.Count

        $Names =
            @(
                $Group.Group |
                Select-Object -ExpandProperty Name
            )

        if ($Names -contains "main.tf") {
            $Score += 10
        }

        if ($Names -contains "variables.tf") {
            $Score += 3
        }

        if ($Names -contains "outputs.tf") {
            $Score += 3
        }

        if ($Names -contains "provider.tf") {
            $Score += 3
        }

        if ($Names -contains "terraform.tf") {
            $Score += 3
        }

        $Candidates +=
            [pscustomobject]@{

                Directory = $Group.Name

                FileCount = $Group.Count

                Score = $Score
            }
    }

    return (
        $Candidates |
        Sort-Object Score, FileCount -Descending |
        Select-Object -First 1 |
        Select-Object -ExpandProperty Directory
    )
}

# ==========================================================
# START
# ==========================================================

Write-Host ""
Write-Host "=========================================================="
Write-Host " AWS HYBRID IAC LAB - CI/CD VERIFICATION"
Write-Host "=========================================================="
Write-Host ""

Add-ReportLine `
    "AWS HYBRID IAC LAB - CI/CD VERIFICATION"

Add-ReportLine `
    "Verification started: $(Get-Date)"

Add-ReportLine `
    "Project root: $ProjectRoot"

# ==========================================================
# TEST 1 - AWS CLI
# ==========================================================

Write-TestHeader "AWS CLI Availability"

$AwsCommand =
    Get-Command aws `
        -ErrorAction SilentlyContinue

if ($null -ne $AwsCommand) {

    Write-Pass "AWS CLI is installed."

    $AwsVersion =
        aws --version 2>&1

    Write-Info `
        "AWS CLI version: $AwsVersion"
}
else {

    Write-Fail `
        "AWS CLI is not installed or is not in PATH."
}

# ==========================================================
# TEST 2 - TERRAFORM
# ==========================================================

Write-TestHeader "Terraform Availability"

$TerraformCommand =
    Get-Command terraform `
        -ErrorAction SilentlyContinue

if ($null -ne $TerraformCommand) {

    Write-Pass "Terraform is installed."

    $TerraformVersion =
        terraform version 2>&1

    foreach ($Line in @($TerraformVersion)) {

        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$Line
            )
        ) {

            Write-Info ([string]$Line)
        }
    }
}
else {

    Write-Fail `
        "Terraform is not installed or is not in PATH."
}

# ==========================================================
# TEST 3 - AWS ACCOUNT IDENTITY
# ==========================================================

Write-TestHeader "AWS Account Identity"

$Identity =
    Get-AwsJson @(
        "sts",
        "get-caller-identity"
    )

if ($null -ne $Identity) {

    $CurrentAccount =
        [string]$Identity.Account

    $CurrentArn =
        [string]$Identity.Arn

    $CurrentUserId =
        [string]$Identity.UserId

    Write-Info `
        "AWS Account: $CurrentAccount"

    Write-Info `
        "AWS ARN: $CurrentArn"

    Write-Info `
        "AWS User ID: $CurrentUserId"

    if (
        $CurrentAccount -eq
        $ExpectedAccountId
    ) {

        Write-Pass `
            "AWS account matches expected account $ExpectedAccountId."
    }
    else {

        Write-Fail `
            "AWS account does not match expected account $ExpectedAccountId."
    }

    if (
        $CurrentArn -eq
        "arn:aws:iam::$ExpectedAccountId:user/$GitHubIamUserName"
    ) {

        Write-Pass `
            "Current AWS CLI identity is IAM user '$GitHubIamUserName'."
    }
    else {

        Write-Info `
            "Current AWS CLI identity is not the expected IAM user. IAM API checks will still continue."
    }
}
else {

    Write-Fail `
        "Unable to retrieve AWS caller identity."
}

# ==========================================================
# TEST 4 - AWS REGION
# ==========================================================

Write-TestHeader "AWS Region"

$CurrentRegion =
    aws configure get region 2>&1

if (
    [string]$CurrentRegion -eq
    $ExpectedRegion
) {

    Write-Pass `
        "AWS CLI region is $ExpectedRegion."
}
else {

    Write-Fail `
        "AWS CLI region is '$CurrentRegion'. Expected '$ExpectedRegion'."
}

# ==========================================================
# ARN VARIABLES
# ==========================================================

$GitHubIamUserArn =
    "arn:aws:iam::$ExpectedAccountId:user/$GitHubIamUserName"

$GitHubRoleArn =
    "arn:aws:iam::$ExpectedAccountId:role/$GitHubRoleName"

$CloudFormationRoleArn =
    "arn:aws:iam::$ExpectedAccountId:role/$CloudFormationRoleName"

$CombinedPolicyArn =
    "arn:aws:iam::$ExpectedAccountId:policy/$CombinedPolicyName"

# ==========================================================
# TEST 5 - IAM USER
# ==========================================================

Write-TestHeader "IAM User"

$User =
    Get-AwsJson @(
        "iam",
        "get-user",
        "--user-name",
        $GitHubIamUserName
    )

if ($null -ne $User) {

    Write-Pass `
        "IAM user exists: $GitHubIamUserName"

    Write-Info `
        "IAM User ARN: $($User.User.Arn)"

    Write-Info `
        "IAM User ID: $($User.User.UserId)"

    Write-Info `
        "IAM User Created: $($User.User.CreateDate)"
}
else {

    Write-Fail `
        "IAM user does not exist: $GitHubIamUserName"
}

# ==========================================================
# TEST 6 - IAM USER ATTACHED POLICIES
# ==========================================================

Write-TestHeader "IAM User Policy Attachment"

$UserAttached =
    Get-AwsJson @(
        "iam",
        "list-attached-user-policies",
        "--user-name",
        $GitHubIamUserName
    )

$UserPolicyNames = @()

if ($null -ne $UserAttached) {

    $UserPolicyList =
        @($UserAttached.AttachedPolicies)

    foreach ($Policy in $UserPolicyList) {

        $UserPolicyNames +=
            [string]$Policy.PolicyName
    }

    if (
        $UserPolicyNames -contains
        $CombinedPolicyName
    ) {

        Write-Pass `
            "Combined policy is attached to IAM user '$GitHubIamUserName'."
    }
    else {

        Write-Fail `
            "Combined policy is NOT attached to IAM user '$GitHubIamUserName'."
    }

    Write-Info `
        "Attached customer-managed/AWS-managed policies for IAM user:"

    foreach ($Policy in $UserPolicyList) {

        Write-Info `
            "  - $($Policy.PolicyName)"

        Write-Info `
            "    $($Policy.PolicyArn)"
    }
}
else {

    Write-Fail `
        "Unable to list IAM user policies."
}

# ==========================================================
# TEST 7 - IAM USER INLINE POLICIES
# ==========================================================

Write-TestHeader "IAM User Inline Policies"

$InlinePolicies =
    Get-AwsJson @(
        "iam",
        "list-user-policies",
        "--user-name",
        $GitHubIamUserName
    )

if ($null -ne $InlinePolicies) {

    $InlineNames =
        @($InlinePolicies.PolicyNames)

    if ($InlineNames.Count -eq 0) {

        Write-Info `
            "IAM user has no inline policies."
    }
    else {

        Write-Info `
            "IAM user inline policies:"

        foreach ($Name in $InlineNames) {

            Write-Info "  - $Name"
        }

        Write-Warn `
            "Legacy inline policies remain attached to the IAM user. Do not remove them until CI/CD has been fully tested."
    }
}
else {

    Write-Warn `
        "Unable to list IAM user inline policies."
}

# ==========================================================
# TEST 8 - COMBINED POLICY EXISTS
# ==========================================================

Write-TestHeader "Combined IAM Policy Exists"

$CombinedPolicy =
    Get-AwsJson @(
        "iam",
        "get-policy",
        "--policy-arn",
        $CombinedPolicyArn
    )

if ($null -ne $CombinedPolicy) {

    Write-Pass `
        "Combined IAM policy exists: $CombinedPolicyName"

    Write-Info `
        "Policy ARN: $($CombinedPolicy.Policy.Arn)"

    Write-Info `
        "Policy ID: $($CombinedPolicy.Policy.PolicyId)"

    Write-Info `
        "Policy Type: $($CombinedPolicy.Policy.PolicyType)"

    Write-Info `
        "Default policy version: $($CombinedPolicy.Policy.DefaultVersionId)"

    Write-Info `
        "Attachment count: $($CombinedPolicy.Policy.AttachmentCount)"
}
else {

    Write-Fail `
        "Combined IAM policy does not exist."
}

# ==========================================================
# TEST 9 - POLICY DOCUMENT
# ==========================================================

Write-TestHeader "Combined IAM Policy Document"

$CombinedPolicyDocument = $null

if ($null -ne $CombinedPolicy) {

    $DefaultVersionId =
        $CombinedPolicy.Policy.DefaultVersionId

    $CombinedPolicyDocument =
        Get-IamPolicyDocument `
            -PolicyArn $CombinedPolicyArn `
            -VersionId $DefaultVersionId

    if ($null -ne $CombinedPolicyDocument) {

        Write-Pass `
            "Combined IAM policy document can be read."

        $Statements =
            @($CombinedPolicyDocument.Statement)

        Write-Info `
            "Policy statement count: $($Statements.Count)"

        foreach ($Statement in $Statements) {

            $Sid =
                [string]$Statement.Sid

            $Effect =
                [string]$Statement.Effect

            Write-Info `
                "Statement: $Sid | Effect: $Effect"
        }
    }
    else {

        Write-Fail `
            "Unable to decode/read combined IAM policy document."
    }
}

# ==========================================================
# TEST 10 - REQUIRED IAM PERMISSIONS
# ==========================================================

Write-TestHeader "Required IAM Policy Permissions"

$RequiredActions = @(

    "lambda:UpdateFunctionCode"

    "lambda:UpdateFunctionConfiguration"

    "lambda:PublishLayerVersion"

    "ssm:SendCommand"

    "secretsmanager:GetSecretValue"

    "ecr:PutImage"

    "ecs:UpdateService"

    "iam:PassRole"

    "ec2:DescribeInstances"

    "s3:ListAllMyBuckets"

    "cloudformation:ListStacks"

    "ssm:DescribeInstanceInformation"
)

if ($null -ne $CombinedPolicyDocument) {

    $AllowActionCount = 0

    foreach (
        $Statement in
        @($CombinedPolicyDocument.Statement)
    ) {

        if (
            $Statement.Effect -eq
            "Allow"
        ) {

            $AllowActionCount +=
                @($Statement.Action).Count
        }
    }

    Write-Info `
        "Total Allow action entries found: $AllowActionCount"

    foreach ($RequiredAction in $RequiredActions) {

        $Result =
            Test-IamActionAllowed `
                -PolicyDocument $CombinedPolicyDocument `
                -RequiredAction $RequiredAction

        if ($Result.Status -eq "Allowed") {

            Write-Pass `
                "Required permission '$RequiredAction' is satisfied by policy action '$($Result.Pattern)'."
        }
        elseif (
            $Result.Status -eq
            "ExplicitDeny"
        ) {

            Write-Fail `
                "Required permission '$RequiredAction' has an explicit Deny."
        }
        else {

            Write-Fail `
                "Required permission '$RequiredAction' is missing from the combined policy."
        }
    }
}
else {

    Write-Fail `
        "Required permission check skipped because policy document is unavailable."
}

# ==========================================================
# TEST 11 - GITHUB ACTIONS ROLE
# ==========================================================

Write-TestHeader "GitHub Actions IAM Role"

$GitHubRole =
    Get-AwsJson @(
        "iam",
        "get-role",
        "--role-name",
        $GitHubRoleName
    )

if ($null -ne $GitHubRole) {

    Write-Pass `
        "GitHub Actions role exists: $GitHubRoleName"

    Write-Info `
        "Role ARN: $($GitHubRole.Role.Arn)"

    Write-Info `
        "Role ID: $($GitHubRole.Role.RoleId)"

    Write-Info `
        "Role Description: $($GitHubRole.Role.Description)"

    Write-Info `
        "Maximum Session Duration: $($GitHubRole.Role.MaxSessionDuration)"

    if ($null -ne $GitHubRole.Role.RoleLastUsed) {

        Write-Info `
            "Last Used: $($GitHubRole.Role.RoleLastUsed.LastUsedDate)"

        Write-Info `
            "Last Used Region: $($GitHubRole.Role.RoleLastUsed.Region)"
    }
}
else {

    Write-Fail `
        "GitHub Actions IAM role does not exist."
}

# ==========================================================
# TEST 12 - ROLE POLICIES
# ==========================================================

Write-TestHeader "IAM Policies Attached to GitHub Actions Role"

$RoleAttached =
    Get-AwsJson @(
        "iam",
        "list-attached-role-policies",
        "--role-name",
        $GitHubRoleName
    )

$RolePolicyNames = @()

if ($null -ne $RoleAttached) {

    $RolePolicyList =
        @($RoleAttached.AttachedPolicies)

    foreach ($Policy in $RolePolicyList) {

        $RolePolicyNames +=
            [string]$Policy.PolicyName
    }

    if (
        $RolePolicyNames -contains
        $CombinedPolicyName
    ) {

        Write-Pass `
            "Combined policy is attached to GitHub Actions role."
    }
    else {

        Write-Fail `
            "Combined policy is NOT attached to GitHub Actions role."
    }

    Write-Info `
        "Currently attached policies:"

    foreach ($Policy in $RolePolicyList) {

        Write-Info `
            "  - $($Policy.PolicyName)"

        Write-Info `
            "    $($Policy.PolicyArn)"
    }
}
else {

    Write-Fail `
        "Unable to list GitHub Actions role policies."
}

# ==========================================================
# TEST 13 - GITHUB OIDC PROVIDER
# ==========================================================

Write-TestHeader "GitHub OIDC Provider"

$OidcProviders =
    Get-AwsJson @(
        "iam",
        "list-open-id-connect-providers"
    )

$OidcFound = $false

if ($null -ne $OidcProviders) {

    foreach ($Arn in @($OidcProviders.Providers)) {

        if (
            [string]$Arn -eq
            $OidcProviderArn
        ) {

            $OidcFound = $true
        }
    }
}

if ($OidcFound) {

    Write-Pass `
        "GitHub Actions OIDC provider exists."

    Write-Info `
        "OIDC ARN: $OidcProviderArn"

    $Oidc =
        Get-AwsJson @(
            "iam",
            "get-open-id-connect-provider",
            "--open-id-connect-provider-arn",
            $OidcProviderArn
        )

    if ($null -ne $Oidc) {

        Write-Info `
            "OIDC URL: $($Oidc.Url)"

        Write-Info `
            "OIDC client IDs: $(
                @($Oidc.ClientIDList) -join ", "
            )"

        Write-Info `
            "OIDC thumbprints configured: $(
                @($Oidc.ThumbprintList) -join ", "
            )"
    }
}
else {

    Write-Fail `
        "GitHub Actions OIDC provider does not exist."
}

# ==========================================================
# TEST 14 - GITHUB TRUST POLICY
# ==========================================================

Write-TestHeader "GitHub Actions Trust Policy"

if ($null -ne $GitHubRole) {

    $TrustPolicyText =
        [string]$GitHubRole.Role.AssumeRolePolicyDocument

    if (
        $TrustPolicyText -match
        '%[0-9A-Fa-f]{2}'
    ) {

        $TrustPolicyText =
            [System.Net.WebUtility]::UrlDecode(
                $TrustPolicyText
            )
    }

    try {

        $TrustPolicy =
            $TrustPolicyText |
            ConvertFrom-Json

        $TrustResult =
            Test-TrustPolicy `
                -TrustPolicy $TrustPolicy

        if ($TrustResult.OidcProvider) {

            Write-Pass `
                "GitHub OIDC provider is correctly referenced in role trust policy."
        }
        else {

            Write-Fail `
                "GitHub OIDC provider is missing from role trust policy."
        }

        if ($TrustResult.Action) {

            Write-Pass `
                "sts:AssumeRoleWithWebIdentity exists in trust policy."
        }
        else {

            Write-Fail `
                "sts:AssumeRoleWithWebIdentity is missing."
        }

        if ($TrustResult.Audience) {

            Write-Pass `
                "GitHub OIDC audience condition is correctly configured."
        }
        else {

            Write-Fail `
                "GitHub OIDC audience condition is missing or incorrect."
        }

        if ($TrustResult.Subject) {

            Write-Pass `
                "GitHub OIDC subject condition is correctly configured for repository '$ExpectedRepository'."
        }
        else {

            Write-Fail `
                "GitHub OIDC subject condition is missing or does not match '$ExpectedRepository'."
        }

        Write-Info `
            "Current GitHub Actions trust policy:"

        $TrustJson =
            $TrustPolicy |
            ConvertTo-Json -Depth 20

        foreach ($Line in ($TrustJson -split "`r?`n")) {

            Write-Info $Line
        }
    }
    catch {

        Write-Fail `
            "Unable to parse GitHub Actions role trust policy: $($_.Exception.Message)"
    }
}

# ==========================================================
# TEST 15 - CLOUDFORMATION SERVICE ROLE
# ==========================================================

Write-TestHeader "CloudFormation Service Role"

$CloudFormationRole =
    Get-AwsJson @(
        "iam",
        "get-role",
        "--role-name",
        $CloudFormationRoleName
    )

if ($null -ne $CloudFormationRole) {

    Write-Pass `
        "CloudFormation service role exists."

    Write-Info `
        "CloudFormation Role ARN: $($CloudFormationRole.Role.Arn)"

    Write-Info `
        "CloudFormation Role ID: $($CloudFormationRole.Role.RoleId)"
}
else {

    Write-Fail `
        "CloudFormation service role does not exist."
}

# ==========================================================
# TEST 16 - PASSROLE SIMULATION - ROLE
# ==========================================================

Write-TestHeader "IAM PassRole Simulation - GitHub Actions Role"

$RoleSimulation =
    Get-AwsJson @(
        "iam",
        "simulate-principal-policy",
        "--policy-source-arn",
        $GitHubRoleArn,
        "--action-names",
        "iam:PassRole",
        "--resource-arns",
        $CloudFormationRoleArn
    )

if ($null -ne $RoleSimulation) {

    $Decision =
        [string]$RoleSimulation.EvaluationResults[0].EvalDecision

    Write-Info `
        "GitHub Actions role PassRole simulation decision: $Decision"

    if ($Decision -eq "allowed") {

        Write-Pass `
            "GitHub Actions role can iam:PassRole the CloudFormation service role."
    }
    else {

        Write-Fail `
            "GitHub Actions role cannot iam:PassRole the CloudFormation service role."
    }
}
else {

    Write-Fail `
        "Unable to simulate GitHub Actions role PassRole permission."
}

# ==========================================================
# TEST 17 - PASSROLE SIMULATION - USER
# ==========================================================

Write-TestHeader "IAM PassRole Simulation - IAM User"

$UserSimulation =
    Get-AwsJson @(
        "iam",
        "simulate-principal-policy",
        "--policy-source-arn",
        $GitHubIamUserArn,
        "--action-names",
        "iam:PassRole",
        "--resource-arns",
        $CloudFormationRoleArn
    )

if ($null -ne $UserSimulation) {

    $Decision =
        [string]$UserSimulation.EvaluationResults[0].EvalDecision

    Write-Info `
        "IAM user PassRole simulation decision: $Decision"

    if ($Decision -eq "allowed") {

        Write-Pass `
            "IAM user '$GitHubIamUserName' can iam:PassRole the CloudFormation service role."
    }
    else {

        Write-Fail `
            "IAM user '$GitHubIamUserName' cannot iam:PassRole the CloudFormation service role."
    }
}
else {

    Write-Fail `
        "Unable to simulate IAM user PassRole permission."
}

# ==========================================================
# TEST 18 - S3
# ==========================================================

Write-TestHeader "S3 Access"

$Buckets =
    aws s3api list-buckets `
        --query "Buckets[].Name" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "S3 access is working."

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$Buckets
        )
    ) {

        Write-Info `
            "S3 buckets: $Buckets"
    }
}
else {

    Write-Fail `
        "S3 access test failed."
}

# ==========================================================
# TEST 19 - EC2
# ==========================================================

Write-TestHeader "EC2 Access"

$Ec2Result =
    aws ec2 describe-instances `
        --query "Reservations[].Instances[].InstanceId" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "EC2 DescribeInstances access is working."
}
else {

    Write-Fail `
        "EC2 DescribeInstances access failed."
}

# ==========================================================
# TEST 20 - SSM
# ==========================================================

Write-TestHeader "SSM Access"

$SsmResult =
    aws ssm describe-instance-information `
        --query "InstanceInformationList[].InstanceId" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "SSM access is working."

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$SsmResult
        )
    ) {

        Write-Info `
            "SSM managed instance count: 0"
    }
    else {

        $SsmCount =
            @(
                $SsmResult -split "`t|`r?`n" |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            ).Count

        Write-Info `
            "SSM managed instance count: $SsmCount"
    }
}
else {

    Write-Fail `
        "SSM access failed."
}

# ==========================================================
# TEST 21 - LAMBDA
# ==========================================================

Write-TestHeader "Lambda Access"

$LambdaFunctions =
    aws lambda list-functions `
        --query "Functions[].FunctionName" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Lambda list-functions access is working."

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$LambdaFunctions
        )
    ) {

        Write-Info `
            "Lambda function count: 0"
    }
    else {

        $LambdaCount =
            @(
                $LambdaFunctions -split "`t|`r?`n" |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            ).Count

        Write-Info `
            "Lambda function count: $LambdaCount"
    }
}
else {

    Write-Fail `
        "Lambda list-functions access failed."
}

# ==========================================================
# TEST 22 - ECR
# ==========================================================

Write-TestHeader "ECR Access"

$EcrEndpoint =
    aws ecr get-authorization-token `
        --query "authorizationData[0].proxyEndpoint" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "ECR access is working."

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$EcrEndpoint
        )
    ) {

        Write-Info `
            "ECR registry endpoint: $EcrEndpoint"
    }
}
else {

    Write-Fail `
        "ECR access failed."
}

# ==========================================================
# TEST 23 - ECS
# ==========================================================

Write-TestHeader "ECS Access"

$EcsClusters =
    aws ecs list-clusters `
        --query "clusterArns[]" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "ECS access is working."

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$EcsClusters
        )
    ) {

        Write-Info `
            "ECS cluster count: 0"
    }
    else {

        $EcsCount =
            @(
                $EcsClusters -split "`t|`r?`n" |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            ).Count

        Write-Info `
            "ECS cluster count: $EcsCount"
    }
}
else {

    Write-Fail `
        "ECS access failed."
}

# ==========================================================
# TEST 24 - CLOUDFORMATION
# ==========================================================

Write-TestHeader "CloudFormation Access"

$Stacks =
    aws cloudformation list-stacks `
        --query "StackSummaries[].StackName" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "CloudFormation access is working."

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$Stacks
        )
    ) {

        Write-Info `
            "CloudFormation stack count: 0"
    }
    else {

        $StackCount =
            @(
                $Stacks -split "`t|`r?`n" |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            ).Count

        Write-Info `
            "CloudFormation stack count: $StackCount"
    }
}
else {

    Write-Fail `
        "CloudFormation access failed."
}

# ==========================================================
# TEST 25 - SECRETS MANAGER
# ==========================================================

Write-TestHeader "Secrets Manager Access"

$SecretArn =
    aws secretsmanager get-secret-value `
        --secret-id $SecretName `
        --query "ARN" `
        --output text `
        --no-cli-pager 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Secrets Manager GetSecretValue access is working for $SecretName."

    Write-Info `
        "Secret ARN: $SecretArn"

    Write-Info `
        "Secret name: $SecretName"
}
else {

    Write-Fail `
        "Secrets Manager GetSecretValue access failed for $SecretName."
}

# ==========================================================
# TEST 26 - TERRAFORM ROOT DISCOVERY
# ==========================================================

Write-TestHeader "Terraform Root Directory Discovery"

$TerraformRoot =
    Find-TerraformRoot `
        -Root $ProjectRoot

if ($null -ne $TerraformRoot) {

    Write-Pass `
        "Terraform configuration files were found."

    Write-Info `
        "Terraform root directory: $TerraformRoot"

    $TerraformFiles =
        Get-ChildItem `
            -Path $TerraformRoot `
            -Filter "*.tf" `
            -File `
            -ErrorAction SilentlyContinue

    Write-Info `
        "Terraform .tf file count: $($TerraformFiles.Count)"

    $AllTerraformFiles =
        Get-ChildItem `
            -Path $ProjectRoot `
            -Filter "*.tf" `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
        Where-Object {

            $_.FullName -notmatch "\\.terraform\\" -and
            $_.FullName -notmatch "\\.git\\"
        }

    $TerraformGroups =
        $AllTerraformFiles |
        Group-Object DirectoryName

    foreach ($Group in $TerraformGroups) {

        Write-Info `
            "Directory: $($Group.Name) | Files: $($Group.Count)"
    }
}
else {

    Write-Fail `
        "No Terraform configuration files were found."
}

# ==========================================================
# TEST 27 - TERRAFORM FILES
# ==========================================================

Write-TestHeader "Terraform Project Files"

if ($null -ne $TerraformRoot) {

    $TerraformFiles =
        Get-ChildItem `
            -Path $TerraformRoot `
            -Filter "*.tf" `
            -File `
            -ErrorAction SilentlyContinue

    if ($TerraformFiles.Count -gt 0) {

        Write-Pass `
            "Terraform configuration files exist in the detected Terraform root."

        foreach ($File in $TerraformFiles) {

            Write-Info `
                "Terraform file: $($File.Name)"
        }
    }

    $RequiredTerraformFiles = @(
        "main.tf",
        "variables.tf",
        "outputs.tf"
    )

    foreach ($RequiredFile in $RequiredTerraformFiles) {

        $FilePath =
            Join-Path `
                $TerraformRoot `
                $RequiredFile

        if (Test-Path $FilePath) {

            Write-Pass `
                "Terraform file exists: $RequiredFile"
        }
        else {

            Write-Warn `
                "Terraform file not found: $RequiredFile"
        }
    }

    $OptionalTerraformFiles = @(
        "provider.tf",
        "terraform.tf",
        "iam.tf"
    )

    foreach ($OptionalFile in $OptionalTerraformFiles) {

        $OptionalPath =
            Join-Path `
                $TerraformRoot `
                $OptionalFile

        if (Test-Path $OptionalPath) {

            Write-Info `
                "Optional/common Terraform file exists: $OptionalFile"
        }
        else {

            Write-Info `
                "Optional/common Terraform file not found: $OptionalFile"
        }
    }
}

# ==========================================================
# TEST 28 - TERRAFORM FORMAT
# ==========================================================

Write-TestHeader "Terraform Format"

if ($null -ne $TerraformRoot) {

    Push-Location $TerraformRoot

    try {

        $FmtOutput =
            terraform fmt `
                -check `
                -recursive `
                -no-color 2>&1

        $FmtExitCode =
            $LASTEXITCODE

        if ($FmtExitCode -eq 0) {

            Write-Pass `
                "Terraform formatting is correct."
        }
        else {

            Write-Warn `
                "Terraform formatting check reported files that may need formatting."

            foreach ($Line in @($FmtOutput)) {

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$Line
                    )
                ) {

                    Write-Info ([string]$Line)
                }
            }
        }
    }
    finally {

        Pop-Location
    }
}

# ==========================================================
# TEST 29 - TERRAFORM INIT
# ==========================================================

Write-TestHeader "Terraform Initialization"

$TerraformInitSucceeded = $false

if ($null -ne $TerraformRoot) {

    Push-Location $TerraformRoot

    try {

        $InitOutput =
            terraform init `
                -input=false `
                -no-color 2>&1

        $InitExitCode =
            $LASTEXITCODE

        if ($InitExitCode -eq 0) {

            $TerraformInitSucceeded = $true

            Write-Pass `
                "Terraform initialization completed successfully."

            foreach ($Line in @($InitOutput)) {

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$Line
                    )
                ) {

                    Write-Info ([string]$Line)
                }
            }
        }
        else {

            Write-Fail `
                "Terraform initialization failed."

            foreach ($Line in @($InitOutput)) {

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$Line
                    )
                ) {

                    Write-Info ([string]$Line)
                }
            }
        }
    }
    finally {

        Pop-Location
    }
}

# ==========================================================
# TEST 30 - TERRAFORM VALIDATE
# ==========================================================

Write-TestHeader "Terraform Validate"

if (
    $null -ne $TerraformRoot -and
    $TerraformInitSucceeded
) {

    Push-Location $TerraformRoot

    try {

        $ValidateOutput =
            terraform validate `
                -no-color 2>&1

        $ValidateExitCode =
            $LASTEXITCODE

        if ($ValidateExitCode -eq 0) {

            Write-Pass `
                "Terraform configuration is valid."

            foreach ($Line in @($ValidateOutput)) {

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$Line
                    )
                ) {

                    Write-Info ([string]$Line)
                }
            }
        }
        else {

            Write-Fail `
                "Terraform configuration validation failed."

            foreach ($Line in @($ValidateOutput)) {

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$Line
                    )
                ) {

                    Write-Info ([string]$Line)
                }
            }
        }
    }
    finally {

        Pop-Location
    }
}
elseif ($null -ne $TerraformRoot) {

    Write-Warn `
        "Terraform validate skipped because terraform init failed."
}

# ==========================================================
# TEST 31 - TERRAFORM PLAN
# ==========================================================

Write-TestHeader "Terraform Plan"

if (
    $null -ne $TerraformRoot -and
    $TerraformInitSucceeded
) {

    Push-Location $TerraformRoot

    try {

        Write-Info `
            "Running terraform plan -refresh=false for verification."

        $PlanOutput =
            terraform plan `
                -input=false `
                -refresh=false `
                -no-color `
                -detailed-exitcode 2>&1

        $PlanExitCode =
            $LASTEXITCODE

        # Terraform detailed exit codes:
        #
        # 0 = successful and no changes
        # 1 = error
        # 2 = successful and changes exist
        #

        if ($PlanExitCode -eq 0) {

            Write-Pass `
                "Terraform plan completed successfully with no pending changes."
        }
        elseif ($PlanExitCode -eq 2) {

            Write-Pass `
                "Terraform plan completed successfully and reports pending changes."
        }
        else {

            Write-Fail `
                "Terraform plan failed with exit code $PlanExitCode."
        }

        # --------------------------------------------------
        # FIX:
        # Do not send empty strings to Write-Info.
        # --------------------------------------------------

        $NonEmptyPlanLines =
            @(
                $PlanOutput |
                Where-Object {

                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                }
            )

        if ($NonEmptyPlanLines.Count -gt 0) {

            Write-Info `
                "Terraform plan output follows:"

            $LinesToShow =
                $NonEmptyPlanLines |
                Select-Object -Last 40

            foreach ($Line in $LinesToShow) {

                Write-Info ([string]$Line)
            }
        }
        else {

            Write-Info `
                "Terraform plan produced no additional console output."
        }
    }
    finally {

        Pop-Location
    }
}
elseif ($null -ne $TerraformRoot) {

    Write-Warn `
        "Terraform plan skipped because terraform init failed."
}

# ==========================================================
# TEST 32 - TERRAFORM STATE
# ==========================================================

Write-TestHeader "Terraform State"

if ($null -ne $TerraformRoot) {

    $LocalStateFile =
        Join-Path `
            $TerraformRoot `
            "terraform.tfstate"

    if (Test-Path $LocalStateFile) {

        Write-Warn `
            "Local terraform.tfstate file exists in the Terraform root."

        Write-Info `
            "Verify whether local state is intentional."
    }
    else {

        Write-Info `
            "No local terraform.tfstate file exists in the Terraform root."
    }

    $BackendBlocks =
        Get-ChildItem `
            -Path $TerraformRoot `
            -Filter "*.tf" `
            -File `
            -ErrorAction SilentlyContinue |
        Select-String `
            -Pattern 'backend\s+"[^"]+"' `
            -ErrorAction SilentlyContinue

    if ($null -ne $BackendBlocks) {

        Write-Pass `
            "Explicit Terraform backend configuration was detected."

        foreach ($Match in $BackendBlocks) {

            Write-Info `
                "Backend reference: $($Match.Line.Trim())"
        }
    }
    else {

        Write-Info `
            "No explicit Terraform backend block detected in the application Terraform root."
    }

    # ------------------------------------------------------
    # State bootstrap directory is separate.
    # ------------------------------------------------------

    $BootstrapTerraformRoot =
        Join-Path `
            $ProjectRoot `
            "infrastructure\bootstrap\terraform-state"

    if (Test-Path $BootstrapTerraformRoot) {

        $BootstrapTfFiles =
            Get-ChildItem `
                -Path $BootstrapTerraformRoot `
                -Filter "*.tf" `
                -File `
                -ErrorAction SilentlyContinue

        if ($BootstrapTfFiles.Count -gt 0) {

            Write-Info `
                "Separate Terraform state-bootstrap configuration detected at:"

            Write-Info `
                $BootstrapTerraformRoot
        }
    }
}

# ==========================================================
# TEST 33 - GITHUB ACTIONS WORKFLOW DIRECTORY
# ==========================================================

Write-TestHeader "GitHub Actions Workflow"

if (Test-Path $WorkflowDirectory) {

    Write-Pass `
        "GitHub Actions workflow directory exists."

    $WorkflowFiles =
        Get-ChildItem `
            -Path $WorkflowDirectory `
            -File `
            -Include "*.yml", "*.yaml" `
            -ErrorAction SilentlyContinue

    if ($WorkflowFiles.Count -gt 0) {

        foreach ($Workflow in $WorkflowFiles) {

            Write-Pass `
                "GitHub Actions workflow found: $($Workflow.Name)"

            Write-Info `
                "Workflow path: $($Workflow.FullName)"
        }
    }
    else {

        Write-Fail `
            "No GitHub Actions workflow files were found."
    }
}
else {

    Write-Fail `
        "GitHub Actions workflow directory does not exist."
}

# ==========================================================
# TEST 34 - GITHUB OIDC WORKFLOW PERMISSION
# ==========================================================

Write-TestHeader "GitHub Workflow AWS OIDC Configuration"

if (Test-Path $WorkflowDirectory) {

    $WorkflowFiles =
        Get-ChildItem `
            -Path $WorkflowDirectory `
            -File `
            -Include "*.yml", "*.yaml" `
            -ErrorAction SilentlyContinue

    foreach ($Workflow in $WorkflowFiles) {

        $Content =
            Get-Content `
                -Path $Workflow.FullName `
                -Raw `
                -ErrorAction SilentlyContinue

        if (
            $Content -match
            "id-token:\s*write"
        ) {

            Write-Pass `
                "$($Workflow.Name) contains id-token: write."
        }
        else {

            Write-Warn `
                "$($Workflow.Name) does not contain id-token: write."
        }
    }
}

# ==========================================================
# TEST 35 - GITHUB ROLE REFERENCE
# ==========================================================

Write-TestHeader "GitHub Workflow AWS Role Reference"

$RoleReferenceFound = $false

if (Test-Path $WorkflowDirectory) {

    $WorkflowFiles =
        Get-ChildItem `
            -Path $WorkflowDirectory `
            -File `
            -Include "*.yml", "*.yaml" `
            -ErrorAction SilentlyContinue

    foreach ($Workflow in $WorkflowFiles) {

        $Content =
            Get-Content `
                -Path $Workflow.FullName `
                -Raw `
                -ErrorAction SilentlyContinue

        if (
            $Content -match
            "AWS_ROLE_ARN"
        ) {

            $RoleReferenceFound = $true

            Write-Pass `
                "$($Workflow.Name) references AWS_ROLE_ARN."
        }
        elseif (
            $Content -match
            [regex]::Escape($GitHubRoleName)
        ) {

            $RoleReferenceFound = $true

            Write-Pass `
                "$($Workflow.Name) directly references role '$GitHubRoleName'."
        }
        else {

            Write-Info `
                "$($Workflow.Name) does not directly reference AWS_ROLE_ARN."
        }
    }
}

if ($RoleReferenceFound) {

    Write-Info `
        "At least one GitHub workflow references the AWS role through AWS_ROLE_ARN or the literal role name."
}
else {

    Write-Info `
        "No workflow directly contains the literal role name '$GitHubRoleName'."

    Write-Info `
        "This is acceptable if AWS_ROLE_ARN is supplied through GitHub repository/environment variables or secrets."
}

# ==========================================================
# TEST 36 - GIT REPOSITORY
# ==========================================================

Write-TestHeader "Git Repository"

$GitRoot =
    git rev-parse --show-toplevel 2>$null

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Current directory is a Git repository."

    $GitBranch =
        git branch --show-current 2>&1

    Write-Info `
        "Current Git branch: $GitBranch"

    $GitRemote =
        git remote -v 2>&1

    Write-Info `
        "Git remotes:"

    foreach ($Line in @($GitRemote)) {

        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$Line
            )
        ) {

            Write-Info ([string]$Line)
        }
    }

    $GitStatus =
        git status --short 2>&1

    if (
        [string]::IsNullOrWhiteSpace(
            ($GitStatus -join "`n")
        )
    ) {

        Write-Pass `
            "Git working tree is clean."
    }
    else {

        Write-Warn `
            "Git working tree contains uncommitted/untracked changes."

        Write-Info `
            "Git status:"

        foreach ($Line in @($GitStatus)) {

            if (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$Line
                )
            ) {

                Write-Info ([string]$Line)
            }
        }
    }
}
else {

    Write-Fail `
        "Current directory is not a Git repository."
}

# ==========================================================
# TEST 37 - IMPORTANT PROJECT FILES
# ==========================================================

Write-TestHeader "Important Project Files"

$ImportantPaths = @(
    ".gitignore",
    ".github\workflows"
)

foreach ($RelativePath in $ImportantPaths) {

    $FullPath =
        Join-Path `
            $ProjectRoot `
            $RelativePath

    if (Test-Path $FullPath) {

        Write-Pass `
            "Project path exists: $RelativePath"
    }
    else {

        Write-Warn `
            "Project path does not exist: $RelativePath"
    }
}

# ==========================================================
# TEST 38 - EXISTING ROLE POLICIES
# ==========================================================

Write-TestHeader "Existing GitHub Actions Role Policies"

if ($null -ne $RoleAttached) {

    $LegacyRolePolicies = @(
        "github-actions-terraform-backend-policy",
        "aws-hybrid-iac-lab-GitHubActionsPolicy"
    )

    foreach ($LegacyPolicy in $LegacyRolePolicies) {

        if (
            $RolePolicyNames -contains
            $LegacyPolicy
        ) {

            Write-Info `
                "Additional policy remains attached: $LegacyPolicy"
        }
    }

    if (
        $RolePolicyNames -contains
        $CombinedPolicyName
    ) {

        Write-Pass `
            "Combined policy is present on GitHub Actions role."
    }

    Write-Info `
        "No policies were detached or modified by this script."
}

# ==========================================================
# FINAL RESULT
# ==========================================================

Write-Host ""
Write-Host "=========================================================="
Write-Host "FINAL RESULT"
Write-Host "=========================================================="

Add-ReportLine ""
Add-ReportLine "=========================================================="
Add-ReportLine "FINAL RESULT"
Add-ReportLine "=========================================================="

if ($Errors -eq 0) {

    $Status = "PASSED"

    Write-Host "STATUS: PASSED"

    Add-ReportLine "STATUS: PASSED"
}
else {

    $Status = "FAILED"

    Write-Host "STATUS: FAILED"

    Add-ReportLine "STATUS: FAILED"
}

Write-Host ""
Write-Host "Passed  : $Passed"
Write-Host "Warnings: $Warnings"
Write-Host "Errors  : $Errors"

Add-ReportLine ""
Add-ReportLine "Passed  : $Passed"
Add-ReportLine "Warnings: $Warnings"
Add-ReportLine "Errors  : $Errors"

Write-Host ""
Write-Host "IAM User:"
Write-Host $GitHubIamUserName

Write-Host ""
Write-Host "Combined Policy:"
Write-Host $CombinedPolicyName

Write-Host ""
Write-Host "GitHub Actions Role:"
Write-Host $GitHubRoleName

Write-Host ""
Write-Host "Terraform Directory:"

if ($null -ne $TerraformRoot) {

    Write-Host $TerraformRoot
}
else {

    Write-Host "Not detected"
}

Add-ReportLine ""
Add-ReportLine "IAM User:"
Add-ReportLine $GitHubIamUserName

Add-ReportLine ""
Add-ReportLine "Combined Policy:"
Add-ReportLine $CombinedPolicyName

Add-ReportLine ""
Add-ReportLine "GitHub Actions Role:"
Add-ReportLine $GitHubRoleName

Add-ReportLine ""
Add-ReportLine "Terraform Directory:"

if ($null -ne $TerraformRoot) {

    Add-ReportLine $TerraformRoot
}
else {

    Add-ReportLine "Not detected"
}

# ==========================================================
# SAVE REPORT
# ==========================================================

try {

    $ReportLines |
        Out-File `
            -FilePath $ReportFile `
            -Encoding UTF8

    Write-Host ""
    Write-Host "Report saved to:"
    Write-Host $ReportFile

    Add-ReportLine ""
    Add-ReportLine "Report saved to:"
    Add-ReportLine $ReportFile
}
catch {

    Write-Warn `
        "Unable to save verification report: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Verification complete."