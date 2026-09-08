# 50+ PowerShell & AWS CLI Commands Every Cloud Engineer and DevOps Engineer Should Know

## A Practical Command-Line Guide for AWS, Terraform, CloudFormation, IAM, GitHub Actions, Docker, ECR, ECS and Kubernetes

Cloud engineering is not only about clicking through the AWS Console.

As you work on real-world AWS projects, you quickly discover that the command line becomes one of your most important tools for troubleshooting, automation, infrastructure deployment, security verification, and CI/CD.

During my AWS Hybrid IaC Lab, I collected a practical set of PowerShell, AWS CLI, Terraform, GitHub CLI, and verification commands that helped me investigate infrastructure problems and understand what was actually happening behind the scenes.

This article organizes those commands by **technology, job responsibility, and practical task** so they can be useful as a reference for Cloud Engineers, DevOps Engineers, Platform Engineers, and AWS learners.

> **Important:** These commands are examples from an AWS/Terraform hybrid infrastructure workflow. Replace account IDs, repository names, resource names, paths, and other environment-specific values with your own values.

---

# 1. PowerShell — Your Windows Cloud Engineering Terminal

PowerShell is extremely useful when working with AWS CLI, Terraform, Git, GitHub CLI, Docker, and automation scripts on Windows.

## Task: Find Your Current Directory

### Command

```powershell
Get-Location
```

### What does it do?

Displays the current working directory.

### When should you use it?

Use it whenever you are unsure where PowerShell is currently operating.

This is especially useful before running:

- Terraform commands
- Git commands
- PowerShell scripts
- AWS CLI commands
- file-management commands

---

## Task: Change to Your Project Directory

```powershell
cd "C:\Users\YourUser\Downloads\AWS-Labs\aws-hybrid-iac-lab"
```

### Why is this important?

Terraform works with configuration files in the current working directory unless you explicitly specify another directory.

A common beginner problem is running:

```powershell
terraform plan
```

from the wrong folder and receiving:

```text
No Terraform configuration files
```

Therefore, checking your location first is a simple but powerful troubleshooting habit.

---

# 2. PowerShell File Discovery

## Task: List Files

```powershell
Get-ChildItem
```

This displays files and directories in the current location.

### Useful for

- Finding Terraform files
- Finding scripts
- Checking project structure
- Verifying configuration files

---

## Find Terraform Files

```powershell
Get-ChildItem -Filter "*.tf"
```

This shows Terraform configuration files in the current directory.

Typical files might include:

```text
main.tf
provider.tf
variables.tf
iam.tf
outputs.tf
cloudformation.tf
template_bucket.tf
```

---

## Find Terraform Files Recursively

```powershell
Get-ChildItem -Path . -Filter "*.tf" -Recurse |
    Select-Object FullName
```

### When should you use this?

Use it when you know Terraform files exist somewhere in your project but you don't know exactly where.

This is particularly useful for diagnosing:

```text
No Terraform configuration files
```

---

# 3. Searching Configuration Files with Select-String

One of the most useful PowerShell commands for Cloud Engineers is:

```powershell
Select-String
```

It allows you to search configuration files for specific text.

For example:

```powershell
Get-ChildItem ".\infrastructure\terraform" -Filter "*.tf" |
    Select-String -Pattern "backend"
```

### What does it do?

Searches Terraform files for the word:

```text
backend
```

### Why is this useful?

You can quickly locate:

- Terraform backend configuration
- IAM actions
- resource names
- variables
- S3 references
- DynamoDB references
- old configuration
- deprecated parameters

---

## Search the Infrastructure Directory

```powershell
Get-ChildItem ".\infrastructure" -Recurse -File |
    Select-String -Pattern "terraform.tfstate|backend|dynamodb|s3"
```

This is useful when troubleshooting Terraform state and backend configuration.

---

# 4. Terraform — Infrastructure as Code

Terraform is one of the most important tools in a modern Cloud/DevOps workflow.

## Check Terraform Version

```powershell
terraform version
```

### Why use it?

Before troubleshooting Terraform, verify:

- Terraform is installed
- Terraform is available in PATH
- the expected version is being used

---

# 5. Terraform Formatting

```powershell
terraform fmt
```

### Purpose

Automatically formats Terraform files according to Terraform's standard formatting.

### When to use it?

Use it:

- before committing Terraform code
- before creating a pull request
- after editing `.tf` files
- before running validation

---

## Check Formatting Without Changing Files

```powershell
terraform fmt -check -recursive
```

This is particularly useful in CI/CD pipelines because it checks formatting without modifying files.

A verification script in the project uses this approach as part of its Terraform checks.

---

# 6. Terraform Validation

```powershell
terraform validate
```

### Purpose

Checks whether the Terraform configuration is syntactically and structurally valid.

A successful result looks like:

```text
Success! The configuration is valid.
```

### Important distinction

`terraform validate` does **not** mean your infrastructure is ready to deploy.

It mainly verifies the Terraform configuration.

---

# 7. Terraform Plan — The Most Important Safety Check

```powershell
terraform plan
```

### What does it do?

Terraform compares:

```text
Terraform configuration
        ↓
Terraform state
        ↓
Actual infrastructure
```

and determines what changes would be made.

Typical output:

```text
Plan: 0 to add, 5 to change, 0 to destroy
```

### When should you use it?

Before:

```powershell
terraform apply
```

Always inspect the plan carefully.

For example, in the lab workflow, `terraform plan` was used to verify whether an IAM role would be recreated after importing an existing AWS resource.

---

# 8. Terraform State

Terraform state is critical because it records what Terraform believes it manages.

## List Managed Resources

```powershell
terraform state list
```

### Example

```text
aws_iam_role.cloudformation_execution
aws_s3_bucket.cloudformation_templates
aws_cloudformation_stack.main
```

### When should you use it?

Use this when troubleshooting:

- missing resources
- duplicate resources
- imports
- state migration
- unexpected Terraform plans

---

## Filter State Resources

```powershell
terraform state list | Select-String "iam"
```

This is an excellent way to focus on IAM-related resources.

The lab used this technique to verify IAM resources managed by Terraform.

---

# 9. Terraform State Show

```powershell
terraform state show aws_cloudformation_stack.main
```

### Purpose

Displays the detailed state information for a specific Terraform resource.

### When to use it?

After:

```powershell
terraform import
```

to verify what Terraform actually imported.

---

# 10. Terraform Import

Sometimes an AWS resource already exists but Terraform does not know about it.

Instead of recreating it, you can import it.

Example:

```powershell
terraform import aws_cloudformation_stack.main hybridiaclab-dev-MainStack
```

### Concept

```text
Existing AWS resource
        ↓
terraform import
        ↓
Terraform state
```

This is especially important when adopting existing infrastructure into Infrastructure as Code.

The lab workflow explicitly used CloudFormation stack import to prevent Terraform from attempting to create an already-existing stack.

---

# 11. Terraform with a Specific Directory

Instead of changing directories, you can use:

```powershell
terraform -chdir="infrastructure/terraform" plan
```

Similarly:

```powershell
terraform -chdir="infrastructure/terraform" state list
```

and:

```powershell
terraform -chdir="infrastructure/terraform" validate
```

### Why is this useful?

It allows automation scripts and CI/CD pipelines to execute Terraform against a specific directory.

---

# 12. Terraform Backend Investigation

Terraform commonly stores state remotely using services such as:

- Amazon S3
- DynamoDB for state locking in older/common patterns

Check Terraform backend configuration:

```powershell
Get-ChildItem ".\infrastructure\terraform" -Filter "*.tf" |
    Select-String -Pattern "backend"
```

Check S3 buckets:

```powershell
aws s3api list-buckets `
    --query "Buckets[].Name" `
    --output table
```

Check DynamoDB tables:

```powershell
aws dynamodb list-tables --output table
```

These commands help determine whether the expected Terraform state infrastructure exists.

---

# 13. AWS CLI — Your AWS Investigation Tool

AWS CLI allows engineers to interact directly with AWS services without relying entirely on the AWS Console.

This becomes especially important for:

- automation
- troubleshooting
- CI/CD
- scripting
- auditing
- infrastructure verification

---

# 14. Check AWS Identity

```powershell
aws sts get-caller-identity
```

### What does it tell you?

It identifies the AWS account and identity currently being used.

This should be one of the **first commands you run when troubleshooting AWS CLI permissions**.

---

## More Detailed Identity Output

```powershell
aws sts get-caller-identity `
    --query "{Account:Account,Arn:Arn,UserId:UserId}" `
    --output table
```

### Why is this important?

You may think you're using one IAM user or role while your terminal is actually authenticated as another.

Always verify the identity before debugging permissions.

---

# 15. IAM — Investigating Permissions

IAM troubleshooting is one of the most important skills for Cloud and DevOps Engineers.

## List Policies Attached to a User

```powershell
aws iam list-attached-user-policies `
    --user-name "github-ci-cd-user" `
    --output table
```

### Purpose

Shows managed policies attached to the IAM user.

---

## List Inline Policies

```powershell
aws iam list-user-policies `
    --user-name "github-ci-cd-user" `
    --output table
```

### Why is this important?

Managed policies and inline policies are different.

If you only inspect attached managed policies, you can miss permissions defined through inline policies.

---

# 16. Display IAM Policy Names and ARNs

```powershell
aws iam list-attached-user-policies `
    --user-name "github-ci-cd-user" `
    --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" `
    --output table
```

This provides a cleaner view of:

```text
PolicyName
PolicyArn
```

---

# 17. List Customer-Managed IAM Policies

```powershell
aws iam list-policies `
    --scope Local `
    --query "Policies[].{PolicyName:PolicyName,PolicyArn:Arn}" `
    --output table
```

### What does `--scope Local` mean?

It limits the result to customer-managed policies in your AWS account.

---

# 18. Find Which IAM Entities Use a Policy

```powershell
aws iam list-entities-for-policy `
    --policy-arn "arn:aws:iam::ACCOUNT_ID:policy/POLICY_NAME" `
    --output table
```

This can help identify whether a policy is attached to:

- users
- groups
- roles

---

# 19. Inspect an IAM Role

```powershell
aws iam get-role `
    --role-name "HybridIaCLab-dev-CloudFormationExecutionRole"
```

### Use case

Use this to verify that a role exists and inspect its configuration.

---

# 20. Inspect an Inline Role Policy

```powershell
aws iam get-role-policy `
    --role-name "HybridIaCLab-dev-CloudFormationExecutionRole" `
    --policy-name "HybridIaCLab-dev-CloudFormationPermissions"
```

### When should you use it?

Use it when an AWS operation fails even though you believe the role has the required permission.

For example:

```text
iam:PassRole
```

can be particularly important when CloudFormation needs to use another IAM role.

The lab used this command to inspect the CloudFormation execution role and its inline permissions.

---

# 21. CloudFormation — Stack Investigation

CloudFormation is commonly used to create and manage AWS infrastructure.

## Check a Stack

```powershell
aws cloudformation describe-stacks `
    --stack-name "hybridiaclab-dev-MainStack" `
    --region us-east-1 `
    --query "Stacks[0].{StackName:StackName,Status:StackStatus,RoleARN:RoleARN}" `
    --output table
```

### Why use it?

It helps determine whether a stack is:

```text
CREATE_COMPLETE
UPDATE_COMPLETE
ROLLBACK_COMPLETE
DELETE_COMPLETE
```

or another state.

---

# 22. CloudFormation + Terraform Hybrid Infrastructure

When Terraform manages a CloudFormation stack, you may need to inspect both systems:

```text
Terraform
   ↓
CloudFormation Stack
   ↓
Nested CloudFormation Stacks
   ↓
AWS Resources
```

The lab architecture separates infrastructure bootstrap from later Docker/ECS deployment. The verification workflow checks that ECS is not unnecessarily created during the bootstrap phase while ECR remains part of the infrastructure layer.

---

# 23. S3 — Bucket Discovery

```powershell
aws s3api list-buckets `
    --query "Buckets[].Name" `
    --output table
```

### Use cases

Useful for finding:

- Terraform state buckets
- CloudFormation template buckets
- application buckets
- deployment buckets

---

# 24. Check Whether an S3 Bucket Exists

```powershell
aws s3api head-bucket `
    --bucket "YOUR_BUCKET_NAME" `
    --region us-east-1
```

### Why use it?

Useful when Terraform or another service reports that a bucket does not exist.

---

# 25. Check S3 Versioning

```powershell
aws s3api get-bucket-versioning `
    --bucket "YOUR_BUCKET_NAME"
```

### Why?

Versioning can be important for:

- Terraform state protection
- CloudFormation templates
- application artifacts
- recovery from accidental overwrites

---

# 26. Check S3 Public Access Block

```powershell
aws s3api get-public-access-block `
    --bucket "YOUR_BUCKET_NAME"
```

### Use case

Security verification.

It helps determine whether public-access blocking is configured on the bucket.

---

# 27. EC2 — Discover VPCs

```powershell
aws ec2 describe-vpcs `
    --region us-east-1 `
    --query "Vpcs[].{VpcId:VpcId,Name:Tags[?Key=='Name']|[0].Value}" `
    --output table
```

### Why use it?

Useful when multiple VPCs exist and you need to identify the VPC associated with your application.

---

# 28. EC2 — Discover Subnets

```powershell
aws ec2 describe-subnets `
    --region us-east-1 `
    --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,PublicIp:MapPublicIpOnLaunch,Name:Tags[?Key=='Name']|[0].Value}" `
    --output table
```

### Useful information

This command helps identify:

- subnet ID
- VPC ID
- Availability Zone
- public IP behavior
- subnet Name tag

This is particularly useful when building or troubleshooting multi-AZ infrastructure.

---

# 29. Amazon Linux 2023 AMI Discovery

Instead of hard-coding an AMI ID, you can query the AWS Systems Manager public parameter:

```powershell
aws ssm get-parameter `
    --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
    --query "Parameter.Value" `
    --output text `
    --region us-east-1
```

### Why is this useful?

AMI IDs differ between AWS regions and can change over time.

Using the public SSM parameter helps retrieve the current Amazon Linux 2023 AMI for the selected region.

---

# 30. Lambda — List Functions

```powershell
aws lambda list-functions `
    --region us-east-1 `
    --query "Functions[].{Name:FunctionName,Arn:FunctionArn}" `
    --output table
```

### Use cases

Useful for:

- Lambda discovery
- deployment verification
- troubleshooting
- inventory
- CI/CD validation

---

# 31. ECR — List Repositories

```powershell
aws ecr describe-repositories `
    --region us-east-1 `
    --query "repositories[].{Repository:repositoryName,URI:repositoryUri}" `
    --output table
```

### What does it provide?

It helps identify:

- ECR repository name
- ECR repository URI

---

# 32. ECR — List Images

```powershell
aws ecr list-images `
    --repository-name YOUR_REPOSITORY_NAME `
    --region us-east-1 `
    --output table
```

### When should you use it?

After a Docker CI/CD pipeline, use this command to verify whether images were actually pushed to ECR.

---

# 33. Docker + ECR — Immutable Tags

A major lesson from the lab is the importance of immutable image tagging.

Instead of repeatedly pushing:

```text
latest
```

a CI/CD workflow can use:

```text
${GITHUB_SHA}
```

as an immutable deployment identifier.

For example:

```text
application:8a2f91c...
```

This makes deployments traceable to a specific Git commit.

The verification workflow checks that Docker uses `GITHUB_SHA` and that ECR login and image push are present.

---

# 34. GitHub Actions — OIDC Investigation

Modern GitHub Actions pipelines can authenticate to AWS using OpenID Connect rather than long-lived AWS access keys.

A repository's OIDC customization can be inspected with GitHub CLI:

```powershell
gh api `
    repos/OWNER/REPOSITORY/actions/oidc/customization/sub
```

### Why is this useful?

When GitHub Actions cannot assume an AWS IAM role, you need to investigate:

- OIDC provider
- repository
- owner
- subject (`sub`)
- trust policy
- workflow permissions
- environment configuration

---

# 35. Get GitHub Repository IDs

```powershell
gh api repos/OWNER/REPOSITORY `
    --jq '{owner_login: .owner.login, owner_id: .owner.id, repo_name: .name, repo_id: .id}'
```

### Why?

If your GitHub OIDC configuration uses immutable subjects, the owner and repository IDs can become part of the subject format.

The lab specifically investigated GitHub OIDC customization and repository IDs before changing the IAM trust policy.

---

# 36. GitHub Actions Workflow Investigation

Search workflows for AWS OIDC configuration:

```powershell
git grep -n -E "environment:|role-to-assume|id-token:"
```

### What are you looking for?

Important configuration such as:

```yaml
permissions:
  id-token: write
```

and:

```yaml
role-to-assume:
```

and:

```yaml
environment:
```

These settings can directly affect whether GitHub Actions can authenticate to AWS.

---

# 37. Search All GitHub Workflows

```powershell
Get-ChildItem .github\workflows -File |
    ForEach-Object {
        Write-Host ""
        Write-Host "========== $($_.Name) =========="
        Select-String -Path $_.FullName `
            -Pattern 'aws-actions/configure-aws-credentials|role-to-assume|aws-region|permissions:|id-token:|environment:'
    }
```

### Why is this useful?

Instead of opening every workflow manually, you can inspect important AWS authentication and deployment settings across the entire workflow directory.

---

# 38. GitHub Actions Deployment Ordering

A mature CI/CD pipeline should have logical dependencies.

For example:

```text
Terraform
    ↓
Docker
    ↓
Kubernetes
```

The lab verification script checks whether:

```text
Docker → depends on Terraform
Kubernetes → depends on Terraform + Docker
```

This prevents deployment stages from running before their dependencies are ready.

---

# 39. Kubernetes — Deployment Verification

Kubernetes becomes particularly important when your application moves from simple container deployment toward orchestration.

In a hybrid DevOps architecture:

```text
GitHub
   ↓
Terraform
   ↓
AWS infrastructure
   ↓
Docker
   ↓
ECR
   ↓
Kubernetes / EKS
```

A CI/CD workflow can therefore enforce:

```text
Infrastructure → Container Image → Kubernetes Deployment
```

This ordering is checked in the project's verification process.

---

# 40. PowerShell JSON Validation

IAM policies stored as JSON should be validated before Terraform attempts to manage them.

Example:

```powershell
Get-Content .\IAM\aws-hybrid-iac-lab-GitHubActionsPolicy.json |
    ConvertFrom-Json
```

You can perform the same validation for other policy files:

```powershell
Get-Content .\IAM\github-actions-terraform-backend-policy.json |
    ConvertFrom-Json
```

and:

```powershell
Get-Content .\IAM\github-ci-cd-user-combined-access.json |
    ConvertFrom-Json
```

### Why?

It catches JSON syntax problems before they become Terraform or IAM deployment problems.

---

# 41. PowerShell Test-Path

```powershell
Test-Path .\iam.tf
```

Returns:

```text
True
```

or:

```text
False
```

### Use case

Perfect for checking whether a required file exists.

For example:

```powershell
Test-Path ..\..\IAM\aws-hybrid-iac-lab-GitHubActionsPolicy.json
Test-Path ..\..\IAM\github-actions-terraform-backend-policy.json
Test-Path ..\..\IAM\github-ci-cd-user-combined-access.json
```

---

# 42. Resolve-Path

```powershell
Resolve-Path ..\..\IAM
```

### Purpose

Shows the absolute path of a directory.

### When useful?

When relative paths are confusing.

This is especially helpful when Terraform references files outside its working directory.

---

# 43. CloudFormation IAM PassRole Troubleshooting

One of the most important AWS permission concepts is:

```text
iam:PassRole
```

Suppose CloudFormation needs to use:

```text
CloudFormationExecutionRole
```

The identity launching CloudFormation may need permission to pass that role.

You can inspect the inline policy using:

```powershell
aws iam get-role-policy `
    --role-name "YOUR_ROLE_NAME" `
    --policy-name "YOUR_POLICY_NAME" `
    --output json
```

Then look for:

```text
iam:PassRole
```

and verify that the resource ARN points to the intended role.

This is a classic example of why AWS permissions troubleshooting requires checking both the **caller identity** and the **target role**.

---

# 44. Permissions Boundaries

When an IAM policy appears to allow an operation but AWS still denies it, check whether the role has a permissions boundary:

```powershell
aws iam get-role `
    --role-name "YOUR_ROLE_NAME" `
    --query "Role.{RoleName:RoleName,Arn:Arn,PermissionsBoundary:PermissionsBoundary,Path:Path}" `
    --output json
```

A permissions boundary can restrict the effective permissions of an IAM principal even when an attached policy contains an `Allow`.

---

# 45. Read-Only Architecture Verification

One of the strongest practices in infrastructure engineering is separating:

```text
Verification
```

from:

```text
Deployment
```

A verification script should ideally inspect the architecture without modifying AWS resources.

The lab's verification script was specifically designed as a **read-only audit tool**. It checks files, Terraform configuration, CloudFormation architecture, ECR configuration, Docker workflow, GitHub Actions ordering, Terraform formatting, and CloudFormation validation without running `terraform apply`, `terraform destroy`, or deploying containers.

---

# 46. A Practical Verification Workflow

A useful workflow is:

```text
1. Check current directory
        ↓
2. Check project files
        ↓
3. Check AWS identity
        ↓
4. Check Terraform configuration
        ↓
5. terraform fmt
        ↓
6. terraform validate
        ↓
7. Inspect Terraform state
        ↓
8. Inspect AWS resources
        ↓
9. terraform plan
        ↓
10. Review changes
        ↓
11. Apply only when safe
```

This approach is much safer than immediately running:

```powershell
terraform apply
```

---

# 47. Commands by Job Role

## Cloud Engineer

Focus on:

```text
aws sts get-caller-identity
aws ec2 describe-vpcs
aws ec2 describe-subnets
aws s3api list-buckets
aws lambda list-functions
aws ecr describe-repositories
aws cloudformation describe-stacks
```

### Main responsibility

Infrastructure discovery, troubleshooting, networking, IAM, and AWS resource management.

---

## DevOps Engineer

Focus on:

```text
terraform fmt
terraform validate
terraform plan
terraform state list
aws ecr describe-repositories
aws ecr list-images
git grep
gh api
```

### Main responsibility

Infrastructure as Code, CI/CD, containers, automation, and deployment pipelines.

---

## Platform Engineer

Focus on:

```text
Terraform
AWS CLI
GitHub Actions
ECR
ECS
EKS
IAM
CloudFormation
```

### Main responsibility

Building reusable infrastructure and deployment platforms for development teams.

---

## Security / IAM Engineer

Focus on:

```text
aws sts get-caller-identity
aws iam list-attached-user-policies
aws iam list-user-policies
aws iam get-role
aws iam get-role-policy
aws iam list-entities-for-policy
```

### Main responsibility

Identity, authorization, least privilege, trust policies, and permission troubleshooting.

---

# 48. Commands by Common Real-World Task

| Task | Useful Commands |
|---|---|
| Find current directory | `Get-Location` |
| Find Terraform files | `Get-ChildItem -Filter "*.tf"` |
| Search configuration | `Select-String` |
| Check Terraform version | `terraform version` |
| Format Terraform | `terraform fmt` |
| Validate Terraform | `terraform validate` |
| Preview infrastructure changes | `terraform plan` |
| Inspect Terraform state | `terraform state list` |
| Inspect one state resource | `terraform state show` |
| Import existing resource | `terraform import` |
| Check AWS identity | `aws sts get-caller-identity` |
| Inspect IAM policies | `aws iam ...` |
| Check CloudFormation | `aws cloudformation describe-stacks` |
| Check S3 | `aws s3api ...` |
| Check VPCs | `aws ec2 describe-vpcs` |
| Check subnets | `aws ec2 describe-subnets` |
| Check Lambda | `aws lambda list-functions` |
| Check ECR | `aws ecr describe-repositories` |
| Check ECR images | `aws ecr list-images` |
| Inspect GitHub OIDC | `gh api` |
| Search GitHub workflows | `git grep` |
| Validate JSON | `ConvertFrom-Json` |
| Verify file exists | `Test-Path` |
| Resolve absolute path | `Resolve-Path` |

---

# 49. My Recommended Troubleshooting Golden Rule

When something fails, don't immediately change the configuration.

Instead:

### 1. Identify

```powershell
aws sts get-caller-identity
```

### 2. Locate

```powershell
Get-Location
Get-ChildItem
```

### 3. Inspect

```powershell
terraform state list
aws cloudformation describe-stacks
aws iam get-role
```

### 4. Validate

```powershell
terraform fmt
terraform validate
```

### 5. Preview

```powershell
terraform plan
```

### 6. Change

Only after understanding the problem.

### 7. Verify

Run your read-only verification commands again.

This mindset can prevent accidental resource creation, deletion, or configuration drift.

---

# 50. Final Takeaway

Learning AWS is not only about memorizing AWS services.

A strong Cloud or DevOps Engineer needs to understand how to:

```text
Discover
    ↓
Inspect
    ↓
Validate
    ↓
Plan
    ↓
Deploy
    ↓
Verify
    ↓
Troubleshoot
```

PowerShell gives Windows-based engineers a powerful automation environment.

AWS CLI provides direct access to AWS services.

Terraform provides Infrastructure as Code.

CloudFormation provides AWS-native infrastructure orchestration.

IAM provides identity and authorization.

GitHub Actions provides CI/CD automation.

Docker and ECR provide containerization and image management.

ECS and Kubernetes/EKS provide container orchestration.

Together, these tools create the foundation of a modern cloud engineering workflow.

The most valuable skill is not knowing one command.

It is knowing **which command to use, why you are using it, what the output means, and what you should do next.**

---

## Quick Reference

When troubleshooting an AWS + Terraform project, start with:

```powershell
Get-Location
```

```powershell
Get-ChildItem -Filter "*.tf"
```

```powershell
aws sts get-caller-identity
```

```powershell
terraform version
```

```powershell
terraform fmt
```

```powershell
terraform validate
```

```powershell
terraform state list
```

```powershell
terraform plan
```

Then investigate the specific AWS service involved.

**Don't just run commands. Understand the infrastructure behind them.**

---
Yes. Since the **MainStack still exists**, we can investigate API Gateway directly from AWS without deleting anything.

Run this **single large PowerShell command**. It will:

* inspect `MainStack`
* find the API Gateway nested stack automatically
* show its status
* show its template URL
* show all API Gateway resources
* show failed/rollback events
* show the **exact CloudFormation failure reason**
* also inspect the root stack events related to API Gateway

```powershell
$region="us-east-1"; $main="aws-hybrid-iac-lab-dev-MainStack"; Write-Host "`n============================================================" -ForegroundColor Cyan; Write-Host "API GATEWAY NESTED STACK INVESTIGATION" -ForegroundColor Cyan; Write-Host "============================================================" -ForegroundColor Cyan; Write-Host "`n[1] MAIN STACK STATUS" -ForegroundColor Yellow; aws cloudformation describe-stacks --stack-name $main --region $region --query "Stacks[0].{StackName:StackName,Status:StackStatus,Reason:StackStatusReason,Created:CreationTime,Updated:LastUpdatedTime}" --output table; Write-Host "`n[2] SEARCHING FOR API GATEWAY NESTED STACK..." -ForegroundColor Yellow; $resources=aws cloudformation describe-stack-resources --stack-name $main --region $region --output json | ConvertFrom-Json; $api=$resources.StackResources | Where-Object { $_.LogicalResourceId -match "Api|API|Gateway|gateway" -or $_.ResourceType -eq "AWS::CloudFormation::Stack" -and $_.LogicalResourceId -match "Api|API|Gateway|gateway" }; if(-not $api){Write-Host "No API Gateway nested stack found by logical ID. Showing ALL nested stacks:" -ForegroundColor Red; $api=$resources.StackResources | Where-Object {$_.ResourceType -eq "AWS::CloudFormation::Stack"} }; $api | Select-Object LogicalResourceId,ResourceType,ResourceStatus,ResourceStatusReason,PhysicalResourceId | Format-Table -AutoSize; Write-Host "`n[3] API GATEWAY NESTED STACK IDs" -ForegroundColor Yellow; $nestedIds=$api | Where-Object {$_.ResourceType -eq "AWS::CloudFormation::Stack"} | Select-Object -ExpandProperty PhysicalResourceId; if($nestedIds){foreach($nested in $nestedIds){Write-Host "`n------------------------------------------------------------" -ForegroundColor DarkCyan; Write-Host "NESTED STACK: $nested" -ForegroundColor Cyan; Write-Host "------------------------------------------------------------"; aws cloudformation describe-stacks --stack-name $nested --region $region --query "Stacks[0].{StackName:StackName,Status:StackStatus,Reason:StackStatusReason,TemplateURL:TemplateURL,Created:CreationTime,Updated:LastUpdatedTime}" --output table; Write-Host "`nRESOURCES:" -ForegroundColor Yellow; aws cloudformation describe-stack-resources --stack-name $nested --region $region --query "StackResources[].{LogicalId:LogicalResourceId,Type:ResourceType,Status:ResourceStatus,Reason:ResourceStatusReason,PhysicalId:PhysicalResourceId}" --output table; Write-Host "`nFAILURE / ROLLBACK EVENTS:" -ForegroundColor Red; aws cloudformation describe-stack-events --stack-name $nested --region $region --query "StackEvents[?contains(ResourceStatus,'FAILED') || contains(ResourceStatus,'ROLLBACK') || contains(ResourceStatus,'CANCELLED')] | [].{Time:Timestamp,LogicalId:LogicalResourceId,Type:ResourceType,Status:ResourceStatus,Reason:ResourceStatusReason,PhysicalId:PhysicalResourceId}" --output table; Write-Host "`nALL RECENT EVENTS:" -ForegroundColor Yellow; aws cloudformation describe-stack-events --stack-name $nested --region $region --max-items 30 --query "StackEvents[].{Time:Timestamp,LogicalId:LogicalResourceId,Type:ResourceType,Status:ResourceStatus,Reason:ResourceStatusReason,PhysicalId:PhysicalResourceId}" --output table }}; Write-Host "`n[4] ROOT MAINSTACK EVENTS RELATED TO API GATEWAY" -ForegroundColor Yellow; aws cloudformation describe-stack-events --stack-name $main --region $region --query "StackEvents[?contains(LogicalResourceId,'Api') || contains(LogicalResourceId,'API') || contains(LogicalResourceId,'Gateway') || contains(ResourceType,'ApiGateway') || contains(ResourceType,'CloudFormation::Stack') && contains(ResourceStatus,'FAILED')] | [].{Time:Timestamp,LogicalId:LogicalResourceId,Type:ResourceType,Status:ResourceStatus,Reason:ResourceStatusReason,PhysicalId:PhysicalResourceId}" --output table; Write-Host "`n============================================================" -ForegroundColor Green; Write-Host "INVESTIGATION COMPLETE" -ForegroundColor Green; Write-Host "============================================================" -ForegroundColor Green
```

### What we're looking for

The most important output will look something like:

```text
NESTED STACK: arn:aws:cloudformation:...

Status
------
CREATE_FAILED

Reason
------
Template URL ... does not exist
```

or:

```text
AWS::ApiGateway::RestApi
CREATE_FAILED
AccessDenied...
```

or:

```text
AWS::CloudFormation::Stack
UPDATE_FAILED
Nested stack ... was not successfully created
```

**Paste the entire output here.** We can then determine whether API Gateway is the actual remaining failure and fix only that nested stack—without touching your working VPC, ECR, Lambda, S3, DynamoDB, EC2, CloudFront, or RDS stacks.

### First, let's find **what CloudFormation stacks currently exist**, including failed/rollback stacks and possible different names.

Run this **single PowerShell command**:

```powershell id="3c7p1a"
$region="us-east-1"; Write-Host "`n============================================================" -ForegroundColor Cyan; Write-Host "AWS CLOUDFORMATION STACK DISCOVERY" -ForegroundColor Cyan; Write-Host "============================================================" -ForegroundColor Cyan; Write-Host "`n[1] ALL CLOUDFORMATION STACKS" -ForegroundColor Yellow; aws cloudformation list-stacks --region $region --query "StackSummaries[].{Name:StackName,Status:StackStatus,Created:CreationTime,Updated:LastUpdatedTime}" --output table; Write-Host "`n[2] HYBRID IAC STACKS" -ForegroundColor Yellow; aws cloudformation list-stacks --region $region --query "StackSummaries[?contains(StackName,'hybrid') || contains(StackName,'Hybrid') || contains(StackName,'iac') || contains(StackName,'Iac')].{Name:StackName,Status:StackStatus,Created:CreationTime,Updated:LastUpdatedTime}" --output table; Write-Host "`n[3] FAILED / ROLLBACK / DELETE-FAILED STACKS" -ForegroundColor Red; aws cloudformation list-stacks --region $region --query "StackSummaries[?contains(StackStatus,'FAILED') || contains(StackStatus,'ROLLBACK') || contains(StackStatus,'DELETE_FAILED') || contains(StackStatus,'CANCEL')].{Name:StackName,Status:StackStatus,Reason:StackStatusReason,Created:CreationTime,Updated:LastUpdatedTime}" --output table; Write-Host "`n[4] API / ECS / EKS RELATED STACKS" -ForegroundColor Yellow; aws cloudformation list-stacks --region $region --query "StackSummaries[?contains(StackName,'Api') || contains(StackName,'API') || contains(StackName,'Gateway') || contains(StackName,'Ecs') || contains(StackName,'ECS') || contains(StackName,'Eks') || contains(StackName,'EKS')].{Name:StackName,Status:StackStatus,Created:CreationTime,Updated:LastUpdatedTime}" --output table; Write-Host "`n============================================================" -ForegroundColor Green; Write-Host "DISCOVERY COMPLETE" -ForegroundColor Green; Write-Host "============================================================" -ForegroundColor Green
```

### Why this is the correct next step

We now need to establish **what CloudFormation actually created**, rather than assuming the root stack name.

If the failed stack is still retained, this command should reveal something like:

```text
aws-hybrid-iac-lab-dev-xxxxx
CREATE_FAILED
```

or:

```text
aws-hybrid-iac-lab-dev-MainStack
ROLLBACK_COMPLETE
```

or potentially an API Gateway/ECS-specific stack.

**Paste the complete output.** Then we'll trace the API Gateway stack and its exact failure reason without making another blind Terraform change.

---
Run this exact command

```
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "TERRAFORM S3 TEMPLATE UPLOAD CONFIGURATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`n[1] locals.tf" -ForegroundColor Yellow

Get-Content ".\infrastructure\terraform\locals.tf" |
    Select-Object -Skip 100 -First 45

Write-Host "`n[2] template_objects.tf" -ForegroundColor Yellow

Get-Content ".\infrastructure\terraform\template_objects.tf"

Write-Host "`n[3] ALL TERRAFORM API GATEWAY REFERENCES" -ForegroundColor Yellow

Get-ChildItem ".\infrastructure\terraform" -Recurse -File -Include "*.tf" |
    Select-String -Pattern "api_gateway|api-gateway|TemplateURL|aws_s3_object|aws_s3" |
    Select-Object Path,LineNumber,Line

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "TERRAFORM UPLOAD AUDIT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
```

Next step — inspect the complete cloudformation_templates map

Run only this:

```
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "CLOUDFORMATION TEMPLATES MAP" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Get-Content ".\infrastructure\terraform\locals.tf" |
    Select-Object -Skip 35 -First 100

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "MAP INSPECTION COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
```



----
