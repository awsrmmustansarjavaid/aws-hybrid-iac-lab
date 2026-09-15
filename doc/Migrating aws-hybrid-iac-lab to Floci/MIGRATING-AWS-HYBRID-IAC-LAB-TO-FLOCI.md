# Migrating `aws-hybrid-iac-lab` to Floci — Professional Approach

Yes. **Your idea is possible, and I recommend doing it.**

The important point is:

> **Do not delete your existing AWS/OIDC logic.**
> Keep it intact and add a new Floci path beside it.

This will give your lab two modes:

```text
                    aws-hybrid-iac-lab
                           │
                    CLOUD_ENVIRONMENT
                           │
              ┌────────────┴────────────┐
              │                         │
             AWS                      Floci
              │                         │
          GitHub OIDC              test / test
              │                         │
        Real AWS APIs             localhost:4566
```

You can then switch between them using **one GitHub repository variable**.

---

# 1. What I Recommend

I would **not** put everything into a "global variables" file.

Instead, create reusable GitHub Actions for the common logic.

Your existing workflows:

```text
.github/workflows/
├── terraform.yml
├── delete.yml
├── docker.yml
├── kubernetes.yml
└── main-deploy.yaml
```

will use new reusable actions:

```text
.github/actions/
├── cloud-auth/
│   └── action.yml
│
├── cloud-verify/
│   └── action.yml
│
└── aws-oidc-diagnose/
    └── action.yml
```

The responsibilities would be:

| File                           | Responsibility                       |
| ------------------------------ | ------------------------------------ |
| `cloud-auth/action.yml`        | AWS OIDC **or** Floci authentication |
| `cloud-verify/action.yml`      | Verify AWS/Floci identity            |
| `aws-oidc-diagnose/action.yml` | AWS OIDC diagnostics only            |

This is cleaner than copying the same authentication code into four workflows.

---

# 2. One Global Variable Controls Everything

Create this GitHub Actions repository variable:

```text
CLOUD_ENVIRONMENT
```

Possible values:

```text
aws
```

or:

```text
floci
```

For example:

### Real AWS

```text
CLOUD_ENVIRONMENT=aws
```

### Local Floci

```text
CLOUD_ENVIRONMENT=floci
```

You can configure it here:

**GitHub → Repository → Settings → Secrets and variables → Actions → Variables**

You can keep:

```text
AWS_REGION=us-east-1
```

as another repository variable.

---

# 3. Why This Is Better

Instead of having this inside every workflow:

```yaml
Configure AWS Credentials Using OIDC
Verify AWS Identity
Diagnose GitHub OIDC Claims
```

you will have:

```yaml
- name: Configure Cloud Environment
  uses: ./.github/actions/cloud-auth
```

and:

```yaml
- name: Verify Cloud Identity
  uses: ./.github/actions/cloud-verify
```

The workflow doesn't need to care whether it is AWS or Floci.

The reusable action decides.

---

# 4. AWS Mode

When:

```text
CLOUD_ENVIRONMENT=aws
```

the authentication action executes your existing AWS OIDC logic.

Conceptually:

```text
CLOUD_ENVIRONMENT=aws
        │
        ▼
cloud-auth
        │
        ▼
GitHub OIDC
        │
        ▼
AWS IAM Role
        │
        ▼
Real AWS
```

Your existing:

```yaml
aws-actions/configure-aws-credentials
```

remains.

**We don't remove it.**

We simply move that logic into the reusable action.

---

# 5. Floci Mode

When:

```text
CLOUD_ENVIRONMENT=floci
```

the same action takes another path:

```text
CLOUD_ENVIRONMENT=floci
        │
        ▼
cloud-auth
        │
        ▼
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_ENDPOINT_URL=http://localhost:4566
        │
        ▼
Floci
```

There is no OIDC authentication.

That's correct because Floci is running locally.

---

# 6. Your Existing OIDC Code Is Not Deleted

This is important because you specifically don't want to remove your AWS implementation.

Instead of:

```text
DELETE AWS OIDC
ADD Floci
```

we do:

```text
KEEP AWS OIDC
      +
ADD Floci
      +
ADD selector
```

So your project becomes:

```text
                Authentication
                      │
             CLOUD_ENVIRONMENT
                      │
          ┌───────────┴───────────┐
          │                       │
         AWS                    Floci
          │                       │
       OIDC                     test/test
          │                       │
      AWS Role              localhost:4566
```

This is the architecture I recommend.

---

# 7. `cloud-auth/action.yml`

Create:

```text
.github/actions/cloud-auth/action.yml
```

The basic structure would be:

```yaml
name: Cloud Authentication

description: Configure credentials for AWS or Floci

inputs:
  environment:
    description: AWS or Floci
    required: true

  aws-region:
    description: AWS region
    required: true

runs:
  using: composite

  steps:

    - name: Configure AWS Credentials Using OIDC
      if: inputs.environment == 'aws'
      uses: aws-actions/configure-aws-credentials@v5.1.1
      with:
        role-to-assume: ${{ vars.AWS_ROLE_ARN }}
        aws-region: ${{ inputs.aws-region }}

    - name: Configure Floci Credentials
      if: inputs.environment == 'floci'
      shell: bash
      run: |
        echo "AWS_ENDPOINT_URL=http://localhost:4566" >> "$GITHUB_ENV"
        echo "AWS_ACCESS_KEY_ID=test" >> "$GITHUB_ENV"
        echo "AWS_SECRET_ACCESS_KEY=test" >> "$GITHUB_ENV"
        echo "AWS_DEFAULT_REGION=${{ inputs.aws-region }}" >> "$GITHUB_ENV"
```

This is only the basic design.

When we actually modify your repository, I would preserve the **exact options, environment variables, permissions, role ARN handling, and error handling from your current workflow** rather than blindly replacing them.

---

# 8. `cloud-verify/action.yml`

Create:

```text
.github/actions/cloud-verify/action.yml
```

It can handle both environments.

For AWS:

```bash
aws sts get-caller-identity
```

For Floci:

```bash
aws sts get-caller-identity \
  --endpoint-url http://localhost:4566
```

So your workflow only needs:

```yaml
- name: Verify Cloud Identity
  uses: ./.github/actions/cloud-verify
  with:
    environment: ${{ vars.CLOUD_ENVIRONMENT }}
```

---

# 9. OIDC Diagnostics Stay Separate

I strongly recommend **not** combining OIDC diagnostics with Floci.

Why?

Because:

```text
OIDC = AWS authentication mechanism
```

Floci doesn't need it.

Therefore:

```yaml
- name: Diagnose GitHub OIDC Claims
  if: vars.CLOUD_ENVIRONMENT == 'aws'
  uses: ./.github/actions/aws-oidc-diagnose
```

When using AWS:

```text
AWS
 ├── Authentication       ✓
 ├── Identity verification ✓
 └── OIDC diagnostics      ✓
```

When using Floci:

```text
Floci
 ├── Authentication       ✓
 ├── Identity verification ✓
 └── OIDC diagnostics      SKIPPED
```

That's exactly what we want.

---

# 10. Terraform Workflow

Your existing:

```text
terraform.yml
```

would eventually look conceptually like this:

```yaml
jobs:
  terraform:

    runs-on: ...

    steps:

      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure Cloud Environment
        uses: ./.github/actions/cloud-auth
        with:
          environment: ${{ vars.CLOUD_ENVIRONMENT }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Verify Cloud Identity
        uses: ./.github/actions/cloud-verify
        with:
          environment: ${{ vars.CLOUD_ENVIRONMENT }}

      - name: Diagnose GitHub OIDC Claims
        if: vars.CLOUD_ENVIRONMENT == 'aws'
        uses: ./.github/actions/aws-oidc-diagnose

      # EVERYTHING ELSE
      # remains your existing Terraform logic
```

The important part is that we **don't rewrite the Terraform deployment logic**.

---

# 11. Delete Workflow

The same architecture applies to:

```text
delete.yml
```

It becomes:

```yaml
- name: Configure Cloud Environment
  uses: ./.github/actions/cloud-auth
  with:
    environment: ${{ vars.CLOUD_ENVIRONMENT }}
    aws-region: ${{ vars.AWS_REGION }}

- name: Verify Cloud Identity
  uses: ./.github/actions/cloud-verify
  with:
    environment: ${{ vars.CLOUD_ENVIRONMENT }}

- name: Diagnose GitHub OIDC Claims
  if: vars.CLOUD_ENVIRONMENT == 'aws'
  uses: ./.github/actions/aws-oidc-diagnose
```

Then the existing deletion logic continues.

---

# 12. Docker and Kubernetes Can Use the Same System

Later:

```text
docker.yml
kubernetes.yml
```

can also use:

```yaml
uses: ./.github/actions/cloud-auth
```

and:

```yaml
uses: ./.github/actions/cloud-verify
```

This gives you one authentication implementation for the entire lab.

---

# 13. Self-Hosted Runner Is Still Separate

There is one thing I would **not** mix into the authentication action:

```text
runs-on
```

Your Floci environment needs a self-hosted runner because Floci is running on your laptop.

So:

### AWS

```yaml
runs-on: ubuntu-latest
```

### Floci

```yaml
runs-on: [self-hosted, floci-local]
```

We can also make runner selection environment-aware later, but I would **not put runner logic inside `cloud-auth`**.

Authentication and runner selection are separate concerns.

---

# 14. Terraform Also Needs Environment Switching

There is another important part that Claude correctly identified.

Moving OIDC into a reusable action **doesn't automatically make Terraform use Floci**.

You still need:

```text
Terraform Provider
        │
        ├── AWS → real AWS endpoints
        │
        └── Floci → localhost:4566
```

So eventually your Terraform provider should have Floci endpoint configuration.

However, I would **not immediately hardcode Floci into your existing provider**.

A more professional design is:

```text
CLOUD_ENVIRONMENT
        │
        ▼
Terraform configuration
        │
   ┌────┴────┐
   │         │
  AWS      Floci
   │         │
AWS APIs   localhost:4566
```

That means AWS remains your normal/default configuration.

Floci becomes an additional execution mode.

---

# 15. CloudFormation Should Follow the Same Principle

Your CloudFormation templates don't need to become "Floci templates."

Keep:

```text
infrastructure/cloudformation/
```

as your existing infrastructure definition.

Then the execution environment changes:

```text
CloudFormation templates
        │
        ▼
AWS CLI
        │
   ┌────┴────┐
   │         │
 AWS       Floci
```

This is much better than creating:

```text
cloudformation-aws/
cloudformation-floci/
```

because then you would have two infrastructure implementations to maintain.

---

# 16. Don't Change the Existing AWS Architecture

I recommend keeping your existing structure:

```text
infrastructure/
├── cloudformation/
├── terraform/
└── bootstrap/
```

and:

```text
.github/
└── workflows/
```

Then only add:

```text
.github/actions/
```

and the Floci-specific configuration where necessary.

So we're **extending** the lab rather than creating a second lab.

---

# 17. Recommended Final Architecture

I would target this:

```text
aws-hybrid-iac-lab
│
├── .github/
│   │
│   ├── actions/
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
├── kubernetes/
└── scripts/
```

---

# 18. How You Will Use It

## Run against AWS

Set:

```text
CLOUD_ENVIRONMENT=aws
```

Then:

```text
GitHub Actions
      ↓
AWS OIDC
      ↓
AWS IAM
      ↓
AWS services
```

Your existing AWS functionality remains.

---

## Run against Floci

Set:

```text
CLOUD_ENVIRONMENT=floci
```

Then:

```text
GitHub Actions
      ↓
Self-hosted runner
      ↓
Floci
      ↓
localhost:4566
      ↓
Local AWS-compatible services
```

No AWS account is required for that execution path.

---

# 19. One Important Improvement to Claude's Proposal

I would **not immediately replace**:

```yaml
runs-on: ubuntu-latest
```

everywhere with:

```yaml
runs-on: [self-hosted, floci-local]
```

because that would make your workflows permanently dependent on your laptop.

Instead, eventually we can make the runner selection itself environment-aware.

For example:

```text
CLOUD_ENVIRONMENT=aws
        ↓
GitHub-hosted runner

CLOUD_ENVIRONMENT=floci
        ↓
Self-hosted Floci runner
```

That gives you a much more complete AWS/Floci switch.

---

# 20. The Most Important Rule

For your migration, I recommend this principle:

> **AWS is not being replaced. Floci is being added as a second execution backend.**

Therefore:

```text
❌ Delete OIDC
❌ Delete AWS workflow
❌ Rewrite CFN for Floci
❌ Create duplicate infrastructure

Instead:

✅ Keep AWS OIDC
✅ Keep AWS deployment logic
✅ Add Floci authentication
✅ Add Floci endpoints
✅ Add environment selector
✅ Reuse authentication actions
✅ Add self-hosted runner
✅ Keep the same infrastructure definitions where compatible
```

This will make your `aws-hybrid-iac-lab` much more professional and, importantly, you'll be able to demonstrate **both real AWS deployment and local AWS-compatible deployment from the same repository**.

### Next step

Before changing any files, I recommend we do this **safely in two phases**:

**Phase 1 — Authentication refactoring**

* inspect your actual `terraform.yml`
* inspect your actual `delete.yml`
* extract the existing OIDC/identity/diagnostic logic
* create the three reusable actions
* keep the AWS behavior unchanged

**Phase 2 — Floci integration**

* add `CLOUD_ENVIRONMENT`
* add Floci authentication branch
* add self-hosted runner support
* configure Terraform/CloudFormation/AWS CLI endpoints
* add Floci-specific logic without deleting the AWS path

That way we can make the migration **incrementally and verify each change locally**, rather than modifying the whole lab at once.

---
