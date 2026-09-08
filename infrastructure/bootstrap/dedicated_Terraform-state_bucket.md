# dedicated Terraform state bucket

Create a persistent S3 backend for Terraform state, then import the resources that already exist into that state.

This will prevent GitHub Actions from starting with an empty state on every run.

Step 1 — Create a dedicated Terraform state bucket

Do not use your CloudFormation template bucket for Terraform state.

Use a separate bucket.

Run this in PowerShell:

```
$ACCOUNT_ID = "123456789"
$REGION = "us-east-1"
$STATE_BUCKET = "aws-hybrid-iac-lab-terraform-state-$ACCOUNT_ID"
```

```
aws s3api create-bucket `
  --bucket $STATE_BUCKET `
  --region $REGION
```

Because you're using us-east-1, do not add --create-bucket-configuration.

You should get something similar to:

```
Location
--------
/aws-hybrid-iac-lab-terraform-state-123456789
```

Step 2 — Enable versioning

Run:

```
aws s3api put-bucket-versioning `
  --bucket $STATE_BUCKET `
  --versioning-configuration Status=Enabled
```

Verify:

```
aws s3api get-bucket-versioning `
  --bucket $STATE_BUCKET
```

Expected:

```
{
    "Status": "Enabled"
}
```

Step 3 — Enable encryption

Run:

```
aws s3api put-bucket-encryption `
  --bucket $STATE_BUCKET `
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

Step 4 — Block public access

Run:

```
aws s3api put-public-access-block `
  --bucket $STATE_BUCKET `
  --public-access-block-configuration `
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Your Terraform state bucket will now have:

```
Versioning:       Enabled
Encryption:       AES256
Public access:    Completely blocked
```

Step 5 — Add the Terraform backend

Open:

```
infrastructure\terraform
```

Create a new file:

```
backend.tf
```

Put this inside:

```
terraform {
  backend "s3" {
    bucket       = "aws-hybrid-iac-lab-terraform-state-123456789"
    key          = "aws-hybrid-iac-lab/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Important

This bucket is only for Terraform state.

Your existing bucket:

```
hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638
```

continues to store:

```
main.yaml
nested/vpc.yaml
nested/s3.yaml
nested/dynamodb.yaml
nested/ecr.yaml
...

```
So the architecture becomes:

                    GitHub Actions
                          |
                          | OIDC
                          v
                 GitHubActions IAM Role
                          |
                          v
                     Terraform
                    /          \
                   /            \
                  v              v
        Terraform State       AWS Resources
              S3                   |
                                   |
                          CloudFormation
                                   |
                         CloudFormation Templates
                                   |
                                   v
                         CFN Template S3 Bucket
```

Step 6 — Reinitialize Terraform

After creating backend.tf, run:

```
terraform -chdir="infrastructure/terraform" init
```

Terraform should detect the new S3 backend.

You should see something similar to:

```
Initializing the backend...
```

Successfully configured the backend "s3"!

Then run:

```
terraform -chdir="infrastructure/terraform" validate
```

Expected:

```
Success! The configuration is valid.
```

Step 7 — Import the existing IAM role

Because the role already exists in AWS, we need to tell Terraform:

```
"This AWS role belongs to aws_iam_role.cloudformation_execution."
```

Run:

```
terraform -chdir="infrastructure/terraform" import `
  aws_iam_role.cloudformation_execution `
  "HybridIaCLab-dev-CloudFormationExecutionRole"
```

Expected:

```
Import successful!
```

Step 8 — Import the existing inline IAM policy

Run:

```
terraform -chdir="infrastructure/terraform" import `
  aws_iam_role_policy.cloudformation_lab_permissions `
  "HybridIaCLab-dev-CloudFormationExecutionRole:HybridIaCLab-dev-CloudFormationPermissions"
```

Expected:

```
Import successful!
```

Step 9 — Import the existing S3 bucket

Run:

```
terraform -chdir="infrastructure/terraform" import `
  aws_s3_bucket.cloudformation_templates `
  "hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638"
```

Step 10 — Import S3 configuration

Your Terraform configuration has separate resources for:

```
aws_s3_bucket_versioning.cloudformation_templates
aws_s3_bucket_public_access_block.cloudformation_templates
aws_s3_bucket_server_side_encryption_configuration.cloudformation_templates
```

Import them individually.

Versioning

```
terraform -chdir="infrastructure/terraform" import `
  aws_s3_bucket_versioning.cloudformation_templates `
  "hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638"
```

Public access block

```
terraform -chdir="infrastructure/terraform" import `
  aws_s3_bucket_public_access_block.cloudformation_templates `
  "hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638"
```

Encryption

```
terraform -chdir="infrastructure/terraform" import `
  aws_s3_bucket_server_side_encryption_configuration.cloudformation_templates `
  "hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638"
```

Step 11 — Import the existing template objects

This part is important.

Your previous GitHub Actions run successfully uploaded these objects:

```
main.yaml
nested/vpc.yaml
nested/s3.yaml
nested/dynamodb.yaml
nested/ecr.yaml
nested/ec2.yaml
nested/ecs.yaml
nested/eks.yaml
nested/rds.yaml
nested/lambda.yaml
nested/api-gateway.yaml
nested/cloudfront.yaml
```

Your Terraform configuration already has resources for those objects.

Before I give you the exact import commands, I want to avoid guessing the Terraform resource names in your template_objects.tf.

So stop here for a moment.

Run:

```
Get-Content ".\infrastructure\terraform\template_objects.tf"
```

and paste the complete output here.

Then I can give you the exact import commands for every existing S3 object, matching your actual Terraform resource names.

Do NOT run these yet

Do not run:

```
terraform apply
```

and do not delete:

```
HybridIaCLab-dev-CloudFormationExecutionRole
```

or:

```
hybridiaclab-dev-cfn-templates-235c07a804ed70725b36022638
```

We're going to bring the existing AWS resources under Terraform management instead.

Your current situation is actually good

You haven't lost anything. The first GitHub Actions run created the AWS resources, but because there was no persistent Terraform state, the next run didn't know they existed.

Once we establish the S3 backend + imports, Terraform will have a persistent record and future GitHub Actions runs should behave correctly.

---
for your GitHub Actions + Terraform lab, I strongly recommend a dedicated Terraform state bucket. In your case, it is not just a nice-to-have: GitHub-hosted runners are temporary, so persistent remote state is essential if you want your pipeline to work reliably.

But there is one important architectural correction:

Do not have Terraform create the bucket that Terraform itself needs as its backend.

Terraform must access its backend before Terraform can manage resources. Therefore, the state bucket should be bootstrapped separately (manually once, or with a small separate bootstrap stack/project), and then your main Terraform project uses it permanently.

You should not put aws_s3_bucket for the state bucket inside your existing infrastructure/terraform configuration.


Your permanent architecture

```
aws-hybrid-iac-lab/
│
├── infrastructure/
│   │
│   ├── terraform/
│   │   ├── backend.tf              ← USES state bucket
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── iam.tf
│   │   ├── cloudformation.tf
│   │   ├── template_bucket.tf
│   │   ├── template_objects.tf
│   │   └── ...
│   │
│   ├── cloudformation/
│   │   ├── main.yaml
│   │   └── nested/
│   │
│   └── bootstrap/
│       └── terraform-state/        ← optional separate bootstrap Terraform
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── .github/
    └── workflows/
        └── terraform.yml
```

The important distinction is:

```
Bootstrap Terraform
        ↓
creates Terraform State S3 bucket
        ↓
Main Terraform
        ↓
uses that bucket as backend
        ↓
manages your actual lab
```

Do you need state-bucket.tf in the main Terraform?

No.

I would not create this:

```
infrastructure/terraform/state-bucket.tf
```

containing:

```
resource "aws_s3_bucket" "terraform_state" {
   ...
}
```

because that creates a circular dependency:

```
Terraform needs backend
        ↓
Backend needs S3 bucket
        ↓
S3 bucket is managed by same Terraform
        ↓
Terraform cannot initialize
```

Instead, make the state bucket a bootstrap resource.

What I recommend for your lab

Since your goal is to learn a professional hybrid IaC architecture, use:

One-time bootstrap

```
infrastructure/bootstrap/terraform-state/
```

Permanent main infrastructure

```
infrastructure/terraform/
```

GitHub Actions

```
.github/workflows/terraform.yml
```

Your workflow does not create the state bucket every time.

It simply uses the already-existing backend.
---