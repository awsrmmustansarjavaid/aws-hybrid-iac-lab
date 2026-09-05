# GitHub Actions → OIDC → AWS Setup Guide (AWS Hybrid IaC Lab)

## 1. Your CloudFormation `main.yaml`

The file you pasted looks structurally appropriate for your design:

```text
main.yaml
   |
   +-- nested/vpc.yaml
   |
   +-- nested/s3.yaml
   |
   +-- nested/dynamodb.yaml
   |
   +-- nested/ecr.yaml
```

It doesn't need AWS access keys.

CloudFormation will receive its permissions from the IAM identity that GitHub Actions uses to call CloudFormation.

---

## 2. Recommended Architecture: GitHub Actions → OIDC → IAM Role → AWS

Instead of:

```text
GitHub Actions
     |
     | AWS_ACCESS_KEY_ID
     | AWS_SECRET_ACCESS_KEY
     v
AWS
```

I recommend:

```text
GitHub Actions
      |
      | OIDC token
      v
AWS STS
      |
      | AssumeRoleWithWebIdentity
      v
IAM Role
      |
      v
AWS Resources
```

This means you don't need:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

stored in GitHub.

The credentials are temporary and obtained when the workflow runs.

---

## 3. Your GitHub Actions Configuration

Your workflow should eventually have something like:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:

      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Configure AWS credentials using OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Verify AWS identity
        run: |
          aws sts get-caller-identity
```

You could also put the region directly in the workflow:

```yaml
aws-region: us-east-1
```

but I prefer:

```yaml
aws-region: ${{ vars.AWS_REGION }}
```

because the region is configuration, not a secret.

---

## 4. What You Need in GitHub

With OIDC, you can reduce your GitHub configuration to something like:

**GitHub Variable**

```text
AWS_REGION = us-east-1
```

**GitHub Secret**

```text
AWS_ROLE_ARN = arn:aws:iam::123456789012:role/GitHubActions-HybridIaCLab
```

You do **not** need:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

That is a significant security improvement.

---

## 5. What IAM Needs

AWS needs an IAM OIDC provider for GitHub.

The trust relationship on your deployment role should restrict access to your repository.

For example, conceptually:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
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

That says, essentially:

> Only GitHub Actions from this repository can assume this AWS role.

For even stronger security, you can restrict it to a specific branch/environment rather than allowing `:*`.

---

## 6. Important Distinction for Your Hybrid Lab

Your architecture is:

```text
                 GitHub
                   |
                   | OIDC
                   v
             AWS IAM Role
                   |
             +-----+-----+
             |           |
             v           v
       CloudFormation  Terraform
             |           |
             v           v
       AWS resources  AWS resources
```

This is perfectly reasonable.

For example:

**CloudFormation manages**

- VPC
- S3
- DynamoDB
- ECR
- IAM
- etc.

**Terraform manages**

- EC2
- ECS
- EKS
- ALB
- RDS
- etc.

The GitHub Actions role can be given permissions appropriate to what your pipeline actually deploys.

---

## 7. Your Current Error Still Needs Fixing

Even if you switch to OIDC, this part is still required:

```yaml
aws-region: ${{ vars.AWS_REGION }}
```

Your current workflow apparently has:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
```

but doesn't provide `aws-region`.

So your immediate error is unrelated to the CloudFormation template you pasted.

---

## 8. Recommendation: Use OIDC for This Project

For a portfolio/DevOps lab, I would not build the final architecture around permanent IAM access keys.

Use:

```text
GitHub Actions
       |
       | OIDC
       v
AWS IAM Role
       |
       +---- CloudFormation deployment
       |
       +---- Terraform deployment
       |
       +---- S3 template upload
       |
       +---- ECR operations
       |
       +---- other required AWS operations
```

Then GitHub contains no permanent AWS access key.
