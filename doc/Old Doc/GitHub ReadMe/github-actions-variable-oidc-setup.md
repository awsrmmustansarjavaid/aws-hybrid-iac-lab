# GitHub Actions Variable Setup and OIDC Configuration

## 1. Create the `AWS_REGION` Repository Variable

Go to your GitHub repository:

```
Settings → Secrets and variables → Actions → Variables
```

Create a Repository variable:

```
Name:
AWS_REGION

Value:
us-east-1
```

Use whatever AWS region your lab actually uses. For example, if your Terraform provider is:

```
provider "aws" {
  region = "us-east-1"
}
```

then use:

```
AWS_REGION = us-east-1
```

Do not put the region in Secrets unless you specifically want to.

---

## 2. Your OIDC Configuration Is Correct

You currently have:

```yaml
permissions:
  id-token: write
  contents: read
```

and:

```yaml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-region: ${{ vars.AWS_REGION }}
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
```

This is the correct modern pattern:

```text
GitHub Actions
      │
      │ OIDC token
      ▼
GitHub OIDC Provider
      │
      ▼
AWS STS
      │
      │ AssumeRoleWithWebIdentity
      ▼
IAM Role
      │
      ▼
Terraform
      │
      ├── CloudFormation template S3 bucket
      ├── CloudFormation templates
      ├── CloudFormation execution role
      └── CloudFormation stack
```

You do not need:

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

for this workflow.
