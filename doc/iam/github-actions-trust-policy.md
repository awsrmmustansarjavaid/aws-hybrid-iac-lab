Based on the output you provided, your OIDC provider exists and the role has the correct basic OIDC structure. The part I would change for a permanent, more secure solution is the sub condition.

Your current policy is:

repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*

That trusts every GitHub Actions OIDC subject from that repository—all branches, environments, PR-related subjects, etc. AWS recommends restricting this further to the repository and branch when possible.

Since your failing workflow is running from main, I recommend locking this role specifically to:

repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main

That gives you a much more deterministic OIDC trust relationship.

1. Create the permanent trust policy

Create this file:

github-actions-trust-policy.json

Put this inside:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOIDCTrust",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
        }
      }
    }
  ]
}

This is the important change:

"token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"

AWS documents this repository + branch pattern as the recommended way to restrict GitHub OIDC role assumption.

2. Apply it to your role

From PowerShell, from the directory containing the JSON file:

aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document file://github-actions-trust-policy.json

You should get no error.

3. Immediately verify it

Run:

aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json

You want to see:

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "GitHubActionsOIDCTrust",
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
                    "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
                }
            }
        }
    ]
}
4. Your GitHub workflow must also permanently have this

Your Terraform workflow needs:

permissions:
  id-token: write
  contents: read

For example:

name: Terraform Infrastructure Deployment

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    name: Terraform Infrastructure Deployment
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - name: Verify AWS Identity
        run: |
          aws sts get-caller-identity

      # Terraform steps...

GitHub specifically requires id-token: write for the workflow to request its OIDC JWT.

5. Check your GitHub secret

Your:

AWS_ROLE_ARN

should contain exactly:

arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions

Notice:

role/aws-hybrid-iac-lab-GitHubActions

not:

user/github-ci-cd-user

and not:

role/github-ci-cd-user
6. Your combined IAM policy is a separate issue

This is the key thing I want you to understand.

You currently have:

GitHub
   │
   │ OIDC
   ▼
AWS STS
   │
   │ AssumeRoleWithWebIdentity
   ▼
aws-hybrid-iac-lab-GitHubActions
   │
   ▼
Permissions attached to ROLE
   │
   ├── S3
   ├── EC2
   ├── CloudFormation
   ├── Lambda
   ├── ECS
   ├── ECR
   ├── SSM
   └── etc.

Your:

github-ci-cd-user-combined-access

belongs to:

github-ci-cd-user

That's a different IAM principal.

Therefore, that policy does not determine whether GitHub can perform:

sts:AssumeRoleWithWebIdentity

The role's trust policy determines that.

7. There is another important architectural issue

You currently have this in your combined IAM user policy:

{
  "Sid": "ManageGitHubActionsRoleTrustPolicy",
  "Effect": "Allow",
  "Action": [
    "iam:GetRole",
    "iam:UpdateAssumeRolePolicy"
  ],
  "Resource": "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions"
}

I would remove iam:UpdateAssumeRolePolicy from your CI/CD IAM user if you want a genuinely permanent and secure setup.

Why?

Because your CI/CD identity should not be able to modify the very trust relationship that controls who can become the CI/CD role.

Otherwise the flow can effectively become:

CI/CD identity
     │
     ├── Can modify GitHubActions trust policy
     │
     ▼
GitHubActions role
     │
     ▼
AWS infrastructure

That weakens the security boundary.

I recommend keeping:

"iam:GetRole"

if your automation needs to inspect the role, but removing:

"iam:UpdateAssumeRolePolicy"

from the CI/CD user's policy.

8. One more thing: your current sub:* isn't why the current error happens

This is important.

Your current policy:

"StringLike": {
  "token.actions.githubusercontent.com:sub":
    "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*"
}

should already match a normal main branch subject:

repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main

So simply seeing:

sts:AssumeRoleWithWebIdentity

doesn't prove that the wildcard * is causing yesterday's failure.

Your current trust policy looks structurally valid.

Therefore, if you apply the branch-specific policy and the workflow still returns:

Not authorized to perform sts:AssumeRoleWithWebIdentity

then we should investigate the next layer rather than repeatedly changing the policy.

9. I would do these checks in this exact order
Check 1 — OIDC provider

You already confirmed this exists:

arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com

✅ Good.

Check 2 — Trust policy

Change:

repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:*

to:

repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main
Check 3 — GitHub permissions

Make sure:

permissions:
  id-token: write
  contents: read
Check 4 — Role ARN

Make sure:

AWS_ROLE_ARN

is:

arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions
Check 5 — Workflow branch

Your workflow must actually run from:

main

which your log appears to show.

Check 6 — Test

Add this immediately after AWS credentials:

- name: Verify AWS Identity
  run: |
    aws sts get-caller-identity

If this passes, OIDC is fixed. Any subsequent Terraform failure is a separate IAM permissions problem.

The permanent architecture I recommend

For your project, I would keep these as three separate security layers:

┌─────────────────────────────────────────────┐
│             GitHub Repository               │
│                                             │
│  awsrmmustansarjavaid/aws-hybrid-iac-lab    │
│                    │                        │
│                    │ OIDC JWT               │
└────────────────────┼────────────────────────┘
                     ▼
┌─────────────────────────────────────────────┐
│        GitHub OIDC Provider in AWS          │
│                                             │
│ token.actions.githubusercontent.com         │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│     aws-hybrid-iac-lab-GitHubActions        │
│                  IAM Role                   │
│                                             │
│ Trust:                                      │
│ repo:.../aws-hybrid-iac-lab:                │
│ ref:refs/heads/main                         │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│        Role Permissions                     │
│                                             │
│ S3 / EC2 / CloudFormation / Lambda / ECS    │
│ ECR / SSM / CloudWatch / IAM / etc.         │
└─────────────────────────────────────────────┘

And separately:

github-ci-cd-user
       │
       └── Administrative/bootstrap purposes

I would not make the IAM user responsible for modifying the OIDC trust policy during normal CI/CD operation.

GitHub's current guidance also emphasizes restricting the OIDC sub claim to the repository/branch or environment rather than broadly trusting the repository with a wildcard.

One caveat for September 2026

GitHub now documents an immutable subject format for repositories created after July 15, 2026, or repositories that have opted into immutable subject claims. Those subjects can look like:

repo:ORG@OWNER_ID/REPO@REPO_ID:ref:refs/heads/main

rather than:

repo:ORG/REPO:ref:refs/heads/main

So before locking your policy permanently, we should confirm which subject format your repository actually emits.

For your existing repository, don't change to the immutable format blindly. Your current trust policy's successful repository match is useful evidence, but if you want me to make this truly permanent, the next thing I'd check is your current terraform.yml, especially its permissions, on: branch/environment configuration, and role-to-assume.

Yes — I see the problem. The JSON itself is a valid IAM role trust policy, but you are almost certainly trying to put it into the wrong IAM policy editor.

The error:

Policy error
Has prohibited field Principal

means AWS is treating what you're entering as a permissions policy, not as an IAM role trust policy.

Principal is allowed in a role trust policy, but it is prohibited in an ordinary IAM permissions policy.

Do NOT put this JSON into:
github-ci-cd-user-combined-access

That is a permissions policy.

Put it here:

IAM → Roles → aws-hybrid-iac-lab-GitHubActions → Trust relationships → Edit trust policy

Your existing role already has a trust policy, so you should edit that trust relationship rather than create another customer-managed permissions policy.

One correction to the JSON you pasted

Your pasted JSON contains escaped colons:

"arn\:aws\:iam..."

and:

"token.actions.githubusercontent.com\:aud"

Those backslashes should not be there in the actual JSON file/editor.

Use this exact policy:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsOIDCTrust",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
        }
      }
    }
  ]
}
Then save it under:
IAM
└── Roles
    └── aws-hybrid-iac-lab-GitHubActions
        └── Trust relationships
            └── Edit trust policy

Not:

IAM
└── Policies
    └── github-ci-cd-user-combined-access
Even better: use PowerShell

Since your current trust policy is already correct structurally, I recommend avoiding the AWS Console policy editor entirely.

Save the above as:

github-actions-trust-policy.json

Then run:

aws iam update-assume-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-document file://github-actions-trust-policy.json

Then verify:

aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json

You should see:

"Principal": {
  "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
}

and:

"token.actions.githubusercontent.com:sub": "repo:awsrmmustansarjavaid/aws-hybrid-iac-lab:ref:refs/heads/main"
Important

Do not add Principal to github-ci-cd-user-combined-access.

That policy is a permissions policy and should continue to look like:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "..."
      ],
      "Resource": "*"
    }
  ]
}

The Principal belongs specifically in the trust policy of aws-hybrid-iac-lab-GitHubActions.

If you want, 
paste your current terraform.yml next. I can 
check the workflow's permissions, AWS_ROLE_ARN, branch, and OIDC configuration together so we can fix the AssumeRoleWithWebIdentity error permanently rather than changing IAM policies blindly.
