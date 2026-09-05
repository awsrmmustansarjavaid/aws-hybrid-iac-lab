# Diagnosing and Fixing the GitHub OIDC `sub` Claim Mismatch

## 1. First Verify Your Trust Policy

Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

You should see your GitHub OIDC provider and the `sub` condition.

---

## 2. The Real GitHub Problem Is Still OIDC

Your original GitHub error was:

```
Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

This is not fixed by attaching the role to `github-ci-cd-user`.

The architecture should be:

```text
                    YOUR PC
                       │
                       │ AWS CLI
                       ▼
              github-ci-cd-user
                       │
                       │ administers IAM
                       │
                       ▼
        ┌──────────────────────────────┐
        │ aws-hybrid-iac-lab-          │
        │ GitHubActions ROLE           │
        │                              │
        │ Trust Policy                 │
        │      ▲                       │
        │      │ OIDC                  │
        └──────┼───────────────────────┘
               │
               │ AssumeRoleWithWebIdentity
               │
        GitHub Actions
               │
               ▼
       Terraform / AWS
```

So:

```
Local user
→ manages AWS

GitHub Actions
→ assumes aws-hybrid-iac-lab-GitHubActions
```

The role should not be attached to the local user.

---

## 3. There Is a Very Important Clue in Your Dates

Your role was created:

```
September 05, 2026
```

And your GitHub repository appears to have been created around this same period.

GitHub changed its OIDC subject behavior for repositories created after July 15, 2026. New repositories can use an immutable `sub` format.

The old format is:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

But the newer immutable format can look like:

```
repo:OWNER_ID/REPO_ID:ref:refs/heads/main
```

with the actual GitHub organization/user and repository IDs embedded in the subject.

That could explain exactly why your trust policy looks correct but GitHub still receives:

```
sts:AssumeRoleWithWebIdentity
AccessDenied
```

GitHub's current AWS OIDC guidance recommends restricting the trust policy using the `sub` claim.

---

## 4. Let's Check Your Repository

Run this in PowerShell:

```powershell
$repo = gh api repos/awsrmmustansarjavaid/aws-hybrid-iac-lab | ConvertFrom-Json

$repo | Select-Object `
    full_name,
    created_at,
    id,
    @{Name="owner_id"; Expression={$_.owner.id}}
```

You should get something similar to:

```
full_name : awsrmmustansarjavaid/aws-hybrid-iac-lab
created_at: 2026-09-04T...
id        : 123456789
owner_id  : 987654321
```

Do not send me any token/password. Those four values are enough.

---

## 5. Also Check GitHub's OIDC Configuration

Run:

```powershell
gh api repos/awsrmmustansarjavaid/aws-hybrid-iac-lab/actions/oidc/customization/sub
```

If GitHub returns something like:

```json
{
  "use_immutable_subject": true
}
```

then we have likely found the reason.

If it returns:

```json
{
  "use_default": true
}
```

or similar, we'll use the actual default subject format.

---

## 6. Don't Change Your Trust Policy to `*` Yet

You may see advice like:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*"
}
```

I don't recommend doing that yet.

Your lab should use a properly restricted GitHub OIDC trust policy.

We want:

```text
GitHub repository
       +
main branch
       +
correct OIDC subject
       ↓
AWS IAM role
```

rather than allowing arbitrary GitHub subjects.

GitHub specifically recommends using the `sub` claim to restrict which workflows can assume the AWS role.

---

## 7. About the Policy You Created

You currently have:

```
github-ci-cd-user-iam-role-management
```

attached to:

```
aws-hybrid-iac-lab-GitHubActions
```

I would remove it from the GitHub Actions role because it is not needed by GitHub Actions.

The GitHub Actions role should contain permissions needed by your Terraform deployment, such as your:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

Its trust relationship should contain:

```
token.actions.githubusercontent.com
```

and the correct `sub`.

Don't try this again from `github-ci-cd-user`:

```powershell
aws iam put-user-policy ...
```

because your user isn't authorized to modify its own permissions.

If you eventually need that administrative policy attached to `github-ci-cd-user`, it must be done by an administrator/root-equivalent IAM identity, or through the IAM console using an identity that has `iam:PutUserPolicy`.

---

## Do These Two Checks Now

**Check 1:**

```powershell
$repo = gh api repos/awsrmmustansarjavaid/aws-hybrid-iac-lab | ConvertFrom-Json

$repo | Select-Object `
    full_name,
    created_at,
    id,
    @{Name="owner_id"; Expression={$_.owner.id}}
```

**Check 2:**

```powershell
gh api repos/awsrmmustansarjavaid/aws-hybrid-iac-lab/actions/oidc/customization/sub
```

Send me the output of those two commands. Then I can give you the exact final `github-actions-trust-policy.json` for your repository instead of guessing at the OIDC `sub`.

---

# Part 2 — Diagnosing With a Debug Step in the Workflow

## 1. Ignore These Errors

You typed:

```powershell
aws iam update-assume-role-policy ...
```

and:

```powershell
aws iam put-user-policy ...
```

Those `...` are not placeholders that AWS CLI understands. They literally mean you didn't provide the required parameters.

For example, this is invalid:

```powershell
aws iam update-assume-role-policy ...
```

The correct command is:

```powershell
aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document "file://github-actions-trust-policy.json"
```

But you don't need to run it again right now, because your current trust policy is already updated successfully.

---

## 2. Your Current Trust Policy

You have:

```json
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
```

This is structurally correct for GitHub OIDC.

AWS requires the role trust policy to trust the GitHub OIDC provider for `AssumeRoleWithWebIdentity`.

---

## 3. Let's Verify the OIDC Provider Itself

Run:

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
```

You should see information including:

```
ClientIDList
ThumbprintList
Url
```

Most importantly, `ClientIDList` should contain:

```
sts.amazonaws.com
```

---

## 4. Verify the Role Policy

Run:

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"
```

You should have:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

The `github-ci-cd-user-iam-role-management` policy is not required by GitHub Actions.

---

## 5. One Thing I Want to Correct From Your Earlier Setup

You showed:

```
Permissions policies (2)

aws-hybrid-iac-lab-GitHubActionsPolicy
github-ci-cd-user-iam-role-management
```

on the GitHub Actions role.

I recommend removing:

```
github-ci-cd-user-iam-role-management
```

from that role.

It was intended to be an administrative policy for your local IAM user, not a permission required by GitHub Actions.

Your GitHub role should basically be:

```text
aws-hybrid-iac-lab-GitHubActions
│
├── Trust policy
│   └── GitHub OIDC
│
└── Permissions
    └── aws-hybrid-iac-lab-GitHubActionsPolicy
```

---

## 6. Now We Need to See the ACTUAL GitHub OIDC Claims

This is the most important next step.

Your AWS trust policy says:

```
aud = sts.amazonaws.com
```

and:

```
sub = repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*
```

We know GitHub is configured for the default subject.

So let's have GitHub show us exactly what claims it is issuing.

Temporarily add this step before **Configure AWS Credentials** in `.github/workflows/terraform.yml`:

```yaml
      - name: Debug GitHub OIDC Claims
        shell: bash
        run: |
          set -euo pipefail

          echo "Requesting GitHub OIDC token..."

          TOKEN_RESPONSE=$(curl -sSf \
            -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
            "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=sts.amazonaws.com")

          TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.value')

          if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
            echo "ERROR: GitHub OIDC token was not returned."
            exit 1
          fi

          PAYLOAD=$(echo "$TOKEN" | cut -d '.' -f 2)

          DECODED=$(python3 -c '
          import sys
          import base64
          import json

          payload = sys.stdin.read().strip()
          payload += "=" * ((4 - len(payload) % 4) % 4)

          decoded = base64.urlsafe_b64decode(payload)
          claims = json.loads(decoded)

          print(json.dumps({
              "aud": claims.get("aud"),
              "sub": claims.get("sub"),
              "repository": claims.get("repository"),
              "repository_owner": claims.get("repository_owner"),
              "ref": claims.get("ref"),
              "job_workflow_ref": claims.get("job_workflow_ref")
          }, indent=2))
          ' <<< "$PAYLOAD")

          echo ""
          echo "======================================"
          echo "GitHub OIDC Claims"
          echo "======================================"
          echo "$DECODED"
          echo "======================================"
```

### Important

This does not print the complete JWT.

It extracts only:

```
aud
sub
repository
repository_owner
ref
job_workflow_ref
```

So don't print the actual TOKEN.

---

## 7. Commit and Push

After adding that diagnostic step:

```powershell
git status
```

Then:

```powershell
git add .github/workflows/terraform.yml
```

Then:

```powershell
git commit -m "debug GitHub OIDC claims"
```

Then:

```powershell
git push origin main
```

GitHub Actions will run.

---

## 8. What We're Looking For

The important output should look approximately like:

```json
{
  "aud": "sts.amazonaws.com",
  "sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main",
  "repository": "awsrmmustansarjavaid/aws-hybrid-iac-lab",
  "repository_owner": "awsrmmustansarjavaid",
  "ref": "refs/heads/main",
  "job_workflow_ref": "awsrmmustansarjavaid/aws-hybrid-iac-lab/.github/workflows/terraform.yml@refs/heads/main"
}
```

If that is what GitHub gives us, then your AWS trust policy:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*
```

must match it, and we'll investigate the OIDC provider/configuration next.

If the `sub` is different, we'll know exactly what AWS needs.

### Your Architecture Should NOT Be Changed

Don't attach this:

```
aws-hybrid-iac-lab-GitHubActions
```

to:

```
github-ci-cd-user
```

Keep them separate:

```text
┌───────────────────────────────┐
│ github-ci-cd-user              │
│                               │
│ Your local AWS CLI identity   │
│                               │
│ Used to administer AWS        │
└───────────────┬───────────────┘
                │
                │ manages
                ▼
┌───────────────────────────────┐
│ aws-hybrid-iac-lab-            │
│ GitHubActions ROLE             │
│                               │
│ Trust: GitHub OIDC            │
│ Permissions: Terraform AWS    │
└───────────────▲───────────────┘
                │
                │ AssumeRoleWithWebIdentity
                │
┌───────────────┴───────────────┐
│ GitHub Actions                 │
│                               │
│ Terraform                     │
│ Docker                        │
│ Kubernetes                    │
└───────────────────────────────┘
```

Next step: add the temporary OIDC diagnostic step, push it, and show me the GitHub OIDC Claims output. That will let us pinpoint why AWS is still rejecting `AssumeRoleWithWebIdentity`.

---

# Part 3 — Root Cause Found: `sub` Claim Mismatch

Yes — **we found the exact cause now.** Your GitHub OIDC diagnostic has given us the answer.

## 🔴 Exact Problem

Your GitHub Actions token says:

```text
sub:
repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main
```

But your AWS IAM role currently trusts:

```text
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*
```

These are **different values**.

Therefore AWS correctly rejects:

```
sts:AssumeRoleWithWebIdentity
```

Your OIDC provider and audience are correct:

```text
OIDC Provider:
arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com

aud:
sts.amazonaws.com
```

The problem is specifically the **`sub` condition in the role trust policy**.

GitHub's OIDC documentation uses the `sub` claim to restrict which repository/workflow can assume an AWS role.

---

## 1. Your Actual GitHub OIDC Identity

Your diagnostic proved:

```json
{
  "aud": "sts.amazonaws.com",
  "sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main",
  "repository": "awsrmmustansarjavaid/aws-hybrid-iac-lab",
  "repository_owner": "awsrmmustansarjavaid",
  "ref": "refs/heads/main",
  "job_workflow_ref": "awsrmmustansarjavaid/aws-hybrid-iac-lab/.github/workflows/terraform.yml@refs/heads/main"
}
```

This is the value AWS must match.

Your repository IDs are:

```
Owner ID: 242676971
Repository ID: 1357303207
```

So we now know the exact trust relationship.

---

## 2. Replace Your Trust Policy

Open:

```
github-actions-trust-policy.json
```

Replace **the entire file** with this:

```json
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### Why This Is Correct

Your GitHub token:

```
repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main
```

AWS trust policy:

```
repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main
```

They now match **exactly**.

---

## 3. You Can Create the File Directly From PowerShell

To avoid editing mistakes, run:

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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
        }
      }
    }
  ]
}
'@ | Set-Content -Path ".\github-actions-trust-policy.json"
```

Then verify the file:

```powershell
Get-Content .\github-actions-trust-policy.json
```

---

## 4. Update the IAM Role Trust Policy

Now run the **full command**, not `...`:

```powershell
aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document "file://github-actions-trust-policy.json"
```

You should get **no output** if it succeeds.

That means:

```
SUCCESS
```

AWS's `UpdateAssumeRolePolicy` operation changes the role's trust policy — the policy that determines which identities are allowed to assume the role.

---

## 5. Verify the Trust Policy

Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

You should see:

```json
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

---

## 6. Do NOT Modify `terraform.yml` Anymore

Your diagnostic step worked:

```
GitHub OIDC diagnostic completed successfully.
```

That proves:

```text
GitHub Actions
     ↓
OIDC token request
     ↓
GitHub
     ↓
OIDC JWT
```

is working.

Your:

```yaml
permissions:
  id-token: write
  contents: read
```

is also correct.

Your AWS configuration:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ vars.AWS_REGION }}
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

is also correct.

**Leave those parts alone for now.**

The only thing we needed to fix was the AWS role's trust policy.

---

## 7. Your Authentication Flow Will Then Be

After the fix:

```text
┌────────────────────────────────────────────┐
│ GitHub Actions                             │
│                                            │
│ Repository:                                │
│ awsrmmustansarjavaid/aws-hybrid-iac-lab    │
│                                            │
│ Branch: main                               │
└─────────────────────┬──────────────────────┘
                      │
                      │ GitHub OIDC JWT
                      │
                      │ sub =
                      │ repo:awsrmmustansarjavaid@242676971/
                      │ aws-hybrid-iac-lab@1357303207:
                      │ ref:refs/heads/main
                      ▼
┌────────────────────────────────────────────┐
│ AWS STS                                    │
│                                            │
│ AssumeRoleWithWebIdentity                  │
└─────────────────────┬──────────────────────┘
                      │
                      │
                      ▼
┌────────────────────────────────────────────┐
│ IAM ROLE                                   │
│                                            │
│ aws-hybrid-iac-lab-GitHubActions            │
│                                            │
│ Trust Policy                               │
│        ▲                                   │
│        │ exact sub match                   │
└────────┼───────────────────────────────────┘
         │
         │ temporary credentials
         ▼
┌────────────────────────────────────────────┐
│ Terraform                                  │
│                                            │
│ terraform init                             │
│ terraform fmt                              │
│ terraform validate                         │
│ terraform plan                             │
│ terraform apply                            │
└────────────────────────────────────────────┘
```

---

## 8. About `github-ci-cd-user`

There are actually **two completely different things** here.

### Your Local User

```
github-ci-cd-user
```

This is what your PowerShell AWS CLI is authenticated as:

```
arn:aws:iam::537236558357:user/github-ci-cd-user
```

It administers AWS.

### GitHub Actions Role

```
aws-hybrid-iac-lab-GitHubActions
```

This is **not attached to the local user**.

GitHub assumes it through:

```
sts:AssumeRoleWithWebIdentity
```

That's the correct architecture.

---

## 9. About the `github-ci-cd-user-iam-role-management` Policy

You showed earlier that the role has:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
github-ci-cd-user-iam-role-management
```

I recommend removing:

```
github-ci-cd-user-iam-role-management
```

from:

```
aws-hybrid-iac-lab-GitHubActions
```

because GitHub Actions does not need permissions such as:

```
iam:GetRole
iam:UpdateAssumeRolePolicy
```

Those are **IAM administration permissions**, not Terraform runtime authentication permissions.

Your GitHub Actions role should retain the actual deployment policy:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

---

## 10. You Don't Need to Give `github-ci-cd-user` `PutUserPolicy`

This:

```powershell
aws iam put-user-policy ...
```

failed with:

```
not authorized to perform: iam:PutUserPolicy
```

That's fine.

Don't try to solve the GitHub OIDC problem by giving your local user more permissions.

You already successfully executed:

```powershell
aws iam update-assume-role-policy
```

so your local user currently has enough permission to update the GitHub Actions role trust policy.

---

## 11. Now Run These Commands in Order

### Step 1 — Create Corrected Trust Policy

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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
        }
      }
    }
  ]
}
'@ | Set-Content -Path ".\github-actions-trust-policy.json"
```

### Step 2 — Update Role

```powershell
aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document "file://github-actions-trust-policy.json"
```

### Step 3 — Verify

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

### Step 4 — Check Your GitHub Secret

```powershell
gh secret list
```

You should have:

```
AWS_ROLE_ARN
```

### Step 5 — Check Your GitHub Variable

```powershell
gh variable list
```

You should have:

```
AWS_REGION    us-east-1
```

### Step 6 — Push a New Commit

Since your OIDC diagnostic step is already committed in the workflow, after changing only the AWS trust policy you can simply trigger the workflow manually.

---

## 🎯 Expected Result

The next run should get past:

```
Run aws-actions/configure-aws-credentials@v4
Assuming role with OIDC
```

and then:

```text
Configure AWS Credentials
        ↓
SUCCESS
        ↓
Verify AWS Identity
        ↓
aws sts get-caller-identity
        ↓
Terraform Init
        ↓
Terraform Validate
        ↓
Terraform Plan
        ↓
Terraform Apply
```

And the `Verify AWS Identity` output should identify an assumed role similar to:

```
arn:aws:sts::537236558357:assumed-role/aws-hybrid-iac-lab-GitHubActions/...
```

**This is the fix.** We now have the actual OIDC claim from GitHub, so there is no more guessing about the `sub` value. Your previous trust policy was using the old repository subject format, while the token actually issued to your workflow uses the owner-ID/repository-ID subject format.

---

# Part 4 — Confirming Exactly What Gets Replaced

Yes. **You replace the trust policy on the IAM role `aws-hybrid-iac-lab-GitHubActions`.**

But you do **not** edit the IAM role's trust policy by manually replacing text in the AWS console only. The `github-actions-trust-policy.json` file on your PC is the source document, and this AWS CLI command uploads that file into the role's **Trust relationships**.

You currently have:

```text
OLD
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

but GitHub is actually sending:

```text
NEW
repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main
```

So yes — **we need to replace the role's current trust policy with the new one.**

## Do This Exactly

### Step 1 — Stay in Your Project Folder

You are already here:

```powershell
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

Good.

### Step 2 — Replace the Local JSON File

Run this entire PowerShell command:

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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
        }
      }
    }
  ]
}
'@ | Set-Content -Path ".\github-actions-trust-policy.json"
```

This changes the file:

```text
aws-hybrid-iac-lab
│
└── github-actions-trust-policy.json   ← UPDATED
```

### Step 3 — Check the File

Run:

```powershell
Get-Content .\github-actions-trust-policy.json
```

You should see this important line:

```json
"token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
```

Make sure it says:

```
@242676971
```

and:

```
@1357303207
```

### Step 4 — NOW Update the IAM Role

This is the part that actually changes AWS.

Run:

```powershell
aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document "file://github-actions-trust-policy.json"
```

#### Important Distinction

This command:

```powershell
aws iam update-assume-role-policy
```

updates **this IAM role**:

```
aws-hybrid-iac-lab-GitHubActions
```

It does **not** update:

```
github-ci-cd-user
```

It does **not** update:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

It updates specifically:

```text
IAM Role
   ↓
aws-hybrid-iac-lab-GitHubActions
   ↓
Trust relationships
```

### Step 5 — Verify AWS Changed It

Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

Look for:

```json
"token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
```

It should NOT say this anymore:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

### Step 6 — You Can Also Verify in AWS Console

Go to:

**IAM → Roles → `aws-hybrid-iac-lab-GitHubActions` → Trust relationships**

You should see:

```json
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
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

---

## Why Were You Confused?

Because there are **three separate things**:

### ① Local JSON File

```
github-actions-trust-policy.json
```

This is just a file on your computer.

⬇️

### ② IAM Role Trust Policy

```text
aws-hybrid-iac-lab-GitHubActions
    └── Trust relationships
```

This is the policy AWS actually uses to decide:

> "Is GitHub allowed to assume this role?"

⬇️

### ③ IAM Permissions Policy

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

This answers a different question:

> "After GitHub assumes the role, what AWS actions can it perform?"

So:

```text
github-actions-trust-policy.json
            │
            │ update-assume-role-policy
            ▼
IAM ROLE TRUST POLICY
            │
            │ allows GitHub OIDC
            ▼
GitHub Actions
            │
            │ assumes role
            ▼
aws-hybrid-iac-lab-GitHubActionsPolicy
            │
            ▼
AWS resources
```

---

## ⚠️ Don't Change `terraform.yml` Again

Your diagnostic already proved this:

```text
GitHub OIDC Diagnostic
        ↓
SUCCESS
        ↓
aud = sts.amazonaws.com
        ↓
sub = repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main
```

So your `terraform.yml` OIDC configuration is working.

The problem was:

```text
GitHub token SUB
        ≠
AWS IAM trusted SUB
```

We're fixing exactly that.

---

## After Step 4, Run This Verification

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

**If you see the new `sub` value, stop there and trigger your GitHub Actions workflow again.** You should then see `Configure AWS Credentials` succeed and `Verify AWS Identity` run.

---

# Part 5 — Further Diagnostics If Access Is Still Denied

## 1. Verify the AWS OIDC Provider

Run this exactly:

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
```

You should see something similar to:

```json
{
    "Url": "token.actions.githubusercontent.com",
    "ClientIDList": [
        "sts.amazonaws.com"
    ],
    ...
}
```

### The Critical Part

Make sure this exists:

```
"sts.amazonaws.com"
```

If it does not, we found the problem.

---

## 2. Verify the Actual Role ARN

Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text
```

It must return:

```
arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 3. Verify the GitHub OIDC Customization

Run:

```powershell
gh api `
  repos/awsrmmustansarjavaid/aws-hybrid-iac-lab/actions/oidc/customization/sub
```

Please show me the complete output.

We want to confirm that GitHub is configured consistently with the token we're seeing.

---

## 4. Very Useful Test: Temporarily Broaden ONLY the `sub`

Your exact trust policy should work. But let's perform a controlled test to determine whether AWS is somehow rejecting the exact subject condition.

Create this test policy:

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
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:*"
        }
      }
    }
  ]
}
'@ | Set-Content -Path ".\github-actions-trust-test.json"
```

Then apply it:

```powershell
aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document "file://github-actions-trust-test.json"
```

Then verify:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json
```

Then run GitHub Actions again.

This test is safe in the sense that it is still restricted to your exact repository immutable IDs; we're only removing the branch restriction temporarily.

If GitHub succeeds after this change, we know the problem is specifically the branch portion of the condition.

If it still fails, then the problem is somewhere else — most likely the OIDC provider configuration or the role ARN being supplied to GitHub.

---

## 5. Don't Change These Things Yet

Do not:

- recreate the IAM role
- recreate the OIDC provider
- change `AWS_REGION`
- change `AWS_ROLE_ARN`
- attach the IAM role to `github-ci-cd-user`
- run `aws iam put-user-policy ...`
- change `id-token: write`
- change Terraform

Your workflow has already proven:

```text
GitHub OIDC Diagnostic
        ↓
OIDC token successfully generated
        ↓
aud = sts.amazonaws.com
        ↓
sub = correct immutable repository subject
        ↓
AWS STS AssumeRoleWithWebIdentity
        ↓
❌ Access denied
```

So we're now narrowing down AWS's OIDC provider/role evaluation, not GitHub's ability to generate the token.

### Please Run These 3 Commands First

```powershell
aws iam get-open-id-connect-provider `
  --open-id-connect-provider-arn "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
```

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.Arn" `
  --output text
```

```powershell
gh api `
  repos/awsrmmustansarjavaid/aws-hybrid-iac-lab/actions/oidc/customization/sub
```

---

# Part 6 — Deeper Investigation: Permissions Boundaries and CloudTrail

## Step 1 — Check the Role Details

Run this:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --output json
```

Look for these fields:

```
RoleName
Arn
AssumeRolePolicyDocument
PermissionsBoundary
MaxSessionDuration
```

Especially tell me whether you have:

```
"PermissionsBoundary"
```

or whether it is absent.

## Step 2 — Check Attached Policies

Run:

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"
```

Then:

```powershell
aws iam list-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"
```

This will tell us whether your `aws-hybrid-iac-lab-GitHubActionsPolicy` is attached and whether there are any inline policies.

## Step 3 — Check Whether the Role Has a Permissions Boundary

Run:

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.PermissionsBoundary" `
  --output json
```

If it returns:

```
null
```

that's fine.

## Step 4 — Check the IAM User's Effective Identity

Your local AWS CLI is using:

```
arn:aws:iam::537236558357:user/github-ci-cd-user
```

Run:

```powershell
aws sts get-caller-identity
```

Then:

```powershell
aws iam get-user `
  --user-name "github-ci-cd-user" `
  --output json
```

We're checking whether that user has a permissions boundary or unusual restrictions.

---

## But There Is Another Important Possibility

Your GitHub repository has this configuration:

```json
{
  "use_default": true,
  "use_immutable_subject": false,
  "sub_claim_prefix": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207"
}
```

Yet GitHub is producing:

```
repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:ref:refs/heads/main
```

That's internally consistent.

So I don't want you changing GitHub OIDC customization again.

---

## One More Test I Want You to Perform

We can test whether AWS itself can evaluate the trust relationship using an AWS CloudTrail event.

Run:

```powershell
aws cloudtrail lookup-events `
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity `
  --max-results 10 `
  --output json
```

If there are events, look for the most recent one.

This can give us significantly more information about the rejected STS request.

---

## ⚠️ Don't Restore the Exact Trust Policy Yet

Leave your current test policy:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid@242676971/aws-hybrid-iac-lab@1357303207:*"
}
```

for the moment.

It is still restricted to your specific GitHub repository's immutable IDs, so it's a reasonable diagnostic policy.

Once we identify the actual problem, we'll put the final least-privilege trust policy back.

---

## Please Send Me the Output of These 5 Commands

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "{Arn:Role.Arn,PermissionsBoundary:Role.PermissionsBoundary}" `
  --output json
```

```powershell
aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"
```

```powershell
aws iam list-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"
```

```powershell
aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.PermissionsBoundary" `
  --output json
```

```powershell
aws cloudtrail lookup-events `
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity `
  --max-results 10 `
  --output json
```

The CloudTrail result is particularly important. If AWS recorded the failed `AssumeRoleWithWebIdentity` request, it may tell us exactly which AWS-side condition is causing the denial.
