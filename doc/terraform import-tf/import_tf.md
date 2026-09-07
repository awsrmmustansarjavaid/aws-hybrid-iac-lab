# import.tf 

Yes — your output confirms the situation very clearly.

### What we know now

1. `terraform fmt` ✅
2. `terraform validate` ✅
3. The IAM imports using the `for_each` addresses are **still failing because PowerShell is stripping the quotes inside the Terraform address**.
4. The IAM user attachment import **does reach AWS**, but Terraform aborts because your `terraform.tfvars` still contains placeholders.
5. Your IAM state is unchanged, so **none of the 7 missing IAM resources have been imported yet**.

So don't add IAM permissions yet. **We have a different problem to solve first.**

## The easiest fix: use single quotes + escaped quotes differently

PowerShell's handling of Terraform's indexed resource addresses is causing this:

```text
aws_iam_policy.github_actions[github_actions]
```

when Terraform requires:

```text
aws_iam_policy.github_actions["github_actions"]
```

Instead of fighting PowerShell quoting, use Terraform's **import block** approach. This is much cleaner for your project and avoids the PowerShell address parsing problem entirely.

### Step 1 — temporarily create `import.tf`

Inside:

```text
infrastructure\terraform
```

create:

```text
import.tf
```

Put this in it:

```hcl
# ============================================================
# EXISTING IAM RESOURCES
# ============================================================
#
# These resources already exist in AWS.
#
# These import blocks tell Terraform to adopt the existing
# AWS resources into Terraform state instead of attempting
# to create duplicate resources.
#
# IMPORTANT:
#
# These imports are a ONE-TIME state adoption operation.
#
# After the resources are successfully imported, these blocks
# can be removed from the configuration.
#
# ============================================================


# ============================================================
# 1. GitHub Actions customer-managed IAM policy
# ============================================================

import {
  to = aws_iam_policy.github_actions["github_actions"]

  id = "arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
}


# ============================================================
# 2. Terraform backend IAM policy
# ============================================================

import {
  to = aws_iam_policy.github_actions["terraform_backend"]

  id = "arn:aws:iam::537236558357:policy/github-actions-terraform-backend-policy"
}


# ============================================================
# 3. Combined CI/CD access IAM policy
# ============================================================

import {
  to = aws_iam_policy.github_actions["combined_access"]

  id = "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ============================================================
# 4. GitHub Actions role attachment
# ============================================================

import {
  to = aws_iam_role_policy_attachment.github_actions["github_actions"]

  id = "aws-hybrid-iac-lab-GitHubActions/arn:aws:iam::537236558357:policy/aws-hybrid-iac-lab-GitHubActionsPolicy"
}


# ============================================================
# 5. Terraform backend role attachment
# ============================================================

import {
  to = aws_iam_role_policy_attachment.github_actions["terraform_backend"]

  id = "aws-hybrid-iac-lab-GitHubActions/arn:aws:iam::537236558357:policy/github-actions-terraform-backend-policy"
}


# ============================================================
# 6. Combined access role attachment
# ============================================================

import {
  to = aws_iam_role_policy_attachment.github_actions["combined_access"]

  id = "aws-hybrid-iac-lab-GitHubActions/arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ============================================================
# 7. Existing IAM user policy attachment
# ============================================================

import {
  to = aws_iam_user_policy_attachment.combined_access

  id = "github-ci-cd-user/arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"
}


# ============================================================
# END OF IMPORT CONFIGURATION
# ============================================================
```

This avoids the PowerShell problem completely because the Terraform resource addresses are parsed by Terraform itself.

---

# Step 2 — BUT first fix `terraform.tfvars`

This is currently the **actual blocker**.

Your import output proves it:

```text
Invalid value for variable

vpc_id = "REPLACE_WITH_REAL_VPC_ID"
```

and the same happens for the other variables.

Terraform evaluates the entire configuration before performing the import, so even though you're importing an IAM resource, the invalid variables prevent the operation from completing.

You therefore need real values for:

```text
vpc_id
public_subnet_id
public_subnet_1_id
public_subnet_2_id
private_subnet_1_id
private_subnet_2_id
ami_id
application_bucket_name
lambda_function_arn
ecr_image_uri
database_password
```

---

# Step 3 — Find the real AWS values

Because your account/region are already known:

```text
Account: 537236558357
Region:  us-east-1
```

you can use AWS CLI.

### VPCs

```powershell
aws ec2 describe-vpcs `
  --region us-east-1 `
  --query "Vpcs[].{VpcId:VpcId,Name:Tags[?Key=='Name']|[0].Value}" `
  --output table
```

### Subnets

```powershell
aws ec2 describe-subnets `
  --region us-east-1 `
  --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,PublicIp:MapPublicIpOnLaunch,Name:Tags[?Key=='Name']|[0].Value}" `
  --output table
```

This is particularly important because we need to select the **correct six subnets belonging to your lab's VPC**, not simply any subnets in the account.

### Amazon Linux 2023 AMI

```powershell
aws ssm get-parameter `
  --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
  --query "Parameter.Value" `
  --output text `
  --region us-east-1
```

### S3 buckets

```powershell
aws s3api list-buckets `
  --query "Buckets[].Name" `
  --output table
```

You need to identify the **application bucket**, not:

```text
hybridiaclab-dev-cfn-templates-a635abe09098d12756b031e2bb
```

That one is your CloudFormation template bucket.

### Lambda functions

```powershell
aws lambda list-functions `
  --region us-east-1 `
  --query "Functions[].{Name:FunctionName,Arn:FunctionArn}" `
  --output table
```

### ECR repositories

```powershell
aws ecr describe-repositories `
  --region us-east-1 `
  --query "repositories[].{Repository:repositoryName,URI:repositoryUri}" `
  --output table
```

Then, if necessary, list images:

```powershell
aws ecr list-images `
  --repository-name YOUR_REPOSITORY_NAME `
  --region us-east-1 `
  --output table
```

---

# Step 4 — Put those values into `terraform.tfvars`

For example, after discovering the actual resources, your file will look like:

```hcl
aws_region  = "us-east-1"
project_name = "HybridIaCLab"
environment  = "dev"

vpc_id = "vpc-ACTUAL_VALUE"

public_subnet_id   = "subnet-ACTUAL_VALUE"
public_subnet_1_id = "subnet-ACTUAL_VALUE"
public_subnet_2_id = "subnet-ACTUAL_VALUE"

private_subnet_1_id = "subnet-ACTUAL_VALUE"
private_subnet_2_id = "subnet-ACTUAL_VALUE"

ami_id = "ami-ACTUAL_VALUE"

application_bucket_name = "ACTUAL-APPLICATION-BUCKET"

lambda_function_arn = "arn:aws:lambda:us-east-1:537236558357:function:ACTUAL_FUNCTION"

ecr_image_uri = "537236558357.dkr.ecr.us-east-1.amazonaws.com/ACTUAL_REPOSITORY:ACTUAL_TAG"

database_password = "ACTUAL_PASSWORD"
```

**Do not change your `variables.tf` validation.**

---

# Step 5 — Validate again

After replacing the placeholders:

```powershell
terraform fmt
```

then:

```powershell
terraform validate
```

Expected:

```text
Success! The configuration is valid.
```

---

# Step 6 — Run the imports through Terraform

Now that `terraform.tfvars` contains valid values:

```powershell
terraform plan
```

**Do not apply yet.**

Because the `import.tf` blocks exist, Terraform should recognize that the existing AWS resources need to be imported.

Then run:

```powershell
terraform apply
```

Terraform should show the import operations.

### Important

The `import.tf` file is **not creating new IAM policies**.

It is telling Terraform:

> "These objects already exist in AWS. Adopt them into Terraform state."

That is exactly what we need.

---

# Step 7 — Verify state

After the import succeeds:

```powershell
terraform state list | Select-String "iam"
```

You should see something similar to:

```text
aws_iam_openid_connect_provider.github_actions

aws_iam_policy.github_actions["github_actions"]
aws_iam_policy.github_actions["terraform_backend"]
aws_iam_policy.github_actions["combined_access"]

aws_iam_role.github_actions

aws_iam_role_policy_attachment.github_actions["github_actions"]
aws_iam_role_policy_attachment.github_actions["terraform_backend"]
aws_iam_role_policy_attachment.github_actions["combined_access"]

aws_iam_user_policy_attachment.combined_access

aws_iam_role.cloudformation_execution
aws_iam_role_policy.cloudformation_lab_permissions
```

That's the state we want.

---

# Step 8 — Remove `import.tf`

Once the import is successful, delete:

```text
import.tf
```

The important part is that the resources remain in Terraform state.

You **do not need import blocks forever**.

Your actual Terraform resources remain in:

```text
iam.tf
```

---

# Step 9 — Final plan

Run:

```powershell
terraform fmt
terraform validate
terraform plan
```

Now Terraform should **not** say:

```text
aws_iam_policy.github_actions["github_actions"] will be created
aws_iam_policy.github_actions["terraform_backend"] will be created
aws_iam_policy.github_actions["combined_access"] will be created
```

because Terraform now knows:

```text
AWS resource
     ↓
Terraform state
     ↓
iam.tf
```

---

## One more important observation

Your output:

```text
aws_iam_user_policy_attachment.combined_access: Importing...
aws_iam_user_policy_attachment.combined_access: Import prepared!
aws_iam_user_policy_attachment.combined_access: Refreshing state...
```

is actually **good evidence** that Terraform can reach AWS and that this is not simply an IAM permission problem.

The process got far enough to prepare and refresh the attachment, then Terraform stopped because of:

```text
Invalid value for variable
```

So **don't add additional IAM permissions right now**.

### Your next move

I recommend you **do not manually guess the values**.

Run these two commands first:

```powershell
aws ec2 describe-vpcs `
  --region us-east-1 `
  --query "Vpcs[].{VpcId:VpcId,Name:Tags[?Key=='Name']|[0].Value}" `
  --output table
```

and:

```powershell
aws ec2 describe-subnets `
  --region us-east-1 `
  --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,PublicIp:MapPublicIpOnLaunch,Name:Tags[?Key=='Name']|[0].Value}" `
  --output table
```

**Paste those two outputs here.** I can then tell you exactly which VPC and which six subnets should go into your `terraform.tfvars`, rather than risking putting the wrong AWS resources into the lab.
---
