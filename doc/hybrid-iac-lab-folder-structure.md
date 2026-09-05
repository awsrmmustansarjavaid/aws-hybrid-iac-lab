# 1. How many main folders?

At the root of your repository:

```text
aws-hybrid-iac-lab/
```

you have 5 main directories:

```text
aws-hybrid-iac-lab/
│
├── docker/             # 1
├── infrastructure/    # 2
├── kubernetes/         # 3
├── scripts/            # 4
└── .github/            # 5
```

Plus these root-level files:

```text
README.md
.gitignore
```

So I would create 5 main folders.

---

# 2. Folder #1 — docker/

Purpose: everything related to your Docker application.

```text
docker/
└── app/
    ├── Dockerfile
    └── app/
        └── index.html
```

There are 2 levels of subfolders here:

```text
docker/
└── app/
    └── app/
```

It looks a little confusing because both folders are called `app`.

I would actually recommend changing it to:

```text
docker/
└── app/
    ├── Dockerfile
    └── src/
        └── index.html
```

Much easier to understand:

```text
docker/app/
├── Dockerfile
└── src/
    └── index.html
```

## What goes here?

Dockerfile:

```dockerfile
FROM nginx:alpine

COPY src/index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

Your application:

```text
src/
└── index.html
```

So Docker's job is simply:

```text
index.html
     ↓
Dockerfile
     ↓
Docker Image
     ↓
Container
```

---

# 3. Folder #2 — infrastructure/

This is the most important folder in your project.

It contains your Infrastructure as Code.

```text
infrastructure/
│
├── terraform/
│
└── cloudformation/
```

So `infrastructure` has 2 main subfolders.

The concept is:

```text
infrastructure/
│
├── terraform/       → Terraform IaC
│
└── cloudformation/  → CloudFormation IaC
```

You are intentionally practicing two IaC technologies against the same AWS environment.

---

# 4. infrastructure/terraform/

Inside:

```text
terraform/
├── versions.tf
├── provider.tf
├── variables.tf
├── locals.tf
├── iam.tf
├── template_bucket.tf
├── cloudformation.tf
├── outputs.tf
└── terraform.tfvars.example
```

Notice something important:

> These are files, NOT folders.

You don't need to create a folder for every `.tf` file.

For example:

```text
terraform/
├── provider.tf
├── variables.tf
├── iam.tf
└── outputs.tf
```

is perfectly fine.

Terraform automatically reads all `.tf` files in that directory.

---

# 5. What each Terraform file means

### versions.tf

Terraform and provider version requirements.

```text
versions.tf
    ↓
Which Terraform/provider versions?
```

### provider.tf

AWS provider configuration.

```text
provider.tf
    ↓
AWS
    ↓
Region
```

### variables.tf

Inputs to your Terraform configuration.

Example:

```text
AWS region
environment
project name
instance type
```

### locals.tf

Calculated/reusable values.

For example:

```text
project_name = "aws-hybrid-iac-lab"
environment  = "dev"
```

### iam.tf

IAM resources.

```text
IAM
├── Role
├── Policy
└── Policy Attachment
```

### template_bucket.tf

S3 bucket used to store CloudFormation templates.

This is an important part of your hybrid design.

You can have:

```text
Terraform
   │
   └── creates S3 bucket
             │
             └── stores CloudFormation templates
```

### cloudformation.tf

Terraform can create/manage a CloudFormation stack.

So you get:

```text
Terraform
    │
    └── CloudFormation Stack
             │
             ├── VPC
             ├── EC2
             ├── S3
             ├── CloudFront
             ├── Lambda
             ├── RDS
             └── etc.
```

### outputs.tf

Important values returned after deployment.

For example:

```text
VPC ID
S3 bucket
CloudFront domain
EC2 instance ID
CloudFormation stack name
```

### terraform.tfvars.example

Example configuration.

Don't put secrets here.

---

# 6. infrastructure/cloudformation/

This is your second IaC system.

```text
cloudformation/
│
├── main.yaml
│
├── nested/
│
└── iam/
```

So CloudFormation has 2 subfolders:

```text
cloudformation/
├── nested/
└── iam/
```

And one file directly inside it:

```text
main.yaml
```

---

# 7. cloudformation/main.yaml

This is your root CloudFormation template.

Think of it as the manager.

```text
main.yaml
   │
   ├── vpc.yaml
   ├── ec2.yaml
   ├── s3.yaml
   ├── cloudfront.yaml
   ├── api-gateway.yaml
   ├── lambda.yaml
   ├── rds.yaml
   ├── dynamodb.yaml
   ├── ecr.yaml
   ├── ecs.yaml
   └── eks.yaml
```

Instead of putting hundreds/thousands of lines into one giant YAML file, you divide the infrastructure into nested stacks.

That's why the folder is called:

```text
nested/
```

---

# 8. cloudformation/nested/

Here you have:

```text
nested/
├── vpc.yaml
├── ec2.yaml
├── s3.yaml
├── cloudfront.yaml
├── api-gateway.yaml
├── lambda.yaml
├── rds.yaml
├── dynamodb.yaml
├── ecr.yaml
├── ecs.yaml
└── eks.yaml
```

Again:

> These are files, not folders.

You don't need:

```text
nested/vpc/vpc.yaml
nested/ec2/ec2.yaml
nested/s3/s3.yaml
```

at this stage.

Keep it simple.

---

# 9. cloudformation/iam/

This is separate because IAM is being used specifically to allow CloudFormation to deploy resources.

```text
iam/
└── cloudformation-execution-role.yaml
```

Conceptually:

```text
CloudFormation
      │
      ↓
Execution Role
      │
      ↓
AWS Resources
```

---

# 10. Folder #3 — kubernetes/

This is your Kubernetes layer.

```text
kubernetes/
├── namespace.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml
```

Again, one folder with four YAML files.

You don't need additional folders yet.

The flow is:

```text
Docker Image
     ↓
ECR
     ↓
Kubernetes
     ↓
Deployment
     ↓
Pod
     ↓
Service
```

For example:

**deployment.yaml** — defines your application pods.

**service.yaml** — exposes your application.

**configmap.yaml** — stores non-secret configuration.

**namespace.yaml** — creates an isolated Kubernetes namespace.

---

# 11. Folder #4 — scripts/

Your helper/automation scripts go here:

```text
scripts/
├── validate-cfn.ps1
├── terraform-plan.ps1
└── build-docker.ps1
```

Again:

> One folder. Three files.

For example:

**validate-cfn.ps1** — could validate CloudFormation.

**terraform-plan.ps1** — could run:

```text
terraform init
terraform validate
terraform plan
```

And **build-docker.ps1** — could build your Docker image.

---

# 12. Folder #5 — .github/

This is GitHub-specific.

```text
.github/
└── workflows/
```

So `.github` contains one subfolder:

```text
workflows/
```

Inside:

```text
workflows/
├── terraform.yml
├── docker.yml
└── kubernetes.yml
```

These are GitHub Actions workflows.

Conceptually:

```text
GitHub Push
     │
     ├──────────────→ terraform.yml
     │
     ├──────────────→ docker.yml
     │
     └──────────────→ kubernetes.yml
```

---

# 13. So how many folders are you actually creating?

Let's count them.

### Root

```text
aws-hybrid-iac-lab/
```

### Level 1

```text
docker/
infrastructure/
kubernetes/
scripts/
.github/
```

**5 folders**

### Level 2

Under Docker:

```text
docker/app/
```

Under infrastructure:

```text
infrastructure/terraform/
infrastructure/cloudformation/
```

Under CloudFormation:

```text
infrastructure/cloudformation/nested/
infrastructure/cloudformation/iam/
```

Under GitHub:

```text
.github/workflows/
```

That's **6 more folders**.

### Level 3

Your original structure has:

```text
docker/app/app/
```

But I recommend changing that to:

```text
docker/app/src/
```

So that's **1 additional folder**.

### Total

You would have approximately:

> **12 folders total**, including `.github` and the repository root depending on how you count.

But don't worry about the number. The structure is logically only 5 major areas:

```text
                    aws-hybrid-iac-lab
                            │
        ┌───────────────────┼────────────────────┐
        │                   │                    │
      Docker          Infrastructure       Kubernetes
        │                   │                    │
        │             ┌─────┴─────┐              │
        │             │           │              │
        │         Terraform  CloudFormation     │
        │                         │              │
        │                    ┌────┴────┐         │
        │                  Nested    IAM         │
        │
        ├── Scripts
        │
        └── GitHub Actions
```

---

# 14. I recommend this final structure

I would make one small improvement to your structure:

```text
aws-hybrid-iac-lab/
│
├── README.md
├── .gitignore
│
├── docker/
│   └── app/
│       ├── Dockerfile
│       └── src/
│           └── index.html
│
├── infrastructure/
│   │
│   ├── terraform/
│   │   ├── versions.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── iam.tf
│   │   ├── template_bucket.tf
│   │   ├── cloudformation.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── cloudformation/
│       ├── main.yaml
│       │
│       ├── nested/
│       │   ├── vpc.yaml
│       │   ├── ec2.yaml
│       │   ├── s3.yaml
│       │   ├── cloudfront.yaml
│       │   ├── api-gateway.yaml
│       │   ├── lambda.yaml
│       │   ├── rds.yaml
│       │   ├── dynamodb.yaml
│       │   ├── ecr.yaml
│       │   ├── ecs.yaml
│       │   └── eks.yaml
│       │
│       └── iam/
│           └── cloudformation-execution-role.yaml
│
├── kubernetes/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
│
├── scripts/
│   ├── validate-cfn.ps1
│   ├── terraform-plan.ps1
│   └── build-docker.ps1
│
└── .github/
    └── workflows/
        ├── terraform.yml
        ├── docker.yml
        └── kubernetes.yml
```

## The key idea

Don't think:

> "I have to create 30 files and 12 folders."

Think:

```text
Docker → Infrastructure → Kubernetes → Scripts → CI/CD
```

And inside Infrastructure:

```text
Terraform → CloudFormation
```

That makes the whole repository much easier to understand.

If you're building this as your new practice lab, I would also recommend that we create it incrementally rather than creating all these files at once:

**Step 1** = repository/folders → **Step 2** = Terraform → **Step 3** = CloudFormation → **Step 4** = Docker/ECR → **Step 5** = Kubernetes/EKS → **Step 6** = GitHub Actions.
