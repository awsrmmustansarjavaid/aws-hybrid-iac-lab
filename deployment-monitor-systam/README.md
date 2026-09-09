# AWS Hybrid IaC Lab — Real-Time Deployment Monitoring & Root-Cause Diagnosis

### Real Time Monitoring

## Purpose

This directory contains the PowerShell-based deployment monitoring
system used by the AWS Hybrid IaC Lab.

The system monitors CloudFormation while Terraform is executing.

---

### 1. Architecture

```
GitHub Actions
       |
       v
Start-Deployment.ps1
       |
       +-----------------------+
       |                       |
       v                       v
CloudFormation Monitor     Terraform Apply
       |                       |
       |                       |
       +-----------+-----------+
                   |
                   v
          Generate-Report.ps1
                   |
                   v
          deployment-summary.md
                   |
                   v
          diagnosis.json
```

### 2. What This System Is

The system we designed is a **Real-Time Infrastructure Deployment Monitoring and Failure-Diagnosis System** for your AWS Hybrid IaC Lab.

Its main purpose is to make Terraform deployment **observable while it is actually running**, instead of waiting for:

> Terraform Apply → Failure → Read logs manually → Open CloudFormation → Find the real error

The new model changes that into:

> **Terraform Apply + CloudFormation Monitoring + Nested-Stack Monitoring + Live Diagnostics → Correlation → Root-Cause Report**

So Terraform remains responsible for **orchestrating the infrastructure deployment**, while the monitoring system independently watches what AWS CloudFormation is doing underneath.

---

### 3. High-Level Architecture

The system can be understood as five layers:

```text
                    GitHub Actions
                         │
                         ▼
              ┌─────────────────────┐
              │     Step 15          │
              │ Terraform Apply      │
              └──────────┬──────────┘
                         │
             ┌───────────┴───────────┐
             │                       │
             ▼                       ▼
    ┌─────────────────┐     ┌─────────────────────┐
    │ Terraform       │     │ CloudFormation      │
    │ Process         │     │ Live Monitor        │
    │                 │     │                     │
    │ terraform       │     │ Root Stack          │
    │ apply -json     │     │ Nested Stacks       │
    └────────┬────────┘     └──────────┬──────────┘
             │                         │
             ▼                         ▼
      terraform.jsonl          CloudFormation Events
      terraform.log            Operation IDs
                                Stack Status
                                Failure Events
                                      │
                                      ▼
                         ┌──────────────────────┐
                         │ Correlation Engine   │
                         │                      │
                         │ Terraform + CFN      │
                         │ timestamps           │
                         │ resources            │
                         │ errors               │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Diagnosis Report     │
                         │                      │
                         │ Root Cause           │
                         │ Downstream Errors    │
                         │ Evidence             │
                         │ Recommendations      │
                         └──────────────────────┘
```

---

### 4. How the System Actually Works

### Phase 1 — GitHub Actions Starts Deployment

GitHub Actions reaches your deployment step.

For example:

```text
Step 15
Terraform Apply + Live CloudFormation Diagnostics
```

The system creates a unique:

```text
Deployment Correlation ID
```

For example:

```text
DEPLOY-20260909-085100-RUN34255678413
```

This ID becomes the identity of the deployment investigation.

That means all evidence can be associated with one deployment:

```text
GitHub Run
     │
     ├── Deployment ID
     │
     ├── Terraform logs
     │
     ├── CloudFormation operation
     │
     ├── CloudFormation events
     │
     └── Final diagnosis
```

---

### 5. Phase 2 — Terraform Starts

Instead of simply running:

```powershell
terraform apply
```

the system runs Terraform in machine-readable mode:

```powershell
terraform apply -json
```

This is important because Terraform produces structured JSON events while it is running.

The system captures:

```text
terraform.jsonl
```

and also a human-readable:

```text
terraform.log
```

So you have two forms of evidence:

### Structured evidence

```text
terraform.jsonl
```

Useful for automated analysis.

### Human-readable evidence

```text
terraform.log
```

Useful for manually reviewing the deployment.

---

### 6. Phase 3 — CloudFormation Monitoring Starts at the Same Time

This is one of the most important improvements.

The CloudFormation monitor does **not wait for Terraform to finish**.

Instead:

```text
Terraform Process
       │
       │ running
       ▼
CloudFormation Monitor
       │
       │ running simultaneously
       ▼
AWS CloudFormation
```

So while Terraform is waiting for AWS:

```text
Terraform:
Still waiting...
```

the monitor can already show:

```text
CloudFormation:
EKSCluster CREATE_IN_PROGRESS

EKSClusterRole CREATE_COMPLETE

NodeGroup CREATE_IN_PROGRESS

NodeGroup CREATE_FAILED
```

This gives you visibility **during the deployment**, not after it.

---

### 7. Phase 4 — Root Stack Discovery

The monitor first watches your root stack:

```text
hybridiaclab-dev-MainStack
```

Then it discovers nested stacks underneath it.

For example:

```text
hybridiaclab-dev-MainStack
│
├── NetworkStack
├── SecurityStack
├── ComputeStack
├── DatabaseStack
├── EKSStack
│   ├── EKS Cluster
│   ├── Node Group
│   └── IAM resources
│
└── ApplicationStack
```

The monitor does not assume that only the root stack matters.

It follows the CloudFormation hierarchy.

That is particularly important for your architecture because a root CloudFormation stack can report a general failure while the **real error happened several levels deeper**.

---

### 8. Phase 5 — CloudFormation Operation IDs

Another important principle is **operation correlation**.

Suppose CloudFormation performs an update:

```text
Operation ID:
abc12345-....
```

The monitor associates events with that operation.

Conceptually:

```text
Deployment ID
     │
     ▼
CFN Root Stack
     │
     └── Operation ID
            │
            ├── Network
            ├── IAM
            ├── EKS
            └── Nested Stack
```

This is much better than simply looking at the latest CloudFormation events.

Why?

Because CloudFormation may have historical events from previous deployments.

The operation ID helps answer:

> **Which exact CloudFormation operation belongs to this Terraform deployment?**

---

### 9. Phase 6 — Live Event Collection

The monitor repeatedly queries CloudFormation.

For example, every few seconds:

```text
AWS CloudFormation
        │
        ▼
Describe Stack
        │
        ▼
Describe Stack Resources
        │
        ▼
Describe Events
        │
        ▼
Monitor
```

It captures events such as:

```text
CREATE_IN_PROGRESS
CREATE_COMPLETE
CREATE_FAILED

UPDATE_IN_PROGRESS
UPDATE_COMPLETE
UPDATE_FAILED

DELETE_IN_PROGRESS
DELETE_COMPLETE

ROLLBACK_IN_PROGRESS
ROLLBACK_COMPLETE
ROLLBACK_FAILED
```

These are written immediately into:

```text
cloudformation-events.jsonl
```

and:

```text
cloudformation-events.log
```

---

### 10. Phase 7 — Failure Detection

Suppose your EKS node group fails.

The monitor might detect:

```text
AWS::EKS::Nodegroup
CREATE_FAILED
```

with an AWS message such as:

```text
NodeCreationFailure
```

Instead of waiting for Terraform to eventually report:

```text
Error: creating CloudFormation Stack failed
```

the monitor has already identified the deeper AWS event.

This gives us two different levels of information:

### Terraform-level error

```text
CloudFormation stack failed
```

### AWS-level error

```text
EKS Node Group failed because ...
```

The second one is usually much more useful for diagnosis.

---

### 11. Phase 8 — Root Cause vs Downstream Error

This is one of the most important principles of the system.

Consider:

```text
EKS Node Group
       │
       ▼
CREATE_FAILED
       │
       ▼
CloudFormation Rollback
       │
       ▼
Root Stack UPDATE_ROLLBACK_IN_PROGRESS
       │
       ▼
Terraform Apply FAILED
       │
       ▼
GitHub Actions FAILED
```

There are several failures here.

But they are **not all root causes**.

The system tries to identify:

### Primary failure

```text
EKS Node Group CREATE_FAILED
```

### Consequences

```text
CloudFormation rollback
```

then:

```text
Terraform failed
```

then:

```text
GitHub Actions step failed
```

So the final report can say something like:

> **Confirmed root cause:** CloudFormation failed while provisioning the EKS node group. Terraform and GitHub Actions failures occurred downstream as a consequence of the CloudFormation deployment failure.

That is much more professional than simply saying:

> Terraform failed.

---

### 12. Phase 9 — Failure Classification

The system also categorizes failures.

For example:

```text
IAM / PERMISSIONS
EKS / NODE PROVISIONING
NETWORKING
RESOURCE NAMING / EXISTENCE
CLOUDFORMATION VALIDATION
CLOUDFORMATION ROLLBACK
```

Suppose the AWS error contains:

```text
AccessDenied
iam:PassRole
```

The system can classify it as:

```text
Category:
IAM / PERMISSIONS
```

If it sees:

```text
NodeCreationFailure
```

it can classify:

```text
Category:
EKS / NODE PROVISIONING
```

This is the beginning of an automated **diagnostic engine**.

---

### 13. Phase 10 — Final Evidence Correlation

At the end, the system compares the evidence.

Conceptually:

```text
                    Deployment
                        │
       ┌────────────────┼─────────────────┐
       │                │                 │
       ▼                ▼                 ▼
   GitHub Logs      Terraform Logs    CloudFormation
                                          │
                                          ▼
                                     Nested Stacks
                                          │
                                          ▼
                                     AWS Events
                        │
                        ▼
                 Correlation Engine
                        │
                        ▼
                  Root Cause
```

The important question becomes:

> **What failed first, where did it fail, and which later errors were merely consequences?**

---

### 14. The Final Diagnostic Report

The system generates things such as:

```text
deployment-summary.md
diagnosis.json
```

The report can contain:

```text
Deployment ID
GitHub Run ID
Terraform Exit Code
CloudFormation Stack
CloudFormation Operation ID
Final Stack Status
Nested Stack Status
Primary Failure
Failure Category
Root Cause Confidence
Downstream Failures
Timeline
Evidence
Recommendations
```

For example:

```text
============================================================
DEPLOYMENT DIAGNOSIS
============================================================

Deployment:
DEPLOY-20260909-085100-RUN34255678413

Terraform:
FAILED

CloudFormation:
UPDATE_ROLLBACK_COMPLETE

Primary Failure:
EKS Node Group CREATE_FAILED

Category:
EKS / NODE PROVISIONING

Root Cause:
CloudFormation failed while provisioning the EKS
managed node group.

Downstream:
Terraform reported the CloudFormation failure.
GitHub Actions marked the deployment step as failed.

Confidence:
CONFIRMED
```

---

### 15. What Makes This System Different From Normal Terraform

A normal deployment usually looks like:

```text
Terraform
   │
   ▼
AWS
   │
   ▼
wait...
   │
   ▼
failure
   │
   ▼
read logs
```

Your new system works like:

```text
Terraform
   │
   ├──────────────► Terraform telemetry
   │
   │
   └──────────────► CloudFormation monitor
                         │
                         ├── Root stack
                         ├── Nested stacks
                         ├── Operations
                         ├── Events
                         └── Failures
                                  │
                                  ▼
                            Correlation
                                  │
                                  ▼
                             Diagnosis
```

This is much closer to how a **real DevOps deployment observability system** works.

---

### 16. Core Principle Model

The system is based on several important engineering principles.

#### Principle 1 — Observe, Don't Guess

Instead of saying:

> "Terraform failed, probably IAM."

the system collects AWS evidence first.

```text
Evidence
   ↓
Analysis
   ↓
Conclusion
```

---

#### Principle 2 — Correlate Everything

Every deployment should have an identity.

```text
GitHub Run ID
      +
Deployment ID
      +
Terraform process
      +
CloudFormation operation
      +
Stack events
```

This allows you to reconstruct the deployment.

---

#### Principle 3 — Find the Earliest Meaningful Failure

The last error is not necessarily the real error.

For example:

```text
EKS failure
     ↓
CFN rollback
     ↓
Terraform failure
     ↓
GitHub failure
```

The system looks toward the **earliest meaningful infrastructure failure**.

---

#### Principle 4 — Parent Failure ≠ Root Cause

This is extremely important with nested CloudFormation.

For example:

```text
MainStack FAILED
```

doesn't tell you enough.

You need:

```text
MainStack
   ↓
EKSStack
   ↓
NodeGroup
   ↓
CREATE_FAILED
   ↓
actual AWS reason
```

---

#### Principle 5 — Real-Time Observability

Do not wait until the deployment finishes.

Instead:

```text
Deployment running
       │
       ├── Monitor
       ├── Capture
       ├── Analyze
       └── Display
```

---

#### Principle 6 — Evidence-Based Diagnosis

The report should distinguish:

```text
CONFIRMED
LIKELY
UNCONFIRMED
```

This prevents the system from presenting a guess as fact.

---

#### Principle 7 — Separate Root Cause From Consequences

For example:

```text
AWS Resource Failure
        ↓
CloudFormation Failure
        ↓
Terraform Failure
        ↓
GitHub Failure
```

Only the first meaningful infrastructure failure should normally be treated as the root cause.

---

### 17. Key Benefits

#### 1. Much Faster Troubleshooting

Without monitoring:

```text
Deployment failed
       ↓
Open AWS Console
       ↓
Find stack
       ↓
Find nested stack
       ↓
Find event
       ↓
Find actual error
```

With monitoring:

```text
Deployment failed
       ↓
Open artifact
       ↓
Read diagnosis
       ↓
See primary failure
```

---

#### 2. Real-Time Visibility

You can see what AWS is doing while Terraform is still running.

---

#### 3. Better EKS Troubleshooting

EKS deployments can involve:

```text
IAM
VPC
Subnets
Security Groups
Cluster
Node Groups
Roles
Policies
Networking
```

A simple Terraform error often hides the real problem.

Your monitor exposes the CloudFormation/AWS layer.

---

#### 4. Nested Stack Visibility

Instead of only monitoring:

```text
MainStack
```

you can monitor:

```text
MainStack
 ├── Stack A
 ├── Stack B
 ├── Stack C
 └── Stack D
```

---

#### 5. Professional CI/CD Observability

The architecture begins to resemble:

```text
CI/CD
 +
Infrastructure as Code
 +
Observability
 +
Automated Diagnostics
```

rather than just:

```text
CI/CD
 +
Terraform
```

---

#### 6. Historical Evidence

Your GitHub Actions artifact gives you a deployment investigation package:

```text
deployment-logs/
│
├── terraform.jsonl
├── terraform.log
├── cloudformation-events.jsonl
├── cloudformation-events.log
├── cloudformation-failures.json
├── cloudformation-metadata.json
├── diagnosis.json
└── deployment-summary.md
```

This is valuable for debugging later.

---

### 18. Skills You Are Improving

This project is actually teaching you **far more than Terraform**.

## Terraform

You are improving:

* Terraform apply lifecycle
* `terraform apply -json`
* Terraform process management
* Terraform exit codes
* Terraform/IaC troubleshooting
* Terraform + CloudFormation integration

---

#### AWS CloudFormation

You are learning:

* Root stacks
* Nested stacks
* Stack resources
* Stack events
* Stack lifecycle
* Rollbacks
* Operation IDs
* Failure states
* AWS resource provisioning

This is particularly valuable because CloudFormation is often underneath higher-level AWS provisioning workflows.

---

#### AWS EKS

You are learning that EKS is not just:

```text
Create cluster
```

It involves:

```text
IAM
VPC
Subnets
Security Groups
Cluster
Node Groups
IAM Roles
Networking
AWS infrastructure provisioning
```

That gives you much deeper EKS troubleshooting ability.

---

### 19. PowerShell Automation

You are also improving your PowerShell skills.

For example:

```powershell
Start-Process
Get-Process
WaitForExit()
Test-Path
Join-Path
ConvertFrom-Json
ConvertTo-Json
```

You're moving from simple PowerShell commands toward **automation engineering**.

---

### 20. AWS CLI

You're learning how to automate AWS instead of relying only on the console.

For example:

```text
aws cloudformation describe-stacks
aws cloudformation describe-stack-events
aws cloudformation describe-stack-resources
aws cloudformation describe-events
```

This is an important Cloud Engineer/DevOps skill.

---

### 21. GitHub Actions

You're improving:

* Workflow design
* Step dependencies
* Environment variables
* PowerShell inside GitHub runners
* Exit codes
* Artifact collection
* Failure handling
* CI/CD observability

And importantly:

```yaml
if: ${{ always() }}
```

teaches you how to preserve diagnostics even when deployment fails.

---

### 22. JSON and Structured Logging

You are moving away from only reading plain text.

Instead:

```text
JSONL
 ↓
Machine-readable events
 ↓
Automation
 ↓
Analysis
```

This is an important transition from beginner scripting toward professional automation.

---

### 23. Log Correlation

This is probably one of the most valuable skills you're gaining.

You are learning to correlate:

```text
GitHub
   ↓
Terraform
   ↓
CloudFormation
   ↓
Nested CloudFormation
   ↓
AWS Resource
```

This is essentially a simplified form of **distributed-system troubleshooting**.

---

### 24. Root-Cause Analysis

You're learning an important professional debugging question:

> **"What actually failed first?"**

rather than:

> **"What command returned an error?"**

That difference is huge.

---

### 25. Observability Thinking

Your project is introducing you to the same general thinking used in production systems:

```text
Observe
   ↓
Collect
   ↓
Correlate
   ↓
Analyze
   ↓
Diagnose
   ↓
Report
```

This is the foundation of modern observability.

---

### 26. Your Skill Progression

You can think of your learning progression like this:

```text
Level 1
AWS CLI
   ↓
Level 2
Terraform
   ↓
Level 3
CloudFormation
   ↓
Level 4
GitHub Actions
   ↓
Level 5
PowerShell Automation
   ↓
Level 6
Structured Logging
   ↓
Level 7
Real-Time Monitoring
   ↓
Level 8
Log Correlation
   ↓
Level 9
Root-Cause Analysis
   ↓
Level 10
Infrastructure Observability
```

That's a **significant jump in DevOps maturity**.

---

### 27. The Most Important Concept to Remember

If you remember only one thing from this project, remember this:

```text
              ERROR
                │
                ▼
        Don't immediately
        blame Terraform.
                │
                ▼
       Find the first real
       infrastructure failure.
                │
                ▼
       Trace the dependency
              chain.
                │
                ▼
       Separate ROOT CAUSE
              from
       DOWNSTREAM FAILURES.
```

For your AWS Hybrid IaC Lab, the ultimate goal is therefore not simply:

> **"Make Terraform apply succeed."**

It is:

> **"Build infrastructure that can be deployed, observed, correlated, diagnosed, and explained when something goes wrong."**

That is the part of this project that makes it particularly valuable as a **DevOps/Cloud Engineering portfolio project**.

---

### 1. Repository structure

Create:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── infrastructure/
│   └── terraform/
│
├── deployment-monitor-systam/
│       ├── Start-Deployment.ps1
│       ├── Monitor-CloudFormation.ps1
│       ├── Generate-Report.ps1
│       └── failure-rules.json
│
└── deployment-logs/
```

I would also make a few important corrections to the previous version before you use it:

* The monitor will use your new root-level directory.
* It will discover **CloudFormation Operation IDs** from `LastOperations`, which AWS now exposes through `describe-stacks`. ([AWS Documentation][1])
* It will use `describe-events --operation-id` for operation-level diagnostics and failed-event filtering. ([AWS Documentation][2])
* It will still keep `describe-stack-events` as a fallback because those events include `OperationId` as well. ([AWS Documentation][3])
* It will monitor nested stacks recursively.
* Terraform will remain authoritative for the final process exit code.
* We will **not** kill the monitor after an arbitrary 5/20 seconds. It will receive a stop signal and finish after CloudFormation reaches a terminal state.
* It will create a final diagnosis comparing Terraform + CloudFormation evidence.
* All diagnostic files will be placed under `deployment-logs/`.
* Step 15 will reference `deployment-monitor-systam/`.

So I recommend replacing the previous implementation with the following **final version**.

---

### 1. Final directory structure

Your repository should look like this:

```text
aws-hybrid-iac-lab/
│
├── .github/
│   └── workflows/
│       └── terraform.yml
│
├── deployment-monitor-systam/
│   │
│   ├── failure-rules.json
│   ├── Monitor-CloudFormation.ps1
│   ├── Start-Deployment.ps1
│   ├── Generate-Report.ps1
│   └── README.md
│
├── infrastructure/
│   ├── cloudformation/
│   │   ├── main.yaml
│   │   └── nested/
│   │       ├── eks.yaml
│   │       ├── vpc.yaml
│   │       └── ...
│   │
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── ...
│
└── deployment-logs/
    └── created automatically
```

You **do not** need to manually create `deployment-logs`.



---

### 2. `failure-rules.json`

Create:

```text
aws-hybrid-iac-lab/deployment-monitor-systam/failure-rules.json
```

```json
{
  "rules": [
    {
      "category": "IAM / PERMISSIONS",
      "priority": 1,
      "patterns": [
        "AccessDenied",
        "is not authorized",
        "not authorized to perform",
        "UnauthorizedOperation",
        "Access Denied",
        "authorization",
        "iam:"
      ],
      "recommendation": "Inspect the IAM role used by CloudFormation and verify the required service permissions."
    },
    {
      "category": "IAM / PASSROLE",
      "priority": 1,
      "patterns": [
        "iam:PassRole",
        "PassRole",
        "cannot pass role",
        "not authorized to perform iam:PassRole"
      ],
      "recommendation": "Verify that the CloudFormation execution role has iam:PassRole permission for the target service role."
    },
    {
      "category": "EKS / NODE PROVISIONING",
      "priority": 1,
      "patterns": [
        "EKS",
        "eks:",
        "NodeCreationFailure",
        "NodeCreationFailure",
        "Node group",
        "node group",
        "Amazon EKS"
      ],
      "recommendation": "Inspect EKS cluster, node group IAM roles, subnet connectivity, security groups, instance profile, AMI compatibility, and service quotas."
    },
    {
      "category": "NETWORKING",
      "priority": 1,
      "patterns": [
        "VPC",
        "Subnet",
        "RouteTable",
        "Route Table",
        "SecurityGroup",
        "security group",
        "InternetGateway",
        "NatGateway",
        "NAT Gateway",
        "availability zone"
      ],
      "recommendation": "Inspect VPC, subnet, route table, NAT/Internet Gateway, security group, and Availability Zone configuration."
    },
    {
      "category": "RESOURCE NAMING / EXISTENCE",
      "priority": 2,
      "patterns": [
        "already exists",
        "AlreadyExists",
        "Resource already exists",
        "does not exist",
        "not found",
        "NoSuch",
        "EntityAlreadyExists"
      ],
      "recommendation": "Check whether the resource already exists, was deleted manually, or conflicts with another stack/resource."
    },
    {
      "category": "CLOUDFORMATION TEMPLATE",
      "priority": 1,
      "patterns": [
        "Template format error",
        "Invalid template",
        "TemplateURL",
        "Template validation error",
        "Unresolved resource dependencies",
        "Fn::GetAtt",
        "does not exist in the template"
      ],
      "recommendation": "Validate the CloudFormation template and verify parameters, dependencies, references, TemplateURL values, and nested stack templates."
    },
    {
      "category": "S3 / CLOUDFORMATION TEMPLATE",
      "priority": 1,
      "patterns": [
        "S3 object",
        "NoSuchKey",
        "NoSuchBucket",
        "The specified key does not exist",
        "does not exist in bucket"
      ],
      "recommendation": "Verify the S3 bucket, object key, region, permissions, and that the referenced CloudFormation template actually exists."
    },
    {
      "category": "LAMBDA",
      "priority": 2,
      "patterns": [
        "AWS::Lambda",
        "Lambda",
        "lambda",
        "function",
        "Layer"
      ],
      "recommendation": "Inspect Lambda role permissions, runtime, architecture, layer compatibility, package contents, environment variables, and dependencies."
    },
    {
      "category": "API GATEWAY",
      "priority": 2,
      "patterns": [
        "AWS::ApiGateway",
        "API Gateway",
        "apigateway",
        "ApiGateway"
      ],
      "recommendation": "Inspect API Gateway resource configuration, IAM roles, integrations, deployments, authorizers, VPC links, and dependencies."
    },
    {
      "category": "RDS",
      "priority": 2,
      "patterns": [
        "AWS::RDS",
        "RDS",
        "DBInstance",
        "DBCluster"
      ],
      "recommendation": "Inspect subnet groups, security groups, engine/version, credentials, parameter groups, storage, and network connectivity."
    },
    {
      "category": "DYNAMODB",
      "priority": 2,
      "patterns": [
        "AWS::DynamoDB",
        "DynamoDB",
        "dynamodb"
      ],
      "recommendation": "Inspect table name conflicts, billing mode, key schema, indexes, encryption, and IAM permissions."
    },
    {
      "category": "ROLLBACK",
      "priority": 3,
      "patterns": [
        "ROLLBACK_FAILED",
        "UPDATE_ROLLBACK_FAILED",
        "ROLLBACK_COMPLETE",
        "UPDATE_ROLLBACK_COMPLETE"
      ],
      "recommendation": "Do not treat rollback status as the original root cause. Find the earliest CREATE_FAILED or UPDATE_FAILED event before rollback."
    }
  ]
}
```

---

### 3. `Monitor-CloudFormation.ps1`

Create:

```text
aws-hybrid-iac-lab/deployment-monitor-systam/Monitor-CloudFormation.ps1
```

This is the main live monitor.

```powershell
#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 CLOUD FORMATION LIVE DEPLOYMENT MONITOR
====================================================================

 File:
   deployment-monitor-systam/Monitor-CloudFormation.ps1

 PURPOSE
 -------------------------------------------------------------------
 Monitor CloudFormation while Terraform is running.

 The monitor is READ-ONLY.

 It does NOT:
   - create resources
   - update resources
   - delete resources
   - execute Terraform
   - modify CloudFormation

 It observes:

   Main CloudFormation stack
          |
          +---- Nested Stack
          |       |
          |       +---- resources
          |
          +---- Nested Stack
          |
          +---- resources

 It captures:

   - stack status
   - nested stack discovery
   - stack events
   - Operation IDs
   - operation events
   - failed events
   - PhysicalResourceId
   - ResourceStatusReason
   - failure classifications
   - raw JSON
   - human-readable logs

 IMPORTANT
 -------------------------------------------------------------------
 Terraform remains authoritative.

 The monitor does not decide whether Terraform succeeded.

====================================================================
 REQUIREMENTS
====================================================================

 PowerShell 7+
 AWS CLI v2
 Valid AWS credentials

 Required AWS permissions:

   cloudformation:DescribeStacks
   cloudformation:DescribeStackEvents
   cloudformation:DescribeStackResources
   cloudformation:DescribeEvents
   sts:GetCallerIdentity

====================================================================
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [string]$OutputDirectory,

    [int]$PollSeconds = 3,

    [int]$TimeoutMinutes = 120,

    [string]$StopFile,

    [string]$DeploymentId
)

# ====================================================================
# INITIALIZATION
# ====================================================================

$ErrorActionPreference = "Continue"

if ([string]::IsNullOrWhiteSpace($DeploymentId)) {

    $DeploymentId = "manual-$(
        (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    )"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {

    $OutputDirectory = Join-Path `
        (Get-Location) `
        "deployment-logs"
}

$OutputDirectory = [System.IO.Path]::GetFullPath(
    $OutputDirectory
)

if (-not (Test-Path -LiteralPath $OutputDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
        Out-Null
}

if ([string]::IsNullOrWhiteSpace($StopFile)) {

    $StopFile = Join-Path `
        $OutputDirectory `
        "monitor.stop"
}

# ====================================================================
# FILES
# ====================================================================

$MonitorLog =
    Join-Path $OutputDirectory "cloudformation-monitor.log"

$EventsJsonl =
    Join-Path $OutputDirectory "cloudformation-events.jsonl"

$FailuresJsonl =
    Join-Path $OutputDirectory "cloudformation-failures.jsonl"

$OperationsJsonl =
    Join-Path $OutputDirectory "cloudformation-operations.jsonl"

$MetadataJson =
    Join-Path $OutputDirectory "cloudformation-metadata.json"

$NestedStacksJson =
    Join-Path $OutputDirectory "nested-stacks.json"

$LatestStackJson =
    Join-Path $OutputDirectory "cloudformation-latest-stack.json"

$LatestEventsJson =
    Join-Path $OutputDirectory "cloudformation-latest-events.json"

# ====================================================================
# RUNTIME STATE
# ====================================================================

$StartTime = Get-Date

$SeenEvents = @{}

$SeenOperations = @{}

$KnownStacks = @{}

$FirstFailure = $null

$LastRootStatus = $null

$LastRootStatusTime = $null

$MonitorTimedOut = $false

$StopRequested = $false

# ====================================================================
# TERMINAL STATES
# ====================================================================

$SuccessStates = @(
    "CREATE_COMPLETE",
    "UPDATE_COMPLETE",
    "IMPORT_COMPLETE"
)

$FailureStates = @(
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED",
    "ROLLBACK_FAILED",
    "UPDATE_ROLLBACK_FAILED"
)

$TerminalStates = @(
    "CREATE_COMPLETE",
    "UPDATE_COMPLETE",
    "IMPORT_COMPLETE",
    "CREATE_FAILED",
    "UPDATE_FAILED",
    "DELETE_FAILED",
    "ROLLBACK_FAILED",
    "UPDATE_ROLLBACK_FAILED",
    "ROLLBACK_COMPLETE",
    "UPDATE_ROLLBACK_COMPLETE",
    "DELETE_COMPLETE",
    "IMPORT_ROLLBACK_COMPLETE",
    "IMPORT_ROLLBACK_FAILED"
)

# ====================================================================
# LOGGING
# ====================================================================

function Write-MonitorLog {

    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Timestamp = (
        Get-Date
    ).ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ss.fffZ"
    )

    $Line =
        "[${Timestamp}] [$Level] $Message"

    Write-Host $Line

    Add-Content `
        -LiteralPath $MonitorLog `
        -Value $Line `
        -Encoding UTF8
}

function Write-Jsonl {

    param(
        [string]$Path,
        [object]$Object
    )

    $Json =
        $Object |
        ConvertTo-Json `
            -Depth 50 `
            -Compress

    Add-Content `
        -LiteralPath $Path `
        -Value $Json `
        -Encoding UTF8
}

# ====================================================================
# AWS CLI JSON HELPER
# ====================================================================

function Invoke-AwsJson {

    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $Output = & aws @Arguments 2>&1

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -ne 0) {

        return [PSCustomObject]@{
            Success  = $false
            ExitCode = $ExitCode
            Raw      = ($Output -join "`n")
            Data     = $null
        }
    }

    try {

        $Text = $Output -join "`n"

        if ([string]::IsNullOrWhiteSpace($Text)) {

            return [PSCustomObject]@{
                Success  = $true
                ExitCode = 0
                Raw      = ""
                Data     = $null
            }
        }

        return [PSCustomObject]@{
            Success  = $true
            ExitCode = 0
            Raw      = $Text
            Data     = (
                $Text | ConvertFrom-Json
            )
        }
    }
    catch {

        return [PSCustomObject]@{
            Success  = $false
            ExitCode = 0
            Raw      = ($Output -join "`n")
            Data     = $null
        }
    }
}

# ====================================================================
# FAILURE CLASSIFICATION
# ====================================================================

function Get-FailureClassification {

    param(
        [string]$Reason
    )

    if ([string]::IsNullOrWhiteSpace($Reason)) {

        return [PSCustomObject]@{
            Category = "UNKNOWN"
            Priority = 99
        }
    }

    $RulesFile =
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "deployment-monitor-systam/failure-rules.json"

    # Because this script is already inside deployment-monitor-systam,
    # use the direct local path first.
    $RulesFile =
        Join-Path $PSScriptRoot "failure-rules.json"

    if (-not (Test-Path -LiteralPath $RulesFile)) {

        return [PSCustomObject]@{
            Category = "UNCLASSIFIED"
            Priority = 99
        }
    }

    try {

        $Rules =
            Get-Content `
                -LiteralPath $RulesFile `
                -Raw |
            ConvertFrom-Json

        foreach ($Rule in $Rules.rules) {

            foreach ($Pattern in $Rule.patterns) {

                if ($Reason -match $Pattern) {

                    return [PSCustomObject]@{
                        Category =
                            $Rule.category

                        Priority =
                            [int]$Rule.priority

                        Recommendation =
                            $Rule.recommendation
                    }
                }
            }
        }
    }
    catch {

        return [PSCustomObject]@{
            Category = "RULE_ENGINE_ERROR"
            Priority = 99
        }
    }

    return [PSCustomObject]@{
        Category = "UNCLASSIFIED CLOUDFORMATION FAILURE"
        Priority = 99
    }
}

# ====================================================================
# PROCESS EVENT
# ====================================================================

function Process-Event {

    param(
        [Parameter(Mandatory = $true)]
        [object]$Event,

        [Parameter(Mandatory = $true)]
        [string]$SourceStack
    )

    $EventId =
        [string]$Event.EventId

    if ([string]::IsNullOrWhiteSpace($EventId)) {
        return
    }

    if ($SeenEvents.ContainsKey($EventId)) {
        return
    }

    $SeenEvents[$EventId] = $true

    $ResourceStatus =
        [string]$Event.ResourceStatus

    $IsFailure =
        $ResourceStatus -match `
        "FAILED|ROLLBACK_FAILED|DELETE_FAILED"

    # ---------------------------------------------------------------
    # Save every event.
    # ---------------------------------------------------------------

    $EventRecord = [ordered]@{

        DeploymentId =
            $DeploymentId

        DetectedAt =
            (
                Get-Date
            ).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        SourceStack =
            $SourceStack

        EventId =
            $Event.EventId

        OperationId =
            $Event.OperationId

        StackId =
            $Event.StackId

        StackName =
            $Event.StackName

        Timestamp =
            $Event.Timestamp

        LogicalResourceId =
            $Event.LogicalResourceId

        PhysicalResourceId =
            $Event.PhysicalResourceId

        ResourceType =
            $Event.ResourceType

        ResourceStatus =
            $Event.ResourceStatus

        ResourceStatusReason =
            $Event.ResourceStatusReason

        DetailedStatus =
            $Event.DetailedStatus
    }

    Write-Jsonl `
        -Path $EventsJsonl `
        -Object $EventRecord

    # ---------------------------------------------------------------
    # Display important state changes.
    # ---------------------------------------------------------------

    if (
        $ResourceStatus -match
        "IN_PROGRESS|COMPLETE|FAILED|ROLLBACK"
    ) {

        Write-MonitorLog `
            "$SourceStack | $($Event.LogicalResourceId) | $ResourceStatus"
    }

    # ---------------------------------------------------------------
    # FAILURE PROCESSING
    # ---------------------------------------------------------------

    if (-not $IsFailure) {
        return
    }

    $Reason =
        [string]$Event.ResourceStatusReason

    if ([string]::IsNullOrWhiteSpace($Reason)) {

        $Reason =
            "CloudFormation did not provide a resource status reason."
    }

    $Classification =
        Get-FailureClassification `
            -Reason $Reason

    $FailureRecord = [ordered]@{

        DeploymentId =
            $DeploymentId

        DetectedAt =
            (
                Get-Date
            ).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        SourceStack =
            $SourceStack

        EventId =
            $Event.EventId

        OperationId =
            $Event.OperationId

        Timestamp =
            $Event.Timestamp

        LogicalResourceId =
            $Event.LogicalResourceId

        PhysicalResourceId =
            $Event.PhysicalResourceId

        ResourceType =
            $Event.ResourceType

        ResourceStatus =
            $Event.ResourceStatus

        Reason =
            $Reason

        Category =
            $Classification.Category

        Priority =
            $Classification.Priority

        Recommendation =
            $Classification.Recommendation
    }

    Write-Jsonl `
        -Path $FailuresJsonl `
        -Object $FailureRecord

    # ---------------------------------------------------------------
    # First failure is extremely important.
    #
    # We use the earliest actual resource failure as the strongest
    # root-cause candidate.
    # ---------------------------------------------------------------

    if ($null -eq $FirstFailure) {

        $FirstFailure = $FailureRecord

        Write-MonitorLog ""
        Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        Write-MonitorLog "FIRST CLOUDFORMATION FAILURE DETECTED" "ERROR"
        Write-MonitorLog "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

        Write-MonitorLog `
            "Stack: $SourceStack" `
            "ERROR"

        Write-MonitorLog `
            "OperationId: $($Event.OperationId)" `
            "ERROR"

        Write-MonitorLog `
            "LogicalResourceId: $($Event.LogicalResourceId)" `
            "ERROR"

        Write-MonitorLog `
            "ResourceType: $($Event.ResourceType)" `
            "ERROR"

        Write-MonitorLog `
            "Status: $($Event.ResourceStatus)" `
            "ERROR"

        Write-MonitorLog `
            "EXACT REASON: $Reason" `
            "ERROR"

        Write-MonitorLog `
            "CLASSIFICATION: $($Classification.Category)" `
            "ERROR"

        if ($Classification.Recommendation) {

            Write-MonitorLog `
                "RECOMMENDATION: $($Classification.Recommendation)" `
                "WARN"
        }

        Write-MonitorLog ""
    }
}

# ====================================================================
# DISCOVER OPERATION IDS
# ====================================================================

function Discover-Operations {

    param(
        [string]$TargetStack
    )

    $Result = Invoke-AwsJson @(
        "cloudformation"
        "describe-stacks"
        "--stack-name"
        $TargetStack
        "--region"
        $Region
        "--output"
        "json"
    )

    if (-not $Result.Success) {
        return $null
    }

    $Stack =
        $Result.Data.Stacks[0]

    if ($null -eq $Stack) {
        return $null
    }

    if ($null -eq $Stack.LastOperations) {
        return $Stack
    }

    foreach ($Operation in $Stack.LastOperations) {

        $OperationId =
            [string]$Operation.OperationId

        if (
            [string]::IsNullOrWhiteSpace(
                $OperationId
            )
        ) {
            continue
        }

        if (
            $SeenOperations.ContainsKey(
                $OperationId
            )
        ) {
            continue
        }

        $SeenOperations[$OperationId] = $true

        $OperationRecord = [ordered]@{

            DeploymentId =
                $DeploymentId

            DetectedAt =
                (
                    Get-Date
                ).ToUniversalTime().ToString(
                    "yyyy-MM-ddTHH:mm:ss.fffZ"
                )

            StackName =
                $TargetStack

            OperationId =
                $OperationId

            OperationType =
                $Operation.OperationType
        }

        Write-Jsonl `
            -Path $OperationsJsonl `
            -Object $OperationRecord

        Write-MonitorLog `
            "Operation discovered | Stack=$TargetStack | Type=$($Operation.OperationType) | OperationId=$OperationId"

        # -----------------------------------------------------------
        # Retrieve operation-specific events.
        # -----------------------------------------------------------

        $OperationEvents =
            Invoke-AwsJson @(
                "cloudformation"
                "describe-events"
                "--operation-id"
                $OperationId
                "--region"
                $Region
                "--no-paginate"
                "--output"
                "json"
            )

        if ($OperationEvents.Success) {

            if ($null -ne $OperationEvents.Data.OperationEvents) {

                foreach (
                    $Event
                    in $OperationEvents.Data.OperationEvents
                ) {

                    Process-Event `
                        -Event $Event `
                        -SourceStack $TargetStack
                }
            }
        }
    }

    return $Stack
}

# ====================================================================
# DISCOVER STACK RESOURCES / NESTED STACKS
# ====================================================================

function Discover-NestedStacks {

    param(
        [string]$TargetStack
    )

    $Result = Invoke-AwsJson @(
        "cloudformation"
        "describe-stack-resources"
        "--stack-name"
        $TargetStack
        "--region"
        $Region
        "--output"
        "json"
    )

    if (-not $Result.Success) {
        return
    }

    foreach (
        $Resource
        in $Result.Data.StackResources
    ) {

        if (
            $Resource.ResourceType `
            -ne "AWS::CloudFormation::Stack"
        ) {
            continue
        }

        $NestedStackId =
            [string]$Resource.PhysicalResourceId

        if (
            [string]::IsNullOrWhiteSpace(
                $NestedStackId
            )
        ) {
            continue
        }

        if (
            $KnownStacks.ContainsKey(
                $NestedStackId
            )
        ) {
            continue
        }

        $KnownStacks[$NestedStackId] = @{
            LogicalId =
                [string]$Resource.LogicalResourceId

            ParentStack =
                $TargetStack

            StackId =
                $NestedStackId
        }

        Write-MonitorLog ""
        Write-MonitorLog "NESTED STACK DISCOVERED"
        Write-MonitorLog "  Parent: $TargetStack"
        Write-MonitorLog "  LogicalId: $($Resource.LogicalResourceId)"
        Write-MonitorLog "  StackId: $NestedStackId"

        # -----------------------------------------------------------
        # Immediately discover operations for the nested stack.
        # -----------------------------------------------------------

        Discover-Operations `
            -TargetStack $NestedStackId |
            Out-Null

        # -----------------------------------------------------------
        # Recursively discover additional nested stacks.
        # -----------------------------------------------------------

        Discover-NestedStacks `
            -TargetStack $NestedStackId
    }

    # ---------------------------------------------------------------
    # Save nested-stack inventory.
    # ---------------------------------------------------------------

    $NestedArray = @()

    foreach ($Key in $KnownStacks.Keys) {

        $NestedArray += [ordered]@{

            LogicalId =
                $KnownStacks[$Key].LogicalId

            ParentStack =
                $KnownStacks[$Key].ParentStack

            StackId =
                $KnownStacks[$Key].StackId
        }
    }

    $NestedArray |
        ConvertTo-Json `
            -Depth 20 |
        Set-Content `
            -LiteralPath $NestedStacksJson `
            -Encoding UTF8
}

# ====================================================================
# GET STACK EVENTS
# ====================================================================

function Read-StackEvents {

    param(
        [string]$TargetStack
    )

    $Result = Invoke-AwsJson @(
        "cloudformation"
        "describe-stack-events"
        "--stack-name"
        $TargetStack
        "--region"
        $Region
        "--no-paginate"
        "--output"
        "json"
    )

    if (-not $Result.Success) {
        return
    }

    if ($null -eq $Result.Data.StackEvents) {
        return
    }

    foreach (
        $Event
        in $Result.Data.StackEvents
    ) {

        Process-Event `
            -Event $Event `
            -SourceStack $TargetStack
    }

    $Result.Data |
        ConvertTo-Json `
            -Depth 50 |
        Set-Content `
            -LiteralPath $LatestEventsJson `
            -Encoding UTF8
}

# ====================================================================
# WRITE METADATA
# ====================================================================

function Write-Metadata {

    param(
        [object]$Stack
    )

    $Metadata = [ordered]@{

        DeploymentId =
            $DeploymentId

        MonitorStartUtc =
            $StartTime.ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        LastUpdatedUtc =
            (
                Get-Date
            ).ToUniversalTime().ToString(
                "yyyy-MM-ddTHH:mm:ss.fffZ"
            )

        Region =
            $Region

        RootStackName =
            $StackName

        RootStackId =
            $Stack.StackId

        RootStackStatus =
            $Stack.StackStatus

        RootStackStatusReason =
            $Stack.StackStatusReason

        FirstFailure =
            $FirstFailure

        KnownNestedStacks =
            @(
                $KnownStacks.Values
            )
    }

    $Metadata |
        ConvertTo-Json `
            -Depth 50 |
        Set-Content `
            -LiteralPath $MetadataJson `
            -Encoding UTF8
}

# ====================================================================
# START
# ====================================================================

Write-MonitorLog ""
Write-MonitorLog "============================================================"
Write-MonitorLog "CLOUDFORMATION LIVE MONITOR STARTED"
Write-MonitorLog "============================================================"

Write-MonitorLog "DeploymentId: $DeploymentId"
Write-MonitorLog "Root Stack: $StackName"
Write-MonitorLog "Region: $Region"
Write-MonitorLog "Poll Seconds: $PollSeconds"
Write-MonitorLog "Timeout Minutes: $TimeoutMinutes"
Write-MonitorLog "Stop File: $StopFile"

# ====================================================================
# AWS IDENTITY
# ====================================================================

$Identity =
    Invoke-AwsJson @(
        "sts"
        "get-caller-identity"
        "--region"
        $Region
        "--output"
        "json"
    )

if (-not $Identity.Success) {

    Write-MonitorLog `
        "AWS identity check failed." `
        "ERROR"

    exit 2
}

Write-MonitorLog `
    "AWS Account: $($Identity.Data.Account)"

Write-MonitorLog `
    "AWS Principal: $($Identity.Data.Arn)"

# ====================================================================
# MAIN LOOP
# ====================================================================

while ($true) {

    # ================================================================
    # TIMEOUT
    # ================================================================

    if ($TimeoutMinutes -gt 0) {

        $Elapsed =
            (
                New-TimeSpan `
                    -Start $StartTime `
                    -End (Get-Date)
            )

        if (
            $Elapsed.TotalMinutes `
            -ge $TimeoutMinutes
        ) {

            $MonitorTimedOut = $true

            Write-MonitorLog `
                "Monitor timeout reached." `
                "ERROR"

            break
        }
    }

    # ================================================================
    # STOP SIGNAL
    # ================================================================

    if (
        Test-Path `
            -LiteralPath $StopFile
    ) {

        if (-not $StopRequested) {

            $StopRequested = $true

            Write-MonitorLog `
                "Stop signal received from deployment orchestrator." `
                "WARN"
        }
    }

    # ================================================================
    # DISCOVER ROOT STACK
    # ================================================================

    $RootStack =
        Discover-Operations `
            -TargetStack $StackName

    if ($null -eq $RootStack) {

        Write-MonitorLog `
            "Root CloudFormation stack not available yet."

        Start-Sleep `
            -Seconds $PollSeconds

        continue
    }

    # ================================================================
    # REGISTER ROOT STACK
    # ================================================================

    if (
        -not $KnownStacks.ContainsKey(
            $RootStack.StackId
        )
    ) {

        $KnownStacks[$RootStack.StackId] = @{
            LogicalId =
                $RootStack.StackName

            ParentStack =
                $null

            StackId =
                $RootStack.StackId
        }

        Write-MonitorLog ""
        Write-MonitorLog `
            "ROOT CLOUDFORMATION STACK DETECTED"

        Write-MonitorLog `
            "StackId: $($RootStack.StackId)"
    }

    # ================================================================
    # STATUS CHANGE
    # ================================================================

    if (
        $RootStack.StackStatus `
        -ne $LastRootStatus
    ) {

        $LastRootStatus =
            $RootStack.StackStatus

        $LastRootStatusTime =
            Get-Date

        Write-MonitorLog ""
        Write-MonitorLog `
            "ROOT STACK STATUS = $($RootStack.StackStatus)"

        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$RootStack.StackStatusReason
            )
        ) {

            Write-MonitorLog `
                "STATUS REASON = $($RootStack.StackStatusReason)"
        }
    }

    # ================================================================
    # SAVE ROOT STACK SNAPSHOT
    # ================================================================

    $RootStack |
        ConvertTo-Json `
            -Depth 50 |
        Set-Content `
            -LiteralPath $LatestStackJson `
            -Encoding UTF8

    # ================================================================
    # READ EVENTS
    # ================================================================

    Read-StackEvents `
        -TargetStack $StackName

    # ================================================================
    # DISCOVER NESTED STACKS
    # ================================================================

    Discover-NestedStacks `
        -TargetStack $StackName

    # ================================================================
    # READ EVENTS FROM ALL KNOWN STACKS
    # ================================================================

    foreach (
        $StackId
        in @($KnownStacks.Keys)
    ) {

        if ($StackId -eq $RootStack.StackId) {
            continue
        }

        Read-StackEvents `
            -TargetStack $StackId
    }

    # ================================================================
    # UPDATE METADATA
    # ================================================================

    Write-Metadata `
        -Stack $RootStack

    # ================================================================
    # TERMINATION LOGIC
    # ================================================================

    $RootTerminal =
        $TerminalStates `
        -contains `
        $RootStack.StackStatus

    if ($StopRequested -and $RootTerminal) {

        Write-MonitorLog ""
        Write-MonitorLog `
            "Terraform has requested monitor shutdown."

        Write-MonitorLog `
            "Root CloudFormation stack is terminal."

        Write-MonitorLog `
            "Final status: $($RootStack.StackStatus)"

        break
    }

    # ---------------------------------------------------------------
    # If CloudFormation itself reached a terminal failure, keep
    # monitoring until Terraform tells us the deployment is finished.
    # ---------------------------------------------------------------

    if (
        $RootStack.StackStatus `
        -in $FailureStates
    ) {

        Write-MonitorLog `
            "CloudFormation entered terminal failure state." `
            "ERROR"
    }

    Start-Sleep `
        -Seconds $PollSeconds
}

# ====================================================================
# FINAL METADATA
# ====================================================================

$FinalStatus = $LastRootStatus

$FinalMetadata = [ordered]@{

    DeploymentId =
        $DeploymentId

    MonitorStartedUtc =
        $StartTime.ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    MonitorFinishedUtc =
        (
            Get-Date
        ).ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    Region =
        $Region

    RootStackName =
        $StackName

    FinalRootStatus =
        $FinalStatus

    MonitorTimedOut =
        $MonitorTimedOut

    StopRequested =
        $StopRequested

    FirstFailure =
        $FirstFailure

    KnownStackCount =
        $KnownStacks.Count
}

$FinalMetadata |
    ConvertTo-Json `
        -Depth 50 |
    Set-Content `
        -LiteralPath $MetadataJson `
        -Encoding UTF8

Write-MonitorLog ""
Write-MonitorLog "============================================================"
Write-MonitorLog "CLOUDFORMATION LIVE MONITOR FINISHED"
Write-MonitorLog "============================================================"

Write-MonitorLog `
    "Final Root Stack Status: $FinalStatus"

Write-MonitorLog `
    "First Failure Captured: $(
        if ($null -ne $FirstFailure) { "YES" } else { "NO" }
    )"

Write-MonitorLog `
    "Known Stacks: $($KnownStacks.Count)"

if ($MonitorTimedOut) {

    exit 2
}

exit 0
```

---

### 4. `Start-Deployment.ps1`

This is the important orchestrator.

It starts the CloudFormation monitor **first**, then Terraform.

Create:

```text
aws-hybrid-iac-lab/deployment-monitor-systam/Start-Deployment.ps1
```

```powershell
#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 TERRAFORM + CLOUDFORMATION DEPLOYMENT ORCHESTRATOR
====================================================================

 File:
   deployment-monitor-systam/Start-Deployment.ps1

 PURPOSE
 -------------------------------------------------------------------
 Run Terraform and CloudFormation monitoring concurrently.

 Architecture:

                 Start-Deployment.ps1
                         |
              +----------+----------+
              |                     |
              v                     v
       CloudFormation           Terraform
          Monitor                Apply
              |                     |
              +----------+----------+
                         |
                         v
                   Final Report

 Terraform remains authoritative.

====================================================================
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$TerraformWorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$StackName,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$MonitorDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$TerraformPlanFile = "tfplan",

    [switch]$AutoApprove,

    [int]$PollSeconds = 3,

    [int]$MonitorTimeoutMinutes = 120
)

# ====================================================================
# SETTINGS
# ====================================================================

$ErrorActionPreference = "Continue"

$StartTime = Get-Date

# ====================================================================
# PATHS
# ====================================================================

$TerraformWorkingDirectory =
    [System.IO.Path]::GetFullPath(
        $TerraformWorkingDirectory
    )

$MonitorDirectory =
    [System.IO.Path]::GetFullPath(
        $MonitorDirectory
    )

$OutputDirectory =
    [System.IO.Path]::GetFullPath(
        $OutputDirectory
    )

if (-not (Test-Path -LiteralPath $OutputDirectory)) {

    New-Item `
        -ItemType Directory `
        -Path $OutputDirectory `
        -Force |
        Out-Null
}

$MonitorScript =
    Join-Path `
        $MonitorDirectory `
        "Monitor-CloudFormation.ps1"

$ReportScript =
    Join-Path `
        $MonitorDirectory `
        "Generate-Report.ps1"

$StopFile =
    Join-Path `
        $OutputDirectory `
        "monitor.stop"

$TerraformJsonl =
    Join-Path `
        $OutputDirectory `
        "terraform.jsonl"

$TerraformLog =
    Join-Path `
        $OutputDirectory `
        "terraform.log"

$TerraformStdErr =
    Join-Path `
        $OutputDirectory `
        "terraform-stderr.log"

$DeploymentMetadata =
    Join-Path `
        $OutputDirectory `
        "deployment-context.json"

# ====================================================================
# DEPLOYMENT ID
# ====================================================================

$GitHubRunId =
    if ($env:GITHUB_RUN_ID) {
        $env:GITHUB_RUN_ID
    }
    else {
        "local"
    }

$DeploymentId =
    "DEP-$(
        (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
    )-$GitHubRunId"

# ====================================================================
# VALIDATION
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "AWS HYBRID IaC LAB DEPLOYMENT ORCHESTRATOR" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Deployment ID:"
Write-Host $DeploymentId

Write-Host ""
Write-Host "Terraform directory:"
Write-Host $TerraformWorkingDirectory

Write-Host ""
Write-Host "Terraform plan:"
Write-Host $TerraformPlanFile

Write-Host ""
Write-Host "CloudFormation stack:"
Write-Host $StackName

Write-Host ""
Write-Host "AWS region:"
Write-Host $Region

Write-Host ""
Write-Host "Monitor directory:"
Write-Host $MonitorDirectory

Write-Host ""
Write-Host "Output directory:"
Write-Host $OutputDirectory

if (-not (Test-Path -LiteralPath $TerraformWorkingDirectory)) {

    Write-Host ""
    Write-Host "ERROR: Terraform working directory does not exist." -ForegroundColor Red

    exit 1
}

if (-not (Test-Path -LiteralPath $MonitorScript)) {

    Write-Host ""
    Write-Host "ERROR: Monitor script does not exist." -ForegroundColor Red
    Write-Host $MonitorScript

    exit 1
}

if (-not (Test-Path -LiteralPath $ReportScript)) {

    Write-Host ""
    Write-Host "ERROR: Report generator does not exist." -ForegroundColor Red
    Write-Host $ReportScript

    exit 1
}

# ====================================================================
# REMOVE OLD STOP SIGNAL
# ====================================================================

if (Test-Path -LiteralPath $StopFile) {

    Remove-Item `
        -LiteralPath $StopFile `
        -Force `
        -ErrorAction SilentlyContinue
}

# ====================================================================
# SAVE DEPLOYMENT CONTEXT
# ====================================================================

$Context = [ordered]@{

    DeploymentId =
        $DeploymentId

    GitHubRunId =
        $env:GITHUB_RUN_ID

    GitHubRunAttempt =
        $env:GITHUB_RUN_ATTEMPT

    GitHubRepository =
        $env:GITHUB_REPOSITORY

    GitHubSha =
        $env:GITHUB_SHA

    GitHubRef =
        $env:GITHUB_REF

    StartTimeUtc =
        $StartTime.ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    Region =
        $Region

    StackName =
        $StackName

    TerraformWorkingDirectory =
        $TerraformWorkingDirectory

    TerraformPlanFile =
        $TerraformPlanFile

    MonitorScript =
        $MonitorScript

    OutputDirectory =
        $OutputDirectory

    PollSeconds =
        $PollSeconds

    MonitorTimeoutMinutes =
        $MonitorTimeoutMinutes
}

$Context |
    ConvertTo-Json `
        -Depth 20 |
    Set-Content `
        -LiteralPath $DeploymentMetadata `
        -Encoding UTF8

# ====================================================================
# START CLOUDFORMATION MONITOR
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "STARTING CLOUDFORMATION LIVE MONITOR" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

$MonitorProcess = $null

try {

    $MonitorArguments = @(
        "-NoProfile"
        "-NonInteractive"
        "-File"
        $MonitorScript
        "-StackName"
        $StackName
        "-Region"
        $Region
        "-OutputDirectory"
        $OutputDirectory
        "-PollSeconds"
        $PollSeconds
        "-TimeoutMinutes"
        $MonitorTimeoutMinutes
        "-StopFile"
        $StopFile
        "-DeploymentId"
        $DeploymentId
    )

    $MonitorProcess =
        Start-Process `
            -FilePath "pwsh" `
            -WorkingDirectory $MonitorDirectory `
            -ArgumentList $MonitorArguments `
            -PassThru `
            -NoNewWindow

    Write-Host ""
    Write-Host "CloudFormation monitor PID:"
    Write-Host $MonitorProcess.Id

}
catch {

    Write-Host ""
    Write-Host "ERROR: Unable to start CloudFormation monitor." -ForegroundColor Red
    Write-Host $_

    exit 1
}

# ====================================================================
# GIVE MONITOR TIME TO INITIALIZE
# ====================================================================

Start-Sleep -Seconds 2

# ====================================================================
# START TERRAFORM
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "STARTING TERRAFORM APPLY" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

$TerraformArguments = @(
    "apply"
    "-input=false"
)

if ($AutoApprove) {

    $TerraformArguments += "-auto-approve"
}

if (
    -not [string]::IsNullOrWhiteSpace(
        $TerraformPlanFile
    )
) {

    $TerraformArguments += $TerraformPlanFile
}

$TerraformProcess = $null

$TerraformStdOutPath =
    $TerraformJsonl

try {

    $ProcessInfo =
        New-Object `
            System.Diagnostics.ProcessStartInfo

    $ProcessInfo.FileName =
        "terraform"

    $ProcessInfo.WorkingDirectory =
        $TerraformWorkingDirectory

    foreach ($Argument in $TerraformArguments) {

        [void]$ProcessInfo.ArgumentList.Add(
            $Argument
        )
    }

    $ProcessInfo.UseShellExecute =
        $false

    $ProcessInfo.CreateNoWindow =
        $true

    $ProcessInfo.RedirectStandardOutput =
        $true

    $ProcessInfo.RedirectStandardError =
        $true

    $TerraformProcess =
        New-Object `
            System.Diagnostics.Process

    $TerraformProcess.StartInfo =
        $ProcessInfo

    [void]$TerraformProcess.Start()

    Write-Host ""
    Write-Host "Terraform PID:"
    Write-Host $TerraformProcess.Id

}
catch {

    Write-Host ""
    Write-Host "ERROR: Terraform could not be started." -ForegroundColor Red
    Write-Host $_

    # Tell monitor to finish.
    New-Item `
        -ItemType File `
        -Path $StopFile `
        -Force |
        Out-Null

    if ($MonitorProcess) {

        $MonitorProcess.WaitForExit(15000)

        if (-not $MonitorProcess.HasExited) {

            Stop-Process `
                -Id $MonitorProcess.Id `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    exit 1
}

# ====================================================================
# LIVE TERRAFORM OUTPUT LOOP
# ====================================================================

$TerraformStdOutBuffer = New-Object System.Collections.Generic.List[string]

$TerraformStdErrBuffer = New-Object System.Collections.Generic.List[string]

while (-not $TerraformProcess.HasExited) {

    # ---------------------------------------------------------------
    # Read stdout.
    # ---------------------------------------------------------------

    while (-not $TerraformProcess.StandardOutput.EndOfStream) {

        $Line =
            $TerraformProcess.StandardOutput.ReadLine()

        if ($null -eq $Line) {
            break
        }

        $TerraformStdOutBuffer.Add($Line)

        Add-Content `
            -LiteralPath $TerraformJsonl `
            -Value $Line `
            -Encoding UTF8

        # -----------------------------------------------------------
        # Terraform -json produces machine-readable JSONL.
        # Print useful messages to the GitHub console.
        # -----------------------------------------------------------

        try {

            $Json =
                $Line | ConvertFrom-Json

            if ($Json["@message"]) {

                Write-Host `
                    "[Terraform] $($Json["@message"])"
            }
            elseif ($Json.type) {

                Write-Host `
                    "[Terraform] $($Json.type)"
            }
            else {

                Write-Host `
                    "[Terraform] $Line"
            }

        }
        catch {

            Write-Host `
                "[Terraform] $Line"
        }
    }

    # ---------------------------------------------------------------
    # Read stderr.
    # ---------------------------------------------------------------

    while (-not $TerraformProcess.StandardError.EndOfStream) {

        $Line =
            $TerraformProcess.StandardError.ReadLine()

        if ($null -eq $Line) {
            break
        }

        $TerraformStdErrBuffer.Add($Line)

        Add-Content `
            -LiteralPath $TerraformStdErr `
            -Value $Line `
            -Encoding UTF8

        Write-Host `
            "[Terraform STDERR] $Line" `
            -ForegroundColor Yellow
    }

    # ---------------------------------------------------------------
    # Show live CloudFormation log tail when available.
    # ---------------------------------------------------------------

    $CFNLog =
        Join-Path `
            $OutputDirectory `
            "cloudformation-monitor.log"

    if (Test-Path -LiteralPath $CFNLog) {

        $LastLines =
            Get-Content `
                -LiteralPath $CFNLog `
                -Tail 3 `
                -ErrorAction SilentlyContinue

        foreach ($Line in $LastLines) {

            # Deliberately do not print every line continuously.
            # The monitor itself prints live to the GitHub console.
        }
    }

    Start-Sleep -Milliseconds 250
}

# ====================================================================
# READ REMAINING TERRAFORM OUTPUT
# ====================================================================

while (
    -not $TerraformProcess.StandardOutput.EndOfStream
) {

    $Line =
        $TerraformProcess.StandardOutput.ReadLine()

    if ($null -ne $Line) {

        Add-Content `
            -LiteralPath $TerraformJsonl `
            -Value $Line `
            -Encoding UTF8
    }
}

while (
    -not $TerraformProcess.StandardError.EndOfStream
) {

    $Line =
        $TerraformProcess.StandardError.ReadLine()

    if ($null -ne $Line) {

        Add-Content `
            -LiteralPath $TerraformStdErr `
            -Value $Line `
            -Encoding UTF8
    }
}

$TerraformExitCode =
    $TerraformProcess.ExitCode

$TerraformFinishedTime =
    Get-Date

Write-Host ""
Write-Host "============================================================"

if ($TerraformExitCode -eq 0) {

    Write-Host `
        "TERRAFORM EXIT CODE: 0" `
        -ForegroundColor Green
}
else {

    Write-Host `
        "TERRAFORM EXIT CODE: $TerraformExitCode" `
        -ForegroundColor Red
}

Write-Host "============================================================"

# ====================================================================
# UPDATE CONTEXT
# ====================================================================

$Context.TerraformExitCode =
    $TerraformExitCode

$Context.TerraformFinishedUtc =
    $TerraformFinishedTime.ToUniversalTime().ToString(
        "yyyy-MM-ddTHH:mm:ss.fffZ"
    )

$Context |
    ConvertTo-Json `
        -Depth 20 |
    Set-Content `
        -LiteralPath $DeploymentMetadata `
        -Encoding UTF8

# ====================================================================
# SIGNAL MONITOR TO STOP
# ====================================================================

Write-Host ""
Write-Host "Signalling CloudFormation monitor to finish..."

New-Item `
    -ItemType File `
    -Path $StopFile `
    -Force |
    Out-Null

# ====================================================================
# WAIT FOR MONITOR
# ====================================================================

Write-Host ""
Write-Host "Waiting for CloudFormation monitor to finish..."

$MonitorWaitSeconds =
    [int](
        $MonitorTimeoutMinutes * 60
    )

$MonitorFinished =
    $MonitorProcess.WaitForExit(
        $MonitorWaitSeconds * 1000
    )

if (-not $MonitorFinished) {

    Write-Host ""
    Write-Host `
        "WARNING: CloudFormation monitor did not finish before timeout." `
        -ForegroundColor Yellow

    Stop-Process `
        -Id $MonitorProcess.Id `
        -Force `
        -ErrorAction SilentlyContinue
}

# ====================================================================
# GENERATE FINAL REPORT
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "GENERATING FINAL DEPLOYMENT DIAGNOSIS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

& pwsh `
    -NoProfile `
    -NonInteractive `
    -File `
    $ReportScript `
    -OutputDirectory `
    $OutputDirectory `
    -DeploymentId `
    $DeploymentId `
    -TerraformExitCode `
    $TerraformExitCode `
    -Region `
    $Region `
    -StackName `
    $StackName

$ReportExitCode =
    $LASTEXITCODE

# ====================================================================
# CLEANUP STOP FILE
# ====================================================================

if (Test-Path -LiteralPath $StopFile) {

    Remove-Item `
        -LiteralPath $StopFile `
        -Force `
        -ErrorAction SilentlyContinue
}

# ====================================================================
# FINAL RESULT
# ====================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT ORCHESTRATOR FINISHED" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Deployment ID:"
Write-Host $DeploymentId

Write-Host ""
Write-Host "Terraform Exit Code:"
Write-Host $TerraformExitCode

Write-Host ""
Write-Host "Report Exit Code:"
Write-Host $ReportExitCode

Write-Host ""
Write-Host "Diagnostic Directory:"
Write-Host $OutputDirectory

# ====================================================================
# TERRAFORM REMAINS AUTHORITATIVE
# ====================================================================

exit $TerraformExitCode
```

---

### 5. `Generate-Report.ps1`

This is the part that turns raw logs into an actual diagnosis.

Create:

```text
aws-hybrid-iac-lab/deployment-monitor-systam/Generate-Report.ps1
```

````powershell
#requires -Version 7.0

<#
====================================================================
 AWS HYBRID IaC LAB
 DEPLOYMENT DIAGNOSIS REPORT GENERATOR
====================================================================

 File:
   deployment-monitor-systam/Generate-Report.ps1

 PURPOSE
 -------------------------------------------------------------------
 Compare:

   Terraform result
       +
   CloudFormation events
       +
   CloudFormation failure reason
       +
   Operation ID
       +
   Nested stack information

 and produce:

   diagnosis.json
   deployment-summary.md

 IMPORTANT
 -------------------------------------------------------------------
 This script does not change AWS infrastructure.

====================================================================
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DeploymentId,

    [Parameter(Mandatory = $true)]
    [int]$TerraformExitCode,

    [Parameter(Mandatory = $true)]
    [string]$Region,

    [Parameter(Mandatory = $true)]
    [string]$StackName
)

$ErrorActionPreference = "Continue"

$OutputDirectory =
    [System.IO.Path]::GetFullPath(
        $OutputDirectory
    )

# ====================================================================
# FILES
# ====================================================================

$FailuresFile =
    Join-Path `
        $OutputDirectory `
        "cloudformation-failures.jsonl"

$EventsFile =
    Join-Path `
        $OutputDirectory `
        "cloudformation-events.jsonl"

$OperationsFile =
    Join-Path `
        $OutputDirectory `
        "cloudformation-operations.jsonl"

$TerraformJsonl =
    Join-Path `
        $OutputDirectory `
        "terraform.jsonl"

$TerraformStderr =
    Join-Path `
        $OutputDirectory `
        "terraform-stderr.log"

$CFNMetadata =
    Join-Path `
        $OutputDirectory `
        "cloudformation-metadata.json"

$ContextFile =
    Join-Path `
        $OutputDirectory `
        "deployment-context.json"

$DiagnosisJson =
    Join-Path `
        $OutputDirectory `
        "diagnosis.json"

$SummaryMarkdown =
    Join-Path `
        $OutputDirectory `
        "deployment-summary.md"

# ====================================================================
# HELPERS
# ====================================================================

function Read-JsonLines {

    param(
        [string]$Path
    )

    $Items = @()

    if (-not (Test-Path -LiteralPath $Path)) {

        return $Items
    }

    foreach (
        $Line
        in Get-Content -LiteralPath $Path
    ) {

        if ([string]::IsNullOrWhiteSpace($Line)) {
            continue
        }

        try {

            $Items += (
                $Line | ConvertFrom-Json
            )
        }
        catch {

            # Ignore malformed/non-JSON lines.
        }
    }

    return $Items
}

# ====================================================================
# LOAD DATA
# ====================================================================

$Failures =
    Read-JsonLines `
        -Path $FailuresFile

$Events =
    Read-JsonLines `
        -Path $EventsFile

$Operations =
    Read-JsonLines `
        -Path $OperationsFile

$TerraformMessages =
    Read-JsonLines `
        -Path $TerraformJsonl

$TerraformErrors =
    if (Test-Path -LiteralPath $TerraformStderr) {
        Get-Content `
            -LiteralPath $TerraformStderr
    }
    else {
        @()
    }

$Metadata =
    if (Test-Path -LiteralPath $CFNMetadata) {

        try {

            Get-Content `
                -LiteralPath $CFNMetadata `
                -Raw |
            ConvertFrom-Json
        }
        catch {
            $null
        }

    }
    else {
        $null
    }

$Context =
    if (Test-Path -LiteralPath $ContextFile) {

        try {

            Get-Content `
                -LiteralPath $ContextFile `
                -Raw |
            ConvertFrom-Json
        }
        catch {
            $null
        }

    }
    else {
        $null
    }

# ====================================================================
# FIND PRIMARY FAILURE
# ====================================================================

$PrimaryFailure = $null

if ($Failures.Count -gt 0) {

    # ---------------------------------------------------------------
    # Prefer the earliest detected failure.
    # ---------------------------------------------------------------

    $PrimaryFailure =
        $Failures |
        Sort-Object {
            try {
                [DateTime]$_.Timestamp
            }
            catch {
                [DateTime]::MaxValue
            }
        } |
        Select-Object -First 1
}

# ====================================================================
# FALLBACK: SEARCH EVENTS DIRECTLY
# ====================================================================

if ($null -eq $PrimaryFailure) {

    $FailedEvents =
        $Events |
        Where-Object {
            $_.ResourceStatus -match `
                "CREATE_FAILED|UPDATE_FAILED|DELETE_FAILED|ROLLBACK_FAILED"
        }

    if ($FailedEvents.Count -gt 0) {

        $Event =
            $FailedEvents |
            Sort-Object {
                try {
                    [DateTime]$_.Timestamp
                }
                catch {
                    [DateTime]::MaxValue
                }
            } |
            Select-Object -First 1

        $PrimaryFailure = [PSCustomObject]@{

            SourceStack =
                $Event.SourceStack

            EventId =
                $Event.EventId

            OperationId =
                $Event.OperationId

            Timestamp =
                $Event.Timestamp

            LogicalResourceId =
                $Event.LogicalResourceId

            PhysicalResourceId =
                $Event.PhysicalResourceId

            ResourceType =
                $Event.ResourceType

            ResourceStatus =
                $Event.ResourceStatus

            Reason =
                $Event.ResourceStatusReason

            Category =
                "CLOUDFORMATION RESOURCE FAILURE"
        }
    }
}

# ====================================================================
# FIND TERRAFORM ERROR MESSAGES
# ====================================================================

$TerraformErrorMessages = @()

foreach ($Message in $TerraformMessages) {

    $Text = ""

    if ($Message."@message") {

        $Text =
            [string]$Message."@message"
    }
    elseif ($Message.message) {

        $Text =
            [string]$Message.message
    }

    if (
        -not [string]::IsNullOrWhiteSpace($Text) `
        -and
        $Text -match `
            "error|failed|failure|denied|unauthorized"
    ) {

        $TerraformErrorMessages += $Text
    }
}

foreach ($Line in $TerraformErrors) {

    if (
        $Line -match `
            "error|failed|failure|denied|unauthorized"
    ) {

        $TerraformErrorMessages +=
            [string]$Line
    }
}

# ====================================================================
# CORRELATE TERRAFORM WITH CLOUDFORMATION
# ====================================================================

$TerraformCorrelation = @()

if ($null -ne $PrimaryFailure) {

    $SearchTerms = @()

    if ($PrimaryFailure.LogicalResourceId) {

        $SearchTerms +=
            [string]$PrimaryFailure.LogicalResourceId
    }

    if ($PrimaryFailure.ResourceType) {

        $SearchTerms +=
            [string]$PrimaryFailure.ResourceType
    }

    if ($PrimaryFailure.Reason) {

        # -----------------------------------------------------------
        # Search useful words from the CloudFormation reason.
        # -----------------------------------------------------------

        $Words =
            [regex]::Matches(
                [string]$PrimaryFailure.Reason,
                "[A-Za-z0-9:_/-]{4,}"
            )

        foreach ($Word in $Words) {

            $SearchTerms +=
                $Word.Value
        }
    }

    $SearchTerms =
        $SearchTerms |
        Select-Object -Unique

    foreach ($Message in $TerraformErrorMessages) {

        foreach ($Term in $SearchTerms) {

            if (
                $Message `
                -and
                $Message -match `
                    [regex]::Escape($Term)
            ) {

                $TerraformCorrelation += $Message

                break
            }
        }
    }
}

$TerraformCorrelation =
    $TerraformCorrelation |
    Select-Object -Unique

# ====================================================================
# DETERMINE ROOT CAUSE
# ====================================================================

$DiagnosisStatus = "UNKNOWN"

$RootCauseStatement = ""

$Confidence = "LOW"

if (
    $TerraformExitCode -ne 0 `
    -and
    $null -ne $PrimaryFailure
) {

    $DiagnosisStatus =
        "CLOUDFORMATION_FAILURE_CONFIRMED"

    $Confidence =
        "HIGH"

    $RootCauseStatement =
        "Terraform failed because the CloudFormation deployment encountered a confirmed resource-level failure. The CloudFormation failure is considered the primary infrastructure error; Terraform's non-zero exit code is the downstream deployment result."

}
elseif (
    $TerraformExitCode -ne 0 `
    -and
    $null -eq $PrimaryFailure
) {

    $DiagnosisStatus =
        "TERRAFORM_FAILURE_CONFIRMED_CFN_ROOT_CAUSE_NOT_CAPTURED"

    $Confidence =
        "MEDIUM"

    $RootCauseStatement =
        "Terraform returned a non-zero exit code, but this monitoring run did not capture a confirmed CloudFormation resource failure. The Terraform error is confirmed, but a CloudFormation root cause cannot be established from the captured evidence."

}
elseif (
    $TerraformExitCode -eq 0 `
    -and
    $null -ne $PrimaryFailure
) {

    $DiagnosisStatus =
        "INCONSISTENT_RESULTS"

    $Confidence =
        "MEDIUM"

    $RootCauseStatement =
        "Terraform returned success while CloudFormation diagnostics contain a failure event. Further investigation is required because the two signals do not agree."
}
else {

    $DiagnosisStatus =
        "SUCCESS"

    $Confidence =
        "HIGH"

    $RootCauseStatement =
        "Terraform completed successfully and no CloudFormation resource failure was captured."
}

# ====================================================================
# BUILD TIMELINE
# ====================================================================

$Timeline = @()

if ($Context) {

    if ($Context.StartTimeUtc) {

        $Timeline += [ordered]@{
            Time =
                $Context.StartTimeUtc

            Event =
                "Deployment orchestration started"
        }
    }

    if ($Context.TerraformFinishedUtc) {

        $Timeline += [ordered]@{
            Time =
                $Context.TerraformFinishedUtc

            Event =
                "Terraform process finished with exit code $TerraformExitCode"
        }
    }
}

if ($PrimaryFailure) {

    $Timeline += [ordered]@{
        Time =
            $PrimaryFailure.Timestamp

        Event =
            "First CloudFormation resource failure detected: $($PrimaryFailure.LogicalResourceId)"
    }
}

if ($Metadata) {

    if ($Metadata.MonitorFinishedUtc) {

        $Timeline += [ordered]@{
            Time =
                $Metadata.MonitorFinishedUtc

            Event =
                "CloudFormation monitor finished"
        }
    }
}

$Timeline =
    $Timeline |
    Sort-Object {
        try {
            [DateTime]$_.Time
        }
        catch {
            [DateTime]::MaxValue
        }
    }

# ====================================================================
# OPERATION IDS
# ====================================================================

$OperationIds =
    $Operations |
    Select-Object `
        StackName,
        OperationId,
        OperationType,
        DetectedAt

# ====================================================================
# BUILD DIAGNOSIS
# ====================================================================

$Diagnosis = [ordered]@{

    DiagnosisVersion =
        "1.0"

    DeploymentId =
        $DeploymentId

    GeneratedAtUtc =
        (
            Get-Date
        ).ToUniversalTime().ToString(
            "yyyy-MM-ddTHH:mm:ss.fffZ"
        )

    Environment = [ordered]@{

        Region =
            $Region

        RootStack =
            $StackName

        GitHubRunId =
            $env:GITHUB_RUN_ID

        GitHubRepository =
            $env:GITHUB_REPOSITORY

        GitHubSha =
            $env:GITHUB_SHA
    }

    Terraform = [ordered]@{

        ExitCode =
            $TerraformExitCode

        Status =
            if ($TerraformExitCode -eq 0) {
                "SUCCESS"
            }
            else {
                "FAILED"
            }

        ErrorMessages =
            $TerraformErrorMessages |
            Select-Object -Unique
    }

    CloudFormation = [ordered]@{

        FinalStackStatus =
            if ($Metadata) {
                $Metadata.FinalRootStatus
            }
            else {
                $null
            }

        FirstFailure =
            $PrimaryFailure

        OperationIds =
            $OperationIds

        FailureCount =
            $Failures.Count
    }

    Correlation = [ordered]@{

        Status =
            $DiagnosisStatus

        Confidence =
            $Confidence

        RootCauseStatement =
            $RootCauseStatement

        TerraformMatches =
            $TerraformCorrelation
    }

    Timeline =
        $Timeline

    EvidenceFiles = @(
        "deployment-context.json"
        "terraform.jsonl"
        "terraform-stderr.log"
        "cloudformation-monitor.log"
        "cloudformation-events.jsonl"
        "cloudformation-failures.jsonl"
        "cloudformation-operations.jsonl"
        "cloudformation-metadata.json"
        "cloudformation-latest-stack.json"
        "cloudformation-latest-events.json"
        "nested-stacks.json"
    )
}

# ====================================================================
# SAVE JSON REPORT
# ====================================================================

$Diagnosis |
    ConvertTo-Json `
        -Depth 50 |
    Set-Content `
        -LiteralPath $DiagnosisJson `
        -Encoding UTF8

# ====================================================================
# MARKDOWN REPORT
# ====================================================================

$Report = New-Object System.Collections.Generic.List[string]

$Report.Add("# AWS Hybrid IaC Lab - Deployment Diagnosis")

$Report.Add("")

$Report.Add("## Deployment")

$Report.Add("")

$Report.Add("| Field | Value |")
$Report.Add("|---|---|")
$Report.Add("| Deployment ID | `$DeploymentId` |")
$Report.Add("| Region | `$Region` |")
$Report.Add("| Root Stack | `$StackName` |")
$Report.Add("| Terraform Exit Code | `$TerraformExitCode` |")
$Report.Add("| Diagnosis | `$DiagnosisStatus` |")
$Report.Add("| Confidence | `$Confidence` |")

$Report.Add("")

$Report.Add("## Root Cause Statement")

$Report.Add("")

$Report.Add("> $RootCauseStatement")

$Report.Add("")

if ($PrimaryFailure) {

    $Report.Add("## Primary CloudFormation Failure")

    $Report.Add("")

    $Report.Add("| Field | Value |")
    $Report.Add("|---|---|")

    $Report.Add(
        "| Stack | $($PrimaryFailure.SourceStack) |"
    )

    $Report.Add(
        "| Operation ID | $($PrimaryFailure.OperationId) |"
    )

    $Report.Add(
        "| Logical Resource | $($PrimaryFailure.LogicalResourceId) |"
    )

    $Report.Add(
        "| Resource Type | $($PrimaryFailure.ResourceType) |"
    )

    $Report.Add(
        "| Physical Resource | $($PrimaryFailure.PhysicalResourceId) |"
    )

    $Report.Add(
        "| Status | $($PrimaryFailure.ResourceStatus) |"
    )

    $Report.Add(
        "| Classification | $($PrimaryFailure.Category) |"
    )

    $Report.Add(
        "| Timestamp | $($PrimaryFailure.Timestamp) |"
    )

    $Report.Add("")

    $Report.Add("### Exact CloudFormation Reason")

    $Report.Add("")

    $Report.Add(
        "```text"
    )

    $Report.Add(
        [string]$PrimaryFailure.Reason
    )

    $Report.Add(
        "```"
    )

}
else {

    $Report.Add("## Primary CloudFormation Failure")

    $Report.Add("")

    $Report.Add(
        "No confirmed CloudFormation resource failure was captured."
    )
}

$Report.Add("")

$Report.Add("## Terraform / CloudFormation Correlation")

$Report.Add("")

if ($TerraformCorrelation.Count -gt 0) {

    $Report.Add(
        "Terraform output contains messages correlated with the CloudFormation failure:"
    )

    $Report.Add("")

    foreach ($Message in $TerraformCorrelation) {

        $Report.Add(
            "- `$Message`"
        )
    }

}
else {

    $Report.Add(
        "No direct Terraform message could be matched to the primary CloudFormation failure."
    )
}

$Report.Add("")

$Report.Add("## Operation IDs")

$Report.Add("")

if ($OperationIds.Count -gt 0) {

    $Report.Add("| Stack | Operation Type | Operation ID | Detected |")
    $Report.Add("|---|---|---|---|")

    foreach ($Operation in $OperationIds) {

        $Report.Add(
            "| $($Operation.StackName) | $($Operation.OperationType) | `$($Operation.OperationId)` | $($Operation.DetectedAt) |"
        )
    }

}
else {

    $Report.Add(
        "No CloudFormation Operation IDs were captured."
    )
}

$Report.Add("")

$Report.Add("## Timeline")

$Report.Add("")

if ($Timeline.Count -gt 0) {

    $Report.Add("| Time | Event |")
    $Report.Add("|---|---|")

    foreach ($Item in $Timeline) {

        $Report.Add(
            "| $($Item.Time) | $($Item.Event) |"
        )
    }

}
else {

    $Report.Add(
        "No timeline events were captured."
    )
}

$Report.Add("")

$Report.Add("## Interpretation")

$Report.Add("")

if ($DiagnosisStatus -eq "CLOUDFORMATION_FAILURE_CONFIRMED") {

    $Report.Add(
        "The evidence indicates that the primary infrastructure failure occurred inside CloudFormation."
    )

    $Report.Add("")

    $Report.Add(
        "Terraform's non-zero exit code is the deployment-level consequence of the CloudFormation failure."
    )

    $Report.Add("")

    $Report.Add(
        "The earliest resource-level CloudFormation failure should be investigated before later rollback events."
    )

}
elseif (
    $DiagnosisStatus `
    -eq `
    "TERRAFORM_FAILURE_CONFIRMED_CFN_ROOT_CAUSE_NOT_CAPTURED"
) {

    $Report.Add(
        "Terraform definitely failed, but this diagnostic run did not capture enough CloudFormation evidence to establish CloudFormation as the root cause."
    )

}
elseif (
    $DiagnosisStatus `
    -eq `
    "INCONSISTENT_RESULTS"
) {

    $Report.Add(
        "Terraform and CloudFormation signals disagree. Review the complete raw evidence before declaring the deployment successful."
    )

}
else {

    $Report.Add(
        "Terraform and CloudFormation diagnostics indicate a successful deployment."
    )
}

$Report.Add("")

$Report.Add("## Evidence Files")

$Report.Add("")

foreach ($File in $Diagnosis.EvidenceFiles) {

    $FullPath =
        Join-Path `
            $OutputDirectory `
            $File

    if (Test-Path -LiteralPath $FullPath) {

        $Report.Add(
            "- `$File` - available"
        )

    }
    else {

        $Report.Add(
            "- `$File` - not generated"
        )
    }
}

$Report |
    Set-Content `
        -LiteralPath $SummaryMarkdown `
        -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT DIAGNOSIS GENERATED" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Diagnosis:"
Write-Host $DiagnosisStatus

Write-Host ""
Write-Host "Confidence:"
Write-Host $Confidence

Write-Host ""
Write-Host "Report:"
Write-Host $SummaryMarkdown

Write-Host ""
Write-Host "JSON:"
Write-Host $DiagnosisJson

exit 0
````

---

### 6. Important correction inside the monitor

There is one line in the above script worth highlighting.

The monitor gets operation IDs through:

```powershell
describe-stacks
```

and reads:

```text
LastOperations
    ├── OperationType
    └── OperationId
```

That is now the correct AWS-supported mechanism for discovering recent CloudFormation operation IDs. AWS documents `LastOperations` on the stack description for this purpose. ([AWS Documentation][1])

Then it uses:

```powershell
aws cloudformation describe-events `
    --operation-id <OPERATION-ID>
```

This allows the diagnostic system to associate events with the specific CloudFormation operation rather than simply looking at a huge historical event list. AWS specifically documents operation-level filtering and `FailedEvents=true` for troubleshooting. ([AWS Documentation][2])

---

### 7. GitHub Actions Step 15

Now your workflow needs to point to:

```text
deployment-monitor-systam/
```

**not**:

```text
scripts/deployment-monitor-systam/
```

Replace your current Step 15 with:

```yaml
# ==========================================================
# STEP 15 - TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR
# ==========================================================
- name: Step 15 - Terraform Apply With Live CloudFormation Diagnostics
  if: ${{ env.TF_AUTO_APPROVE == 'true' }}
  working-directory: ${{ env.TF_WORKING_DIRECTORY }}
  shell: pwsh
  env:
    AWS_PAGER: ""
  run: |

    $ErrorActionPreference = "Continue"

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STEP 15 - TERRAFORM APPLY + LIVE CLOUDFORMATION MONITOR" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # ==========================================================
    # REPOSITORY ROOT
    # ==========================================================
    #
    # TF_WORKING_DIRECTORY is normally:
    #
    #   infrastructure/terraform
    #
    # Therefore:
    #
    #   ../.. = repository root
    #
    # ==========================================================

    $RepositoryRoot = (
      Resolve-Path "../.."
    ).Path

    Write-Host "Repository root:"
    Write-Host $RepositoryRoot

    # ==========================================================
    # NEW MONITOR DIRECTORY
    # ==========================================================

    $MonitorDirectory = Join-Path `
      $RepositoryRoot `
      "deployment-monitor-systam"

    Write-Host ""
    Write-Host "Deployment monitor directory:"
    Write-Host $MonitorDirectory

    # ==========================================================
    # OUTPUT DIRECTORY
    # ==========================================================

    $OutputDirectory = Join-Path `
      $RepositoryRoot `
      "deployment-logs"

    Write-Host ""
    Write-Host "Deployment diagnostics directory:"
    Write-Host $OutputDirectory

    # ==========================================================
    # VERIFY MONITOR DIRECTORY
    # ==========================================================

    if (
      -not (
        Test-Path `
          -LiteralPath $MonitorDirectory
      )
    ) {

      Write-Host ""
      Write-Host "ERROR: deployment-monitor-systam directory was not found." `
        -ForegroundColor Red

      Write-Host ""
      Write-Host "Expected:"
      Write-Host $MonitorDirectory

      exit 1
    }

    # ==========================================================
    # VERIFY REQUIRED FILES
    # ==========================================================

    $RequiredFiles = @(
      "Monitor-CloudFormation.ps1"
      "Start-Deployment.ps1"
      "Generate-Report.ps1"
      "failure-rules.json"
    )

    foreach ($File in $RequiredFiles) {

      $FullPath = Join-Path `
        $MonitorDirectory `
        $File

      if (
        -not (
          Test-Path `
            -LiteralPath $FullPath
        )
      ) {

        Write-Host ""
        Write-Host "ERROR: Required monitoring file missing:" `
          -ForegroundColor Red

        Write-Host $FullPath

        exit 1
      }

      Write-Host "FOUND: $FullPath"
    }

    # ==========================================================
    # DETERMINE ROOT STACK
    # ==========================================================

    $MainStackName = "${env:PROJECT_NAME}-${env:ENVIRONMENT}-MainStack"

    Write-Host ""
    Write-Host "CloudFormation root stack:"
    Write-Host $MainStackName

    Write-Host ""
    Write-Host "AWS region:"
    Write-Host $env:AWS_REGION

    # ==========================================================
    # DETERMINE TERRAFORM PLAN
    # ==========================================================
    #
    # Keep this aligned with your existing workflow.
    #
    # If your Step 14 creates a different plan filename, change
    # TF_PLAN_FILE in your existing workflow.
    #
    # ==========================================================

    if (
      [string]::IsNullOrWhiteSpace(
        $env:TF_PLAN_FILE
      )
    ) {

      Write-Host ""
      Write-Host "ERROR: TF_PLAN_FILE is not defined." `
        -ForegroundColor Red

      exit 1
    }

    Write-Host ""
    Write-Host "Terraform plan:"
    Write-Host $env:TF_PLAN_FILE

    # ==========================================================
    # START PROFESSIONAL DEPLOYMENT ORCHESTRATOR
    # ==========================================================

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "STARTING DEPLOYMENT MONITORING SYSTEM" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow

    & pwsh `
      -NoProfile `
      -NonInteractive `
      -File `
      (Join-Path $MonitorDirectory "Start-Deployment.ps1") `
      -TerraformWorkingDirectory `
      (Get-Location).Path `
      -StackName `
      $MainStackName `
      -Region `
      $env:AWS_REGION `
      -MonitorDirectory `
      $MonitorDirectory `
      -OutputDirectory `
      $OutputDirectory `
      -TerraformPlanFile `
      $env:TF_PLAN_FILE `
      -AutoApprove `
      -PollSeconds `
      3 `
      -MonitorTimeoutMinutes `
      120

    $DeploymentExitCode = $LASTEXITCODE

    Write-Host ""
    Write-Host "============================================================"

    if ($DeploymentExitCode -eq 0) {

      Write-Host `
        "STEP 15 COMPLETED SUCCESSFULLY" `
        -ForegroundColor Green

    }
    else {

      Write-Host `
        "STEP 15 FAILED" `
        -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Final Terraform/Deployment exit code:"
    Write-Host $DeploymentExitCode

    Write-Host ""
    Write-Host "Diagnostic directory:"
    Write-Host $OutputDirectory

    Write-Host "============================================================"

    # ==========================================================
    # TERRAFORM REMAINS AUTHORITATIVE
    # ==========================================================

    exit $DeploymentExitCode
```

---

### 8. Step 16 — upload everything

Immediately after Step 15:

```yaml
# ==========================================================
# STEP 16 - UPLOAD COMPLETE DEPLOYMENT DIAGNOSTICS
# ==========================================================
- name: Step 16 - Upload Complete Deployment Diagnostics
  if: ${{ always() }}
  uses: actions/upload-artifact@v4
  with:
    name: deployment-diagnostics-${{ github.run_id }}
    path: |
      ${{ github.workspace }}/deployment-logs/
    if-no-files-found: warn
    retention-days: 30
```

This means the artifact should contain things such as:

```text
deployment-diagnostics-34255678413.zip

├── deployment-context.json
│
├── terraform.jsonl
├── terraform-stderr.log
│
├── cloudformation-monitor.log
├── cloudformation-events.jsonl
├── cloudformation-failures.jsonl
├── cloudformation-operations.jsonl
│
├── cloudformation-latest-stack.json
├── cloudformation-latest-events.json
├── cloudformation-metadata.json
├── nested-stacks.json
│
├── diagnosis.json
└── deployment-summary.md
```

---

### 9. `README.md`

I also recommend putting a short README inside the new directory.

Create:

```text
aws-hybrid-iac-lab/deployment-monitor-systam/README.md
```

````markdown
# AWS Hybrid IaC Lab - Deployment Monitor System

## Purpose

This directory contains the PowerShell-based deployment monitoring
system used by the AWS Hybrid IaC Lab.

The system monitors CloudFormation while Terraform is executing.

---

## Architecture

```text
GitHub Actions
       |
       v
Start-Deployment.ps1
       |
       +-----------------------+
       |                       |
       v                       v
CloudFormation Monitor     Terraform Apply
       |                       |
       |                       |
       +-----------+-----------+
                   |
                   v
          Generate-Report.ps1
                   |
                   v
          deployment-summary.md
                   |
                   v
          diagnosis.json
````

---

## Files

### Monitor-CloudFormation.ps1

Read-only CloudFormation monitoring process.

It monitors:

* root CloudFormation stack
* nested CloudFormation stacks
* CloudFormation stack events
* CloudFormation operation IDs
* resource failures
* failure reasons

It also creates JSONL evidence files.

---

### Start-Deployment.ps1

Deployment orchestrator.

It:

1. Starts CloudFormation monitoring.
2. Starts Terraform.
3. Captures Terraform output.
4. Waits for Terraform to finish.
5. Signals the CloudFormation monitor.
6. Waits for the monitor to finish.
7. Generates the final diagnosis.
8. Returns Terraform's original exit code.

---

### Generate-Report.ps1

Correlates:

* Terraform exit code
* Terraform errors
* CloudFormation events
* CloudFormation failures
* Operation IDs
* nested stack information

It creates:

```text
diagnosis.json
deployment-summary.md
```

---

### failure-rules.json

Contains failure classification rules.

Examples:

```text
IAM
PassRole
EKS
Networking
S3
Lambda
API Gateway
RDS
DynamoDB
CloudFormation Template
Rollback
```

---

## Required AWS Permissions

The identity running the monitor should be able to perform:

```text
sts:GetCallerIdentity

cloudformation:DescribeStacks
cloudformation:DescribeStackEvents
cloudformation:DescribeStackResources
cloudformation:DescribeEvents
```

The monitor is read-only.

---

## Monitoring Model

The monitor polls CloudFormation every 3 seconds.

This provides near-real-time diagnostics while Terraform is waiting
for CloudFormation.

CloudFormation itself does not push events directly into this script.

The monitor repeatedly queries AWS.

---

## Root Cause Logic

The system intentionally distinguishes between:

### Primary infrastructure failure

Example:

```text
AWS::IAM::Role
CREATE_FAILED
User is not authorized to perform iam:PassRole
```

and:

### Terraform consequence

Example:

```text
Error: failed to create CloudFormation stack
```

The CloudFormation resource failure is considered the primary
infrastructure error when the evidence clearly establishes it.

Terraform's non-zero exit code is then treated as the deployment-level
consequence.

---

## Important

The monitor never changes AWS resources.

It does not:

* create resources
* update resources
* delete resources
* retry Terraform
* modify CloudFormation

Terraform remains authoritative for deployment success/failure.

---

### 10. One thing you should change in your existing workflow

Your old path was:

```text
scripts/deployment-monitor-systam
````

Remove any reference like:

```powershell
scripts/deployment-monitor-systam
```

or:

```yaml
scripts/Monitor-CloudFormation.ps1
```

for this new system.

The correct repository path is:

```text
deployment-monitor-systam/Monitor-CloudFormation.ps1
```

and from the Terraform directory:

```text
../../deployment-monitor-systam/Monitor-CloudFormation.ps1
```

But I deliberately use:

```powershell
$RepositoryRoot = Resolve-Path "../.."

$MonitorDirectory = Join-Path `
    $RepositoryRoot `
    "deployment-monitor-systam"
```

so we don't have to hard-code `../../` everywhere.

---

### 11. What the final system now does

Your deployment flow becomes:

```text
                    GitHub Actions
                          │
                          ▼
                  Terraform Plan
                          │
                          ▼
                 ┌─────────────────┐
                 │ Step 15          │
                 │ Start-Deployment │
                 └────────┬────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
              ▼                       ▼
      CloudFormation Monitor     Terraform Apply
              │                       │
              │                       │
       every 3 seconds                │
              │                       │
              ▼                       ▼
       MainStack events          Terraform JSONL
              │                       │
              ▼                       │
       Nested stack events            │
              │                       │
              ▼                       │
       Operation IDs                  │
              │                       │
              ▼                       │
       Failed resources               │
              │                       │
              └───────────┬───────────┘
                          │
                          ▼
                  Terraform finishes
                          │
                          ▼
                 Monitor stop signal
                          │
                          ▼
                 Generate-Report.ps1
                          │
             ┌────────────┴────────────┐
             ▼                         ▼
       diagnosis.json          deployment-summary.md
             │                         │
             └────────────┬────────────┘
                          ▼
                    GitHub Artifact
```

The key improvement is that **Operation ID is now a first-class piece of evidence**, rather than something we merely hope to find inside an old event structure. AWS documents `LastOperations` specifically for obtaining recent operation IDs, and `DescribeEvents` is designed to group events by those operation IDs. ([AWS Documentation][1])

Also, `describe-stack-events` remains useful because AWS documents it as returning stack events in reverse chronological order and its current event structure includes `OperationId`. ([AWS Documentation][3])

### Final important note

I would **not** keep the older Step 15 implementation you pasted at the same time as this one. Replace it with the new Step 15 above so you have **one orchestration system**, otherwise you can accidentally start two monitors or two Terraform processes.

Your final monitoring-system location is therefore exactly:

```text
aws-hybrid-iac-lab/
└── deployment-monitor-systam/
    ├── failure-rules.json
    ├── Monitor-CloudFormation.ps1
    ├── Start-Deployment.ps1
    ├── Generate-Report.ps1
    └── README.md
```

And the runtime diagnostics are:

```text
aws-hybrid-iac-lab/
└── deployment-logs/
```

[1]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/view-stack-events-by-operation.html?utm_source=chatgpt.com "View stack events by operation - AWS CloudFormation"
[2]: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-events.html?utm_source=chatgpt.com "describe-events — AWS CLI 2.36.40 Command Reference"
[3]: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-stack-events.html?utm_source=chatgpt.com "describe-stack-events — AWS CLI 2.36.40 Command Reference"
