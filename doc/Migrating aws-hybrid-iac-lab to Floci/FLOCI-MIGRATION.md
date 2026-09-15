# Migrating aws-hybrid-iac-lab to Floci (Self-Hosted Runner)

**Goal:** Run the exact same lab against Floci (local AWS emulator) instead of real AWS, using a GitHub Actions self-hosted runner on your laptop so the existing workflow structure stays intact.

**Read this first:** you asked for a minimal change — swap ARNs, account ID, keys. That covers about half of what's actually needed. The other half is structural (OIDC doesn't apply to Floci at all; Terraform needs to be told where "AWS" now lives). Both are small, but they're not ARN swaps — they're new blocks. This document lists every one, with exact file and line references pulled from your repo.

---

## 0. Prerequisites on your laptop

```bash
# Docker must be running — Floci uses it for EC2, ECS, Lambda, RDS, EKS
docker --version

# Run Floci (mount the docker socket so EC2/ECS/EKS get real containers, not shallow mocks)
docker run -d --name floci -p 4566:4566 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -u root floci/floci:latest

# Sanity check
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
aws sts get-caller-identity
# → Account: 000000000000   ← this is Floci's fixed fake account ID, not one you choose
```

**`000000000000` is the account ID you'll use everywhere** you currently have `537236558357`. It's not a real account you register — it's what Floci always reports.

---

## 1. Register the self-hosted runner

`GitHub repo → Settings → Actions → Runners → New self-hosted runner`. Follow the OS-specific install commands GitHub gives you, then run it as a service so it survives reboots:

```bash
./config.sh --url https://github.com/<you>/aws-hybrid-iac-lab --token <token> --labels floci-local
./svc.sh install
./svc.sh start
```

### Edit every workflow's `runs-on`

| File | Change |
|---|---|
| `.github/workflows/terraform.yml` | `runs-on: ubuntu-latest` → `runs-on: [self-hosted, floci-local]` |
| `.github/workflows/docker.yml` | same |
| `.github/workflows/kubernetes.yml` | same |
| `.github/workflows/delete.yml` | same |

`main-deploy.yaml` itself doesn't need `runs-on` changed if it only orchestrates `workflow_call`s — the called workflows carry their own `runs-on`.

---

## 2. Replace the OIDC credentials step (the biggest real change)

This is the piece that isn't an ARN swap. Floci has no identity verification — it accepts `test`/`test` for anything. Keeping the OIDC → STS → AssumeRole chain would mean authenticating against *real* AWS and then trying to use those credentials against Floci, which doesn't work. So this step gets replaced, not edited.

**In each of `terraform.yml`, `docker.yml`, `kubernetes.yml`, `delete.yml`**, find the step named `Configure AWS Credentials Using OIDC` (or `Configure AWS Credentials`) and replace it:

```yaml
# BEFORE
- name: Configure AWS Credentials Using OIDC
  uses: aws-actions/configure-aws-credentials@v5.1.1
  with:
    role-to-assume: ${{ vars.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}

# AFTER
- name: Configure AWS Credentials (Floci)
  run: |
    echo "AWS_ENDPOINT_URL=http://localhost:4566" >> "$GITHUB_ENV"
    echo "AWS_ACCESS_KEY_ID=test" >> "$GITHUB_ENV"
    echo "AWS_SECRET_ACCESS_KEY=test" >> "$GITHUB_ENV"
    echo "AWS_DEFAULT_REGION=us-east-1" >> "$GITHUB_ENV"
```

Also remove/no-op the **"Verify AWS Identity"** and **"Diagnose GitHub OIDC Claims"** steps in `terraform.yml` and `delete.yml` — there's no OIDC token to diagnose and no role name to verify against. Comment them out rather than delete, so you can revert easily if you ever point this back at real AWS.

You can also drop `permissions: id-token: write` from `main-deploy.yaml` since nothing mints or uses an OIDC token anymore — but leaving it is harmless if you'd rather touch fewer files.

---

## 3. Point Terraform at Floci — `infrastructure/terraform/provider.tf`

Add an `endpoints` block and disable the account/region checks Terraform normally does against real AWS:

```hcl
provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudfront     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    ecr            = "http://localhost:4566"
    ecs            = "http://localhost:4566"
    eks            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
}
```

Keep your existing `default_tags` block — Floci accepts tags fine.

---

## 4. Point Terraform state at Floci — `infrastructure/terraform/backend.tf`

**Line 35** currently:
```hcl
    bucket = "aws-hybrid-iac-lab-terraform-state-537236558357"
```
Two choices:

- **Fully local (recommended, matches your zero-cost goal):** point the S3 backend at Floci too, using the `endpoints` argument the S3 backend supports natively:
```hcl
terraform {
  backend "s3" {
    bucket                      = "aws-hybrid-iac-lab-terraform-state-000000000000"
    key                         = "terraform.tfstate"
    region                      = "us-east-1"
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
    endpoints = { s3 = "http://localhost:4566" }
  }
}
```
- **Keep state in real S3, resources in Floci:** leave `backend.tf` untouched. Works, but means you still need a real (free-tier) AWS account just for one small state bucket. Given you're trying to get off AWS billing entirely, the fully-local option above is the better fit.

Also update **`infrastructure/bootstrap/terraform-state/variables.tf` line 29** the same way (`537236558357` → `000000000000`), and re-run the bootstrap layer against Floci to create the (emulated) state bucket before your first `terraform init`.

---

## 5. Delete or neutralize `infrastructure/terraform/iam-imports.tf`

This file's whole purpose is adopting IAM resources that **already exist** in a real account (lines 71, 92, 113, 134, 226 all reference `537236558357`). Floci starts empty — there is nothing to import, and every `import` block will fail with "resource not found." Comment out the entire file's contents (or rename it to `iam-imports.tf.disabled`) rather than editing the ARNs, since editing them to `000000000000` would just produce the same "not found" error against an empty account.

---

## 6. Account ID cleanup — the actual find/replace list

Real functional ARNs (must change, not just cosmetic):

| File | Line(s) | Change |
|---|---|---|
| `infrastructure/terraform/iam.tf` | 329, 1014, 1057, 1084, 1111 | `537236558357` → `000000000000` |
| `infrastructure/terraform/iam-imports.tf` | 71, 92, 113, 134, 226 | Whole file disabled per §5 — no need to edit individually |

Comment-only occurrences (cosmetic, safe to leave, but do them for consistency since you'll be reading these files while debugging):

| File | Lines |
|---|---|
| `infrastructure/cloudformation/nested/ecs.yaml` | 266, 311, 328, 607, 1255, 1686 |
| `infrastructure/cloudformation/nested/ecr.yaml` | 268, 580 |
| `infrastructure/cloudformation/main.yaml` | 143, 1219 |
| `.github/workflows/docker.yml` | 1195 |

Bucket-name references (functional):

| File | Line |
|---|---|
| `.github/workflows/terraform.yml` | 252 — `TF_STATE_BUCKET: "aws-hybrid-iac-lab-terraform-state-537236558357"` → `...-000000000000` |
| `.github/workflows/delete.yml` | 272 — same |

---

## 7. ECR registry hostname — no template edit needed, but verify it

Your `ecr.yaml` output `EcrRepositoryUri` is generated dynamically by whatever's running the ECR API — under Floci that'll resolve to something like `000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566/hybridiaclab-dev-app` rather than a real `amazonaws.com` host. You don't need to hardcode this — `docker.yml`'s existing step **"Verify ECR Repository and Get Repository URI"** already reads it from the stack output at runtime, so it'll pick up whatever Floci returns automatically.

What *does* need a small edit: the **"Login to Amazon ECR"** step, so `aws ecr get-login-password` and `docker login` both target Floci:
```yaml
- name: Login to Amazon ECR (Floci)
  run: |
    aws ecr get-login-password --endpoint-url http://localhost:4566 \
      | docker login --username AWS --password-stdin \
      000000000000.dkr.ecr.us-east-1.localhost.localstack.cloud:4566
```
Since your runner and Floci are both on the same laptop, this resolves fine over loopback — no `/etc/hosts` edit needed.

---

## 8. EKS — one caveat, no template edit needed

`kubernetes.yml`'s **"Configure kubectl"** step runs `aws eks update-kubeconfig --name ... --region ...`. Add `--endpoint-url http://localhost:4566` to that one command. Floci's EKS is k3s-backed and genuinely runs real Kubernetes, so everything downstream (`kubectl apply`, rollout checks) works unmodified. The only thing that won't behave like real AWS: your `service.yaml`'s `type: LoadBalancer` won't get an internet-facing IP — it'll get a local one. Fine for a lab; just don't expect the ALB-style public URL you get on real AWS.

---

## 9. EC2 SSH — two separate things, only one needs a change

Worth knowing: your `ec2.yaml` **doesn't currently configure an AWS keypair at all** (see its comments around lines 517–648) — it deliberately favors SSM Session Manager over SSH, and only opens port 22 in the security group as an option. So there's nothing to "swap" for the AWS-side key. If you actually want SSH into the Floci-emulated instance (Floci runs EC2 as a real Docker container when the socket is mounted, and does inject an SSH key on `RunInstances`), add it:

```bash
aws ec2 create-key-pair --endpoint-url http://localhost:4566 \
  --key-name floci-lab-key --query 'KeyMaterial' --output text > floci-lab-key.pem
chmod 400 floci-lab-key.pem
```
Then add a `KeyName` parameter to `ec2.yaml`'s `Parameters` and pass `floci-lab-key` to it from `main.yaml`.

Separately, **`scripts/github-ec2-setup.sh`'s `github_ec2` SSH key (line 115) has nothing to do with AWS** — it's a keypair generated *on* the instance to let it clone from GitHub. No change needed there except confirming which local port Floci maps the container's SSH to (it won't necessarily be host port 22), and using that port when you `ssh -i floci-lab-key.pem -p <mapped-port> ec2-user@localhost`.

---

## 10. What to leave alone

- All 12 CloudFormation templates' actual resource definitions — untouched. Floci interprets standard CFN, this isn't a resource-level rewrite.
- `docker/`, `kubernetes/*.yaml` manifests — untouched.
- `versions.tf`, `variables.tf`, `locals.tf`, `data.tf` — untouched (the AMI lookup in `data.tf` still works against Floci's EC2 API).
- `scripts/verify-*` and `report-log/` — still useful; just re-run them with `AWS_ENDPOINT_URL` exported first.

---

## 11. Order of operations for your first Floci run

```
1. docker run floci (with socket mounted)          → §0
2. Register + start self-hosted runner              → §1
3. Edit provider.tf, backend.tf                      → §3, §4
4. Disable iam-imports.tf                            → §5
5. Fix account ID + bucket name references           → §6
6. Edit each workflow's runs-on + credentials step   → §1, §2
7. Bootstrap the (now-Floci) state bucket
8. Push → watch main-deploy.yaml run on your runner
```

Once this works, you have a genuinely free, unlimited version of the same lab — worth keeping regardless of what happens to your AWS free tier.
