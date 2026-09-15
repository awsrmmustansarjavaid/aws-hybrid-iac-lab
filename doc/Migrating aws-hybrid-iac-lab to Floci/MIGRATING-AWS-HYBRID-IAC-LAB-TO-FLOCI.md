# Migrating `aws-hybrid-iac-lab` to Floci

## LinkedIn Article

[Migrating an AWS Infrastructure Lab to Floci: Building a Dual AWS + Local Cloud Execution Model](https://www.linkedin.com/pulse/migrating-aws-infrastructure-lab-floci-building-dual-local-javaid-vfgaf/?trackingId=AsF%2BBxJNT3C5pmntjXSuIw%3D%3D)

## Local AWS-Compatible Development, Testing, and CI

This document describes how to extend the existing `aws-hybrid-iac-lab` so that the same repository can operate in two environments:

1. **Real AWS**

   * GitHub Actions
   * GitHub OIDC
   * AWS IAM role
   * Real AWS services

2. **Local Floci**

   * GitHub Actions self-hosted runner on the developer's laptop
   * Floci local AWS emulator
   * AWS-compatible APIs through `http://localhost:4566`
   * No real AWS account required for the local execution path

The objective is **not to replace AWS**.

The objective is:

> **Keep the existing AWS implementation and add Floci as a second execution backend.**

The repository therefore remains one infrastructure project with two execution targets.

---

# 1. Target Architecture

The final architecture is:

```text
                           aws-hybrid-iac-lab
                                  |
                                  |
                         CLOUD_ENVIRONMENT
                                  |
                    +-------------+-------------+
                    |                           |
                   aws                        floci
                    |                           |
             GitHub OIDC                  Self-hosted runner
                    |                           |
              AWS IAM Role                    Floci
                    |                           |
               Real AWS                  localhost:4566
                    |                           |
                    +-------------+-------------+
                                  |
                         Same repository
                         Same workflows
                         Same IaC
                   Where service-compatible
```

The important distinction is:

```text
AWS mode
    authentication = GitHub OIDC
    endpoint       = AWS

Floci mode
    authentication = local test credentials
    endpoint       = localhost:4566
```

OIDC is therefore an AWS authentication mechanism. It is not required for normal Floci execution.

---

# 2. What Is Being Changed

The migration adds five major capabilities:

```text
1. Floci local runtime
2. Self-hosted GitHub Actions runner
3. CLOUD_ENVIRONMENT selector
4. Reusable cloud authentication/verification actions
5. Terraform/AWS CLI/CloudFormation endpoint configuration
```

The existing AWS path remains available.

We are **not** doing this:

```text
DELETE AWS
    |
    +--> ADD Floci
```

We are doing this:

```text
KEEP AWS
    |
    +--> ADD Floci
    |
    +--> ADD environment selector
```

---

# 3. Important Floci Facts

Floci is an AWS-compatible local emulator.

The standard endpoint is:

```text
http://localhost:4566
```

Floci supports many AWS APIs, including services relevant to this lab such as:

```text
S3
DynamoDB
EC2
ECS
ECR
EKS
RDS
Lambda
IAM
STS
Secrets Manager
CloudFormation
API Gateway
CloudFront
SQS
SNS
SSM
```

The exact operation coverage should always be checked against the current Floci service documentation before assuming that a particular AWS feature behaves exactly like production AWS.

Floci's service overview is the authoritative place to check current service support.

[Floci services overview](https://floci.io/floci/services/?utm_source=chatgpt.com)

---

# 4. Default Floci Account ID

By default, Floci uses:

```text
000000000000
```

This is the default local account ID.

It is important not to describe this as an account that you register with AWS.

It is a local Floci account identity.

Floci's default is:

```text
FLOCI_DEFAULT_ACCOUNT_ID=000000000000
```

However, this value is configurable.

Also, Floci supports multi-account isolation. A 12-digit access key can be used as an account ID.

Therefore:

```text
000000000000
```

should be treated as the **default Floci account ID**, not as an immutable hard-coded fact.

---

# 5. Prerequisites

For local Floci execution, the laptop needs:

```text
Docker / Docker Desktop
AWS CLI
Terraform
Git
GitHub Actions self-hosted runner
```

For Windows, Docker Desktop should be running before starting Floci.

Verify Docker:

```powershell
docker --version
docker info
```

Verify AWS CLI:

```powershell
aws --version
```

Verify Terraform:

```powershell
terraform version
```

Verify Git:

```powershell
git --version
```

---

# 6. Start Floci

The simplest Docker-based installation is:

```powershell
docker run -d `
  --name floci `
  -p 4566:4566 `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -u root `
  floci/floci:latest
```

The Docker socket is useful because several Floci services can create/manage real Docker-backed containers.

Examples include:

```text
EKS
ECS
Lambda
RDS
ECR
```

depending on the service and configuration.

Floci's current documentation provides the Docker setup and Docker-backed service configuration.

[Floci quick start](https://floci.io/floci/getting-started/quick-start/?utm_source=chatgpt.com)

Check the container:

```powershell
docker ps
```

Check Floci logs:

```powershell
docker logs floci
```

Check the endpoint:

```powershell
curl http://localhost:4566
```

---

# 7. Configure Local AWS Environment

For PowerShell:

```powershell
$env:AWS_ENDPOINT_URL = "http://localhost:4566"
$env:AWS_DEFAULT_REGION = "us-east-1"
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
```

Verify:

```powershell
aws sts get-caller-identity
```

The result should identify the local Floci environment rather than your real AWS account.

With the default configuration, the account ID is:

```text
000000000000
```

Floci documents `AWS_ENDPOINT_URL` as the common endpoint mechanism for AWS CLI and SDK usage.

[Floci AWS CLI and SDK setup](https://floci.io/floci/getting-started/aws-setup/?utm_source=chatgpt.com)

---

# 8. Basic Floci Smoke Test

Before involving GitHub Actions or Terraform, verify that Floci itself works.

Create an S3 bucket:

```powershell
aws s3 mb s3://floci-smoke-test
```

List buckets:

```powershell
aws s3 ls
```

Test DynamoDB:

```powershell
aws dynamodb list-tables
```

Test SQS:

```powershell
aws sqs list-queues
```

Test STS:

```powershell
aws sts get-caller-identity
```

If these commands work, the local AWS-compatible endpoint is functioning.

---

# 9. Important Rule About `localhost`

This is one of the most important concepts in the entire migration.

When a workflow executes:

```text
AWS_ENDPOINT_URL=http://localhost:4566
```

`localhost` means:

> The machine executing the workflow job.

Therefore:

```text
GitHub-hosted runner
       |
       +--> localhost
             |
             +--> GitHub's temporary VM
```

It does **not** mean:

```text
your laptop
```

Therefore a GitHub-hosted runner cannot directly use:

```text
http://localhost:4566
```

to reach Floci running on your laptop.

The Floci workflow must execute on a runner running on the same laptop as Floci.

The architecture therefore becomes:

```text
GitHub
   |
   | job
   v
Self-hosted runner on laptop
   |
   +----> localhost:4566
               |
              Floci
```

---

# 10. Install the GitHub Self-Hosted Runner

Go to:

```text
GitHub
  -> Repository
  -> Settings
  -> Actions
  -> Runners
  -> New self-hosted runner
```

Select the operating system used by the laptop.

GitHub provides the correct download and registration commands for the runner.

Use a custom label such as:

```text
floci-local
```

For example, the registration command is conceptually:

```bash
./config.sh \
  --url https://github.com/<OWNER>/aws-hybrid-iac-lab \
  --token <REGISTRATION_TOKEN> \
  --labels floci-local
```

Do not copy an old registration token.

GitHub generates a current registration token when you create the runner.

GitHub supports custom runner labels and allows workflows to target combinations such as:

```yaml
runs-on: [self-hosted, floci-local]
```

---

# 11. Windows Self-Hosted Runner

Because this lab is being developed on Windows, the runner can be installed using the Windows runner package supplied by GitHub.

After configuration, the runner can be started interactively or installed as a Windows service.

A service is preferable for a permanent development machine because it can start automatically.

Do not place GitHub runner registration tokens in the repository.

---

# 12. Do Not Permanently Convert Every Workflow to Self-Hosted

Do not blindly change every:

```yaml
runs-on: ubuntu-latest
```

to:

```yaml
runs-on: [self-hosted, floci-local]
```

That would make the entire repository dependent on your laptop.

Instead, runner selection should also be environment-aware.

For example:

```text
AWS mode
    |
    +--> GitHub-hosted runner

Floci mode
    |
    +--> self-hosted floci-local runner
```

GitHub supports `runs-on` values based on variables and labels, so this can be implemented without putting runner selection into the authentication action.

---

# 13. Recommended Repository Variable

Create this GitHub Actions repository variable:

```text
CLOUD_ENVIRONMENT
```

Allowed values:

```text
aws
floci
```

Configure it here:

```text
Repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> Variables
```

Example:

```text
CLOUD_ENVIRONMENT=aws
```

or:

```text
CLOUD_ENVIRONMENT=floci
```

---

# 14. Recommended Repository Variables

The final configuration can contain:

```text
CLOUD_ENVIRONMENT
AWS_REGION

AWS_ACCOUNT_ID
AWS_ROLE_ARN

FLOCI_ENDPOINT
FLOCI_ACCOUNT_ID
```

Recommended values:

```text
CLOUD_ENVIRONMENT=aws

AWS_REGION=us-east-1

FLOCI_ENDPOINT=http://localhost:4566

FLOCI_ACCOUNT_ID=000000000000
```

Your existing AWS account and role variables remain for AWS execution.

The Floci variables do not replace them.

---

# 15. Recommended Runner Variable

For a clean design, a separate runner variable can be used:

```text
ACTIONS_RUNNER
```

Example AWS configuration:

```text
ACTIONS_RUNNER=ubuntu-latest
```

Example Floci configuration:

```text
ACTIONS_RUNNER=floci-local
```

Then a workflow can use:

```yaml
runs-on: ${{ vars.ACTIONS_RUNNER }}
```

This is preferable to putting runner selection inside `cloud-auth`.

The responsibilities remain separated:

```text
Runner selection
       |
       +--> where the job runs

Cloud authentication
       |
       +--> how AWS-compatible API credentials are configured
```

---

# 16. Why Authentication and Runner Selection Must Be Separate

The self-hosted runner exists because Floci is local.

The authentication action exists because the workflow needs different credentials/endpoints.

They solve different problems.

Therefore:

```text
runs-on
```

should not be implemented inside:

```text
cloud-auth
```

The workflow chooses the machine.

The authentication action configures the cloud environment.

---

# 17. Reusable GitHub Actions

To avoid duplicating cloud configuration across workflows, create:

```text
.github/
└── actions/
    ├── cloud-auth/
    │   └── action.yml
    │
    ├── cloud-verify/
    │   └── action.yml
    │
    └── aws-oidc-diagnose/
        └── action.yml
```

These have three different responsibilities.

---

# 18. `cloud-auth`

File:

```text
.github/actions/cloud-auth/action.yml
```

Responsibility:

```text
AWS mode
    |
    +--> configure GitHub OIDC -> AWS IAM role

Floci mode
    |
    +--> configure local credentials
    +--> configure Floci endpoint
```

Conceptually:

```yaml
name: Cloud Authentication

description: Configure AWS or Floci

inputs:
  environment:
    required: true

  aws-region:
    required: true

  aws-role-arn:
    required: false

  floci-endpoint:
    required: false

runs:
  using: composite

  steps:

    - name: Configure AWS Credentials
      if: inputs.environment == 'aws'
      uses: aws-actions/configure-aws-credentials@v5.1.1
      with:
        role-to-assume: ${{ inputs.aws-role-arn }}
        aws-region: ${{ inputs.aws-region }}

    - name: Configure Floci
      if: inputs.environment == 'floci'
      shell: bash
      run: |
        echo "AWS_ENDPOINT_URL=${{ inputs.floci-endpoint }}" >> "$GITHUB_ENV"
        echo "AWS_ACCESS_KEY_ID=test" >> "$GITHUB_ENV"
        echo "AWS_SECRET_ACCESS_KEY=test" >> "$GITHUB_ENV"
        echo "AWS_DEFAULT_REGION=${{ inputs.aws-region }}" >> "$GITHUB_ENV"
```

The exact implementation should be adapted to the existing repository's authentication variables and validation logic.

Do not blindly delete existing AWS authentication code.

Move it carefully into the reusable action.

---

# 19. AWS OIDC Permissions

The AWS workflow must retain:

```yaml
permissions:
  id-token: write
  contents: read
```

The important point is:

```text
CLOUD_ENVIRONMENT=aws
```

uses:

```text
GitHub OIDC
    |
    v
AWS IAM
```

while:

```text
CLOUD_ENVIRONMENT=floci
```

does not need AWS OIDC authentication.

The permission can remain available to the workflow without meaning that Floci is using OIDC.

---

# 20. `cloud-verify`

File:

```text
.github/actions/cloud-verify/action.yml
```

Its purpose is to prove that the selected cloud environment is reachable.

For AWS:

```bash
aws sts get-caller-identity
```

For Floci:

```bash
aws sts get-caller-identity \
  --endpoint-url "$FLOCI_ENDPOINT"
```

A verification action should also validate the expected account ID.

Conceptually:

```text
AWS
    |
    +--> AWS account ID

Floci
    |
    +--> FLOCI_ACCOUNT_ID
```

---

# 21. `aws-oidc-diagnose`

File:

```text
.github/actions/aws-oidc-diagnose/action.yml
```

This action remains AWS-specific.

It should run only when:

```yaml
if: env.CLOUD_ENVIRONMENT == 'aws'
```

Do not create fake OIDC diagnostics for Floci.

The correct architecture is:

```text
AWS
 ├── OIDC authentication
 ├── AWS identity verification
 └── OIDC diagnostics

Floci
 ├── local credentials
 ├── Floci identity verification
 └── no AWS OIDC diagnostics
```

---

# 22. `terraform.yml`

The Terraform workflow should retain its existing Terraform deployment logic.

The major change is that authentication and endpoint configuration become environment-aware.

At the job level:

```yaml
env:
  CLOUD_ENVIRONMENT: ${{ vars.CLOUD_ENVIRONMENT }}
  AWS_REGION: ${{ vars.AWS_REGION }}

  AWS_ACCOUNT_ID: ${{ vars.AWS_ACCOUNT_ID }}
  AWS_ROLE_ARN: ${{ vars.AWS_ROLE_ARN }}

  FLOCI_ENDPOINT: ${{ vars.FLOCI_ENDPOINT }}
  FLOCI_ACCOUNT_ID: ${{ vars.FLOCI_ACCOUNT_ID }}
```

Then:

```yaml
- name: Configure Cloud Authentication
  uses: ./.github/actions/cloud-auth
  with:
    environment: ${{ env.CLOUD_ENVIRONMENT }}
    aws-region: ${{ env.AWS_REGION }}
    aws-role-arn: ${{ env.AWS_ROLE_ARN }}
    floci-endpoint: ${{ env.FLOCI_ENDPOINT }}
```

Then:

```yaml
- name: Verify Cloud Identity
  uses: ./.github/actions/cloud-verify
  with:
    environment: ${{ env.CLOUD_ENVIRONMENT }}
    aws-account-id: ${{ env.AWS_ACCOUNT_ID }}
    floci-account-id: ${{ env.FLOCI_ACCOUNT_ID }}
```

Then:

```yaml
- name: Diagnose GitHub OIDC Claims
  if: env.CLOUD_ENVIRONMENT == 'aws'
  uses: ./.github/actions/aws-oidc-diagnose
```

After that:

```text
existing Terraform logic
```

continues.

---

# 23. Terraform Provider Must Also Know About Floci

This is a critical part of the migration.

Changing GitHub authentication does **not** automatically redirect Terraform.

Terraform still needs to know:

```text
Where is the AWS API?
```

For AWS:

```text
AWS API endpoints
```

For Floci:

```text
http://localhost:4566
```

Floci's official Terraform documentation uses the standard HashiCorp AWS provider and configures service endpoints to Floci.

[Floci Terraform integration](https://floci.io/floci/getting-started/terraform/?utm_source=chatgpt.com)

---

# 24. Terraform Provider Architecture

The desired model is:

```text
CLOUD_ENVIRONMENT
        |
        v
Terraform AWS provider
        |
        +-------------------+
        |                   |
       aws                floci
        |                   |
   AWS endpoints       localhost:4566
```

Do not create a second Terraform implementation.

Keep:

```text
infrastructure/terraform/
```

as the source of infrastructure definitions.

Only make the provider configuration environment-aware.

---

# 25. Terraform Floci Provider Configuration

For Floci, the provider needs endpoint overrides for the services actually used by the Terraform code.

A basic example is:

```hcl
provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  s3_use_path_style = true

  endpoints {
    s3            = "http://localhost:4566"
    dynamodb      = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sns           = "http://localhost:4566"
    sqs           = "http://localhost:4566"
    ssm           = "http://localhost:4566"
  }
}
```

Do not blindly copy this list into the final repository.

The endpoint list must match the services actually used by the Terraform configuration.

Floci's documentation explicitly notes that the endpoint should be configured for every AWS service used by the Terraform configuration.

---

# 26. Recommended Terraform Provider Pattern

A better long-term structure is to make the provider environment-aware.

For example:

```text
CLOUD_ENVIRONMENT=aws
    |
    +--> normal AWS provider

CLOUD_ENVIRONMENT=floci
    |
    +--> Floci endpoint configuration
```

This can be implemented using Terraform variables, generated configuration, separate provider files, or another controlled mechanism.

The key rule is:

> Do not maintain two independent copies of the infrastructure.

---

# 27. Terraform State

The existing lab may use an S3 backend.

This is another area that must be handled explicitly.

There are two valid strategies for local Floci development:

### Option A — Local Terraform state

Use Terraform's local backend for the first Floci integration test.

This is the simplest approach.

```text
Terraform
   |
   +--> local terraform.tfstate
```

### Option B — Floci S3 backend

Floci can emulate S3 and supports Terraform's S3 backend compatibility.

Floci documents an example using:

```text
S3
DynamoDB
localhost:4566
```

for Terraform state.

---

# 28. Floci Terraform Backend Example

A Floci-specific backend configuration can look like:

```hcl
terraform {
  backend "s3" {
    bucket                      = "tfstate"
    key                         = "terraform.tfstate"
    region                      = "us-east-1"

    endpoint                    = "http://localhost:4566"
    dynamodb_endpoint           = "http://localhost:4566"
    dynamodb_table              = "tflock"

    access_key                  = "test"
    secret_key                  = "test"

    skip_credentials_validation = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
```

However, do not immediately replace the existing AWS backend with this.

The correct migration is:

```text
AWS
   |
   +--> existing AWS backend

Floci
   |
   +--> local backend initially
       OR
       Floci S3 backend
```

Terraform's current S3 backend documentation also supports custom endpoints and S3-based locking via `use_lockfile`; DynamoDB locking is now deprecated in current Terraform versions.

Therefore, when modernizing the lab, the existing backend design should be reviewed rather than blindly copying an older DynamoDB-locking pattern.

---

# 29. CloudFormation

The repository currently contains CloudFormation infrastructure.

Keep:

```text
infrastructure/cloudformation/
```

as the infrastructure definition.

Do not create:

```text
cloudformation-aws/
cloudformation-floci/
```

unless a genuine incompatibility makes it unavoidable.

Floci currently implements CloudFormation APIs, so CloudFormation can be part of the local compatibility path.

However:

> AWS API compatibility does not guarantee that every CloudFormation resource property, lifecycle behavior, or nested-stack feature behaves exactly like AWS.

Therefore CloudFormation should be validated incrementally.

---

# 30. CloudFormation Execution

The desired architecture is:

```text
CloudFormation templates
        |
        v
AWS CLI / SDK
        |
        +------------------+
        |                  |
       AWS               Floci
        |                  |
   AWS endpoint       localhost:4566
```

The templates remain shared.

The execution endpoint changes.

---

# 31. AWS CLI Commands

For AWS:

```bash
aws cloudformation ...
```

uses the normal AWS endpoint.

For Floci:

```bash
aws cloudformation ... \
  --endpoint-url http://localhost:4566
```

or the workflow can set:

```text
AWS_ENDPOINT_URL=http://localhost:4566
```

so that compatible AWS CLI commands use the local endpoint.

This avoids rewriting every command unnecessarily.

---

# 32. Existing `delete.yml`

The existing deletion workflow is more complicated than authentication.

It may contain operations involving:

```text
Terraform
CloudFormation
S3
ECR
ECS
EKS
Kubernetes
AWS CLI
```

Therefore:

> Changing credentials does not make the deletion workflow automatically Floci-compatible.

The correct approach is to separate the migration into layers.

---

# 33. Delete Workflow Migration

First change:

```text
authentication
```

Then:

```text
identity verification
```

Then:

```text
AWS CLI endpoint configuration
```

Then:

```text
Terraform backend
```

Then:

```text
Terraform resources
```

Then:

```text
CloudFormation resources
```

Then:

```text
ECR/ECS
```

Then:

```text
EKS/Kubernetes
```

Each layer should be tested before moving to the next.

---

# 34. Important EKS Consideration

Floci currently has an EKS emulator that can run a real k3s container for each cluster.

This is significantly more useful than simply returning fake EKS metadata.

In real mode, Floci can expose a Kubernetes API server on a host port.

Therefore the Kubernetes part of the lab can eventually be tested locally.

However:

```text
AWS EKS
```

and:

```text
Floci EKS
```

are not automatically identical.

The lab should validate:

```text
cluster creation
cluster readiness
kubeconfig
authentication
node groups
ECR image access
kubectl
Helm
application deployment
```

before declaring the Kubernetes portion fully compatible.

---

# 35. ECR and Kubernetes

Floci also provides an ECR emulator and integration with its EKS implementation.

This means a possible local architecture is:

```text
Docker build
      |
      v
Floci ECR
      |
      v
Floci EKS / k3s
      |
      v
Kubernetes workload
```

Floci's current EKS documentation describes integration between the local ECR registry and k3s.

This is useful for the later Kubernetes phase of the lab.

---

# 36. RDS

Floci currently provides RDS emulation and can use Docker-backed database containers.

The local implementation should nevertheless be tested against the exact RDS engine and operations used by this repository.

The lab's existing RDS design uses:

```text
ManageMasterUserPassword: true
```

and AWS Secrets Manager for the master password.

For Floci, this must be explicitly tested.

Do not assume that an AWS Secrets Manager integration behaves identically merely because both APIs exist.

The compatibility test should verify:

```text
RDS creation
        |
        v
secret creation
        |
        v
database endpoint
        |
        v
application connectivity
        |
        v
deletion
```

---

# 37. AWS Secrets Manager

The existing AWS design should remain unchanged for AWS:

```text
AWS RDS
   |
   +--> AWS Secrets Manager
```

For Floci:

```text
Floci RDS
   |
   +--> Floci Secrets Manager
```

The configuration must be validated against the exact CloudFormation/Terraform resource behavior used by the lab.

Do not add a fake `DB_MASTER_PASSWORD` to GitHub merely to make the local workflow convenient if the existing architecture intentionally uses managed secrets.

---

# 38. Docker Workflow

The existing:

```text
.github/workflows/docker.yml
```

can eventually use the same environment selector.

However, Docker itself is local infrastructure rather than AWS authentication.

The correct separation is:

```text
Docker build/push
       |
       +--> local Docker
       |
       +--> Floci ECR
```

The workflow should only use Floci-specific ECR endpoints when:

```text
CLOUD_ENVIRONMENT=floci
```

---

# 39. Kubernetes Workflow

The existing:

```text
.github/workflows/kubernetes.yml
```

can also use the same cloud environment architecture.

AWS mode:

```text
AWS EKS
```

Floci mode:

```text
Floci EKS / k3s
```

The Kubernetes deployment logic should remain as shared as practical.

Only the cluster connection and image registry configuration should become environment-aware.

---

# 40. `main-deploy.yaml`

If:

```text
main-deploy.yaml
```

only orchestrates other workflows using `workflow_call`, it does not itself need to contain cloud authentication.

The called workflow is responsible for:

```text
runner
authentication
verification
deployment
```

This avoids duplicating infrastructure logic.

---

# 41. Preflight Validation Must Become Environment-Aware

Existing AWS validation may currently require:

```text
AWS_ACCOUNT_ID
AWS_ROLE_ARN
AWS OIDC variables
```

These must not remain unconditional.

Incorrect:

```bash
if [ -z "${AWS_ACCOUNT_ID:-}" ]; then
  exit 1
fi
```

Correct architecture:

```bash
if [ "$CLOUD_ENVIRONMENT" = "aws" ]; then

  # AWS-specific validation

fi
```

and:

```bash
if [ "$CLOUD_ENVIRONMENT" = "floci" ]; then

  # Floci-specific validation

fi
```

---

# 42. AWS Validation

When:

```text
CLOUD_ENVIRONMENT=aws
```

validate things such as:

```text
AWS account ID
AWS role ARN
OIDC configuration
AWS region
AWS credentials
AWS identity
```

The workflow should continue to enforce the existing AWS safety checks.

---

# 43. Floci Validation

When:

```text
CLOUD_ENVIRONMENT=floci
```

validate:

```text
FLOCI_ENDPOINT
FLOCI_ACCOUNT_ID
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION
```

Then test:

```bash
aws sts get-caller-identity
```

against Floci.

The workflow should fail early if Floci is unreachable.

---

# 44. Floci Endpoint Validation

A useful preflight check is:

```bash
curl --fail "$FLOCI_ENDPOINT"
```

followed by:

```bash
aws sts get-caller-identity \
  --endpoint-url "$FLOCI_ENDPOINT"
```

This separates:

```text
network connectivity
```

from:

```text
AWS API compatibility
```

---

# 45. Recommended Workflow Architecture

The final workflow pattern should be:

```text
Workflow
   |
   +--> Select runner
   |
   +--> Checkout
   |
   +--> Configure cloud
   |
   +--> Verify identity
   |
   +--> AWS-only OIDC diagnostics
   |
   +--> Environment-specific preflight
   |
   +--> Existing infrastructure logic
   |
   +--> Verification
```

---

# 46. Example Terraform Workflow

Conceptually:

```yaml
jobs:

  terraform:

    runs-on: ${{ vars.ACTIONS_RUNNER }}

    permissions:
      contents: read
      id-token: write

    env:
      CLOUD_ENVIRONMENT: ${{ vars.CLOUD_ENVIRONMENT }}
      AWS_REGION: ${{ vars.AWS_REGION }}

      AWS_ACCOUNT_ID: ${{ vars.AWS_ACCOUNT_ID }}
      AWS_ROLE_ARN: ${{ vars.AWS_ROLE_ARN }}

      FLOCI_ENDPOINT: ${{ vars.FLOCI_ENDPOINT }}
      FLOCI_ACCOUNT_ID: ${{ vars.FLOCI_ACCOUNT_ID }}

    steps:

      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure Cloud Authentication
        uses: ./.github/actions/cloud-auth
        with:
          environment: ${{ env.CLOUD_ENVIRONMENT }}
          aws-region: ${{ env.AWS_REGION }}
          aws-role-arn: ${{ env.AWS_ROLE_ARN }}
          floci-endpoint: ${{ env.FLOCI_ENDPOINT }}

      - name: Verify Cloud Identity
        uses: ./.github/actions/cloud-verify
        with:
          environment: ${{ env.CLOUD_ENVIRONMENT }}
          aws-account-id: ${{ env.AWS_ACCOUNT_ID }}
          floci-account-id: ${{ env.FLOCI_ACCOUNT_ID }}

      - name: Diagnose GitHub OIDC Claims
        if: env.CLOUD_ENVIRONMENT == 'aws'
        uses: ./.github/actions/aws-oidc-diagnose

      # Existing Terraform steps remain here.
```

This is an architecture example.

The exact existing Terraform steps should not be removed or rewritten until they have been inspected.

---

# 47. AWS Execution

Set:

```text
CLOUD_ENVIRONMENT=aws
ACTIONS_RUNNER=ubuntu-latest
```

Architecture:

```text
GitHub Actions
      |
      v
GitHub-hosted runner
      |
      v
GitHub OIDC
      |
      v
AWS IAM role
      |
      v
AWS STS
      |
      v
Real AWS
```

The existing AWS implementation remains the production/cloud path.

---

# 48. Floci Execution

Set:

```text
CLOUD_ENVIRONMENT=floci
ACTIONS_RUNNER=floci-local
```

Architecture:

```text
GitHub Actions
      |
      v
Self-hosted runner
      |
      v
Laptop
      |
      v
Floci
      |
      v
localhost:4566
```

Credentials:

```text
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
```

Endpoint:

```text
AWS_ENDPOINT_URL=http://localhost:4566
```

---

# 49. What Must NOT Be Changed

The migration should not unnecessarily change:

```text
CloudFormation templates
Terraform modules
Dockerfiles
Kubernetes manifests
application code
AWS OIDC configuration
AWS IAM role architecture
AWS production workflow
```

unless a compatibility problem is discovered.

The goal is:

```text
shared infrastructure definitions
+
environment-specific execution configuration
```

---

# 50. What May Need Environment-Specific Changes

Some things legitimately need branching:

```text
AWS endpoints
Floci endpoints

AWS credentials
Floci credentials

AWS runner
Floci runner

AWS Terraform provider
Floci Terraform provider

AWS Terraform backend
Floci/local Terraform backend

AWS EKS
Floci EKS

AWS ECR
Floci ECR

AWS-specific preflight checks
Floci-specific preflight checks
```

These are execution differences, not necessarily separate infrastructure definitions.

---

# 51. Recommended Repository Structure

The target structure is:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   │
│   ├── actions/
│   │   │
│   │   ├── cloud-auth/
│   │   │   └── action.yml
│   │   │
│   │   ├── cloud-verify/
│   │   │   └── action.yml
│   │   │
│   │   └── aws-oidc-diagnose/
│   │       └── action.yml
│   │
│   └── workflows/
│       ├── main-deploy.yaml
│       ├── terraform.yml
│       ├── delete.yml
│       ├── docker.yml
│       └── kubernetes.yml
│
├── infrastructure/
│   ├── cloudformation/
│   ├── terraform/
│   └── bootstrap/
│
├── docker/
│
├── kubernetes/
│
├── scripts/
│
└── README.md
```

The existing infrastructure directories remain the source of truth.

---

# 52. Migration Phases

Do not attempt the entire migration in one change.

Use the following phases.

---

## Phase 1 — Local Floci

Goal:

```text
Floci works independently.
```

Tasks:

```text
Install Docker
Start Floci
Configure AWS CLI
Run STS test
Run S3 test
Run DynamoDB test
Run SQS test
```

Success criteria:

```text
aws sts get-caller-identity
aws s3 ls
aws dynamodb list-tables
aws sqs list-queues
```

all work against Floci.

---

## Phase 2 — Self-Hosted Runner

Goal:

```text
GitHub Actions can reach laptop Floci.
```

Tasks:

```text
Install self-hosted runner
Assign floci-local label
Start runner
Verify runner online
Run simple test workflow
```

Success criteria:

```text
GitHub workflow
    |
    v
self-hosted runner
    |
    v
Floci
```

---

## Phase 3 — Reusable Cloud Actions

Create:

```text
cloud-auth
cloud-verify
aws-oidc-diagnose
```

Success criteria:

```text
AWS mode:
    OIDC works

Floci mode:
    local credentials work
```

No Terraform changes yet.

---

## Phase 4 — `terraform.yml`

Add:

```text
CLOUD_ENVIRONMENT
ACTIONS_RUNNER
FLOCI_ENDPOINT
FLOCI_ACCOUNT_ID
```

Then make Terraform endpoint-aware.

Success criteria:

```text
terraform validate
terraform plan
```

work locally against Floci for the first supported resources.

---

## Phase 5 — Terraform Apply

Test progressively:

```text
S3
DynamoDB
IAM
Secrets Manager
VPC
EC2
RDS
other resources actually used by the lab
```

Do not assume all resources are compatible merely because the service exists.

---

## Phase 6 — Terraform State

Initially use:

```text
local Terraform backend
```

if that makes testing simpler.

After resource provisioning works, test:

```text
Floci S3 backend
```

and state locking as appropriate for the Terraform version and backend configuration.

---

## Phase 7 — CloudFormation

Test:

```text
CloudFormation
nested stacks
S3 templates
outputs
stack updates
stack deletion
```

The same CloudFormation templates should be used wherever possible.

---

## Phase 8 — Docker / ECR / ECS

Test:

```text
Docker build
ECR repository
image push
ECS resource creation
container execution
deletion
```

Floci currently provides ECR/ECS implementations, including Docker-backed behavior for relevant services.

---

## Phase 9 — Kubernetes / EKS

Test:

```text
EKS cluster creation
cluster readiness
kubeconfig
kubectl
node groups
ECR
deployment
service
ingress where applicable
cluster deletion
```

Floci's EKS implementation can create a local k3s-based cluster.

---

## Phase 10 — Delete Workflow

Only after deployment works should:

```text
delete.yml
```

be migrated completely.

Test deletion in the same order as creation.

---

# 53. Recommended Test Matrix

Maintain a test matrix like this:

| Component       |      AWS |          Floci |
| --------------- | -------: | -------------: |
| STS             | Required |       Required |
| IAM             | Required |       Validate |
| S3              | Required |       Required |
| DynamoDB        | Required |       Required |
| Secrets Manager | Required |       Validate |
| Terraform       | Required |       Required |
| Terraform state |   AWS S3 | Local/Floci S3 |
| CloudFormation  | Required |       Validate |
| EC2             | Required |       Validate |
| RDS             | Required |       Validate |
| Lambda          | Required |       Validate |
| ECR             | Required |       Validate |
| ECS             | Required |       Validate |
| EKS             | Required |       Validate |
| Kubernetes      | Required |       Validate |
| Delete workflow | Required |       Validate |

"Validate" means:

> Verify the exact API operations used by this repository rather than assuming complete AWS equivalence.

---

# 54. Security Rules

Never commit:

```text
AWS access keys
AWS secret keys
GitHub runner registration tokens
AWS temporary credentials
production secrets
```

Floci's test credentials such as:

```text
test/test
```

are local emulator credentials and are not AWS credentials.

Nevertheless, keep them in environment configuration rather than scattering them throughout the repository.

---

# 55. AWS Safety

The most important safety property is:

```text
CLOUD_ENVIRONMENT
```

must be explicit.

Do not allow a workflow to accidentally believe it is running against Floci while actually talking to AWS.

Likewise, do not allow an AWS workflow to accidentally point Terraform or AWS CLI at Floci.

The workflow should print:

```text
Cloud environment: aws
```

or:

```text
Cloud environment: floci
```

before infrastructure operations begin.

---

# 56. Recommended Environment Verification

Before deployment:

```text
Selected environment
Endpoint
Account ID
Runner
Region
```

should be displayed.

Example:

```text
Cloud environment : floci
Runner             : floci-local
Endpoint           : http://localhost:4566
Account            : 000000000000
Region             : us-east-1
```

For AWS:

```text
Cloud environment : aws
Runner             : ubuntu-latest
Endpoint           : AWS
Account            : <AWS_ACCOUNT_ID>
Region             : us-east-1
```

This makes CI logs much easier to understand.

---

# 57. Failure Protection

The workflow should fail if:

```text
CLOUD_ENVIRONMENT
```

is anything other than:

```text
aws
floci
```

For example:

```bash
case "$CLOUD_ENVIRONMENT" in
  aws)
    ;;
  floci)
    ;;
  *)
    echo "Invalid CLOUD_ENVIRONMENT"
    exit 1
    ;;
esac
```

Do not silently fall back to AWS.

A typo such as:

```text
CLOUD_ENVIRONMENT=floc
```

should fail.

---

# 58. Do Not Hard-Code the Real AWS Account for Floci

Do not simply replace:

```text
537236558357
```

with:

```text
000000000000
```

everywhere in the repository.

That would be the wrong abstraction.

Instead:

```text
AWS_ACCOUNT_ID
```

represents the AWS environment.

And:

```text
FLOCI_ACCOUNT_ID
```

represents the local Floci environment.

The selected environment determines which value is expected.

---

# 59. Do Not Replace AWS ARNs Globally

Likewise, do not perform a global search/replace such as:

```text
arn:aws:iam::537236558357:
```

to:

```text
arn:aws:iam::000000000000:
```

That would damage the AWS configuration.

Keep AWS-specific ARNs where they belong.

Generate/use Floci-compatible ARNs when the local execution path requires them.

---

# 60. Do Not Create Duplicate IaC

Avoid:

```text
terraform-aws/
terraform-floci/
```

or:

```text
cloudformation-aws/
cloudformation-floci/
```

unless a real incompatibility proves that separate definitions are unavoidable.

Prefer:

```text
same IaC
     |
     +--> AWS execution configuration

     +--> Floci execution configuration
```

---

# 61. What "Same Lab" Really Means

The phrase "same lab" should mean:

```text
same repository
same architecture
same IaC source
same application
same workflow concepts
same deployment lifecycle
```

It does **not** mean:

```text
100% identical AWS behavior for every API
```

because Floci is an emulator, not the actual AWS control plane.

The correct objective is:

> Maximum reuse of the existing lab with explicit compatibility handling for differences between AWS and Floci.

---

# 62. Recommended Final Architecture

The completed design should look like:

```text
                         aws-hybrid-iac-lab
                                  |
                         CLOUD_ENVIRONMENT
                                  |
                   +--------------+--------------+
                   |                             |
                  AWS                           Floci
                   |                             |
          ACTIONS_RUNNER                  ACTIONS_RUNNER
                   |                             |
        GitHub-hosted runner             Self-hosted runner
                   |                             |
             GitHub OIDC                     test/test
                   |                             |
              AWS IAM role                localhost:4566
                   |                             |
                   +--------------+--------------+
                                  |
                         Shared IaC repository
                                  |
             +--------------------+--------------------+
             |                    |                    |
        Terraform          CloudFormation        Kubernetes
             |                    |                    |
             +--------------------+--------------------+
                                  |
                           Environment-specific
                           endpoint configuration
```

---

# 63. Final Migration Rules

The migration follows these rules:

```text
DO:

✓ Keep AWS OIDC
✓ Keep AWS IAM roles
✓ Keep AWS deployment path
✓ Add Floci
✓ Add CLOUD_ENVIRONMENT
✓ Add Floci endpoint configuration
✓ Add self-hosted runner
✓ Add reusable cloud actions
✓ Keep infrastructure definitions shared
✓ Validate service compatibility
✓ Make preflight checks environment-aware
✓ Test deployment incrementally
✓ Test deletion separately
```

Do not:

```text
✗ Delete AWS OIDC
✗ Replace AWS with Floci
✗ Globally replace AWS account IDs
✗ Globally replace AWS ARNs
✗ Create duplicate infrastructure unnecessarily
✗ Assume authentication automatically configures Terraform
✗ Assume localhost works from GitHub-hosted runners
✗ Assume every AWS API behaves identically
✗ Run the complete delete workflow against Floci before validating deployment
```

---

# 64. Final Operational Model

## AWS

Set:

```text
CLOUD_ENVIRONMENT=aws
ACTIONS_RUNNER=ubuntu-latest
```

Result:

```text
GitHub Actions
      |
      v
GitHub-hosted runner
      |
      v
GitHub OIDC
      |
      v
AWS IAM
      |
      v
AWS STS
      |
      v
Real AWS services
```

---

## Floci

Set:

```text
CLOUD_ENVIRONMENT=floci
ACTIONS_RUNNER=floci-local
FLOCI_ENDPOINT=http://localhost:4566
FLOCI_ACCOUNT_ID=000000000000
```

Result:

```text
GitHub Actions
      |
      v
Self-hosted runner
      |
      v
Developer laptop
      |
      v
Floci
      |
      v
localhost:4566
      |
      v
Local AWS-compatible services
```

---

# 65. Final Migration Sequence

The complete implementation sequence is:

```text
1. Install Docker
        |
2. Start Floci
        |
3. Verify AWS CLI -> Floci
        |
4. Install GitHub self-hosted runner
        |
5. Add floci-local label
        |
6. Create CLOUD_ENVIRONMENT
        |
7. Create ACTIONS_RUNNER
        |
8. Create FLOCI_ENDPOINT
        |
9. Create FLOCI_ACCOUNT_ID
        |
10. Create cloud-auth action
        |
11. Create cloud-verify action
        |
12. Keep AWS OIDC diagnostics as AWS-only
        |
13. Refactor terraform.yml
        |
14. Add Terraform Floci provider configuration
        |
15. Test Terraform plan
        |
16. Test Terraform apply
        |
17. Test Terraform state
        |
18. Test CloudFormation
        |
19. Test Docker/ECR/ECS
        |
20. Test EKS/Kubernetes
        |
21. Refactor delete.yml
        |
22. Test complete local deletion
        |
23. Test AWS path again
        |
24. Finalize documentation
```

---

# 66. Definition of Done

The migration is complete when all of the following are true:

### AWS path

```text
[ ] AWS workflow still authenticates through GitHub OIDC
[ ] AWS IAM role still works
[ ] AWS deployment still works
[ ] AWS delete workflow still works
[ ] AWS OIDC diagnostics still work
```

### Floci path

```text
[ ] Floci starts locally
[ ] Self-hosted runner is online
[ ] GitHub Actions can reach Floci
[ ] Floci identity verification works
[ ] Terraform can communicate with Floci
[ ] Terraform plan works
[ ] Terraform apply works for supported resources
[ ] CloudFormation works for required templates/resources
[ ] Docker/ECR/ECS path is validated
[ ] Kubernetes/EKS path is validated
[ ] Delete workflow removes local resources correctly
```

### Safety

```text
[ ] AWS and Floci account IDs are not globally mixed
[ ] AWS ARNs are not globally replaced
[ ] AWS OIDC remains intact
[ ] No production credentials are committed
[ ] Invalid CLOUD_ENVIRONMENT values fail
[ ] Deployment logs clearly show the selected environment
```

---

# 67. Final Principle

The final architecture is not:

```text
AWS -> Floci migration
```

It is:

```text
AWS + Floci
```

The repository becomes a dual-environment infrastructure lab:

```text
                         aws-hybrid-iac-lab
                                  |
                    +-------------+-------------+
                    |                           |
                   AWS                         Floci
                    |                           |
              GitHub OIDC                  Local emulator
                    |                           |
             Real AWS APIs                AWS-compatible APIs
                    |                           |
                    +-------------+-------------+
                                  |
                           Shared IaC
```

This is the recommended architecture because it preserves the original AWS learning path while adding a local, cost-free execution path for development and testing.

The migration should therefore be implemented incrementally:

> **First make Floci work locally. Then connect the self-hosted runner. Then refactor authentication. Then configure Terraform. Then migrate CloudFormation and individual services. Finally migrate the full deployment and deletion workflows.**

Do not attempt to prove the entire lab is Floci-compatible by changing authentication alone.

---