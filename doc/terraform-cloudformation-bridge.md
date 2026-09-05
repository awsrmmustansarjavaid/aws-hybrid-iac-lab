## Terraform → CloudFormation Bridge

This part of the lab connects Terraform to CloudFormation. Terraform creates a **CloudFormation root stack**, and that root stack creates nested CloudFormation stacks (VPC, S3, DynamoDB, ECR).

### Architecture

```
Terraform
   │
   │ creates
   ▼
CloudFormation Root Stack
   │
   ├──► VPC Nested Stack
   ├──► S3 Nested Stack
   ├──► DynamoDB Nested Stack
   └──► ECR Nested Stack
```

This demonstrates a hybrid IaC approach:

- **Terraform** manages overall deployment/orchestration.
- **CloudFormation** manages AWS resources inside its own stack hierarchy.

---

### `infrastructure/terraform/cloudformation.tf`

Creates the main CloudFormation stack, pointing it at the root template (`main.yaml`) uploaded to S3, passing in parameters, and assigning an execution role.

```hcl
resource "aws_cloudformation_stack" "main" {
  name = "${local.name_prefix}-MainStack"

  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM"
  ]

  parameters = {
    ProjectName    = var.project_name
    Environment    = var.environment
    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket
    TemplatePrefix = ""
  }

  role_arn = aws_iam_role.cloudformation_execution.arn

  depends_on = [
    aws_s3_object.cloudformation_templates,
    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}
```

> ⚠️ `depends_on` must reference the **actual** resource names used elsewhere in your Terraform files (`aws_s3_object.cloudformation_templates`, `aws_iam_role_policy.cloudformation_lab_permissions`). Mismatched names will fail validation.

**Deployment flow:**

```
GitHub
  │
  ▼
Terraform
  │
  ├──► S3 Template Bucket
  └──► IAM Execution Role
         │
         ▼
   CloudFormation Main Stack
         │
         ├──► VPC
         ├──► S3
         ├──► DynamoDB
         └──► ECR
```

Terraform doesn't create VPC/S3/DynamoDB/ECR directly — it creates the CloudFormation stack, which reads `main.yaml`, which creates the nested stacks, which create the AWS resources:

```
Terraform → CloudFormation → Nested CloudFormation → AWS Services
```

---

### `outputs.tf`

Exposes key values after deployment for verification, debugging, and CI/CD.

```hcl
output "cloudformation_template_bucket" {
  description = "S3 bucket containing CloudFormation templates"
  value       = aws_s3_bucket.cloudformation_templates.bucket
}

output "cloudformation_stack_name" {
  description = "Main CloudFormation stack"
  value       = aws_cloudformation_stack.main.name
}

output "cloudformation_execution_role_arn" {
  description = "CloudFormation execution role ARN"
  value       = aws_iam_role.cloudformation_execution.arn
}
```

After `terraform apply`:

```
Outputs:

cloudformation_execution_role_arn = "arn:aws:iam::123456789012:role/..."
cloudformation_stack_name         = "HybridIaCLab-dev-MainStack"
cloudformation_template_bucket    = "hybrid-iaclab-dev-..."
```

Retrieve outputs later:

```bash
terraform output
terraform output cloudformation_stack_name
terraform output -raw cloudformation_stack_name
```

---

### `terraform.tfvars`

Provides actual values for variables declared in `variables.tf`.

```hcl
aws_region   = "us-east-1"
project_name = "HybridIaCLab"
environment  = "dev"
```

**Value flow:**

```
terraform.tfvars
  ├── aws_region
  ├── project_name
  └── environment
         │
         ▼
   variables.tf
         │
         ▼
    Terraform
         │
         ▼
CloudFormation Stack
         │
         ▼
  Nested CFN Stacks
  ├── VPC
  ├── S3
  ├── DynamoDB
  └── ECR
```

Example resource naming produced from these values:

```
HybridIaCLab-dev-MainStack
HybridIaCLab-dev-Orders
HybridIaCLab-dev-app
HybridIaCLab-dev-VpcId
```

> ⚠️ `terraform.tfvars` can be committed for a learning lab **if it only contains non-sensitive values** like these. Never store AWS access keys, passwords, or other secrets in this file.
