# Cloud Authentication Actions

This directory contains the reusable GitHub Actions used by the `aws-hybrid-iac-lab` project to support both:

* Real AWS
* Local Floci

The existing AWS architecture remains supported. Floci is added as an additional local execution target.

---

## Directory Structure

```text
.github/
│
├── actions/
│   │
│   ├── cloud-auth/
│   │   └── action.yml
│   │
│   ├── cloud-verify/
│   │   └── action.yml
│   │
│   └── aws-oidc-diagnose/
│       └── action.yml
│
├── workflows/
│   ├── terraform.yml
│   ├── delete.yml
│   └── ...
│
└── README-cloud-actions.md
```

---

# 1. Cloud Environment

The workflows use one repository variable to select the execution target.

GitHub:

```text
Settings
  → Secrets and variables
  → Actions
  → Variables
```

Create:

```text
CLOUD_ENVIRONMENT
```

Supported values:

```text
aws
floci
```

For real AWS:

```text
CLOUD_ENVIRONMENT=aws
```

For local Floci:

```text
CLOUD_ENVIRONMENT=floci
```

---

# 2. AWS Mode

When:

```text
CLOUD_ENVIRONMENT=aws
```

the workflow uses the existing GitHub Actions OIDC architecture.

```text
GitHub Actions
      |
      v
GitHub OIDC
      |
      v
AWS IAM Role
      |
      v
Temporary AWS Credentials
      |
      v
AWS
```

No long-lived AWS access key is required.

The following repository variables are used:

```text
AWS_ACCOUNT_ID
AWS_ROLE_ARN
```

The AWS authentication is performed by:

```text
.github/actions/cloud-auth/action.yml
```

AWS identity is verified by:

```text
.github/actions/cloud-verify/action.yml
```

GitHub OIDC claims are diagnosed by:

```text
.github/actions/aws-oidc-diagnose/action.yml
```

---

# 3. Floci Mode

When:

```text
CLOUD_ENVIRONMENT=floci
```

the workflow does not use AWS OIDC.

Instead it configures normal AWS-compatible environment variables pointing to the local Floci endpoint.

Example:

```text
AWS_ENDPOINT_URL=http://localhost:4566
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
```

Floci provides an AWS-compatible endpoint on port `4566`.

The same AWS CLI commands can therefore be used for supported services.

Example:

```bash
aws sts get-caller-identity
```

or:

```bash
aws s3 ls
```

The Floci authentication configuration is performed by:

```text
.github/actions/cloud-auth/action.yml
```

The Floci identity is verified by:

```text
.github/actions/cloud-verify/action.yml
```

---

# 4. Repository Variables

Recommended variables:

```text
CLOUD_ENVIRONMENT
AWS_ACCOUNT_ID
AWS_ROLE_ARN
FLOCI_ENDPOINT
FLOCI_ACCOUNT_ID
```

Example:

```text
CLOUD_ENVIRONMENT=aws

AWS_ACCOUNT_ID=123456789012

AWS_ROLE_ARN=arn:aws:iam::123456789012:role/aws-hybrid-iac-lab-GitHubActions

FLOCI_ENDPOINT=http://localhost:4566

FLOCI_ACCOUNT_ID=000000000000
```

The actual AWS account ID and role ARN must be the real values from the repository configuration.

Do not commit AWS credentials to the repository.

---

# 5. Using Cloud Authentication

A workflow can configure the selected cloud environment with:

```yaml
- name: Configure Cloud Authentication
  uses: ./.github/actions/cloud-auth
  with:
    environment: ${{ env.CLOUD_ENVIRONMENT }}
    aws-region: ${{ env.AWS_REGION }}

    aws-account-id: ${{ env.AWS_ACCOUNT_ID }}
    aws-role-arn: ${{ env.AWS_ROLE_ARN }}
    aws-role-session-name: ${{ env.AWS_ROLE_SESSION_NAME }}
    aws-oidc-audience: ${{ env.AWS_OIDC_AUDIENCE }}

    floci-endpoint: ${{ env.FLOCI_ENDPOINT }}
```

The action automatically chooses AWS or Floci.

---

# 6. Verifying Identity

Use:

```yaml
- name: Verify Cloud Identity
  uses: ./.github/actions/cloud-verify
  with:
    environment: ${{ env.CLOUD_ENVIRONMENT }}

    aws-account-id: ${{ env.AWS_ACCOUNT_ID }}
    aws-expected-role-name: ${{ env.AWS_EXPECTED_ROLE_NAME }}

    floci-account-id: ${{ env.FLOCI_ACCOUNT_ID }}
```

AWS mode verifies:

```text
AWS account
AWS IAM role
AWS STS identity
```

Floci mode verifies:

```text
Floci endpoint
Floci STS response
Floci account ID
```

---

# 7. AWS OIDC Diagnostics

OIDC diagnostics are AWS-specific.

Use:

```yaml
- name: Diagnose GitHub OIDC Claims
  if: env.CLOUD_ENVIRONMENT == 'aws'
  uses: ./.github/actions/aws-oidc-diagnose
  with:
    oidc-audience: ${{ env.AWS_OIDC_AUDIENCE }}
    expected-repository: "awsrmmustansarjavaid/aws-hybrid-iac-lab"
```

The action checks:

* OIDC issuer
* OIDC audience
* repository
* repository ID
* repository owner
* GitHub reference
* workflow
* workflow reference
* job workflow reference
* OIDC subject

The actual JWT is never printed.

The OIDC action is skipped when:

```text
CLOUD_ENVIRONMENT=floci
```

because Floci does not require GitHub OIDC authentication.

---

# 8. Terraform Workflow

The Terraform workflow should use the same cloud selection mechanism.

Conceptually:

```text
terraform.yml
      |
      +-- CLOUD_ENVIRONMENT=aws
      |       |
      |       +-- cloud-auth
      |       +-- aws-oidc-diagnose
      |       +-- cloud-verify
      |       +-- Terraform
      |       +-- AWS
      |
      +-- CLOUD_ENVIRONMENT=floci
              |
              +-- cloud-auth
              +-- cloud-verify
              +-- Terraform
              +-- Floci
```

The Terraform resource definitions should remain shared wherever AWS API compatibility allows it.

---

# 9. Delete Workflow

The delete workflow uses the same authentication architecture.

```text
delete.yml
      |
      +-- cloud-auth
      |
      +-- aws-oidc-diagnose
      |       only in AWS mode
      |
      +-- cloud-verify
      |
      +-- deletion operations
```

The destructive confirmation remains mandatory:

```text
DESTROY
```

The existing safety controls should not be removed.

---

# 10. Important Floci Limitation

Changing the authentication endpoint does not automatically make every AWS service behave exactly like real AWS.

The project contains:

```text
Terraform
CloudFormation
EKS
Kubernetes
ECS
ECR
S3
RDS
VPC
IAM
```

Each service must be checked for Floci compatibility before assuming the complete AWS lab can run unchanged.

Therefore Floci migration should be performed incrementally.

Recommended order:

```text
1. Authentication
2. STS verification
3. S3
4. Terraform backend
5. Terraform resources
6. CloudFormation
7. ECR
8. ECS
9. EKS
10. Kubernetes
11. Full delete workflow
```

---

# 11. Self-Hosted Runner

If Floci runs on the user's Windows laptop and GitHub Actions uses a self-hosted runner on the same laptop:

```text
GitHub
   |
   v
Self-hosted GitHub Runner
   |
   +---- AWS CLI
   |
   +---- Terraform
   |
   +---- kubectl
   |
   +---- Docker
   |
   +---- Floci
            |
            +---- localhost:4566
```

This allows:

```text
AWS_ENDPOINT_URL=http://localhost:4566
```

to point to the Floci instance running on the same machine.

The runner and Floci networking must be configured appropriately if either component runs inside a container.

---

# 12. Safety Rule

Do not put real AWS credentials in:

```text
action.yml
terraform.yml
delete.yml
README.md
```

Use GitHub OIDC for real AWS.

Use local dummy credentials for Floci.

---

# 13. Design Principle

The goal is not to create two completely separate projects.

The goal is:

```text
One infrastructure codebase
        |
        +----------------+
        |                |
      AWS              Floci
        |                |
   Real cloud       Local emulator
```

The workflows remain shared.

The target changes through:

```text
CLOUD_ENVIRONMENT
```

This makes Floci a development/testing environment while preserving AWS as the real-cloud environment.

---

# 14. Recommended Initial Configuration

Start with:

```text
CLOUD_ENVIRONMENT=aws
```

First confirm that the existing AWS workflow still works.

Then switch to:

```text
CLOUD_ENVIRONMENT=floci
```

and test only:

```text
cloud-auth
cloud-verify
```

before attempting the full Terraform deployment.

Do not start with the destructive `delete.yml` Floci path.

---

# 15. Final Architecture

The final reusable architecture is:

```text
.github/actions/

    cloud-auth/
        action.yml
            |
            +-- AWS OIDC
            |
            +-- Floci credentials

    cloud-verify/
        action.yml
            |
            +-- AWS STS verification
            |
            +-- Floci STS verification

    aws-oidc-diagnose/
        action.yml
            |
            +-- GitHub OIDC diagnostics
```

Workflows:

```text
terraform.yml
delete.yml
docker.yml
other workflows
        |
        v
CLOUD_ENVIRONMENT
        |
        +--------------------+
        |                    |
       aws                 floci
        |                    |
   AWS OIDC             Local endpoint
        |                    |
   Real AWS              Floci
```

This keeps the authentication concerns reusable, keeps AWS OIDC diagnostics intact, and adds Floci without creating a completely separate workflow architecture.
---
