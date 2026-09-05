# AWS Hybrid IaC Lab — GitHub Actions OIDC & IAM Setup

## 1. GitHub Repository Configuration

Go to your GitHub repository:

```
Settings → Secrets and variables → Actions → Variables
```

Create this repository **variable**:

| Name | Value |
|---|---|
| `AWS_REGION` | `us-east-1` |

Then go to:

```
Settings → Secrets and variables → Actions → Secrets
```

Create this repository **secret**:

| Name | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::<YOUR_ACCOUNT_ID>:role/<YOUR_ROLE_NAME>` |

Example:

```
AWS_ROLE_ARN = arn:aws:iam::123456789012:role/GitHubActionsRole
```

---

## 2. IAM Role and OIDC Setup for `aws-hybrid-iac-lab-GitHubActions`

Because your workflow uses:

```yaml
id-token: write
```

and:

```yaml
uses: aws-actions/configure-aws-credentials@v4
with:
  aws-region: ${{ vars.AWS_REGION }}
  role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

you need an AWS IAM role that GitHub Actions can assume via OIDC.

**Role name:**

```
aws-hybrid-iac-lab-GitHubActions
```

**Resulting ARN:**

```
arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions
```

Example:

```
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

Put this full ARN into the `AWS_ROLE_ARN` GitHub secret.

---

## 3. Why This IAM Role Is Required

Your GitHub Actions runner needs permission to execute AWS operations. The architecture is:

```text
GitHub Actions
      │
      │ OIDC Token
      ▼
AWS IAM OIDC Provider
      │
      │ AssumeRoleWithWebIdentity
      ▼
aws-hybrid-iac-lab-GitHubActions
      │
      │ IAM Permissions
      ▼
AWS Services
      │
      ├── S3
      ├── CloudFormation
      ├── IAM
      ├── EC2
      ├── VPC
      ├── ECR
      ├── EKS
      └── other services
```

You do **not** need long-lived AWS access keys (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) for this setup. GitHub obtains a temporary OIDC token, and AWS issues temporary credentials once the role's trust policy is satisfied.

---

## 4. Create the GitHub OIDC Provider (if not already present)

In AWS IAM, check:

```
IAM → Identity providers
```

You should have one with:

```
Provider type: OpenID Connect
Provider URL:  https://token.actions.githubusercontent.com
Audience:      sts.amazonaws.com
```

If it already exists, do not create a duplicate.

---

## 5. IAM Role Trust Policy

This is the most important part — it controls **who** can assume the role.

Your repository is `awsrmmustansarjavaid/aws-hybrid-iac-lab`, deploying from the `main` branch, so the trust policy should be scoped specifically to that repo + branch:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOIDCTrust",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Replace `<YOUR_AWS_ACCOUNT_ID>` with your real AWS account ID.

### Why restrict it this way?

Avoid a wildcard trust like:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*
```

if only the `main` branch should be able to deploy infrastructure. The scoped version:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

means only that repo, on that branch, can assume the role — no other repos or branches can use it through this trust relationship. This matches AWS/GitHub's documented recommendation to restrict on the `sub` claim rather than trusting an entire GitHub org or all repos.

---

## 6. What Permissions Should the Role Have?

Your Terraform workflow does more than read AWS — it runs:

```
terraform init
terraform validate
terraform plan
terraform apply
```

...against a Terraform + CloudFormation architecture, so the role needs permissions to create/update whatever resources your templates manage.

> **Important:** Don't just grant `"Action": "*", "Resource": "*"` — even though it's the path of least resistance, that's effectively an administrator-level deployment role.

For a learning lab, start with a controlled deployment policy and tighten it once your actual Terraform resource types are known.

### Recommended IAM policy name

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

Attach it to the role:

```text
IAM Role
└── aws-hybrid-iac-lab-GitHubActions
       └── Policy
           └── aws-hybrid-iac-lab-GitHubActionsPolicy
```

### Starting policy (broad, lab-appropriate — not least-privilege)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformAndCloudFormationDeployment",
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ec2:*",
        "s3:*",
        "iam:*",
        "ecr:*",
        "eks:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "logs:*",
        "ssm:*",
        "secretsmanager:*",
        "kms:*",
        "lambda:*",
        "apigateway:*",
        "dynamodb:*",
        "rds:*",
        "ecs:*",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

**Security warning:** This is broad and **not** least-privilege. In particular, `iam:*` is extremely powerful — it can let the workflow create, modify, or delete IAM resources. For a hybrid Terraform + CloudFormation learning lab this may be acceptable if you understand the GitHub repo effectively has significant control over the AWS account. **Do not use this as-is in production.**

### Why `iam:*` may be needed in this lab

If your Terraform/CloudFormation templates create IAM resources (e.g., a CloudFormation execution role), the chain looks like:

```text
GitHub Actions
       ▼
GitHubActions IAM Role
       ▼
Terraform
       ▼
CloudFormation
       ├── IAM Role
       ├── IAM Policy
       ├── S3
       ├── EC2
       ├── VPC
       └── other resources
```

Creating IAM roles/policies from Terraform or CloudFormation requires IAM permissions to do so.

### `iam:PassRole`

A frequent cause of failed Terraform/CloudFormation deployments: when one AWS service needs to use an IAM role, the deployment role often needs:

```json
{
  "Sid": "AllowPassingRequiredRoles",
  "Effect": "Allow",
  "Action": ["iam:PassRole"],
  "Resource": "*"
}
```

Ideally, restrict this to only the roles your infrastructure should be allowed to pass, e.g.:

```
arn:aws:iam::<ACCOUNT_ID>:role/aws-hybrid-iac-lab-*
```

Tighten this once all IAM roles referenced by your Terraform/CloudFormation templates are known.

### A more structured version of the same policy

Once you're ready to move past one giant `Action: *` statement per service, split it by concern:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "CloudFormation", "Effect": "Allow", "Action": ["cloudformation:*"], "Resource": "*" },
    { "Sid": "S3", "Effect": "Allow", "Action": ["s3:*"], "Resource": "*" },
    { "Sid": "EC2AndNetworking", "Effect": "Allow", "Action": ["ec2:*"], "Resource": "*" },
    { "Sid": "ECR", "Effect": "Allow", "Action": ["ecr:*"], "Resource": "*" },
    { "Sid": "EKS", "Effect": "Allow", "Action": ["eks:*"], "Resource": "*" },
    {
      "Sid": "IAM",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

This is already an improvement over one blanket `"Action": "*"` statement, but your real least-privilege policy should ultimately be derived from the exact resources/actions your Terraform and CloudFormation templates use.

---

## 7. GitHub Repository Configuration (Recap)

Once the role exists:

```
Role name: aws-hybrid-iac-lab-GitHubActions
Role ARN:  arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

Go to:

```
GitHub → aws-hybrid-iac-lab → Settings → Secrets and variables → Actions
```

**Repository variable**

```
Name:  AWS_REGION
Value: us-east-1
```

**Repository secret**

```
Name:  AWS_ROLE_ARN
Value: arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 8. Your Workflow Files (Already Correct — No Changes Needed)

Terraform job step:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ vars.AWS_REGION }}
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

Main workflow calling the reusable Terraform workflow:

```yaml
terraform:
  uses: ./.github/workflows/terraform.yml
  secrets: inherit
```

Full flow:

```text
main-deploy.yaml
       ▼
terraform.yml
       ├── AWS_REGION   → Repository Variable
       └── AWS_ROLE_ARN → Repository Secret
              ▼
      GitHub Actions OIDC
              ▼
aws-hybrid-iac-lab-GitHubActions
              ▼
          Terraform
              ▼
       CloudFormation
```

---

## 9. Why Your Previous Run Failed

Error:

```
Error: Input required and not supplied: aws-region
```

Your workflow had:

```yaml
aws-region: ${{ vars.AWS_REGION }}
```

but `vars.AWS_REGION` was empty because the repository variable didn't exist yet:

```text
vars.AWS_REGION → EMPTY → aws-region = EMPTY → configure-aws-credentials → ERROR
```

Once you create `AWS_REGION = us-east-1` as a repository variable, this resolves and the workflow proceeds to the next possible failure point (if any):

```text
vars.AWS_REGION → us-east-1 → aws-region: us-east-1 → configure-aws-credentials → OK
```

---

## 10. Final IAM Setup Summary

| Item | Value |
|---|---|
| OIDC Provider | `token.actions.githubusercontent.com` |
| IAM Role | `aws-hybrid-iac-lab-GitHubActions` |
| IAM Policy | `aws-hybrid-iac-lab-GitHubActionsPolicy` |
| GitHub Repo Variable | `AWS_REGION = us-east-1` |
| GitHub Repo Secret | `AWS_ROLE_ARN = arn:aws:iam::<ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions` |

Authentication flow:

```text
GitHub Actions → OIDC → AWS IAM → aws-hybrid-iac-lab-GitHubActions
→ Temporary AWS credentials → Terraform → CloudFormation → AWS infrastructure
```

**Note on refining this setup:** don't leave a permanent, service-wide `iam:*` policy in place just because it makes the lab work. Once you have the actual Terraform/CloudFormation files, derive the exact IAM policy the lab needs and restrict `iam:PassRole` (and other sensitive permissions) to your `aws-hybrid-iac-lab-*` resources wherever AWS supports resource-level restrictions.

---

## 11. Managing the Trust Policy: A Separate Admin User

You'll sometimes need to update the role's **trust policy** (e.g., to change the allowed repo/branch) from your local machine. Don't do this with a broad admin identity — create a narrowly-scoped IAM user and policy for it instead.

### 11.1 Create the policy

**IAM Policy name:** `github-ci-cd-user-iam-role-management`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageGitHubActionsRoleTrustPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": "arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions"
    }
  ]
}
```

This grants only:

- Reading role information (`iam:GetRole`)
- Updating **only this role's** trust policy (`iam:UpdateAssumeRolePolicy`)

It does **not** grant unrestricted IAM permissions. `UpdateAssumeRolePolicy` is specifically the API used to modify a role's trust policy.

> **Note on formatting:** if you're pasting JSON into the AWS IAM console editor, use plain characters — `iam:GetRole`, not `iam\:GetRole`. Backslash-escaped colons/underscores are just markdown-escaping artifacts from copy-pasting; they aren't valid in the actual JSON.

### 11.2 Create it as a file (PowerShell)

```powershell
@'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageGitHubActionsRoleTrustPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": "arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions"
    }
  ]
}
'@ | Set-Content -Path ".\github-ci-cd-user-iam-role-management.json"

Get-Content .\github-ci-cd-user-iam-role-management.json
```

### 11.3 Create it as a managed policy and attach it to the user

Create it as an **IAM Policy** in the console (`IAM → Policies → Create policy`), name it `github-ci-cd-user-iam-role-management`, then attach the managed policy to the user:

```
IAM → Users → github-ci-cd-user → Permissions → Add permissions → Attach policies directly
→ github-ci-cd-user-iam-role-management
```

> If you instead try to add this as an **inline** policy on the user, you may hit: `Your policy exceeds the non-whitespace character limit of 2048`. That's an inline-policy size limit for the user — attach it as a managed policy instead, not inline.

### 11.4 Verify

```bash
aws iam list-user-policies --user-name "github-ci-cd-user"
aws iam get-user-policy --user-name "github-ci-cd-user" --policy-name "ManageGitHubActionsRoleTrustPolicy"
```

(If attached as a managed policy rather than inline, use `list-attached-user-policies` instead of `list-user-policies`.)

### 11.5 Test the permission

```bash
aws iam get-role --role-name "aws-hybrid-iac-lab-GitHubActions" --query "Role.Arn" --output text
```

Expected:

```
arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions
```

Then updating the trust policy should now be allowed:

```bash
aws iam update-assume-role-policy \
  --role-name "aws-hybrid-iac-lab-GitHubActions" \
  --policy-document "file://github-actions-trust-policy.json"
```

### 11.6 Don't loosen the trust policy afterward

Keep the trust policy scoped to the exact repo + branch (as in Section 5) — don't change the `sub` condition to a wildcard and leave it that way. Restricting the `sub` claim is AWS/GitHub's recommended practice over trusting an entire org or all repos.

---

## 12. Two Separate IAM Identities — Don't Mix Them Up

You should end up with **two distinct IAM identities**, each with its own purpose:

```text
AWS ACCOUNT
│
├── IAM USER: github-ci-cd-user
│   └── Managed Policy: github-ci-cd-user-iam-role-management
│       Allows: iam:GetRole, iam:UpdateAssumeRolePolicy
│       Resource: aws-hybrid-iac-lab-GitHubActions
│
└── IAM ROLE: aws-hybrid-iac-lab-GitHubActions
    ├── Trust policy → GitHub Actions OIDC (Section 5)
    └── Permissions policies → Terraform/AWS resource permissions (Section 6)
```

| Resource | Type | Purpose |
|---|---|---|
| `github-ci-cd-user` | IAM User | Administrative user you use locally to manage the GitHub Actions role's trust policy |
| `github-ci-cd-user-iam-role-management` | IAM **Policy** (not a role) | Grants `github-ci-cd-user` permission to read/update the trust policy of `aws-hybrid-iac-lab-GitHubActions` only |
| `aws-hybrid-iac-lab-GitHubActions` | IAM Role | Assumed by GitHub Actions via OIDC at runtime; holds the Terraform/CloudFormation deployment permissions |

**Rules to keep them separate:**

- `github-ci-cd-user-iam-role-management` is a **policy**, attached to the **user** `github-ci-cd-user` — not a role, and not attached to `aws-hybrid-iac-lab-GitHubActions`.
- `aws-hybrid-iac-lab-GitHubActions` should **not** need `github-ci-cd-user-iam-role-management` — you generally don't want the GitHub Actions workflow itself modifying its own trust policy.
- If you find `github-ci-cd-user-iam-role-management` attached to the role, remove it from there.

If you share the Permissions tabs of `github-ci-cd-user` and `aws-hybrid-iac-lab-GitHubActions`, the full arrangement can be reviewed and corrected precisely.
