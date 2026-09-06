# AWS Hybrid IaC Lab: Understanding Terraform Backend vs. CloudFormation Storage

## 🚀 Intro

While working on my **AWS Hybrid IaC Lab**, I learned an important practical lesson about managing infrastructure with both **AWS CloudFormation and Terraform**.

My CloudFormation workflow already uses an S3 bucket to store CloudFormation templates, but Terraform has a different requirement: it needs persistent storage for its **Terraform state (`terraform.tfstate`)**. Although technically both can use the same S3 bucket, I decided to follow a cleaner and more professional architecture by keeping the CloudFormation templates and Terraform state separated.

The bigger challenge was automation. Since GitHub Actions runners are temporary, I don't want to manually create or configure the Terraform backend every time. The solution is to automate the **Terraform state bucket bootstrap/verification inside the GitHub Actions workflow**, before running `terraform init`.

The workflow becomes:

**GitHub → OIDC Authentication → Backend Bootstrap/Verify → Terraform Init → Validate → Plan → Apply → AWS Infrastructure**

This helped me understand an important Terraform concept: **Terraform needs its backend available before initialization**, so the backend cannot normally be created by the same Terraform configuration that depends on it.

This is another step toward building a more **automated, secure, and production-style Infrastructure as Code workflow** using AWS, Terraform, CloudFormation, GitHub Actions, and OIDC.

---

# CloudFormation Bucket vs Terraform State Bucket

## 1. Why Are These Two Buckets Different?

You have **two different jobs**, so they should normally use **two different S3 buckets**.

### CloudFormation Template Bucket

This bucket stores your CloudFormation templates, such as:

* `main.yaml`
* Nested CloudFormation templates
* Other YAML/JSON templates

Its purpose is:

```text
GitHub
   ↓
Upload CloudFormation templates
   ↓
S3 CloudFormation Bucket
   ↓
CloudFormation
   ↓
Create/Update Stack
```

### Terraform State Bucket

This bucket stores Terraform's state:

* `terraform.tfstate`
* Terraform state history/versioning, if enabled
* State locking information, depending on the backend configuration/version

Its purpose is:

```text
GitHub Actions
      ↓
Terraform
      ↓
Terraform State Bucket
      ↓
terraform.tfstate
      ↓
Terraform knows what infrastructure it manages
```

---

## 2. Can I Use My Existing CloudFormation Bucket?

### Short Answer: Technically Yes — But I Recommend No

You **can technically use the existing CloudFormation S3 bucket as the Terraform backend bucket**.

For example:

```text
aws-hybrid-iac-lab-bucket
│
├── cloudformation/
│   ├── main.yaml
│   └── nested/
│       └── network.yaml
│
└── terraform/
    └── terraform.tfstate
```

Terraform does not require the bucket to be exclusively used for Terraform.

However, for a **professional lab architecture**, I recommend:

```text
CloudFormation S3 Bucket
        ↓
CloudFormation templates


Terraform S3 Backend Bucket
        ↓
Terraform state
```

The important point is that **the bucket is not required to be dedicated by AWS**, but separating the responsibilities is cleaner.

---

## 3. Why Does Terraform Need an S3 Backend Bucket?

This is the important part.

Terraform creates infrastructure based on its **state**.

Terraform needs to remember things such as:

* Which resources it created
* Resource IDs
* Current configuration/state
* Dependencies
* Resource relationships
* What needs to be created, changed, or destroyed

That information is stored in:

```text
terraform.tfstate
```

With a local backend:

```text
Your PC
   ↓
terraform.tfstate
```

But your GitHub Actions runner is temporary:

```text
GitHub Actions Runner
        ↓
Terraform runs
        ↓
Runner disappears
        ↓
Local state disappears
```

Therefore, you want:

```text
GitHub Actions
      ↓
Terraform
      ↓
S3 Backend
      ↓
terraform.tfstate
```

This allows future GitHub Actions runs to access the same Terraform state.

---

## 4. Why Can't My CloudFormation Bucket Do Both Jobs?

Actually, **it can**.

This is an important clarification.

There is nothing technically wrong with doing:

```text
Existing S3 Bucket
│
├── CloudFormation templates
│
└── Terraform state
```

Terraform does not care that CloudFormation templates are also stored in that bucket.

The reason for creating a separate bucket is **architecture, security, lifecycle management, and separation of responsibilities**, not because Terraform requires a completely separate S3 bucket.

So your question:

> "Why can't I use this bucket instead of creating a new backend bucket?"

### Answer:

**You can.**

If your existing bucket is properly configured and you control its permissions, you can use a prefix such as:

```text
terraform/state/
```

for Terraform state.

For example:

```text
aws-hybrid-iac-lab-templates/
│
├── cloudformation/
│   ├── main.yaml
│   └── nested/
│
└── terraform-state/
    └── terraform.tfstate
```

This is technically valid.

---

## 5. Why I Still Recommend a Separate Bucket

For your **AWS Hybrid IaC Lab**, I recommend:

```text
CloudFormation Bucket
aws-hybrid-iac-lab-cloudformation-templates
        ↓
CloudFormation templates


Terraform State Bucket
aws-hybrid-iac-lab-terraform-state
        ↓
Terraform state
```

### Benefits

* Clear separation of responsibilities
* Easier IAM permissions
* Easier troubleshooting
* Easier lifecycle management
* Lower chance of accidentally deleting state
* Easier backup/versioning strategy
* More closely resembles professional infrastructure design
* Cleaner GitHub Actions architecture

---

## 6. Why Can't Terraform Create Its Own Backend Bucket?

This is the most important technical limitation.

Suppose you configure:

```hcl
terraform {
  backend "s3" {
    bucket = "aws-hybrid-iac-lab-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
```

When you execute:

```bash
terraform init
```

Terraform first needs to connect to:

```text
aws-hybrid-iac-lab-terraform-state
```

**before Terraform can manage your infrastructure.**

Therefore, you cannot normally have:

```text
terraform init
     ↓
Create S3 backend bucket
     ↓
Use that same bucket as backend
```

because Terraform needs the backend **during initialization**.

---

## 7. How Can I Automate the Bucket Creation?

Yes — this is where your **GitHub Actions workflow** comes in.

You do **not** have to manually create the bucket every time.

A professional approach for your lab is:

```text
GitHub
   ↓
GitHub Actions
   ↓
Bootstrap / Verify Backend
   ↓
Create S3 state bucket if necessary
   ↓
Configure security
   ↓
Terraform init
   ↓
Terraform plan
   ↓
Terraform apply
```

The important distinction is:

> The bootstrap process creates or verifies the backend **before** Terraform initializes the main Terraform configuration.

---

## 8. Your Recommended Architecture

For your `aws-hybrid-iac-lab`, I recommend this:

```text
                    GitHub Repository
                           │
             ┌─────────────┴─────────────┐
             │                           │
       CloudFormation                 Terraform
             │                           │
             ↓                           ↓
    Template S3 Bucket           Terraform State S3 Bucket
             │                           │
             ↓                           ↓
      CloudFormation              terraform.tfstate
             │                           │
             └─────────────┬─────────────┘
                           ↓
                    AWS Infrastructure
```

And GitHub Actions handles the automation:

```text
GitHub Actions
      │
      ├── Authenticate using OIDC
      │
      ├── Bootstrap/verify Terraform state bucket
      │
      ├── terraform init
      │
      ├── terraform validate
      │
      ├── terraform plan
      │
      └── terraform apply
```

---

## 9. Final Answer to Your Main Questions

### Question 1: Do I Need a New Terraform State Bucket?

**Not technically.**

You can use your existing CloudFormation bucket.

But I recommend a **separate Terraform state bucket** for your hybrid IaC lab.

---

### Question 2: Why Does Terraform Need an S3 Bucket?

Because Terraform needs persistent remote storage for:

```text
terraform.tfstate
```

GitHub Actions runners are temporary, so relying on local state is not appropriate for your CI/CD workflow.

---

### Question 3: Can My Existing CloudFormation Bucket Store Both?

**Yes.**

For example:

```text
existing-bucket/
│
├── cloudformation/
│   ├── main.yaml
│   └── nested.yaml
│
└── terraform-state/
    └── terraform.tfstate
```

That is technically possible.

---

### Question 4: Should I Do That in My Lab?

**I recommend keeping them separate:**

```text
CloudFormation Bucket
        ↓
CloudFormation templates


Terraform State Bucket
        ↓
Terraform state
```

This gives you a cleaner and more professional architecture.

---

### Question 5: Do I Have to Manually Create the Terraform Bucket?

**No.**

You can automate its creation/verification through your GitHub Actions workflow.

The workflow can do:

```text
1. Authenticate to AWS
2. Check whether Terraform state bucket exists
3. Create it if it doesn't exist
4. Configure required security settings
5. Run terraform init
6. Run terraform plan
7. Run terraform apply
```

---

## 10. The Key Concept to Remember

The most important thing is this:

> **Terraform does not require a separate S3 bucket. It requires a persistent backend.**

A separate bucket is an **architecture recommendation**, not a Terraform requirement.

So you have two valid designs:

### Option A — Shared Bucket

```text
One S3 bucket
│
├── CloudFormation templates
└── Terraform state
```

**Works technically.**

### Option B — Separate Buckets ⭐ Recommended

```text
CloudFormation S3 Bucket
        │
        └── CloudFormation templates

Terraform S3 Backend Bucket
        │
        └── terraform.tfstate
```

**Cleaner and more professional for your `aws-hybrid-iac-lab`.**

And because you want this lab to be **fully automated through GitHub Actions**, the recommended solution is to have the workflow **bootstrap/verify the Terraform backend before running `terraform init`**, rather than manually creating the bucket.
