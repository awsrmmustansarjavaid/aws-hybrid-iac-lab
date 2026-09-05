
# GitHub Configuration

What you need to do

Go to your GitHub repository:

```
Settings → Secrets and variables → Actions → Variables
```

Create this Repository variable:

```
Name	Value
AWS_REGION	us-east-1
```

Then go to:

```
Settings → Secrets and variables → Actions → Secrets
```

Make sure you have:

```
Name	Value
AWS_ROLE_ARN	arn:aws:iam::<YOUR_ACCOUNT_ID>:role/<YOUR_ROLE_NAME>
```

For example:

```
AWS_ROLE_ARN
arn:aws:iam::123456789012:role/GitHubActionsRole
```

## an IAM Role for GitHub Actions OIDC

# IAM Role and OIDC Setup for `aws-hybrid-iac-lab-GitHubActions`

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

you need an AWS IAM role that GitHub Actions can assume using OIDC.

Your proposed role name is good:

```
aws-hybrid-iac-lab-GitHubActions
```

I would use exactly that name.

---

## 1. IAM Role Name

Create:

```
aws-hybrid-iac-lab-GitHubActions
```

The resulting ARN will look like:

```
arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions
```

For example:

```
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

You will put this complete ARN into your GitHub repository secret:

```
AWS_ROLE_ARN
```

---

## 2. Why This IAM Role Is Required

Your GitHub Actions runner needs permission to execute AWS operations.

The architecture is:

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

You do not need AWS access keys such as:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

for this setup.

GitHub obtains a temporary OIDC token and AWS gives the workflow temporary credentials after the IAM role trust policy is satisfied.

---

## 3. First: Create the GitHub OIDC Provider

Before creating the role, your AWS account needs the GitHub Actions OIDC identity provider.

In AWS IAM, check:

```
IAM → Identity providers
```

You should have:

```
Provider type:
OpenID Connect

Provider URL:
https://token.actions.githubusercontent.com
```

If it already exists, do not create another one.

The audience should be:

```
sts.amazonaws.com
```

---

## 4. IAM Role Trust Policy

This is the most important part.

The role needs a trust relationship allowing GitHub Actions to assume it.

Because your repository is:

```
awsrmmustansarjavaid/aws-hybrid-iac-lab
```

and your deployment branch is:

```
main
```

I recommend restricting the role specifically to this repository and branch.

Use this trust policy:

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
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Replace:

```
<YOUR_AWS_ACCOUNT_ID>
```

with your real AWS account ID.

For example:

```
arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

---

## 5. Why Restrict the Trust Policy?

Don't simply allow:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*
```

if you only want the `main` branch deploying infrastructure.

The more restrictive configuration is:

```
repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
```

This means:

```text
GitHub
  │
  └── awsrmmustansarjavaid/aws-hybrid-iac-lab
          │
          └── main
               │
               ▼
       Can assume AWS role
```

Other repositories and other branches cannot use this role through this trust relationship.

---

## 6. What Permissions Should the Role Have?

This is where we need to consider your actual lab.

Your Terraform workflow isn't merely reading AWS.

It does:

```
terraform init
terraform validate
terraform plan
terraform apply
```

And your Terraform/CloudFormation architecture involves AWS infrastructure.

Therefore, the GitHub Actions role needs permissions sufficient to create/update the resources managed by your Terraform configuration and CloudFormation stacks.

> **Important:** I do not recommend blindly giving the role:
>
> ```json
> "Action": "*",
> "Resource": "*"
> ```
>
> even though that would make the workflow easier. That's essentially an administrator-level deployment role.

For a learning lab, we can start with a controlled deployment policy and tighten it as your Terraform resources become known.

---

## 7. Recommended IAM Policy Name

Create an IAM customer-managed policy named:

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

Attach this policy to:

```
aws-hybrid-iac-lab-GitHubActions
```

So your structure becomes:

```text
IAM Role
└── aws-hybrid-iac-lab-GitHubActions
       │
       └── Policy
           └── aws-hybrid-iac-lab-GitHubActionsPolicy
```

---

## 8. Recommended Starting Policy

Because your lab uses Terraform + CloudFormation and you are deploying infrastructure, a practical starting policy is:

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

### An Important Security Warning

This is a broad lab/deployment policy.

It is **not least-privilege**.

In particular:

```
iam:*
```

is extremely powerful.

It may allow the workflow to create, modify, or delete IAM resources.

For your hybrid Terraform + CloudFormation learning lab, this can be appropriate if you understand that the GitHub repository effectively has significant control over your AWS account.

For a production environment, I would not recommend this policy as-is.

---

## 9. Why `iam:*` May Be Necessary in Your Lab

Your architecture includes CloudFormation-created IAM resources.

For example, your Terraform workflow may create a CloudFormation execution role.

Therefore the deployment chain can look like:

```text
GitHub Actions
       │
       ▼
GitHubActions IAM Role
       │
       ▼
Terraform
       │
       ▼
CloudFormation
       │
       ├── IAM Role
       ├── IAM Policy
       ├── S3
       ├── EC2
       ├── VPC
       └── other resources
```

Creating IAM roles from Terraform/CloudFormation requires IAM permissions.

---

## 10. Very Important: IAM PassRole

There's another permission that frequently causes Terraform/CloudFormation deployments to fail.

When one AWS service needs to use an IAM role, the deployment role often needs:

```
"iam:PassRole"
```

For example:

```json
{
  "Sid": "AllowPassingRequiredRoles",
  "Effect": "Allow",
  "Action": [
    "iam:PassRole"
  ],
  "Resource": "*"
}
```

However, ideally this should be restricted to only the roles that your infrastructure is allowed to pass.

For example:

```
arn:aws:iam::<ACCOUNT_ID>:role/aws-hybrid-iac-lab-*
```

Once we know all the IAM roles in your Terraform/CloudFormation templates, we can tighten this.

---

## 11. Better Structure for Your Lab

I recommend separating the permissions logically.

Your policy can eventually look like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFormation",
      "Effect": "Allow",
      "Action": [
        "cloudformation:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2AndNetworking",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECR",
      "Effect": "Allow",
      "Action": [
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKS",
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": "*"
    },
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

This is already better conceptually than simply:

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

But your actual least-privilege policy should ultimately be generated from the resources/actions your Terraform and CloudFormation templates use.

---

## 12. GitHub Repository Configuration

After creating the IAM role, you'll have something like:

```
Role name:
aws-hybrid-iac-lab-GitHubActions
```

and:

```
Role ARN:
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

Go to:

```
GitHub → aws-hybrid-iac-lab → Settings → Secrets and variables → Actions
```

### Repository Variable

Create:

```
Name:
AWS_REGION

Value:
us-east-1
```

### Repository Secret

Create:

```
Name:
AWS_ROLE_ARN

Value:
arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions
```

---

## 13. Your Terraform Workflow

Your current code is already correct:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ vars.AWS_REGION }}
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

Don't change that.

---

## 14. Your Main Workflow

Your current:

```yaml
terraform:
  uses: ./.github/workflows/terraform.yml
  secrets: inherit
```

is also correct for passing the secret into the reusable workflow.

Your architecture is:

```text
main-deploy.yaml
       │
       ▼
terraform.yml
       │
       ├── AWS_REGION
       │      ↓
       │   Repository Variable
       │
       └── AWS_ROLE_ARN
              ↓
          Repository Secret
              │
              ▼
      GitHub Actions OIDC
              │
              ▼
aws-hybrid-iac-lab-GitHubActions
              │
              ▼
          Terraform
              │
              ▼
       CloudFormation
```

---

## 15. Why Your Previous Run Failed

Your previous error was:

```
Error: Input required and not supplied: aws-region
```

Your workflow contained:

```yaml
aws-region: ${{ vars.AWS_REGION }}
```

but GitHub apparently returned an empty value.

So:

```text
vars.AWS_REGION
       │
       ▼
    EMPTY
       │
       ▼
aws-region = EMPTY
       │
       ▼
configure-aws-credentials
       │
       ▼
       ERROR
```

Once you create:

```
AWS_REGION = us-east-1
```

the next stage becomes:

```text
vars.AWS_REGION
       │
       ▼
  us-east-1
       │
       ▼
aws-region: us-east-1
       │
       ▼
configure-aws-credentials
```

Then AWS authentication will proceed to the next possible failure point, if any.

---

## 16. Final IAM Setup I Recommend

For your current AWS Hybrid IaC Lab, use these names consistently:

**IAM OIDC Provider**

```
token.actions.githubusercontent.com
```

**IAM Role**

```
aws-hybrid-iac-lab-GitHubActions
```

**IAM Policy**

```
aws-hybrid-iac-lab-GitHubActionsPolicy
```

**GitHub Repository Variable**

```
AWS_REGION

Value:
us-east-1
```

**GitHub Repository Secret**

```
AWS_ROLE_ARN

Value:
arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/aws-hybrid-iac-lab-GitHubActions
```

**Authentication Flow**

```text
GitHub Actions
      ↓
OIDC
      ↓
AWS IAM
      ↓
aws-hybrid-iac-lab-GitHubActions
      ↓
Temporary AWS credentials
      ↓
Terraform
      ↓
CloudFormation
      ↓
AWS infrastructure
```

---

## Note on Refining This Setup

One thing I would change from my earlier answer: don't create a huge `iam:*`/service-wide policy permanently just because it makes the lab work. Since you have the actual Terraform and CloudFormation files, the best next step is to derive the exact IAM policy for your lab and restrict `iam:PassRole` and other sensitive permissions to your `aws-hybrid-iac-lab-*` resources wherever AWS supports resource-level restrictions. That will give you a much cleaner portfolio-grade GitHub OIDC setup.

----



