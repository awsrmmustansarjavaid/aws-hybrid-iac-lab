# Troubleshooting "Not Authorized to Perform sts:AssumeRoleWithWebIdentity"

## 1. First, Check the Secrets Without `--jq`

Run:

```powershell
gh secret list
```

You should see something like:

```
AWS_ROLE_ARN
...
```

Then run:

```powershell
gh variable list
```

You should see:

```
AWS_REGION
...
```

Do this first.

---

## 2. Check the Exact Repository

Run:

```powershell
gh repo view --json nameWithOwner,url
```

You should get:

```
awsrmmustansarjavaid/aws-hybrid-iac-lab
```

This confirms `gh` is operating on the correct repository.

---

## 3. Verify `AWS_ROLE_ARN` Without Revealing Its Value

GitHub will not show secret values, but we can check whether the secret exists:

```powershell
$secrets = gh secret list --json name | ConvertFrom-Json
$secrets.name
```

You should see:

```
AWS_ROLE_ARN
```

Similarly:

```powershell
$variables = gh variable list --json name | ConvertFrom-Json
$variables.name
```

You should see:

```
AWS_REGION
```

This avoids the jq/PowerShell problem entirely.

---

## 4. If `AWS_ROLE_ARN` Is Missing, Create It

Your required role ARN is:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

Run:

```powershell
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions"
```

Then verify:

```powershell
gh secret list
```

You should see:

```
AWS_ROLE_ARN
```

---

## 5. If `AWS_REGION` Is Missing, Create It

Your lab has been using `us-east-1`.

Run:

```powershell
gh variable set AWS_REGION --body "us-east-1"
```

Then:

```powershell
gh variable list
```

You should see:

```
AWS_REGION
```

---

## 6. Check the AWS Role Itself

Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text
```

Expected:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

Then check the trust policy:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

We need to make sure it contains:

```json
"Action": "sts:AssumeRoleWithWebIdentity"
```

and:

```json
"Principal": {
    "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
}
```

---

## 7. Most Important: Check Your Current Trust Policy

Because your GitHub Actions error is:

```
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

the next thing I want to verify is the exact current trust policy.

Run this:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

### If It Currently Has This:

```
"token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
```

then temporarily change it to:

```
"token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*"
```

This is a diagnostic test, not necessarily our final security configuration.

---

## 8. Create the Temporary Trust Policy

From your repo directory:

```powershell
@'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOIDCTrust",
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
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*"
        }
      }
    }
  ]
}
'@ | Set-Content -Path ".\github-actions-trust-policy.json"
```

Then apply it:

```powershell
aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document "file://github-actions-trust-policy.json"
```

Verify:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

---

## 9. Then Test GitHub Actions Again

Push a small change or manually start the workflow.

You can use:

```powershell
gh workflow run "Main Deployment"
```

Then check:

```powershell
gh run list --limit 5
```

Or open your Actions page in GitHub.

The important part is whether this step changes from:

```
Configure AWS Credentials
❌ Could not assume role with OIDC
```

to:

```
Configure AWS Credentials
✓ AWS credentials configured
```

and then:

```
Verify AWS Identity
```

should execute.

---

## Your Situation Right Now

The troubleshooting tree is:

```text
GitHub CLI
   │
   ├── ✓ gh auth status works
   │
   ├── ? AWS_ROLE_ARN exists
   │
   ├── ? AWS_REGION exists
   │
   └── AWS IAM Role
          │
          ├── ✓ Role exists
          ├── ✓ GitHub OIDC provider exists
          ├── ✓ Policy attached
          │
          └── ❌ GitHub cannot AssumeRoleWithWebIdentity
                    │
                    └── Check/test trust policy
```

Do not attach `aws-hybrid-iac-lab-GitHubActions` to `github-ci-cd-user`.

That is not required for GitHub Actions OIDC.

Your local user:

```
github-ci-cd-user
```

is simply the identity you're using with AWS CLI to administer AWS.

GitHub Actions should do:

```text
GitHub
   ↓
GitHub OIDC token
   ↓
AWS STS
   ↓
aws-hybrid-iac-lab-GitHubActions
   ↓
AWS resources
```

---

## Do These Three Commands Now and Send Me the Output

```powershell
gh secret list
gh variable list
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

Do not paste any GitHub token, AWS access key, secret key, or other credential. The `gh secret list` output only shows secret names, which is safe.
