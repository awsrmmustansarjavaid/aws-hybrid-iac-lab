# How to Verify Your GitHub Actions OIDC IAM Setup Using PowerShell

Yes. You can verify almost the entire setup from Windows PowerShell before running GitHub Actions again.

Your intended configuration is:

```text
GitHub Repository
awsrmmustansarjavaid/aws-hybrid-iac-lab
        │
        ▼
GitHub Actions
        │
        │ OIDC
        ▼
AWS IAM OIDC Provider
        │
        ▼
IAM Role
aws-hybrid-iac-lab-GitHubActions
        │
        ▼
IAM Permissions
aws-hybrid-iac-lab-GitHubActionsPolicy
        │
        ▼
Terraform
        │
        ▼
CloudFormation / AWS Infrastructure
```

Below is the verification process in the correct order.

---

## 1. Verify AWS CLI Is Installed

Open PowerShell and run:

```powershell
aws --version
```

Expected result will look similar to:

```
aws-cli/2.x.x Python/3.x.x Windows/...
```

If you get:

```
aws : The term 'aws' is not recognized
```

then AWS CLI is not available in your PATH.

---

## 2. Verify Your Current AWS Identity

Run:

```powershell
aws sts get-caller-identity
```

Expected output:

```json
{
    "UserId": "AIDA....",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/..."
}
```

Write down the:

```
Account
```

For example:

```
123456789012
```

You will use this account ID when checking your IAM role.

> **Important:** Your local PowerShell identity and GitHub Actions OIDC identity can be different. This command only verifies your current local AWS CLI credentials.

---

## 3. Set Your AWS Account ID in PowerShell

You can automatically retrieve your account ID:

```powershell
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
```

Verify it:

```powershell
$AWS_ACCOUNT_ID
```

Expected:

```
123456789012
```

This is convenient because you don't have to repeatedly type your account ID.

---

## 4. Set Your Expected IAM Role Name

Run:

```powershell
$ROLE_NAME = "aws-hybrid-iac-lab-GitHubActions"
```

Verify:

```powershell
$ROLE_NAME
```

Expected:

```
aws-hybrid-iac-lab-GitHubActions
```

---

## 5. Verify the IAM Role Exists

Run:

```powershell
aws iam get-role --role-name $ROLE_NAME
```

If the role exists, AWS will return information similar to:

```json
{
    "Role": {
        "Path": "/",
        "RoleName": "aws-hybrid-iac-lab-GitHubActions",
        "Arn": "arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions",
        "CreateDate": "...",
        "AssumeRolePolicyDocument": {
            ...
        }
    }
}
```

### Quick Verification

You can display only the ARN:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.Arn" `
  --output text
```

Expected:

```
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 6. Verify the IAM Role Name Exactly

Run:

```powershell
aws iam list-roles `
  --query "Roles[?RoleName=='aws-hybrid-iac-lab-GitHubActions'].{Name:RoleName,Arn:Arn}" `
  --output table
```

Expected:

```text
------------------------------------------------------------
|                       ListRoles                          |
+-------------------------------+--------------------------+
| Name                          | Arn                      |
+-------------------------------+--------------------------+
| aws-hybrid-iac-lab-GitHubActions | arn:aws:iam::...:role/... |
+-------------------------------+--------------------------+
```

If nothing is returned, the role does not exist with that exact name.

---

## 7. Verify the IAM Role Trust Policy

This is very important for GitHub OIDC.

Run:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

You should see a trust policy containing:

```
token.actions.githubusercontent.com
```

and:

```
sts:AssumeRoleWithWebIdentity
```

and:

```
sts.amazonaws.com
```

and your GitHub repository:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

---

## 8. Make the Trust Policy Easier to Read

You can save the trust policy into a PowerShell variable:

```powershell
$TrustPolicy = aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

Display it:

```powershell
$TrustPolicy
```

Look for these four important values:

```
token.actions.githubusercontent.com
sts:AssumeRoleWithWebIdentity
sts.amazonaws.com
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

---

## 9. Verify the GitHub OIDC Provider

First list your AWS IAM OIDC providers:

```powershell
aws iam list-open-id-connect-providers
```

You should see something like:

```
arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

---

## 10. Verify GitHub OIDC Provider Specifically

Run:

```powershell
aws iam list-open-id-connect-providers `
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" `
  --output text
```

Expected:

```
arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

If this returns nothing, your GitHub OIDC provider has not been created.

---

## 11. Verify the OIDC Provider Details

Set the provider ARN:

```powershell
$OIDC_PROVIDER_ARN = "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
```

Then run:

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn $OIDC_PROVIDER_ARN
```

You should see:

```json
{
    "Url": "https://token.actions.githubusercontent.com",
    "ClientIDList": [
        "sts.amazonaws.com"
    ],
    ...
}
```

The important values are:

```
Url:
https://token.actions.githubusercontent.com
```

and:

```
sts.amazonaws.com
```

---

## 12. Verify the IAM Policy Name

Your proposed policy name is:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

Set it:

```powershell
$POLICY_NAME = "aws-hybrid-iac-lab-GitHubActionsPolicy"
```

Now search for it:

```powershell
aws iam list-policies `
  --scope Local `
  --query "Policies[?PolicyName=='aws-hybrid-iac-lab-GitHubActionsPolicy'].{Name:PolicyName,Arn:Arn}" `
  --output table
```

Expected:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

---

## 13. Get the IAM Policy ARN

Run:

```powershell
$POLICY_ARN = aws iam list-policies `
  --scope Local `
  --query "Policies[?PolicyName=='aws-hybrid-iac-lab-GitHubActionsPolicy'].Arn" `
  --output text
```

Verify:

```powershell
$POLICY_ARN
```

Expected:

```
arn:aws:iam::123456789012:policy/aws-hybrid-iac-lab-GitHubActionsPolicy
```

---

## 14. Verify the Policy Is Attached to Your Role

This is another very important check.

Run:

```powershell
aws iam list-attached-role-policies `
  --role-name $ROLE_NAME `
  --output table
```

You should see:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

For a cleaner query:

```powershell
aws iam list-attached-role-policies `
  --role-name $ROLE_NAME `
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" `
  --output table
```

---

## 15. Verify the Policy Actually Contains Permissions

First get the default policy version:

```powershell
$POLICY_VERSION = aws iam get-policy `
  --policy-arn $POLICY_ARN `
  --query "Policy.DefaultVersionId" `
  --output text
```

Check it:

```powershell
$POLICY_VERSION
```

Usually you'll see something like:

```
v1
```

Now retrieve the policy:

```powershell
aws iam get-policy-version `
  --policy-arn $POLICY_ARN `
  --version-id $POLICY_VERSION
```

This lets you verify the actual permissions.

---

## 16. Verify Important AWS Permissions

For your hybrid lab, check that your policy contains permissions for the services your Terraform configuration actually manages.

You should expect permissions around services such as:

- CloudFormation
- S3
- EC2
- IAM
- ECR
- EKS
- ELB
- Auto Scaling
- CloudWatch Logs
- SSM
- Secrets Manager
- KMS
- Lambda
- API Gateway
- DynamoDB
- RDS
- ECS

You can retrieve the policy into a variable:

```powershell
$PolicyDocument = aws iam get-policy-version `
  --policy-arn $POLICY_ARN `
  --version-id $POLICY_VERSION `
  --output json
```

Then display it:

```powershell
$PolicyDocument
```

---

## 17. Verify iam:PassRole

Because your infrastructure creates/uses IAM roles, check whether your policy contains:

```
iam:PassRole
```

Retrieve the policy:

```powershell
aws iam get-policy-version `
  --policy-arn $POLICY_ARN `
  --version-id $POLICY_VERSION `
  --query "PolicyVersion.Document.Statement[].Action" `
  --output json
```

Look for:

```
iam:PassRole
```

This permission is commonly required when Terraform/CloudFormation needs to pass an IAM role to another AWS service.

---

## 18. Verify the Role's Complete Configuration

You can use this one command:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.{RoleName:RoleName,Arn:Arn,Path:Path}" `
  --output table
```

Expected:

```text
------------------------------------------------
|                  GetRole                     |
+----------------------+-----------------------+
| RoleName             | aws-hybrid-iac-lab... |
| Arn                  | arn:aws:iam::...     |
| Path                 | /                    |
+----------------------+-----------------------+
```

---

## 19. Verify All Roles Related to Your Lab

Since your project uses multiple AWS roles, this is useful:

```powershell
aws iam list-roles `
  --query "Roles[?contains(RoleName, 'aws-hybrid-iac-lab')].{Name:RoleName,Arn:Arn}" `
  --output table
```

This can show roles such as:

```
aws-hybrid-iac-lab-GitHubActions
aws-hybrid-iac-lab-CloudFormation
aws-hybrid-iac-lab-EKS
...
```

depending on what you have already created.

---

## 20. Verify Your Terraform AWS Provider Region

Your GitHub Actions error was specifically:

```
Error: Input required and not supplied: aws-region
```

You should also verify your Terraform configuration.

From your repository:

```powershell
cd C:\path\to\aws-hybrid-iac-lab
```

Then:

```powershell
Get-ChildItem .\infrastructure\terraform\
```

Look for your provider configuration.

For example:

```hcl
provider "aws" {
  region = var.aws_region
}
```

And:

```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
```

or another mechanism that provides the region.

---

## 21. Verify Terraform Is Installed

Run:

```powershell
terraform version
```

Expected:

```
Terraform v1.x.x
```

---

## 22. Verify Terraform Configuration

Go to:

```powershell
cd .\infrastructure\terraform
```

Then:

```powershell
terraform init
```

After that:

```powershell
terraform validate
```

Expected:

```
Success! The configuration is valid.
```

Then:

```powershell
terraform fmt -check -recursive
```

---

## 23. Verify Terraform AWS Authentication Locally

If your local AWS credentials are valid, run:

```powershell
aws sts get-caller-identity
```

Then:

```powershell
terraform plan
```

Remember:

- This does not test GitHub OIDC.
- It tests your local AWS credentials.

The actual GitHub OIDC test occurs when GitHub Actions runs:

```yaml
uses: aws-actions/configure-aws-credentials@v4
```

---

## 24. Verify GitHub Repository Variable

There is an important limitation here:

AWS CLI cannot directly read your GitHub repository Actions variables.

The AWS CLI only knows about AWS.

You need to verify the GitHub setting in:

```
GitHub
→ Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

You need:

```
AWS_REGION
```

with:

```
us-east-1
```

Your workflow:

```yaml
aws-region: ${{ vars.AWS_REGION }}
```

will then receive:

```
us-east-1
```

---

## 25. Verify GitHub Secret

Likewise, AWS CLI cannot read the value of your GitHub secret.

Verify in:

```
GitHub
→ Repository
→ Settings
→ Secrets and variables
→ Actions
→ Secrets
```

You need:

```
AWS_ROLE_ARN
```

whose value is:

```
arn:aws:iam::<YOUR_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 26. Verify the ARN From PowerShell

You can generate exactly what the GitHub secret should contain:

```powershell
$ROLE_ARN = aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text
```

Display it:

```powershell
$ROLE_ARN
```

You should get something like:

```
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

Copy this exact value into GitHub:

```
AWS_ROLE_ARN
```

---

## 27. Recommended Complete Verification Script

You can run the following PowerShell script to check the AWS-side configuration.

```powershell
# ==========================================================
# AWS Hybrid IaC Lab
# GitHub Actions OIDC Verification
# ==========================================================

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " AWS Hybrid IaC Lab" -ForegroundColor Cyan
Write-Host " GitHub Actions OIDC Verification" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ----------------------------------------------------------
# 1. AWS Account
# ----------------------------------------------------------

Write-Host "[1] Checking AWS account..." -ForegroundColor Yellow

$AWS_ACCOUNT_ID = aws sts get-caller-identity `
    --query "Account" `
    --output text

Write-Host "AWS Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Green

# ----------------------------------------------------------
# 2. Role
# ----------------------------------------------------------

$ROLE_NAME = "aws-hybrid-iac-lab-GitHubActions"

Write-Host ""
Write-Host "[2] Checking IAM role..." -ForegroundColor Yellow

$ROLE_ARN = aws iam get-role `
    --role-name $ROLE_NAME `
    --query "Role.Arn" `
    --output text

if ($LASTEXITCODE -eq 0) {

    Write-Host "Role exists." -ForegroundColor Green
    Write-Host "Role Name: $ROLE_NAME"
    Write-Host "Role ARN : $ROLE_ARN"

}
else {

    Write-Host "ERROR: IAM role was not found." -ForegroundColor Red
    exit 1

}

# ----------------------------------------------------------
# 3. OIDC Provider
# ----------------------------------------------------------

Write-Host ""
Write-Host "[3] Checking GitHub OIDC provider..." -ForegroundColor Yellow

$OIDC_PROVIDER_ARN = aws iam list-open-id-connect-providers `
    --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" `
    --output text

if ($OIDC_PROVIDER_ARN) {

    Write-Host "GitHub OIDC provider exists." -ForegroundColor Green
    Write-Host $OIDC_PROVIDER_ARN

}
else {

    Write-Host "ERROR: GitHub OIDC provider not found." -ForegroundColor Red
}

# ----------------------------------------------------------
# 4. Trust Policy
# ----------------------------------------------------------

Write-Host ""
Write-Host "[4] Checking IAM trust policy..." -ForegroundColor Yellow

aws iam get-role `
    --role-name $ROLE_NAME `
    --query "Role.AssumeRolePolicyDocument" `
    --output json

# ----------------------------------------------------------
# 5. Attached Policies
# ----------------------------------------------------------

Write-Host ""
Write-Host "[5] Checking attached IAM policies..." -ForegroundColor Yellow

aws iam list-attached-role-policies `
    --role-name $ROLE_NAME `
    --output table

# ----------------------------------------------------------
# 6. Expected Policy
# ----------------------------------------------------------

$POLICY_NAME = "aws-hybrid-iac-lab-GitHubActionsPolicy"

Write-Host ""
Write-Host "[6] Checking GitHub Actions IAM policy..." -ForegroundColor Yellow

$POLICY_ARN = aws iam list-policies `
    --scope Local `
    --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" `
    --output text

if ($POLICY_ARN) {

    Write-Host "Policy exists." -ForegroundColor Green
    Write-Host "Policy ARN: $POLICY_ARN"

}
else {

    Write-Host "ERROR: Policy not found." -ForegroundColor Red
}

# ----------------------------------------------------------
# 7. Policy Version
# ----------------------------------------------------------

if ($POLICY_ARN) {

    Write-Host ""
    Write-Host "[7] Checking policy permissions..." -ForegroundColor Yellow

    $POLICY_VERSION = aws iam get-policy `
        --policy-arn $POLICY_ARN `
        --query "Policy.DefaultVersionId" `
        --output text

    Write-Host "Policy Version: $POLICY_VERSION"

    aws iam get-policy-version `
        --policy-arn $POLICY_ARN `
        --version-id $POLICY_VERSION `
        --output json
}

# ----------------------------------------------------------
# 8. Final Information
# ----------------------------------------------------------

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " GitHub Secret Value" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "AWS_ROLE_ARN" -ForegroundColor Yellow
Write-Host $ROLE_ARN -ForegroundColor Green

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " GitHub Repository Variable" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "AWS_REGION" -ForegroundColor Yellow
Write-Host "us-east-1" -ForegroundColor Green

Write-Host ""
Write-Host "Verification completed."
Write-Host ""
```

---

## 28. The Most Important Checks

Before running Main Deployment again, you want these results:

| Component | Expected |
|---|---|
| AWS CLI | Installed |
| AWS Account | Correct account |
| OIDC Provider | `token.actions.githubusercontent.com` |
| OIDC Audience | `sts.amazonaws.com` |
| IAM Role | `aws-hybrid-iac-lab-GitHubActions` |
| Trust Action | `sts:AssumeRoleWithWebIdentity` |
| Repository | `awsrmmustansarjavaid/aws-hybrid-iac-lab` |
| Branch | `main` |
| IAM Policy | `aws-hybrid-iac-lab-GitHubActionsPolicy` |
| Policy attached | Yes |
| AWS_REGION GitHub variable | `us-east-1` |
| AWS_ROLE_ARN GitHub secret | Role ARN |
| Terraform workflow | `aws-region: ${{ vars.AWS_REGION }}` |
| Terraform workflow | `role-to-assume: ${{ secrets.AWS_ROLE_ARN }}` |

---

## 29. Final GitHub Workflow Configuration

Your Terraform workflow should ultimately have:

```yaml
permissions:
  id-token: write
  contents: read
```

and:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ vars.AWS_REGION }}
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

Your main workflow should keep:

```yaml
terraform:
  uses: ./.github/workflows/terraform.yml
  secrets: inherit
```

So your setup is:

```text
                         GitHub
                            │
                            │ OIDC
                            ▼
              token.actions.githubusercontent.com
                            │
                            ▼
                 AWS IAM OIDC Provider
                            │
                            ▼
          aws-hybrid-iac-lab-GitHubActions
                            │
                            ▼
       aws-hybrid-iac-lab-GitHubActionsPolicy
                            │
                            ▼
                       Terraform
                            │
                            ▼
                    CloudFormation
                            │
                            ▼
                     AWS Resources
```

The immediate fix for your current failure remains: create the GitHub Repository Variable `AWS_REGION` with value `us-east-1`, and create/verify the IAM OIDC role and `AWS_ROLE_ARN` as above. Then rerun the workflow.

---

# PowerShell vs Bash Script

The script given above is a **PowerShell script**, not a Bash script.

Since you are running this on Windows PowerShell, save it as:

```
verify-github-aws-oidc.ps1
```

## 1. Create the File

For example, create it inside your project:

```text
aws-hybrid-iac-lab/
└── scripts/
    └── verify-github-aws-oidc.ps1
```

So the full path could be:

```
C:\Users\<YOUR_USERNAME>\...\aws-hybrid-iac-lab\scripts\verify-github-aws-oidc.ps1
```

## 2. Run the PowerShell Script

Open PowerShell and go to your repository:

```powershell
cd "C:\path\to\aws-hybrid-iac-lab"
```

Then:

```powershell
.\scripts\verify-github-aws-oidc.ps1
```

If PowerShell blocks script execution with an execution-policy error, run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run:

```powershell
.\scripts\verify-github-aws-oidc.ps1
```

`-Scope Process` only changes the policy for the current PowerShell session.

## 3. If You Actually Want a Bash Version

If you specifically want a Bash script, use this filename:

```
verify-github-aws-oidc.sh
```

But because you are working from Windows PowerShell, the `.ps1` version is the better choice.

### Recommended

Use:

```text
scripts/
└── verify-github-aws-oidc.ps1
```

Run:

```powershell
.\scripts\verify-github-aws-oidc.ps1
```

---

# Final Complete PowerShell Verification Script

Below is a fully final PowerShell script designed for your `aws-hybrid-iac-lab` repository.

Save it as:

```
scripts\verify-github-aws-oidc.ps1
```

It checks:

- AWS CLI
- AWS account
- AWS caller identity
- AWS region
- GitHub OIDC provider
- OIDC audience
- IAM role
- IAM role ARN
- IAM trust policy
- GitHub repository/branch restriction
- GitHub Actions IAM policy
- Policy attachment
- Policy version
- `iam:PassRole`
- Important AWS permissions
- Terraform installation
- Terraform directory
- Terraform files
- Terraform formatting
- Terraform initialization
- Terraform validation
- Terraform AWS provider configuration
- GitHub Actions workflow configuration
- `AWS_REGION` usage
- `AWS_ROLE_ARN` usage

It also produces a clear PASS / FAIL / WARNING summary.

```powershell
#requires -Version 5.1

<#
=======================================================================
 AWS Hybrid IaC Lab
 GitHub Actions OIDC + IAM + Terraform Verification Script
=======================================================================

File:
    scripts\verify-github-aws-oidc.ps1

Repository:
    awsrmmustansarjavaid/aws-hybrid-iac-lab

Purpose:
    Automatically verify the AWS and Terraform configuration required
    by GitHub Actions using AWS OIDC.

Checks:
    1. AWS CLI
    2. AWS account
    3. AWS caller identity
    4. AWS region
    5. GitHub OIDC provider
    6. OIDC audience
    7. IAM role
    8. IAM role ARN
    9. IAM trust policy
   10. GitHub repository trust restriction
   11. GitHub branch trust restriction
   12. GitHub Actions IAM policy
   13. IAM policy attachment
   14. IAM policy version
   15. iam:PassRole
   16. Important AWS permissions
   17. Terraform installation
   18. Terraform directory
   19. Terraform files
   20. Terraform formatting
   21. Terraform initialization
   22. Terraform validation
   23. Terraform provider configuration
   24. main-deploy.yaml
   25. terraform.yml
   26. AWS_REGION
   27. AWS_ROLE_ARN
   28. Final PASS / FAIL / WARNING summary

IMPORTANT:
    This script does NOT attempt to assume the GitHub OIDC role.
    GitHub's OIDC token exists only inside GitHub Actions.

    The script verifies that the AWS-side configuration is ready
    for GitHub Actions OIDC.

=======================================================================
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# =====================================================================
# CONFIGURATION
# =====================================================================

$ExpectedRoleName = "aws-hybrid-iac-lab-GitHubActions"

$ExpectedPolicyName = "aws-hybrid-iac-lab-GitHubActionsPolicy"

$ExpectedGitHubRepository = "awsrmmustansarjavaid/aws-hybrid-iac-lab"

$ExpectedGitHubBranch = "main"

$ExpectedAwsRegion = "us-east-1"

$ExpectedOidcUrl = "https://token.actions.githubusercontent.com"

$ExpectedOidcAudience = "sts.amazonaws.com"

$TerraformDirectory = Join-Path $PSScriptRoot "..\infrastructure\terraform"

$MainWorkflow = Join-Path $PSScriptRoot "..\.github\workflows\main-deploy.yaml"

$TerraformWorkflow = Join-Path $PSScriptRoot "..\.github\workflows\terraform.yml"


# =====================================================================
# RESULT STORAGE
# =====================================================================

$Passed = 0
$Failed = 0
$Warnings = 0

$Results = @()


# =====================================================================
# HELPER FUNCTIONS
# =====================================================================

function Write-Section {
    param (
        [string]$Title
    )

    Write-Host ""
    Write-Host "=======================================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=======================================================================" -ForegroundColor Cyan
}


function Write-Check {
    param (
        [string]$Name
    )

    Write-Host ""
    Write-Host "[CHECK] $Name" -ForegroundColor Yellow
}


function Write-Pass {
    param (
        [string]$Message
    )

    $script:Passed++

    $script:Results += [PSCustomObject]@{
        Status = "PASS"
        Check  = $Message
    }

    Write-Host "[PASS] $Message" -ForegroundColor Green
}


function Write-Fail {
    param (
        [string]$Message
    )

    $script:Failed++

    $script:Results += [PSCustomObject]@{
        Status = "FAIL"
        Check  = $Message
    }

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}


function Write-Warn {
    param (
        [string]$Message
    )

    $script:Warnings++

    $script:Results += [PSCustomObject]@{
        Status = "WARN"
        Check  = $Message
    }

    Write-Host "[WARN] $Message" -ForegroundColor DarkYellow
}


function Test-CommandExists {
    param (
        [string]$CommandName
    )

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}


# =====================================================================
# HEADER
# =====================================================================

Clear-Host

Write-Host ""
Write-Host "#######################################################################" -ForegroundColor Cyan
Write-Host "#                                                                     #" -ForegroundColor Cyan
Write-Host "#       AWS HYBRID IaC LAB - GITHUB ACTIONS OIDC CHECK               #" -ForegroundColor Cyan
Write-Host "#                                                                     #" -ForegroundColor Cyan
Write-Host "#######################################################################" -ForegroundColor Cyan

Write-Host ""
Write-Host "Repository : $ExpectedGitHubRepository"
Write-Host "Branch     : $ExpectedGitHubBranch"
Write-Host "AWS Region : $ExpectedAwsRegion"
Write-Host "IAM Role   : $ExpectedRoleName"
Write-Host "IAM Policy : $ExpectedPolicyName"

# =====================================================================
# 1. CHECK AWS CLI
# =====================================================================

Write-Section "1. AWS CLI"

Write-Check "AWS CLI installation"

if (Test-CommandExists "aws") {

    $AwsVersion = aws --version 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Pass "AWS CLI is installed."
        Write-Host "        $AwsVersion"
    }
    else {
        Write-Fail "AWS CLI exists but could not execute."
    }

}
else {

    Write-Fail "AWS CLI is not installed or not available in PATH."
    Write-Host ""
    Write-Host "Install AWS CLI before continuing." -ForegroundColor Yellow
}


# =====================================================================
# 2. AWS CALLER IDENTITY
# =====================================================================

Write-Section "2. AWS Account and Caller Identity"

if (Test-CommandExists "aws") {

    Write-Check "AWS caller identity"

    $CallerIdentityRaw = aws sts get-caller-identity --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        try {

            $CallerIdentity = $CallerIdentityRaw | ConvertFrom-Json

            $AWSAccountId = $CallerIdentity.Account
            $CallerArn = $CallerIdentity.Arn

            Write-Pass "AWS authentication is working."

            Write-Host "        Account : $AWSAccountId"
            Write-Host "        ARN     : $CallerArn"

        }
        catch {

            Write-Fail "AWS returned an unexpected caller identity response."

        }

    }
    else {

        Write-Fail "AWS CLI cannot authenticate with AWS."
        Write-Host "        $CallerIdentityRaw" -ForegroundColor Red

    }

}
else {

    Write-Fail "Cannot check AWS identity because AWS CLI is unavailable."

}


# =====================================================================
# 3. AWS REGION
# =====================================================================

Write-Section "3. AWS Region"

Write-Check "Expected AWS region"

Write-Host "Expected region: $ExpectedAwsRegion"

$AwsRegionEnvironment = $env:AWS_REGION

if ([string]::IsNullOrWhiteSpace($AwsRegionEnvironment)) {

    Write-Warn "Local AWS_REGION environment variable is not set."

}
elseif ($AwsRegionEnvironment -eq $ExpectedAwsRegion) {

    Write-Pass "Local AWS_REGION matches expected region."

}
else {

    Write-Warn "Local AWS_REGION is '$AwsRegionEnvironment', expected '$ExpectedAwsRegion'."

}


# =====================================================================
# 4. GITHUB OIDC PROVIDER
# =====================================================================

Write-Section "4. GitHub OIDC Provider"

if ($AWSAccountId) {

    $OidcProviderArn = "arn:aws:iam::$AWSAccountId`:oidc-provider/token.actions.githubusercontent.com"

    Write-Check "GitHub OIDC provider"

    $OidcProviderRaw = aws iam get-open-id-connect-provider `
        --open-id-connect-provider-arn $OidcProviderArn `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        try {

            $OidcProvider = $OidcProviderRaw | ConvertFrom-Json

            Write-Pass "GitHub OIDC provider exists."

            Write-Host "        ARN: $OidcProviderArn"

        }
        catch {

            Write-Fail "OIDC provider exists but could not be parsed."

        }

    }
    else {

        Write-Fail "GitHub OIDC provider was not found."

        Write-Host "        Expected:" -ForegroundColor Yellow
        Write-Host "        $OidcProviderArn"

    }

}
else {

    Write-Fail "Cannot check OIDC provider because AWS account ID is unavailable."

}


# =====================================================================
# 5. OIDC URL
# =====================================================================

if ($OidcProvider) {

    Write-Check "OIDC provider URL"

    $OidcUrl = $OidcProvider.Url

    if ($OidcUrl -eq $ExpectedOidcUrl) {

        Write-Pass "OIDC provider URL is correct."
        Write-Host "        $OidcUrl"

    }
    else {

        Write-Fail "OIDC provider URL is incorrect."
        Write-Host "        Found   : $OidcUrl"
        Write-Host "        Expected: $ExpectedOidcUrl"

    }


    # ================================================================
    # 6. OIDC AUDIENCE
    # ================================================================

    Write-Check "OIDC audience"

    $AudienceFound = $false

    foreach ($ClientId in $OidcProvider.ClientIDList) {

        if ($ClientId -eq $ExpectedOidcAudience) {

            $AudienceFound = $true
        }
    }

    if ($AudienceFound) {

        Write-Pass "OIDC audience contains sts.amazonaws.com."

    }
    else {

        Write-Fail "OIDC audience does not contain sts.amazonaws.com."

    }

}


# =====================================================================
# 7. IAM ROLE
# =====================================================================

Write-Section "5. GitHub Actions IAM Role"

Write-Check "IAM role exists"

$RoleRaw = aws iam get-role `
    --role-name $ExpectedRoleName `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    try {

        $Role = $RoleRaw | ConvertFrom-Json

        $RoleArn = $Role.Role.Arn

        Write-Pass "IAM role exists."

        Write-Host "        Name: $ExpectedRoleName"
        Write-Host "        ARN : $RoleArn"

    }
    catch {

        Write-Fail "IAM role was found but could not be parsed."

    }

}
else {

    Write-Fail "IAM role '$ExpectedRoleName' does not exist."

}


# =====================================================================
# 8. TRUST POLICY
# =====================================================================

if ($Role) {

    Write-Section "6. IAM Trust Policy"

    $TrustPolicy = $Role.Role.AssumeRolePolicyDocument

    Write-Check "OIDC AssumeRoleWithWebIdentity"

    $TrustJson = $TrustPolicy | ConvertTo-Json -Depth 20

    if ($TrustJson -match "AssumeRoleWithWebIdentity") {

        Write-Pass "Trust policy allows AssumeRoleWithWebIdentity."

    }
    else {

        Write-Fail "Trust policy does not contain AssumeRoleWithWebIdentity."

    }


    Write-Check "GitHub OIDC provider in trust policy"

    if ($TrustJson -match "token.actions.githubusercontent.com") {

        Write-Pass "Trust policy references GitHub OIDC."

    }
    else {

        Write-Fail "Trust policy does not reference GitHub OIDC."

    }


    Write-Check "OIDC audience condition"

    if ($TrustJson -match "sts.amazonaws.com") {

        Write-Pass "Trust policy contains sts.amazonaws.com audience."

    }
    else {

        Write-Fail "Trust policy does not contain sts.amazonaws.com."

    }


    # ================================================================
    # GITHUB REPOSITORY
    # ================================================================

    Write-Check "GitHub repository restriction"

    if ($TrustJson -match [regex]::Escape($ExpectedGitHubRepository)) {

        Write-Pass "Trust policy references the correct GitHub repository."

    }
    else {

        Write-Fail "Trust policy does not reference the expected repository."

        Write-Host "        Expected:"
        Write-Host "        $ExpectedGitHubRepository"

    }


    # ================================================================
    # GITHUB BRANCH
    # ================================================================

    Write-Check "GitHub main branch restriction"

    $ExpectedSubject = "repo:$ExpectedGitHubRepository`:ref:refs/heads/$ExpectedGitHubBranch"

    if ($TrustJson -match [regex]::Escape($ExpectedSubject)) {

        Write-Pass "Trust policy restricts access to the main branch."

    }
    else {

        Write-Warn "Could not confirm exact main branch restriction."

        Write-Host "        Expected subject:"
        Write-Host "        $ExpectedSubject"

    }

}


# =====================================================================
# 9. IAM POLICY
# =====================================================================

Write-Section "7. GitHub Actions IAM Policy"

Write-Check "IAM customer-managed policy"

$PolicyRaw = aws iam list-policies `
    --scope Local `
    --query "Policies[?PolicyName=='$ExpectedPolicyName']" `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    try {

        $Policies = $PolicyRaw | ConvertFrom-Json

        if ($Policies.Count -gt 0) {

            $Policy = $Policies[0]

            $PolicyArn = $Policy.Arn

            Write-Pass "IAM policy exists."

            Write-Host "        Name: $ExpectedPolicyName"
            Write-Host "        ARN : $PolicyArn"

        }
        else {

            Write-Fail "IAM policy '$ExpectedPolicyName' does not exist."

        }

    }
    catch {

        Write-Fail "Could not parse IAM policy response."

    }

}
else {

    Write-Fail "Unable to query IAM policies."

}


# =====================================================================
# 10. POLICY ATTACHMENT
# =====================================================================

if ($Role) {

    Write-Section "8. IAM Policy Attachment"

    Write-Check "Policy attached to GitHub Actions role"

    $AttachedPoliciesRaw = aws iam list-attached-role-policies `
        --role-name $ExpectedRoleName `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $AttachedPolicies = $AttachedPoliciesRaw | ConvertFrom-Json

        $Attached = $false

        foreach ($AttachedPolicy in $AttachedPolicies.AttachedPolicies) {

            if ($AttachedPolicy.PolicyName -eq $ExpectedPolicyName) {

                $Attached = $true
            }
        }

        if ($Attached) {

            Write-Pass "GitHub Actions IAM policy is attached to the role."

        }
        else {

            Write-Fail "GitHub Actions IAM policy is NOT attached to the role."

        }

    }
    else {

        Write-Fail "Could not retrieve attached policies."

    }

}


# =====================================================================
# 11. POLICY VERSION AND DOCUMENT
# =====================================================================

if ($PolicyArn) {

    Write-Section "9. IAM Policy Permissions"

    Write-Check "IAM policy default version"

    $PolicyVersion = aws iam get-policy `
        --policy-arn $PolicyArn `
        --query "Policy.DefaultVersionId" `
        --output text 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "IAM policy default version: $PolicyVersion"

    }
    else {

        Write-Fail "Could not retrieve IAM policy version."

    }


    Write-Check "IAM policy document"

    $PolicyDocumentRaw = aws iam get-policy-version `
        --policy-arn $PolicyArn `
        --version-id $PolicyVersion `
        --query "PolicyVersion.Document" `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        try {

            $PolicyDocument = $PolicyDocumentRaw | ConvertFrom-Json

            $PolicyJson = $PolicyDocument | ConvertTo-Json -Depth 30

            Write-Pass "IAM policy document can be read."

        }
        catch {

            Write-Fail "Could not parse IAM policy document."

        }

    }
    else {

        Write-Fail "Could not retrieve IAM policy document."

    }


    # ================================================================
    # IAM PASSROLE
    # ================================================================

    if ($PolicyJson) {

        Write-Check "iam:PassRole"

        if ($PolicyJson -match "iam:PassRole" -or $PolicyJson -match "iam:\*") {

            Write-Pass "Policy contains iam:PassRole capability."

        }
        else {

            Write-Fail "Policy does not contain iam:PassRole."

        }


        # ============================================================
        # IMPORTANT SERVICES
        # ============================================================

        Write-Check "CloudFormation permissions"

        if ($PolicyJson -match "cloudformation:\*" -or $PolicyJson -match "cloudformation:") {

            Write-Pass "CloudFormation permissions detected."

        }
        else {

            Write-Warn "CloudFormation permissions were not detected."

        }


        Write-Check "S3 permissions"

        if ($PolicyJson -match "s3:\*" -or $PolicyJson -match "s3:") {

            Write-Pass "S3 permissions detected."

        }
        else {

            Write-Warn "S3 permissions were not detected."

        }


        Write-Check "EC2 permissions"

        if ($PolicyJson -match "ec2:\*" -or $PolicyJson -match "ec2:") {

            Write-Pass "EC2 permissions detected."

        }
        else {

            Write-Warn "EC2 permissions were not detected."

        }


        Write-Check "IAM permissions"

        if ($PolicyJson -match "iam:\*" -or $PolicyJson -match "iam:") {

            Write-Pass "IAM permissions detected."

        }
        else {

            Write-Warn "IAM permissions were not detected."

        }


        Write-Check "ECR permissions"

        if ($PolicyJson -match "ecr:\*" -or $PolicyJson -match "ecr:") {

            Write-Pass "ECR permissions detected."

        }
        else {

            Write-Warn "ECR permissions were not detected."

        }


        Write-Check "EKS permissions"

        if ($PolicyJson -match "eks:\*" -or $PolicyJson -match "eks:") {

            Write-Pass "EKS permissions detected."

        }
        else {

            Write-Warn "EKS permissions were not detected."

        }


        Write-Check "RDS permissions"

        if ($PolicyJson -match "rds:\*" -or $PolicyJson -match "rds:") {

            Write-Pass "RDS permissions detected."

        }
        else {

            Write-Warn "RDS permissions were not detected."

        }


        Write-Check "Lambda permissions"

        if ($PolicyJson -match "lambda:\*" -or $PolicyJson -match "lambda:") {

            Write-Pass "Lambda permissions detected."

        }
        else {

            Write-Warn "Lambda permissions were not detected."

        }

    }

}


# =====================================================================
# 12. TERRAFORM INSTALLATION
# =====================================================================

Write-Section "10. Terraform"

Write-Check "Terraform installation"

if (Test-CommandExists "terraform") {

    $TerraformVersion = terraform version 2>&1

    if ($LASTEXITCODE -eq 0) {

        Write-Pass "Terraform is installed."

        Write-Host $TerraformVersion

    }
    else {

        Write-Fail "Terraform command exists but could not execute."

    }

}
else {

    Write-Fail "Terraform is not installed or not available in PATH."

}


# =====================================================================
# 13. TERRAFORM DIRECTORY
# =====================================================================

Write-Check "Terraform directory"

$TerraformDirectoryFull = [System.IO.Path]::GetFullPath($TerraformDirectory)

if (Test-Path $TerraformDirectoryFull -PathType Container) {

    Write-Pass "Terraform directory exists."

    Write-Host "        $TerraformDirectoryFull"

}
else {

    Write-Fail "Terraform directory does not exist."

    Write-Host "        Expected:"
    Write-Host "        $TerraformDirectoryFull"

}


# =====================================================================
# 14. TERRAFORM FILES
# =====================================================================

if (Test-Path $TerraformDirectoryFull -PathType Container) {

    Write-Check "Terraform files"

    $TerraformFiles = Get-ChildItem `
        -Path $TerraformDirectoryFull `
        -Filter "*.tf" `
        -File `
        -ErrorAction SilentlyContinue

    if ($TerraformFiles.Count -gt 0) {

        Write-Pass "Terraform files found: $($TerraformFiles.Count)"

        foreach ($File in $TerraformFiles) {

            Write-Host "        $($File.Name)"

        }

    }
    else {

        Write-Fail "No Terraform .tf files were found."

    }

}


# =====================================================================
# 15. TERRAFORM PROVIDER
# =====================================================================

if (Test-Path $TerraformDirectoryFull -PathType Container) {

    Write-Section "11. Terraform AWS Provider"

    $TerraformFiles = Get-ChildItem `
        -Path $TerraformDirectoryFull `
        -Filter "*.tf" `
        -File `
        -ErrorAction SilentlyContinue

    $TerraformText = ""

    foreach ($File in $TerraformFiles) {

        $TerraformText += Get-Content $File.FullName -Raw
        $TerraformText += "`n"

    }


    Write-Check "AWS provider configuration"

    if ($TerraformText -match 'provider\s+"aws"') {

        Write-Pass "AWS provider block detected."

    }
    else {

        Write-Fail "AWS provider block was not detected."

    }


    Write-Check "AWS region configuration"

    if (
        ($TerraformText -match 'region\s*=\s*var\.aws_region') -or
        ($TerraformText -match 'region\s*=\s*["''][^"'']+["'']')
    ) {

        Write-Pass "Terraform AWS region configuration detected."

    }
    else {

        Write-Warn "Could not automatically detect Terraform AWS region configuration."

    }

}


# =====================================================================
# 16. TERRAFORM FMT
# =====================================================================

if (Test-CommandExists "terraform" -and
    (Test-Path $TerraformDirectoryFull -PathType Container)) {

    Write-Check "Terraform format"

    Push-Location $TerraformDirectoryFull

    try {

        terraform fmt -check -recursive

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Terraform formatting check passed."

        }
        else {

            Write-Warn "Terraform formatting check failed. Run 'terraform fmt -recursive'."

        }

    }
    finally {

        Pop-Location

    }

}


# =====================================================================
# 17. TERRAFORM INIT
# =====================================================================

if (Test-CommandExists "terraform" -and
    (Test-Path $TerraformDirectoryFull -PathType Container)) {

    Write-Check "Terraform init"

    Push-Location $TerraformDirectoryFull

    try {

        terraform init -input=false

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Terraform initialization succeeded."

        }
        else {

            Write-Fail "Terraform initialization failed."

        }

    }
    finally {

        Pop-Location

    }

}


# =====================================================================
# 18. TERRAFORM VALIDATE
# =====================================================================

if (Test-CommandExists "terraform" -and
    (Test-Path $TerraformDirectoryFull -PathType Container)) {

    Write-Check "Terraform validate"

    Push-Location $TerraformDirectoryFull

    try {

        terraform validate

        if ($LASTEXITCODE -eq 0) {

            Write-Pass "Terraform validation succeeded."

        }
        else {

            Write-Fail "Terraform validation failed."

        }

    }
    finally {

        Pop-Location

    }

}


# =====================================================================
# 19. MAIN WORKFLOW
# =====================================================================

Write-Section "12. GitHub Actions Workflows"

Write-Check "main-deploy.yaml"

if (Test-Path $MainWorkflow -PathType Leaf) {

    Write-Pass "main-deploy.yaml exists."

    $MainWorkflowText = Get-Content $MainWorkflow -Raw

    if ($MainWorkflowText -match 'terraform\.yml') {

        Write-Pass "main-deploy.yaml calls terraform.yml."

    }
    else {

        Write-Warn "main-deploy.yaml does not appear to call terraform.yml."

    }

}
else {

    Write-Fail "main-deploy.yaml was not found."

}


# =====================================================================
# 20. TERRAFORM WORKFLOW
# =====================================================================

Write-Check "terraform.yml"

if (Test-Path $TerraformWorkflow -PathType Leaf) {

    Write-Pass "terraform.yml exists."

    $TerraformWorkflowText = Get-Content $TerraformWorkflow -Raw


    Write-Check "workflow_call"

    if ($TerraformWorkflowText -match "workflow_call") {

        Write-Pass "terraform.yml supports workflow_call."

    }
    else {

        Write-Fail "terraform.yml does not contain workflow_call."

    }


    Write-Check "GitHub OIDC permission"

    if ($TerraformWorkflowText -match "id-token:\s*write") {

        Write-Pass "terraform.yml has id-token: write."

    }
    else {

        Write-Fail "terraform.yml is missing id-token: write."

    }


    Write-Check "AWS_REGION"

    if ($TerraformWorkflowText -match 'aws-region:\s*\$\{\{\s*vars\.AWS_REGION\s*\}\}') {

        Write-Pass "terraform.yml uses vars.AWS_REGION."

    }
    else {

        Write-Fail "terraform.yml does not use vars.AWS_REGION for aws-region."

    }


    Write-Check "AWS_ROLE_ARN"

    if ($TerraformWorkflowText -match 'role-to-assume:\s*\$\{\{\s*secrets\.AWS_ROLE_ARN\s*\}\}') {

        Write-Pass "terraform.yml uses secrets.AWS_ROLE_ARN."

    }
    else {

        Write-Fail "terraform.yml does not use secrets.AWS_ROLE_ARN."

    }


    Write-Check "configure-aws-credentials"

    if ($TerraformWorkflowText -match "aws-actions/configure-aws-credentials@v4") {

        Write-Pass "terraform.yml uses configure-aws-credentials@v4."

    }
    else {

        Write-Fail "terraform.yml does not use configure-aws-credentials@v4."

    }

}
else {

    Write-Fail "terraform.yml was not found."

}


# =====================================================================
# 21. GITHUB CONFIGURATION REMINDER
# =====================================================================

Write-Section "13. GitHub Repository Configuration"

Write-Host ""
Write-Host "The following values MUST exist in GitHub:" -ForegroundColor Yellow

Write-Host ""
Write-Host "Repository Variable:" -ForegroundColor Cyan
Write-Host "    AWS_REGION = $ExpectedAwsRegion"

Write-Host ""
Write-Host "Repository Secret:" -ForegroundColor Cyan
Write-Host "    AWS_ROLE_ARN = $RoleArn"

Write-Host ""
Write-Host "GitHub Repository:" -ForegroundColor Cyan
Write-Host "    $ExpectedGitHubRepository"

Write-Host ""
Write-Host "GitHub Branch:" -ForegroundColor Cyan
Write-Host "    $ExpectedGitHubBranch"

Write-Warn "GitHub Actions variables/secrets cannot be read directly using AWS CLI."
Write-Warn "Verify AWS_REGION and AWS_ROLE_ARN manually in GitHub Settings."


# =====================================================================
# 22. FINAL SUMMARY
# =====================================================================

Write-Section "FINAL VERIFICATION SUMMARY"

Write-Host ""
Write-Host "PASS    : $Passed" -ForegroundColor Green
Write-Host "FAIL    : $Failed" -ForegroundColor Red
Write-Host "WARNING : $Warnings" -ForegroundColor Yellow

Write-Host ""

if ($Failed -eq 0) {

    Write-Host "=======================================================================" -ForegroundColor Green
    Write-Host " RESULT: AWS/GitHub OIDC verification PASSED" -ForegroundColor Green
    Write-Host "=======================================================================" -ForegroundColor Green

    Write-Host ""
    Write-Host "AWS-side configuration looks ready for GitHub Actions OIDC." -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEP:" -ForegroundColor Cyan
    Write-Host "1. Verify AWS_REGION in GitHub:"
    Write-Host "   Settings -> Secrets and variables -> Actions -> Variables"
    Write-Host ""
    Write-Host "2. Verify AWS_ROLE_ARN in GitHub:"
    Write-Host "   Settings -> Secrets and variables -> Actions -> Secrets"
    Write-Host ""
    Write-Host "3. Run Main Deployment again."

}
else {

    Write-Host "=======================================================================" -ForegroundColor Red
    Write-Host " RESULT: VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "=======================================================================" -ForegroundColor Red

    Write-Host ""
    Write-Host "Fix the FAIL items above before running Main Deployment again." -ForegroundColor Yellow

}


# =====================================================================
# FINAL EXPECTED CONFIGURATION
# =====================================================================

Write-Section "EXPECTED FINAL CONFIGURATION"

Write-Host ""
Write-Host "IAM ROLE"
Write-Host "    $ExpectedRoleName"

Write-Host ""
Write-Host "IAM POLICY"
Write-Host "    $ExpectedPolicyName"

Write-Host ""
Write-Host "GITHUB OIDC"
Write-Host "    $ExpectedOidcUrl"

Write-Host ""
Write-Host "OIDC AUDIENCE"
Write-Host "    $ExpectedOidcAudience"

Write-Host ""
Write-Host "GITHUB REPOSITORY"
Write-Host "    $ExpectedGitHubRepository"

Write-Host ""
Write-Host "GITHUB BRANCH"
Write-Host "    $ExpectedGitHubBranch"

Write-Host ""
Write-Host "AWS REGION"
Write-Host "    $ExpectedAwsRegion"

Write-Host ""
Write-Host "GITHUB SECRET"
Write-Host "    AWS_ROLE_ARN"

Write-Host ""
Write-Host "GITHUB VARIABLE"
Write-Host "    AWS_REGION"

Write-Host ""
Write-Host "======================================================================="
Write-Host " Verification script finished."
Write-Host "======================================================================="
Write-Host ""
```

---

## How to Save the File

From the root of your repository:

```powershell
cd "C:\path\to\aws-hybrid-iac-lab"
```

Create the scripts directory if it doesn't exist:

```powershell
New-Item -ItemType Directory -Path ".\scripts" -Force
```

Create/open the file:

```powershell
notepad ".\scripts\verify-github-aws-oidc.ps1"
```

Paste the complete script above, save it, and close Notepad.

## How to Run It

From the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then:

```powershell
.\scripts\verify-github-aws-oidc.ps1
```

## Important: Run It From the Repository Root

Use:

```
aws-hybrid-iac-lab\
```

as your current directory.

For example:

```
PS C:\Users\...\aws-hybrid-iac-lab>
```

Then:

```powershell
.\scripts\verify-github-aws-oidc.ps1
```

The script automatically finds:

```
.github\workflows\main-deploy.yaml
.github\workflows\terraform.yml
infrastructure\terraform\
```

## What I Expect Your Output to Show

The most important section should eventually look approximately like:

```
[PASS] AWS CLI is installed.
[PASS] AWS authentication is working.
[PASS] GitHub OIDC provider exists.
[PASS] OIDC provider URL is correct.
[PASS] OIDC audience contains sts.amazonaws.com.
[PASS] IAM role exists.
[PASS] Trust policy allows AssumeRoleWithWebIdentity.
[PASS] Trust policy references GitHub OIDC.
[PASS] Trust policy contains sts.amazonaws.com audience.
[PASS] Trust policy references the correct GitHub repository.
[PASS] Trust policy restricts access to the main branch.
[PASS] IAM policy exists.
[PASS] GitHub Actions IAM policy is attached to the role.
[PASS] IAM policy document can be read.
[PASS] Policy contains iam:PassRole.
[PASS] CloudFormation permissions detected.
[PASS] S3 permissions detected.
[PASS] EC2 permissions detected.
[PASS] IAM permissions detected.
[PASS] ECR permissions detected.
[PASS] EKS permissions detected.
[PASS] Terraform is installed.
[PASS] Terraform directory exists.
[PASS] Terraform files found.
[PASS] Terraform validation succeeded.
[PASS] main-deploy.yaml exists.
[PASS] terraform.yml exists.
[PASS] terraform.yml supports workflow_call.
[PASS] terraform.yml has id-token: write.
[PASS] terraform.yml uses vars.AWS_REGION.
[PASS] terraform.yml uses secrets.AWS_ROLE_ARN.
[PASS] terraform.yml uses configure-aws-credentials@v4.
```

## One Important Limitation

The script cannot verify the actual value of your GitHub secret:

```
AWS_ROLE_ARN
```

or GitHub repository variable:

```
AWS_REGION
```

because those are stored inside GitHub, not AWS.

It can verify that your AWS role and workflow are configured to expect them.

So manually verify:

```
GitHub → aws-hybrid-iac-lab → Settings → Secrets and variables → Actions
```

### Repository Variable

```
AWS_REGION

Value:
us-east-1
```

### Repository Secret

```
AWS_ROLE_ARN
```

Value should be the exact ARN generated by the script, such as:

```
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

Do not paste your actual secret value into chat.

After you run the script, paste the PASS/FAIL/WARN output here. I can then go through every failed item and tell you exactly what needs to be fixed before you rerun Main Deployment #12.
