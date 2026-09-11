1. Add IAM management for the HybridIaC role

I recommend keeping this narrowly scoped to the role Terraform is managing.

Create a file:

```
infrastructure/terraform/github-ci-cd-hybrid-iac-iam-policy.json
```

with:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageHybridIaCCloudFormationExecutionRole",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:DeleteRolePolicy"
      ],
      "Resource": "arn:aws:iam::537236558357:role/HybridIaCLab-dev-CloudFormationExecutionRole"
    }
  ]
}
```

Then attach it as a new managed policy to github-ci-cd-user.

From your project root:

```
aws iam create-policy `
  --policy-name "github-ci-cd-hybrid-iac-iam-management" `
  --policy-document "file://infrastructure/terraform/github-ci-cd-hybrid-iac-iam-policy.json"
```

You should receive an ARN similar to:

arn:aws:iam::537236558357:policy/github-ci-cd-hybrid-iac-iam-management

Then:

aws iam attach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-hybrid-iac-iam-management"
2. Fix the PassRole permission

This is important.

Your current policy allows:

CharlieCafe-CloudFormation-ServiceRole

but your Terraform configuration is creating/using:

HybridIaCLab-dev-CloudFormationExecutionRole

Therefore the existing PassRole statement doesn't cover this project.

You should add a separate statement for the HybridIaC role.

I would not replace your existing Charlie Cafe statement if that old project is still in use.

Instead, create another policy specifically for this lab.

Create:

infrastructure/terraform/github-ci-cd-hybrid-iac-passrole-policy.json

with:

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PassHybridIaCCloudFormationExecutionRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::537236558357:role/HybridIaCLab-dev-CloudFormationExecutionRole",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "cloudformation.amazonaws.com"
        }
      }
    }
  ]
}

Create it:

aws iam create-policy `
  --policy-name "github-ci-cd-hybrid-iac-passrole" `
  --policy-document "file://infrastructure/terraform/github-ci-cd-hybrid-iac-passrole-policy.json"

Then attach it:

aws iam attach-user-policy `
  --user-name "github-ci-cd-user" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-hybrid-iac-passrole"
3. Verify the policies

Run:

aws iam list-attached-user-policies `
  --user-name "github-ci-cd-user"

You should now see these additional policies:

github-ci-cd-hybrid-iac-iam-management
github-ci-cd-hybrid-iac-passrole

Your existing policies can remain.

4. Then test the Terraform plan

Run:

terraform -chdir="infrastructure/terraform" plan

You should still get:

Plan: 2 to add, 0 to change, 0 to destroy.

The important difference is that Terraform should now be authorized to create:

aws_iam_role_policy.cloudformation_lab_permissions
5. Before apply, I want you to check one thing

There is a subtle point in your configuration.

Your Terraform plan shows:

aws_cloudformation_stack.main

but it doesn't show:

role_arn = ...

in the displayed attributes.

That means I want to see your actual aws_cloudformation_stack "main" resource before we assume that the PassRole policy is required.

Please show me the relevant section of:

infrastructure/terraform/main.tf

specifically:

resource "aws_cloudformation_stack" "main" {
    ...
}

Also, because your CloudFormation execution role currently has:

ec2:*
s3:*
cloudfront:*
lambda:*
apigateway:*
rds:*
dynamodb:*
ecr:*
ecs:*
eks:*
logs:*

we should not yet assume that this is sufficient for all your nested templates. Your api_gateway.yaml, cloudfront.yaml, ec2.yaml, ecs.yaml, rds.yaml, and eks.yaml may require additional AWS service permissions.

So don't run apply yet.

Send me the aws_cloudformation_stack "main" block from main.tf, and I can check the Terraform → CloudFormation role chain first.

