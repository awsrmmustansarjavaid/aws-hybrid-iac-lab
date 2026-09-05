# Setting Up GitHub OIDC and IAM Role for AWS Hybrid IaC Lab

I'll guide you step by step in the GitHub website. You don't need to change your CloudFormation `main.yaml` for this.

You need to create two GitHub settings:

- `AWS_REGION` → Repository Variable
- `AWS_ROLE_ARN` → Repository Secret

But there is one important point: `AWS_ROLE_ARN` must point to an IAM role that exists in AWS and has GitHub OIDC trust configured.

---

## Part 1 — Find Your AWS Account ID

Open PowerShell and run:

```powershell
aws sts get-caller-identity
```

You should get:

```json
{
    "UserId": "...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/..."
}
```

Copy the value of:

```
Account
```

For example:

```
123456789012
```

Don't send me your account ID if you don't want to. You can keep it private.

---

## Part 2 — Decide Your AWS Region

Your Terraform configuration should already have your region somewhere.

For example, check:

```
infrastructure/terraform/
```

and look for something like:

```hcl
provider "aws" {
  region = var.aws_region
}
```

and possibly:

```hcl
variable "aws_region" {
  default = "us-east-1"
}
```

If your lab uses:

```
us-east-1
```

then we'll use:

```
AWS_REGION = us-east-1
```

If it uses another region, use that region instead.

---

## Part 3 — Create AWS_REGION GitHub Variable

Go to your repository:

```
GitHub → awsrmmustansarjavaid/aws-hybrid-iac-lab
```

Then:

```
Settings
   ↓
Secrets and variables
   ↓
Actions
```

You should see tabs/sections for:

- Secrets
- Variables

Select:

```
Variables
```

Then click:

```
New repository variable
```

Enter:

```
Name:
AWS_REGION

Value:
us-east-1
```

Again, replace `us-east-1` if your lab uses another region.

Then click:

```
Add variable
```

You should now have:

```
Repository variables

AWS_REGION
us-east-1
```

---

## Part 4 — Create the AWS IAM Role

This part happens in AWS, not GitHub.

You need an IAM role specifically for GitHub Actions.

A good name for your project would be:

```
GitHubActions-HybridIaCLab
```

Go to:

```
AWS Console → IAM → Roles → Create role
```

For the trusted entity, choose the option for a custom trust policy, because we want GitHub's OIDC provider.

The important trust relationship will eventually look approximately like this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
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

Replace:

```
<ACCOUNT_ID>
```

with your AWS account ID.

> **Important:** Before this can work, your AWS account needs the GitHub OIDC provider: `token.actions.githubusercontent.com`. If you haven't created that yet, don't guess the configuration — I can walk you through creating the OIDC provider and the IAM role next.

---

## Part 5 — Give the Role Permissions

After creating:

```
GitHubActions-HybridIaCLab
```

you need to attach permissions to it.

Your role needs enough permissions for what your Terraform workflow actually does.

Your Terraform workflow performs:

```text
terraform init
       ↓
terraform plan
       ↓
terraform apply
       ↓
CloudFormation
       ↓
S3
       ↓
IAM
       ↓
other AWS resources
```

So the role needs permissions corresponding to your Terraform and CloudFormation resources.

Don't blindly attach `AdministratorAccess` as the final design. It may be convenient while troubleshooting, but for your final portfolio lab I'd recommend a purpose-built deployment policy.

---

## Part 6 — Get the IAM Role ARN

Once the role exists, open:

```
AWS Console
   ↓
IAM
   ↓
Roles
   ↓
GitHubActions-HybridIaCLab
```

You'll see something similar to:

```
ARN

arn:aws:iam::123456789012:role/GitHubActions-HybridIaCLab
```

Copy the entire ARN.

It will look like:

```
arn:aws:iam::<YOUR_ACCOUNT_ID>:role/GitHubActions-HybridIaCLab
```

---

## Part 7 — Add AWS_ROLE_ARN to GitHub

Return to:

```
GitHub
   ↓
awsrmmustansarjavaid/aws-hybrid-iac-lab
   ↓
Settings
   ↓
Secrets and variables
   ↓
Actions
```

This time select:

```
Secrets
```

Click:

```
New repository secret
```

Enter:

```
Name:
AWS_ROLE_ARN
```

For the secret value, paste your actual role ARN:

```
arn:aws:iam::123456789012:role/GitHubActions-HybridIaCLab
```

Then click:

```
Add secret
```

You'll now have:

```
Repository secrets

AWS_ROLE_ARN
```

GitHub won't display the secret value afterward.

---

## Part 8 — Your Final GitHub Configuration

You should end up with:

```
Variables
AWS_REGION
    ↓
us-east-1
```

```
Secrets
AWS_ROLE_ARN
    ↓
arn:aws:iam::123456789012:role/GitHubActions-HybridIaCLab
```

And you don't need:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

for this OIDC-based workflow.

---

## Part 9 — Your `terraform.yml`

Your existing code is already using these values correctly:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ vars.AWS_REGION }}
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

Then immediately underneath it:

```yaml
- name: Verify AWS Identity
  run: |
    aws sts get-caller-identity
```

So GitHub Actions does:

```text
${{ vars.AWS_REGION }}
          ↓
      us-east-1


${{ secrets.AWS_ROLE_ARN }}
          ↓
arn:aws:iam::123456789012:role/GitHubActions-HybridIaCLab
```

Then:

```text
GitHub Actions
       │
       │ OIDC
       ▼
GitHub OIDC Provider
       │
       ▼
AWS STS
       │
       │ AssumeRoleWithWebIdentity
       ▼
GitHubActions-HybridIaCLab
       │
       ▼
aws sts get-caller-identity
       │
       ▼
Terraform
```
