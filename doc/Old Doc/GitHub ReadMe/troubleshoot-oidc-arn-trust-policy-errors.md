# Troubleshooting GitHub Actions OIDC: Invalid ARN, Empty Policy Version, and AssumeRoleWithWebIdentity Failures

You actually have **two separate PowerShell problems**, and the GitHub Actions failure is the important one.

## 1. `Invalid ARN: Could not be parsed`

This means `$OIDC_PROVIDER_ARN` is either **empty** or contains something that is not a valid AWS ARN.

Run:

```powershell
$OIDC_PROVIDER_ARN
```

If it prints nothing, the variable was never set in your current PowerShell session.

For GitHub Actions OIDC, it should look similar to:

```text
arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

Get the actual provider ARN directly from AWS:

```powershell
aws iam list-open-id-connect-providers
```

You should get something like:

```json
{
    "OpenIDConnectProviderList": [
        {
            "Arn": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
        }
    ]
}
```

Then set it:

```powershell
$OIDC_PROVIDER_ARN = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
```

Verify:

```powershell
$OIDC_PROVIDER_ARN
```

Then:

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn $OIDC_PROVIDER_ARN
```

---

## 2. `$POLICY_VERSION` Is Empty

Your second error tells us exactly what happened:

```text
argument --version-id: expected one argument
```

You ran:

```powershell
$POLICY_VERSION
```

and PowerShell displayed nothing.

So this command:

```powershell
aws iam get-policy-version `
  --policy-arn $POLICY_ARN `
  --version-id $POLICY_VERSION
```

effectively became:

```text
--version-id
```

with no value.

First check:

```powershell
$POLICY_ARN
$POLICY_VERSION
```

If `$POLICY_ARN` is also empty, set it to your actual policy ARN.

Then discover the policy's default version:

```powershell
aws iam get-policy `
  --policy-arn $POLICY_ARN `
  --query "Policy.DefaultVersionId" `
  --output text
```

For example, AWS may return:

```text
v1
```

Then:

```powershell
$POLICY_VERSION = aws iam get-policy `
  --policy-arn $POLICY_ARN `
  --query "Policy.DefaultVersionId" `
  --output text
```

Verify:

```powershell
$POLICY_VERSION
```

It should now say something like:

```text
v1
```

Then:

```powershell
aws iam get-policy-version `
  --policy-arn $POLICY_ARN `
  --version-id $POLICY_VERSION
```

---

## 3. Your GitHub Actions Failure Is the Real Problem

Your workflow reaches:

```text
Run aws-actions/configure-aws-credentials@v4
Assuming role with OIDC
```

but AWS returns:

```text
Error: Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

That means:

> **GitHub successfully obtained an OIDC token, but AWS IAM refused to allow that token to assume your GitHub Actions IAM role.**

The most common cause is the **trust policy of the IAM role**.

Your architecture should be:

```text
GitHub Actions
      |
      | OIDC token
      v
token.actions.githubusercontent.com
      |
      v
AWS IAM OIDC Provider
      |
      v
GitHub Actions IAM Role
      |
      | sts:AssumeRoleWithWebIdentity
      v
AWS resources
```

The trust relationship on the role must explicitly allow GitHub's OIDC provider.

---

## 4. Check Your OIDC Provider

Run:

```powershell
aws iam list-open-id-connect-providers
```

You need to see:

```text
arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
```

If it exists, inspect it.

First:

```powershell
$OIDC_PROVIDER_ARN = aws iam list-open-id-connect-providers `
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" `
  --output text
```

Then:

```powershell
$OIDC_PROVIDER_ARN
```

Then:

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn $OIDC_PROVIDER_ARN
```

You want the provider URL to be:

```text
https://token.actions.githubusercontent.com
```

---

## 5. Check Your GitHub Actions IAM Role

You need to find the role you are using in GitHub.

For example, if your role is:

```text
CharlieCafe-GitHubActionsRole
```

run:

```powershell
$ROLE_NAME = "CharlieCafe-GitHubActionsRole"
```

Then:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

Look for something similar to:

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/aws-hybrid-iac-lab:*"
        }
      }
    }
  ]
}
```

### Very Important

This part:

```text
repo:YOUR_GITHUB_USERNAME/aws-hybrid-iac-lab:*
```

must match your **actual GitHub repository**.

For example, if your repository is:

```text
IT-charlie/aws-hybrid-iac-lab
```

then use:

```text
repo:IT-charlie/aws-hybrid-iac-lab:*
```

Not:

```text
repo:IT-charlie/aws-hybrid-iac-lab
```

and not another repository name.

---

## 6. I Strongly Recommend Checking Your Actual GitHub Workflow

Your workflow probably contains something like:

```yaml
permissions:
  id-token: write
  contents: read
```

That is required for OIDC.

For example:

```yaml
name: Terraform Infrastructure Deployment

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    name: Terraform Infrastructure Deployment
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan
```

The important part is:

```yaml
permissions:
  id-token: write
  contents: read
```

Without:

```yaml
id-token: write
```

GitHub cannot provide the OIDC token properly.

---

## 7. Check Your GitHub `AWS_ROLE_ARN`

Since you were setting up repository variables/secrets, verify that the secret contains the **IAM role ARN**, not the role name.

It should look like:

```text
arn:aws:iam::123456789012:role/CharlieCafe-GitHubActionsRole
```

NOT:

```text
CharlieCafe-GitHubActionsRole
```

and NOT:

```text
arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

Those are three different things.

---

## 8. Check the Role ARN From AWS

You can verify the role exists:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.Arn" `
  --output text
```

For example:

```text
arn:aws:iam::123456789012:role/CharlieCafe-GitHubActionsRole
```

Compare that with your GitHub repository secret:

```text
AWS_ROLE_ARN
```

They must match.

---

## 9. Check the Exact Trust Policy

This is the **most important command** to run now:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

You should have these three critical pieces:

### Federated Principal

```json
"Principal": {
  "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
}
```

### Action

```json
"Action": "sts:AssumeRoleWithWebIdentity"
```

### Audience

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
}
```

And your repository restriction:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:<GITHUB_OWNER>/aws-hybrid-iac-lab:*"
}
```

---

## 10. A Very Important Detail About Your Branch

If your trust policy is currently something like:

```json
"token.actions.githubusercontent.com:sub":
  "repo:IT-charlie/aws-hybrid-iac-lab:ref:refs/heads/main"
```

then only the `main` branch can assume the role.

If you're testing with another branch, such as:

```text
update-print-statement
```

it will be rejected.

For a lab, I recommend initially using:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:IT-charlie/aws-hybrid-iac-lab:*"
}
```

Once everything works, you can tighten the condition to only the branches/environments you actually need.

---

## 11. Your Node 20 Message Is NOT the Cause

This message:

```text
Node 20 is being deprecated.
This workflow is running with Node 24 by default.
```

is a warning.

It is **not why your Terraform job failed**.

The actual failure is:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

So don't waste time trying to fix Node first.

---

## 12. Run These Commands Now

From your PowerShell, run these **in this order**:

```powershell
aws sts get-caller-identity
```

Then:

```powershell
aws iam list-open-id-connect-providers
```

Then:

```powershell
$OIDC_PROVIDER_ARN = aws iam list-open-id-connect-providers `
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn" `
  --output text
```

Then:

```powershell
$OIDC_PROVIDER_ARN
```

Then:

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn $OIDC_PROVIDER_ARN
```

Then set your actual role:

```powershell
$ROLE_NAME = "YOUR_GITHUB_ACTIONS_ROLE_NAME"
```

Then:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

---

## Step 1 — Set the Correct Role Name

Run:

```powershell
$ROLE_NAME = "aws-hybrid-iac-lab-GitHubActions"
```

Then verify the role exists:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.{RoleName:RoleName,Arn:Role.Arn}" `
  --output table
```

You should get something like:

```text
----------------------------------------------------------
|                       GetRole                          |
+----------------------+---------------------------------+
| RoleName             | aws-hybrid-iac-lab-GitHubActions |
| Arn                  | arn:aws:iam::537236558357:role/... |
+----------------------+---------------------------------+
```

---

## Step 2 — Get the Trust Policy

Now run:

```powershell
aws iam get-role `
  --role-name $ROLE_NAME `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

This is the command I want you to run next.

The result should contain something like:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:YOUR-GITHUB-OWNER/aws-hybrid-iac-lab:*"
                }
            }
        }
    ]
}
```

Do not change anything yet.

Run the command and paste the output here.

---

## 1. First, Get the Actual Role ARN

Your previous command showing:

```
Arn | None
```

is only because the JMESPath query was slightly wrong. Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text
```

It should return something like:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

### Then Set It Locally

```powershell
$ROLE_ARN = aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text

$ROLE_ARN
```

You want:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 2. Verify the IAM Policy Is Attached to the Role

Run:

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --output table
```

You should see:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

with an ARN similar to:

```
arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy
```

If it isn't there, attach it:

```powershell
aws iam attach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
```

Then verify again:

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --output table
```

---

## 5. Check Your GitHub `AWS_ROLE_ARN`

This is now one of the most likely problems.

Your GitHub repository secret must be:

```
AWS_ROLE_ARN
```

and its value must be the role ARN, not the role name.

It should be:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

### It Must NOT Be:

```
aws-hybrid-iac-lab-GitHubActions
```

And it must NOT be:

```
arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com
```

And it must NOT be the policy ARN:

```
arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy
```

The correct value is:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 6. Check `AWS_REGION`

Your repository variable should be:

```
AWS_REGION
```

with something like:

```
us-east-1
```

Since your workflow uses:

```yaml
aws-region: ${{ vars.AWS_REGION }}
```

---

## 7. Important: Check Whether GitHub Is Actually Running From `main`

Your trust policy specifically says:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

So if your workflow is running from another branch, for example:

```
develop
```

or:

```
feature/terraform
```

AWS will reject the token.

Your workflow must run from:

```
main
```

### Check Your Local Branch

From:

```
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

run:

```powershell
git branch --show-current
```

You want:

```
main
```

Then:

```powershell
git status
```

and:

```powershell
git remote -v
```

Your remote should point to:

```
https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git
```

or the SSH equivalent.

---

## 8. Check the GitHub Repository Exactly

Run:

```powershell
git remote get-url origin
```

I expect:

```
https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git
```

This must match the IAM trust policy:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:...
```

Even a small difference matters.

For example, if the actual repository were:

```
awsrmmustansarjavaid/AWS-Hybrid-IaC-Lab
```

then the trust policy would not match.

---

## Run These 5 Commands Now

Please run these exactly in PowerShell:

### Command 1 — Role ARN

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text
```

### Command 2 — Attached Policies

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --output table
```

### Command 3 — Current Git Branch

```powershell
git branch --show-current
```

### Command 4 — GitHub Repository

```powershell
git remote get-url origin
```

### Command 5 — Git Status

```powershell
git status
```

---

## One More Useful Test

Run this locally:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.{Arn:Arn,MaxSessionDuration:MaxSessionDuration}" `
  --output table
```

Then run:

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "AttachedPolicies[].{Name:PolicyName,Arn:PolicyArn}" `
  --output table
```

We already know the second one should show:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

---

# Verify GitHub Actions Secret and Variable Using PowerShell

Yes. You can verify **whether they exist** from PowerShell without displaying the secret value.

## 1. Verify `AWS_ROLE_ARN` Secret

GitHub CLI (`gh`) does **not** allow you to retrieve the secret's value, but it can confirm whether the secret exists.

First make sure you're authenticated:

```powershell
gh auth status
```

Then run:

```powershell
gh secret list
```

Look for:

```text
AWS_ROLE_ARN
```

### More Direct Check

Run:

```powershell
gh secret list --json name --jq ".[] | select(.name == \"AWS_ROLE_ARN\") | .name"
```

If it exists, you should get:

```text
AWS_ROLE_ARN
```

If nothing is returned, it doesn't exist.

You can therefore report:

```text
AWS_ROLE_ARN exists: YES
```

or:

```text
AWS_ROLE_ARN exists: NO
```

> **Important:** Do not run commands that attempt to print the secret value.

---

## 2. Verify `AWS_REGION` Repository Variable

Run:

```powershell
gh variable list
```

Look for:

```text
AWS_REGION
```

Or use this direct check:

```powershell
gh variable list --json name --jq ".[] | select(.name == \"AWS_REGION\") | .name"
```

If it exists:

```text
AWS_REGION
```

Then report:

```text
AWS_REGION exists: YES
```

If nothing is returned:

```text
AWS_REGION exists: NO
```

---

## 3. Check Both at Once

You can use this PowerShell block:

```powershell
Write-Host "Checking GitHub Actions configuration..."
Write-Host ""

$roleSecret = gh secret list --json name --jq ".[] | select(.name == `"AWS_ROLE_ARN`") | .name"
$regionVariable = gh variable list --json name --jq ".[] | select(.name == `"AWS_REGION`") | .name"

if ($roleSecret -eq "AWS_ROLE_ARN") {
    Write-Host "AWS_ROLE_ARN exists: YES"
} else {
    Write-Host "AWS_ROLE_ARN exists: NO"
}

if ($regionVariable -eq "AWS_REGION") {
    Write-Host "AWS_REGION exists: YES"
} else {
    Write-Host "AWS_REGION exists: NO"
}
```

Expected output:

```text
Checking GitHub Actions configuration...

AWS_ROLE_ARN exists: YES
AWS_REGION exists: YES
```

This checks **only the names**. It does **not print the `AWS_ROLE_ARN` secret value**, which is what you want.

## If `gh` Is Not Recognized

Check:

```powershell
gh --version
```

If PowerShell says that `gh` is not recognized, GitHub CLI isn't installed or isn't in your PATH.
