# Terraform IAM Resource Adoption & State Import Configuration

### AWS Hybrid IaC Lab — Terraform IAM Resource Import & State Reconciliation

Yes. **Do not delete any existing AWS resources.** Your error is not caused by `data.tf`. Your `data.tf` is fundamentally fine, and the AMI lookup is unrelated to the IAM `409 EntityAlreadyExists` failures.

What happened is very specific:

> AWS already contains these IAM resources, but the Terraform state being used by the GitHub Actions run does not contain them.

So Terraform thinks:

```text
Terraform State
    |
    |-- OIDC Provider: missing
    |-- GitHubActionsPolicy: missing
    |-- terraform-backend-policy: missing
    |-- combined-access-policy: missing
    |-- CloudFormation role: missing
```

while AWS has:

```text
AWS IAM
    |
    |-- OIDC Provider: EXISTS
    |-- GitHubActionsPolicy: EXISTS
    |-- terraform-backend-policy: EXISTS
    |-- combined-access-policy: EXISTS
    |-- CloudFormation role: EXISTS
```

Terraform therefore tries to create them and AWS correctly says:

```text
409 EntityAlreadyExists
```

### The professional solution

**Import the existing resources into Terraform state.**

Do **not** rename them.
Do **not** delete them.
Do **not** recreate them.
Do **not** add `count`/`for_each` tricks to conditionally create them.

I would also **not make a large modification to your existing `iam.tf`**.

Instead, because you want a clean professional solution, create a separate file:

```text
infrastructure/
└── terraform/
    ├── iam.tf
    ├── data.tf
    ├── variables.tf
    ├── provider.tf
    ├── backend.tf
    └── iam-imports.tf       <-- NEW
```

This separates **IAM resource definitions** from **one-time resource adoption/import instructions**.

---

# 1. First: understand exactly what failed

Your five important errors are:

### Existing OIDC provider

```text
Provider with url https://token.actions.githubusercontent.com already exists.
```

Terraform resource:

```text
aws_iam_openid_connect_provider.github_actions
```

---

### Existing GitHub Actions policy

```text
aws-hybrid-iac-lab-GitHubActionsPolicy
```

Terraform resource:

```text
aws_iam_policy.github_actions["github_actions"]
```

---

### Existing combined-access policy

```text
github-ci-cd-user-combined-access
```

Terraform resource:

```text
aws_iam_policy.github_actions["combined_access"]
```

---

### Existing Terraform backend policy

```text
github-actions-terraform-backend-policy
```

Terraform resource:

```text
aws_iam_policy.github_actions["terraform_backend"]
```

---

### Existing CloudFormation execution role

```text
HybridIaCLab-dev-CloudFormationExecutionRole
```

Terraform resource:

```text
aws_iam_role.cloudformation_execution
```

These are **five existing AWS resources that need to be adopted by Terraform state**.

---

# 2. Don't change `data.tf`

Your new:

```text
data.tf
```

is not responsible for this failure.

This:

```hcl
data "aws_ami" "amazon_linux_2023" {
```

is a **data source**.

It doesn't create an AMI.

It asks AWS:

```text
"What is the latest Amazon Linux 2023 AMI matching these conditions?"
```

That's exactly the right direction for your project.

So I would leave `data.tf` alone for now.

---

# 3. Don't make a big change to `iam.tf`

Your `iam.tf` is actually already structured around the correct Terraform model:

```text
Existing AWS resource
        |
        v
terraform import
        |
        v
Terraform state
        |
        v
Terraform manages resource
```

That comment in your own file is correct.

The problem is simply that **the imports have apparently not been performed for all of these resources in the state currently used by CI/CD**.

---

# 4. First perform a safe AWS inventory

Before creating `iam-imports.tf`, I recommend we verify exactly what currently exists.

Run these commands locally from:

```powershell
infrastructure\terraform
```

or wherever your Terraform working directory is.

### Check OIDC provider

```powershell
aws iam list-open-id-connect-providers
```

You should see something similar to:

```text
arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

---

### Check GitHub Actions policy

```powershell
aws iam list-policies `
  --scope Local `
  --query "Policies[?PolicyName=='aws-hybrid-iac-lab-GitHubActionsPolicy'].[PolicyName,Arn]" `
  --output table
```

---

### Check Terraform backend policy

```powershell
aws iam list-policies `
  --scope Local `
  --query "Policies[?PolicyName=='github-actions-terraform-backend-policy'].[PolicyName,Arn]" `
  --output table
```

---

### Check combined-access policy

```powershell
aws iam list-policies `
  --scope Local `
  --query "Policies[?PolicyName=='github-ci-cd-user-combined-access'].[PolicyName,Arn]" `
  --output table
```

---

### Check CloudFormation role

```powershell
aws iam get-role `
  --role-name HybridIaCLab-dev-CloudFormationExecutionRole
```

If these commands return the resources, **we adopt them rather than creating replacements**.

---

# 5. Check your Terraform state before doing anything

This is extremely important.

Run:

```powershell
terraform state list
```

Then specifically:

```powershell
terraform state list | Select-String "github_actions"
```

and:

```powershell
terraform state list | Select-String "cloudformation"
```

You want to determine whether these resources are:

```text
AWS exists
Terraform state exists
```

or:

```text
AWS exists
Terraform state missing
```

The second situation is what your GitHub Actions error strongly indicates.

---

# 6. I recommend creating `iam-imports.tf`

If you're using Terraform **1.5+**, we can use Terraform's native `import` blocks.

Create:

```text
infrastructure/terraform/iam-imports.tf
```

Initially, I would make it look like this:

```hcl
# ==========================================================
#
# TERRAFORM RESOURCE ADOPTION / IMPORTS
#
# Project:
#   aws-hybrid-iac-lab
#
# File:
#   infrastructure/terraform/iam-imports.tf
#
# Purpose:
#   Adopt existing AWS IAM resources into Terraform state.
#
# IMPORTANT:
#   These import blocks DO NOT create new AWS resources.
#
#   They tell Terraform:
#
#       "This existing AWS resource belongs to this
#        Terraform resource address."
#
# Existing AWS resources are therefore preserved.
#
# ==========================================================


# ==========================================================
# 1. GITHUB ACTIONS OIDC PROVIDER
# ==========================================================
#
# Existing AWS resource:
#
#   https://token.actions.githubusercontent.com
#
# Terraform resource:
#
#   aws_iam_openid_connect_provider.github_actions
#
# IMPORTANT:
#   Replace ACCOUNT_ID with your actual AWS account ID.
#
# ==========================================================

import {
  to = aws_iam_openid_connect_provider.github_actions

  id = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
}


# ==========================================================
# 2. GITHUB ACTIONS IAM POLICY
# ==========================================================
#
# Existing AWS policy:
#
#   aws-hybrid-iac-lab-GitHubActionsPolicy
#
# Terraform resource:
#
#   aws_iam_policy.github_actions["github_actions"]
#
# ==========================================================

import {
  to = aws_iam_policy.github_actions["github_actions"]

  id = "arn:aws:iam::ACCOUNT_ID:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
}


# ==========================================================
# 3. TERRAFORM BACKEND POLICY
# ==========================================================
#
# Existing AWS policy:
#
#   github-actions-terraform-backend-policy
#
# ==========================================================

import {
  to = aws_iam_policy.github_actions["terraform_backend"]

  id = "arn:aws:iam::ACCOUNT_ID:policy/github-actions-terraform-backend-policy"
}


# ==========================================================
# 4. COMBINED ACCESS POLICY
# ==========================================================
#
# Existing AWS policy:
#
#   github-ci-cd-user-combined-access
#
# ==========================================================

import {
  to = aws_iam_policy.github_actions["combined_access"]

  id = "arn:aws:iam::ACCOUNT_ID:policy/github-ci-cd-user-combined-access"
}


# ==========================================================
# 5. CLOUDFORMATION EXECUTION ROLE
# ==========================================================
#
# Existing AWS role:
#
#   HybridIaCLab-dev-CloudFormationExecutionRole
#
# Terraform resource:
#
#   aws_iam_role.cloudformation_execution
#
# ==========================================================

import {
  to = aws_iam_role.cloudformation_execution

  id = "HybridIaCLab-dev-CloudFormationExecutionRole"
}
```

### But DON'T commit this yet.

First we should verify your actual account ID and current Terraform state.

---

# 7. Why this is better than modifying `iam.tf`

Your architecture becomes:

```text
                    GitHub
                      |
                      v
              Terraform configuration
                      |
          +-----------+-----------+
          |                       |
       iam.tf                iam-imports.tf
          |                       |
          |                 resource adoption
          |                       |
          +-----------+-----------+
                      |
                      v
               Terraform State
                      |
                      v
                   AWS IAM
```

`iam.tf` says:

> "This is what the infrastructure should look like."

`iam-imports.tf` says:

> "These particular resources already exist; associate them with these Terraform addresses."

That is a clean separation.

---

# 8. Important: the import is NOT deleting anything

This is the part I especially want you to understand.

Suppose AWS currently has:

```text
aws-hybrid-iac-lab-GitHubActionsPolicy
```

Terraform import does **not** do this:

```text
AWS policy
   |
   X DELETE
   |
   X RECREATE
```

Instead:

```text
Existing AWS policy
        |
        | import
        v
Terraform state
        |
        v
Terraform knows:
"This resource already exists."
```

The physical AWS policy stays where it is.

---

# 9. But there is one more important issue

Your CloudFormation execution role has:

```hcl
resource "aws_iam_role_policy" "cloudformation_lab_permissions"
```

That's an **inline IAM policy**.

The role already exists.

It is possible that its inline policy also already exists.

Your workflow stopped when this happened:

```text
aws_iam_role.cloudformation_execution: Creating...
```

because the role creation failed.

Terraform therefore didn't get far enough to tell us whether the inline policy is also already present.

We should check.

Run:

```powershell
aws iam list-role-policies `
  --role-name HybridIaCLab-dev-CloudFormationExecutionRole
```

You may get something like:

```text
HybridIaCLab-dev-CloudFormationPermissions
```

If it exists, **we should import that too** rather than allowing Terraform to attempt to create it.

The import address would be:

```text
aws_iam_role_policy.cloudformation_lab_permissions
```

and the import ID is:

```text
HybridIaCLab-dev-CloudFormationExecutionRole:HybridIaCLab-dev-CloudFormationPermissions
```

But **don't add this import until we confirm the inline policy actually exists**.

---

# 10. There may also be an existing user-policy attachment

You have:

```hcl
resource "aws_iam_user_policy_attachment" "combined_access"
```

for:

```text
github-ci-cd-user
```

and:

```text
github-ci-cd-user-combined-access
```

You said in your comments that this attachment already exists.

Therefore we should also check it.

Run:

```powershell
aws iam list-attached-user-policies `
  --user-name github-ci-cd-user
```

Look for:

```text
github-ci-cd-user-combined-access
```

If it exists, that resource should also be imported into Terraform state.

This is important because otherwise the next Terraform run could eventually encounter another:

```text
EntityAlreadyExists
```

or attachment/state conflict.

---

# 11. Check the GitHub Actions role too

Your `iam.tf` says:

```hcl
resource "aws_iam_role" "github_actions" {
```

with:

```hcl
name = "aws-hybrid-iac-lab-GitHubActions"
```

Your comments claim:

> this role has already been imported into Terraform state.

Let's verify rather than trusting the comment.

Run:

```powershell
terraform state show aws_iam_role.github_actions
```

If Terraform returns the resource, good.

Then:

```powershell
aws iam get-role `
  --role-name aws-hybrid-iac-lab-GitHubActions
```

Both should point to the same existing role.

---

# 12. Your real problem may be Terraform state

This is the most important thing I want you to investigate before changing more files.

Your workflow is called:

```text
Terraform Infrastructure Deployment
```

and you're presumably using an S3 backend.

If your local Terraform state and GitHub Actions Terraform state are not the same state, you can get exactly this situation.

For example:

```text
LOCAL MACHINE

Terraform state
     |
     +--> IAM resources imported
```

but:

```text
GITHUB ACTIONS

Terraform state
     |
     +--> IAM resources NOT imported
```

Then GitHub Actions says:

```text
AWS:
"I already have it."

Terraform:
"I don't know about it."

Result:
409 EntityAlreadyExists
```

So **before we import anything**, verify that your CI workflow is using the same backend.

---

# 13. Check your Terraform backend

Run locally:

```powershell
terraform init
```

Then:

```powershell
terraform state list
```

If your state is in S3, check the backend configuration.

For example, you may have something conceptually like:

```hcl
terraform {
  backend "s3" {
    bucket = "..."
    key    = "..."
    region = "..."
  }
}
```

The GitHub Actions workflow must initialize Terraform against the **same backend bucket/key/region**.

Otherwise you can import resources locally and GitHub Actions will still think they don't exist.

---

# 14. Professional workflow I recommend

Don't do this:

```text
Change IAM
     ↓
Push GitHub
     ↓
Hope
     ↓
Terraform fails
     ↓
Change more IAM
     ↓
Push again
```

Instead:

```text
                 AWS
                  |
                  v
          Inventory existing
             IAM resources
                  |
                  v
       Verify Terraform backend
                  |
                  v
       Verify Terraform state
                  |
                  v
        Create iam-imports.tf
                  |
                  v
          terraform plan
                  |
                  v
       Review import operations
                  |
                  v
         Terraform apply
                  |
                  v
          terraform state
                  |
                  v
      Terraform plan again
                  |
                  v
             NO DRIFT
                  |
                  v
          Commit to GitHub
                  |
                  v
       GitHub Actions succeeds
```

That's the professional migration/adoption workflow.

---

# 15. One thing I would NOT do

I would **not** solve this with something like:

```hcl
count = ...
```

or:

```hcl
for_each = ...
```

to conditionally create IAM resources.

For example, don't try to build:

```text
if exists in AWS
    don't create
else
    create
```

Terraform isn't designed to use AWS existence as an ad-hoc conditional resource creation mechanism.

The correct model is:

```text
Existing AWS resource
        ↓
Terraform import
        ↓
Terraform state
        ↓
Terraform manages it
```

Exactly as your own `iam.tf` comments already describe.

---

# 16. One additional improvement to your IAM architecture

You currently have:

```hcl
resource "aws_iam_policy" "github_actions" {
    for_each = {
        github_actions = {...}
        terraform_backend = {...}
        combined_access = {...}
    }
}
```

That's perfectly reasonable.

Your import addresses must therefore match the actual Terraform addresses:

```text
aws_iam_policy.github_actions["github_actions"]

aws_iam_policy.github_actions["terraform_backend"]

aws_iam_policy.github_actions["combined_access"]
```

This is why the import file is useful.

For example:

```hcl
import {
  to = aws_iam_policy.github_actions["terraform_backend"]

  id = "arn:aws:iam::ACCOUNT_ID:policy/github-actions-terraform-backend-policy"
}
```

Terraform will understand:

```text
AWS policy
    |
    v
github-actions-terraform-backend-policy
    |
    v
aws_iam_policy.github_actions["terraform_backend"]
```

No duplicate policy.

---

# 17. About the `Node 20` message

This:

```text
Node 20 is being deprecated.
This workflow is running with Node 24 by default.
```

is **not the reason your Terraform deployment failed**.

Your actual failure is:

```text
Error: creating IAM OIDC Provider
409 EntityAlreadyExists
```

and:

```text
Error: creating IAM Policy
409 EntityAlreadyExists
```

and:

```text
Error: creating IAM Role
409 EntityAlreadyExists
```

So don't start changing your GitHub Actions Node configuration right now.

That's a separate maintenance warning.

---

# 18. Your `data.tf` is a separate concern

Your new architecture is actually moving in a good direction:

### Before

```text
EC2
 |
 +--> ami-xxxxxxxxxxxx
```

Hard-coded.

### Now

```text
Terraform
    |
    v
aws_ami.amazon_linux_2023
    |
    v
AWS EC2 AMI search
    |
    v
Latest matching AL2023 AMI
```

Then your EC2 CloudFormation template can receive the dynamically discovered AMI through Terraform.

That's a good architecture.

The current IAM error is simply happening during the same Terraform deployment.

---

# 19. What I recommend you do RIGHT NOW

Don't modify anything else yet.

Run these **six checks** and give me the output:

### A. Terraform state

```powershell
terraform state list
```

### B. OIDC provider

```powershell
aws iam list-open-id-connect-providers
```

### C. CloudFormation inline policies

```powershell
aws iam list-role-policies `
  --role-name HybridIaCLab-dev-CloudFormationExecutionRole
```

### D. GitHub Actions role

```powershell
aws iam get-role `
  --role-name aws-hybrid-iac-lab-GitHubActions
```

### E. GitHub Actions user attachments

```powershell
aws iam list-attached-user-policies `
  --user-name github-ci-cd-user
```

### F. IAM policy ARNs

```powershell
aws iam list-policies `
  --scope Local `
  --query "Policies[?PolicyName=='aws-hybrid-iac-lab-GitHubActionsPolicy' || PolicyName=='github-actions-terraform-backend-policy' || PolicyName=='github-ci-cd-user-combined-access'].[PolicyName,Arn]" `
  --output table
```

**Don't delete anything. Don't recreate anything. Don't change `iam.tf` yet.**

Once you give me those six outputs, I can map the **exact existing AWS resources → exact Terraform addresses** and give you the final `iam-imports.tf` with the correct import blocks, including whether we need to import the CloudFormation inline policy and the `github-ci-cd-user` attachment.

That is the safest path because we're **adopting what already exists**, not rebuilding your IAM infrastructure.
---
