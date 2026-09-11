Yes — we can consolidate the permissions into one customer-managed policy, but there is one important correction to your plan:

You cannot put other IAM managed policies inside another IAM managed policy.

For example, you cannot create github-ci-cd-user-manager-all-iam-policy and then attach AdministratorAccess, IAMFullAccess, and your custom policies to that policy. IAM managed policies are standalone policies attached to users, groups, or roles.

Instead, we can read the permissions from your existing AWS-managed/custom policies and create one new customer-managed policy containing the required permissions.

Step 1 — First, see exactly what is attached

Assuming the IAM user is the GitHub CI/CD IAM user, run this PowerShell command:

aws iam list-attached-user-policies `
  --user-name "github-ci-cd-user" `
  --output table

This will show the managed policies attached to the user, including both:

AWS managed policies
Customer managed policies

AWS provides list-attached-user-policies for exactly this type of inspection.

Step 2 — Also check inline policies

Run:

aws iam list-user-policies `
  --user-name "github-ci-cd-user" `
  --output table

This is important because inline policies are different from managed policies.

Step 3 — Get the complete list with useful information

I recommend this PowerShell command:

aws iam list-attached-user-policies `
  --user-name "github-ci-cd-user" `
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" `
  --output table

You should get something similar to:

---------------------------------------------------------------
|                    ListAttachedUserPolicies                 |
+-------------------------------+-----------------------------+
| PolicyName                    | PolicyArn                   |
+-------------------------------+-----------------------------+
| IAMFullAccess                 | arn:aws:iam::aws:policy/IAMFullAccess
| AmazonS3FullAccess            | arn:aws:iam::aws:policy/AmazonS3FullAccess
| github-ci-cd-custom-policy    | arn:aws:iam::537236558357:policy/github-ci-cd-custom-policy
| github-ci-cd-user-iam-role-management
|                               | arn:aws:iam::537236558357:policy/github-ci-cd-user-iam-role-management
+-------------------------------+-----------------------------+
Step 4 — Find all customer-managed policies

This command lists the policies that belong to your AWS account:

aws iam list-policies `
  --scope Local `
  --query "Policies[].{PolicyName:PolicyName,PolicyArn:Arn}" `
  --output table

--scope Local means customer-managed policies rather than AWS-managed policies.

Step 5 — Check which policies are attached to the user

For a particular policy:

aws iam list-entities-for-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-iam-role-management" `
  --output table

This tells us whether the policy is attached to users, groups, or roles.

Important: I recommend we don't blindly combine everything

You mentioned:

"add all AWS managed policy and my custom IAM policy inside this new IAM policy"

Technically, we should not simply copy every permission from every policy.

For your GitHub CI/CD setup, we should first inventory what you currently have:

github-ci-cd-user
       |
       +-- AWS managed policy
       |
       +-- AWS managed policy
       |
       +-- custom policy
       |
       +-- custom policy
       |
       +-- inline policy

Then we can build:

github-ci-cd-user
       |
       +-- github-ci-cd-user-manager-all-iam-policy
                    |
                    +-- required IAM permissions
                    +-- required S3 permissions
                    +-- required CloudFormation permissions
                    +-- required Terraform permissions
                    +-- required EC2 permissions
                    +-- required ECR permissions
                    +-- required ECS/EKS permissions
                    +-- required other lab permissions

This gives you one customer-managed policy attached to the GitHub CI/CD identity.

AWS specifically supports customer-managed policies for permissions that you control yourself, and those policies can be attached to IAM users, groups, and roles.

One more important point

If your reason for doing this is:

"I cannot attach another IAM policy because I reached the policy attachment limit."

then creating another policy does not automatically solve the limit if that new policy is simply attached in addition to the existing ones.

The solution is to:

Inspect existing policies.
Combine the required permissions into the new policy.
Attach the new policy.
Verify it.
Detach the old policies that have been consolidated.

AWS documents attaching and detaching managed policies with attach-user-policy and detach-user-policy.

Let's do this safely

Do not delete or detach anything yet.

First run these two commands in PowerShell:

aws iam list-attached-user-policies `
  --user-name "github-ci-cd-user" `
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" `
  --output table

and:

aws iam list-user-policies `
  --user-name "github-ci-cd-user" `
  --output table

Paste both outputs here. Then I can identify every AWS-managed and custom policy you currently have and build the exact github-ci-cd-user-manager-all-iam-policy JSON for your AWS hybrid IaC/GitHub Actions project, rather than giving you an unnecessarily broad *:* policy.


Yes. I’ve reviewed the output carefully.

What you currently have

Your github-ci-cd-user has:

10 attached managed policies

4 AWS-managed:
AmazonSSMFullAccess
AmazonEC2FullAccess
AmazonSSMReadOnlyAccess
IAMReadOnlyAccess
AmazonS3FullAccess
AWSCloudFormationFullAccess
4 customer-managed attached policies:
aws-rds-CreateDBSnapshot
github-ci-cd-user-iam-role-management
GitHub-Actions
iam-policiesgithub-ci-cd-cloudformation-passrole-policy

Actually, that is 6 AWS-managed + 4 customer-managed = 10 attached managed policies.

You also have 6 inline policies:

aws-rds-CreateDBSnapshot
CharlieCafe-ECS-ECR-CloudFormation-Policy
CloudFormation-Lab-S3-RDS-Policy
GitHubActions-ECR-ECS-Policy
GitHubCICD-RDS-KMS-SecretsManager-Access
Lab01-CloudFormation-ECS-ECR-IAM

And your account contains many additional customer-managed policies that aren't currently attached to this user.

My recommendation

Do NOT create an IAM role just to put all these policies into it.

An IAM role is not a container for policies that you then attach to the user. Instead:

IAM User
   |
   +-- Managed Policy 1
   +-- Managed Policy 2
   +-- Managed Policy 3
   +-- ...
   +-- Inline Policy

A role looks like:

GitHub Actions
      |
      | AssumeRoleWithWebIdentity
      v
GitHub-Actions-Role
      |
      +-- Managed Policy
      +-- Managed Policy
      +-- Inline Policy

For your GitHub Actions + AWS hybrid IaC project, I actually recommend the second architecture.

Better architecture
GitHub Actions
      |
      | GitHub OIDC
      v
AWS STS
      |
      | AssumeRoleWithWebIdentity
      v
github-actions-terraform-role
      |
      +-- github-ci-cd-user-manager-all-iam-policy
      |
      +-- other narrowly scoped policies if necessary

Then GitHub Actions doesn't need to use:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

Instead it uses:

GitHub OIDC
       ↓
IAM Role
       ↓
Temporary AWS credentials

That is much better for your CI/CD architecture.

But there is an important issue in your current setup

You have duplicate/overlapping permissions.

For example:

AmazonEC2FullAccess

plus:

AmazonSSMFullAccess
AmazonSSMReadOnlyAccess

The AmazonSSMReadOnlyAccess permissions are largely redundant if you already have AmazonSSMFullAccess.

You also have:

AmazonS3FullAccess

while you have several custom policies dealing with S3.

And:

AWSCloudFormationFullAccess

while you have several CloudFormation-related custom policies.

So I would not blindly merge everything.

What I would do in your project

I would migrate from this:

github-ci-cd-user
│
├── AmazonEC2FullAccess
├── AmazonSSMFullAccess
├── AmazonSSMReadOnlyAccess
├── IAMReadOnlyAccess
├── AmazonS3FullAccess
├── AWSCloudFormationFullAccess
├── aws-rds-CreateDBSnapshot
├── github-ci-cd-user-iam-role-management
├── GitHub-Actions
├── iam-policiesgithub-ci-cd-cloudformation-passrole-policy
│
├── 6 inline policies
│
└── lots of duplicated permissions

to something like:

GitHub Actions
       │
       │ OIDC
       ▼
┌─────────────────────────────────────┐
│ github-actions-terraform-role       │
│                                     │
│ Trust: GitHub OIDC                  │
│                                     │
│ Permissions:                        │
│                                     │
│ └── github-ci-cd-user-manager-all-  │
│     iam-policy                      │
└─────────────────────────────────────┘

And the new policy would contain the actual permissions your pipeline requires, not other policies themselves.

But don't create the new policy yet

This is important.

Before creating:

github-ci-cd-user-manager-all-iam-policy

I want to inspect the contents of your existing policies.

For example, we need to know what is inside:

GitHub-Actions
github-ci-cd-user-iam-role-management
iam-policiesgithub-ci-cd-cloudformation-passrole-policy
aws-rds-CreateDBSnapshot

and especially your six inline policies.

Otherwise, we could accidentally remove a permission that Terraform or CloudFormation needs.

Run this first

For the four customer-managed policies attached to the user, run:

aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/aws-rds-CreateDBSnapshot"
aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-iam-role-management"
aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/GitHub-Actions"
aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/iam-policiesgithub-ci-cd-cloudformation-passrole-policy"

But get-policy only gives us the policy metadata/default version. We also need the actual JSON.

For example:

aws iam get-policy-version `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-iam-role-management" `
  --version-id "v1"

The version may not be v1, so let's get the default version automatically:

$PolicyArn = "arn:aws:iam::537236558357:policy/github-ci-cd-user-iam-role-management"

$VersionId = aws iam get-policy `
  --policy-arn $PolicyArn `
  --query "Policy.DefaultVersionId" `
  --output text

aws iam get-policy-version `
  --policy-arn $PolicyArn `
  --version-id $VersionId
Even better: let's inspect everything automatically

Since you have quite a few policies, I recommend we create a PowerShell inspection script that outputs:

========================================
GITHUB CI/CD IAM AUDIT
========================================

USER
github-ci-cd-user

MANAGED POLICIES
----------------
AWS Managed
    AmazonEC2FullAccess
    AmazonSSMFullAccess
    ...

Customer Managed
    GitHub-Actions
    github-ci-cd-user-iam-role-management
    ...

INLINE POLICIES
---------------
    aws-rds-CreateDBSnapshot
    CharlieCafe-ECS-ECR-CloudFormation-Policy
    ...

POLICY ACTIONS
--------------
s3:*
ec2:*
cloudformation:*
iam:*
ecr:*
ecs:*
rds:*
secretsmanager:*
kms:*
ssm:*
...

Then we can identify duplicates and excessive permissions before creating the new policy.

One thing I strongly recommend

Don't call the new policy:

github-ci-cd-user-manager-all-iam-policy

if we're eventually moving GitHub Actions from an IAM user to an IAM role.

A cleaner name would be:

github-ci-cd-hybrid-iac-policy

and the role:

github-actions-hybrid-iac-role

Architecture:

GitHub Repository
       │
       │ GitHub Actions
       ▼
GitHub OIDC Provider
       │
       │ AssumeRoleWithWebIdentity
       ▼
github-actions-hybrid-iac-role
       │
       └── github-ci-cd-hybrid-iac-policy
              │
              ├── Terraform
              ├── CloudFormation
              ├── S3
              ├── EC2
              ├── ECR
              ├── ECS
              ├── RDS
              ├── IAM
              ├── SSM
              ├── Secrets Manager
              └── KMS

This is the direction I recommend for your lab.

But before we change anything, let's inspect the six inline policies and four attached customer-managed policies. Then I can tell you exactly what should be retained, merged, removed, or moved to the new GitHub Actions role.

Yes — I understand exactly what you want now.

You want to replace the AWS-managed policies with one customer-managed policy, so instead of attaching these individually:

AmazonSSMFullAccess
AmazonEC2FullAccess
AmazonSSMReadOnlyAccess
IAMReadOnlyAccess
AmazonS3FullAccess
AWSCloudFormationFullAccess

you will have:

github-ci-cd-user-aws-manager-policies

attached to github-ci-cd-user.

Important clarification

We cannot put the six AWS-managed policies inside the new policy as policy references.

Instead, we create one customer-managed policy containing the combined IAM actions/permissions provided by those AWS-managed policies.

Also, you listed 6 AWS-managed policies, not 4.

Your new structure
github-ci-cd-user
│
├── github-ci-cd-user-aws-manager-policies     ← NEW
│
├── aws-rds-CreateDBSnapshot
├── github-ci-cd-user-iam-role-management
├── GitHub-Actions
├── iam-policiesgithub-ci-cd-cloudformation-passrole-policy
│
└── existing inline policies

The new policy will represent the permissions from:

AmazonSSMFullAccess
AmazonEC2FullAccess
AmazonSSMReadOnlyAccess
IAMReadOnlyAccess
AmazonS3FullAccess
AWSCloudFormationFullAccess
One thing I recommend

Because AmazonSSMFullAccess already provides SSM write access, AmazonSSMReadOnlyAccess doesn't add meaningful additional capability for a user that already has the full-access policy. But if your goal is an exact combined replacement, we can include the union of permissions from all six policies.

I would not remove the six AWS-managed policies yet.

First, we should generate the combined policy and validate it. Then:

1. Create github-ci-cd-user-aws-manager-policies
             ↓
2. Attach it to github-ci-cd-user
             ↓
3. Verify permissions
             ↓
4. Detach the six AWS-managed policies
             ↓
5. Keep the new customer-managed policy



Yes. Below is the customer-managed policy you can create as:

github-ci-cd-user-aws-manager-policies

It combines the effective permissions of the six AWS-managed policies you listed. AWS confirms that these are standalone AWS-managed policies, and their permissions can be represented in a customer-managed policy.

Important: This is a snapshot of the permissions, not a live reference to those AWS-managed policies. If AWS later changes one of those managed policies, your customer-managed policy will not automatically change.

github-ci-cd-user-aws-manager-policies.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AmazonEC2FullAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ElasticLoadBalancingFullAccess",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchFullAccess",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScalingFullAccess",
      "Effect": "Allow",
      "Action": [
        "autoscaling:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2ServiceLinkedRoles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": [
            "autoscaling.amazonaws.com",
            "ec2scheduled.amazonaws.com",
            "elasticloadbalancing.amazonaws.com",
            "spot.amazonaws.com",
            "spotfleet.amazonaws.com",
            "transitgateway.amazonaws.com"
          ]
        }
      }
    },
    {
      "Sid": "SSMFullAccess",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ds:CreateComputer",
        "ds:DescribeDirectories",
        "ec2:DescribeInstanceStatus",
        "logs:*",
        "ssm:*",
        "ec2messages:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSMServiceLinkedRoleCreate",
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole"
      ],
      "Resource": "arn:aws:iam::*:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM*",
      "Condition": {
        "StringLike": {
          "iam:AWSServiceName": "ssm.amazonaws.com"
        }
      }
    },
    {
      "Sid": "SSMServiceLinkedRoleDelete",
      "Effect": "Allow",
      "Action": [
        "iam:DeleteServiceLinkedRole",
        "iam:GetServiceLinkedRoleDeletionStatus"
      ],
      "Resource": "arn:aws:iam::*:role/aws-service-role/ssm.amazonaws.com/AWSServiceRoleForAmazonSSM*"
    },
    {
      "Sid": "SSMMessagesAccess",
      "Effect": "Allow",
      "Action": [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3FullAccess",
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "s3-object-lambda:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudFormationFullAccess",
      "Effect": "Allow",
      "Action": [
        "cloudformation:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMReadOnlyAccess",
      "Effect": "Allow",
      "Action": [
        "iam:GenerateCredentialReport",
        "iam:GenerateServiceLastAccessedDetails",
        "iam:Get*",
        "iam:List*",
        "iam:SimulateCustomPolicy",
        "iam:SimulatePrincipalPolicy"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SSMReadOnlyAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:Describe*",
        "ssm:Get*",
        "ssm:List*"
      ],
      "Resource": "*"
    }
  ]
}

The EC2, SSM, S3, CloudFormation, and IAM portions above correspond to the AWS-managed policy documents currently documented by AWS.

Create it from PowerShell

Save the JSON as:

github-ci-cd-user-aws-manager-policies.json

Then create the customer-managed policy:

aws iam create-policy `
  --policy-name "github-ci-cd-user-aws-manager-policies" `
  --policy-document "file://github-ci-cd-user-aws-manager-policies.json"

Then attach it to your existing user:

aws iam attach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-aws-manager-policies"

Verify:

aws iam list-attached-user-policies `
  --user-name "github-ci-cd-user" `
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" `
  --output table
Then, and only then, remove the old AWS-managed policies

After you've verified the new policy is attached, you can detach:

aws iam detach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::aws:policy/AmazonSSMFullAccess"

aws iam detach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess"

aws iam detach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"

aws iam detach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::aws:policy/IAMReadOnlyAccess"

aws iam detach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::aws:policy/AmazonS3FullAccess"

aws iam detach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"

I recommend doing the detach step only after we verify the new policy. This avoids accidentally breaking your GitHub Actions/Terraform pipeline.

Also, note that your original list actually contains six AWS-managed policies, not four.

