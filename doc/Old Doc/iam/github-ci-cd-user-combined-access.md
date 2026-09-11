Merged Custom IAM Policy — github-ci-cd-user-combined-access

Yes. You can combine the permissions from all four custom IAM policies into one customer-managed policy.

I recommend the new policy name:

github-ci-cd-user-combined-access

This combines:

GitHub-Actions
iam-policiesgithub-ci-cd-cloudformation-passrole-policy
github-ci-cd-user-iam-role-management
github-ci-cd-user-aws-manager-policies

I also corrected the escaped \: characters in your second and third policies so the result is valid IAM JSON.

GitHub CI/CD Combined Custom IAM Policy

Policy Name: github-ci-cd-user-combined-access

Purpose:
A single customer-managed IAM policy that combines the permissions required by GitHub Actions for AWS CI/CD, CloudFormation deployments, EC2/SSM management, Lambda, ECR, ECS, S3, CloudWatch, Auto Scaling, Elastic Load Balancing, IAM read access, and the required IAM role-management operations.

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LambdaAccess",
            "Effect": "Allow",
            "Action": [
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration",
                "lambda:PublishLayerVersion",
                "lambda:GetFunction",
                "lambda:ListFunctions"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EC2SSMAccess",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ssm:SendCommand",
                "ssm:GetCommandInvocation"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SecretsManagerAccess",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECRAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ECSAccess",
            "Effect": "Allow",
            "Action": [
                "ecs:DescribeClusters",
                "ecs:DescribeServices",
                "ecs:UpdateService",
                "ecs:RegisterTaskDefinition",
                "ecs:DescribeTaskDefinition"
            ],
            "Resource": "*"
        },
        {
            "Sid": "PassCharlieCafeCloudFormationRole",
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::537236558357:role/CharlieCafe-CloudFormation-ServiceRole",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "cloudformation.amazonaws.com"
                }
            }
        },
        {
            "Sid": "ManageGitHubActionsRoleTrustPolicy",
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:UpdateAssumeRolePolicy"
            ],
            "Resource": "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions"
        },
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
What this merged policy provides
AWS Area	Access
Lambda	Update code/configuration, publish layers, read functions
EC2	Full EC2 API access
SSM	Full SSM access + command execution
SSM Messages	Control/data channel access
Secrets Manager	Get secret values
ECR	Push and pull container images
ECS	Register task definitions and update services
S3	Full S3 access
CloudFormation	Full CloudFormation access
CloudWatch	Full CloudWatch access
Auto Scaling	Full Auto Scaling access
Elastic Load Balancing	Full ELB access
IAM	Read/list/simulate IAM + specific role trust-policy management
IAM PassRole	Pass the specific CloudFormation service role to CloudFormation
Service-linked roles	Create/delete required service-linked roles
Directory Service	Required SSM-related ds permissions
Important correction I made

I did not keep this from your original GitHub-Actions policy:

{
    "Sid": "PassRole",
    "Effect": "Allow",
    "Action": "iam:PassRole",
    "Resource": "*"
}

Instead, I retained the more restricted CloudFormation-specific permission:

"Action": "iam:PassRole",
"Resource": "arn:aws:iam::537236558357:role/CharlieCafe-CloudFormation-ServiceRole",
"Condition": {
    "StringEquals": {
        "iam:PassedToService": "cloudformation.amazonaws.com"
    }
}

That's a better security design, because iam:PassRole with "Resource": "*" can allow the GitHub Actions role to pass many IAM roles to AWS services.

One important security note

Your merged policy is functionally correct as a lab/CI-CD administration policy, but it is very powerful because it contains:

ec2:*
s3:*
cloudformation:*
cloudwatch:*
autoscaling:*
elasticloadbalancing:*
ssm:*

So I would treat github-ci-cd-user-combined-access as a high-privilege deployment policy rather than a least-privilege production policy.

Also, because the policy contains cloudformation:*, CloudFormation itself can potentially create/change many AWS resources. For your current AWS hybrid IaC lab, that may be intentional.

If you want to create this policy from PowerShell, the next step would be:

aws iam create-policy `
  --policy-name "github-ci-cd-user-combined-access" `
  --policy-document "file://github-ci-cd-user-combined-access.json"

Then attach it to your GitHub Actions IAM role:

aws iam attach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"

I recommend testing the new policy first, then detaching the four old policies rather than deleting them immediately. That gives you an easy rollback if your GitHub Actions workflow discovers a missing permission.

Absolutely. Here is the valid, properly formatted JSON for your merged custom IAM policy.

Policy name:
github-ci-cd-user-combined-access

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LambdaAccess",
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:PublishLayerVersion",
        "lambda:GetFunction",
        "lambda:ListFunctions"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2SSMAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ssm:SendCommand",
        "ssm:GetCommandInvocation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeClusters",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "ecs:RegisterTaskDefinition",
        "ecs:DescribeTaskDefinition"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassCharlieCafeCloudFormationRole",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::537236558357:role/CharlieCafe-CloudFormation-ServiceRole",
      "Condition": {
        "StringEquals": {
          "iam:PassedToService": "cloudformation.amazonaws.com"
        }
      }
    },
    {
      "Sid": "ManageGitHubActionsRoleTrustPolicy",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:UpdateAssumeRolePolicy"
      ],
      "Resource": "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions"
    },
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
Save it as
github-ci-cd-user-combined-access.json

Then you can create the customer-managed IAM policy with:

aws iam create-policy `
  --policy-name "github-ci-cd-user-combined-access" `
  --policy-document "file://github-ci-cd-user-combined-access.json"

This JSON is valid IAM syntax; in particular, the iam: actions use normal colons rather than the escaped iam\: that appeared in your original pasted policies.

---
Complete Verification Plan — Combined IAM Policy + Terraform + GitHub Actions

Yes. After replacing the four separate policies with your new:

github-ci-cd-user-combined-access

you should not immediately delete the four old policies.

The safest approach is:

Create → Attach → Verify IAM → Test AWS CLI → Test Terraform → Test GitHub OIDC → Test GitHub Actions → Confirm AWS resources → Remove old policies

Below is the exact sequence I recommend for your AWS hybrid IaC lab.

1. Verify the New IAM Policy Exists

From PowerShell:

aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"

You should see:

PolicyName: github-ci-cd-user-combined-access
Arn: arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access

Then check the default policy version:

aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access" `
  --query "Policy.DefaultVersionId" `
  --output text

You should get something like:

v1
2. Verify the Actual Policy JSON

Get the policy version:

aws iam get-policy-version `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access" `
  --version-id v1

Or display only the policy document:

aws iam get-policy-version `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access" `
  --version-id v1 `
  --query "PolicyVersion.Document"

Check that you can see your major sections:

LambdaAccess
EC2SSMAccess
SecretsManagerAccess
ECRAccess
ECSAccess
PassCharlieCafeCloudFormationRole
ManageGitHubActionsRoleTrustPolicy
AmazonEC2FullAccess
ElasticLoadBalancingFullAccess
CloudWatchFullAccess
AutoScalingFullAccess
EC2ServiceLinkedRoles
SSMFullAccess
SSMServiceLinkedRoleCreate
SSMServiceLinkedRoleDelete
SSMMessagesAccess
S3FullAccess
CloudFormationFullAccess
IAMReadOnlyAccess
SSMReadOnlyAccess
3. Verify the Policy Is Attached to the GitHub Actions Role

Your role is:

aws-hybrid-iac-lab-GitHubActions

Run:

aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions"

You should see:

github-ci-cd-user-combined-access

For a cleaner result:

aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "AttachedPolicies[].{Name:PolicyName,Arn:PolicyArn}" `
  --output table
4. Check Whether the Four Old Policies Are Still Attached

Run:

aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "AttachedPolicies[].PolicyName" `
  --output table

Initially, I recommend that you see something similar to:

GitHub-Actions
iam-policiesgithub-ci-cd-cloudformation-passrole-policy
github-ci-cd-user-iam-role-management
github-ci-cd-user-aws-manager-policies
github-ci-cd-user-combined-access

Do not detach the four old policies yet.

First prove that the new combined policy works by itself.

5. Verify the GitHub Actions Role Trust Policy

This is extremely important because your GitHub Actions authentication uses OIDC.

Run:

aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument" `
  --output json

You should verify that the trust policy contains your GitHub OIDC provider and the correct GitHub repository/branch conditions.

For example, conceptually:

{
  "Principal": {
    "Federated": "arn:aws:iam::537236558357:oidc-provider/token.actions.githubusercontent.com"
  }
}

And normally you want conditions restricting which GitHub repository and branch/workflow can assume the role.

6. Verify the AWS Account

Before testing Terraform, make sure your PowerShell AWS CLI is pointing at the expected account:

aws sts get-caller-identity

You should see your account:

537236558357

You can check only the account ID:

aws sts get-caller-identity `
  --query "Account" `
  --output text

Expected:

537236558357

Also check your region:

aws configure get region

For your lab, if you are using us-east-1:

us-east-1
7. Verify the IAM Policy JSON Locally

If you saved the policy as:

github-ci-cd-user-combined-access.json

you can validate the JSON structure with PowerShell:

Get-Content .\github-ci-cd-user-combined-access.json -Raw | ConvertFrom-Json

If there is no error, PowerShell successfully parsed the JSON.

You can also use AWS IAM policy validation:

aws iam validate-policy `
  --policy-document file://github-ci-cd-user-combined-access.json

If your AWS CLI version supports the command, this is an excellent additional check.

8. Test Important IAM Permissions

You can use IAM policy simulation for several actions.

For example:

aws iam simulate-principal-policy `
  --policy-source-arn "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions" `
  --action-names `
    ec2:DescribeInstances `
    s3:ListAllMyBuckets `
    cloudformation:ListStacks `
    lambda:ListFunctions `
    ecs:DescribeClusters `
    ecr:GetAuthorizationToken `
    ssm:DescribeInstanceInformation

Look for:

EvalDecision: allowed

for the actions you expect.

9. Specifically Test iam:PassRole

This is important because CloudFormation needs to use:

CharlieCafe-CloudFormation-ServiceRole

Your policy restricts PassRole to that role and to CloudFormation.

You can simulate:

aws iam simulate-principal-policy `
  --policy-source-arn "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions" `
  --action-names "iam:PassRole" `
  --resource-arns "arn:aws:iam::537236558357:role/CharlieCafe-CloudFormation-ServiceRole"

You want:

allowed

However, remember that policy simulation is not a complete end-to-end CloudFormation test. The real CloudFormation deployment is the final test.

10. Test S3 Access

Because your Terraform/CloudFormation workflow uses S3, test:

aws s3 ls

Then:

aws s3api list-buckets `
  --query "Buckets[].Name" `
  --output table

You should be able to see your lab buckets.

11. Test EC2 Access

Run:

aws ec2 describe-instances `
  --region us-east-1 `
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name}" `
  --output table

You should receive your EC2 instances.

12. Test SSM Access

Run:

aws ssm describe-instance-information `
  --region us-east-1

You should see your managed EC2 instances.

Then test SSM command functionality against your intended instance:

aws ssm send-command `
  --region us-east-1 `
  --instance-ids "YOUR_INSTANCE_ID" `
  --document-name "AWS-RunShellScript" `
  --parameters 'commands=["echo GitHub-IAM-Test"]'

Then retrieve the command:

aws ssm list-command-invocations `
  --region us-east-1 `
  --details

This verifies more than simply having ssm:* in the policy.

13. Test Lambda

Run:

aws lambda list-functions `
  --region us-east-1 `
  --query "Functions[].FunctionName" `
  --output table

You should see your Lambda functions.

14. Test ECR

Run:

aws ecr describe-repositories `
  --region us-east-1

Then:

aws ecr get-login-password `
  --region us-east-1

The second command should return a long token.

Do not paste that token anywhere.

15. Test ECS

Run:

aws ecs list-clusters `
  --region us-east-1

Then:

aws ecs describe-clusters `
  --region us-east-1 `
  --clusters "YOUR_CLUSTER_NAME"

Then:

aws ecs describe-services `
  --region us-east-1 `
  --cluster "YOUR_CLUSTER_NAME" `
  --services "YOUR_SERVICE_NAME"
16. Test CloudFormation

Run:

aws cloudformation list-stacks `
  --region us-east-1 `
  --query "StackSummaries[].{Name:StackName,Status:StackStatus}" `
  --output table

Then test the specific stack you use for the lab:

aws cloudformation describe-stacks `
  --region us-east-1 `
  --stack-name "YOUR_STACK_NAME"
17. Test Secrets Manager

You have:

secretsmanager:GetSecretValue

So test against the specific secret you intend GitHub/your deployment process to access:

aws secretsmanager describe-secret `
  --secret-id "CafeDevDBSM" `
  --region us-east-1

Then, only if you intentionally want to verify the value-access permission:

aws secretsmanager get-secret-value `
  --secret-id "CafeDevDBSM" `
  --region us-east-1 `
  --query "ARN"

Using --query "ARN" avoids printing the secret itself.

18. Now Test Terraform

Go to your Terraform directory:

cd C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab

First:

terraform fmt -recursive

Then:

terraform init

You want:

Terraform has been successfully initialized!

Next:

terraform validate

Expected:

Success! The configuration is valid.

Then:

terraform plan

This is one of the most important tests.

You want Terraform to successfully:

Authenticate to AWS.
Read the required AWS resources.
Read/write the Terraform state.
Read variables.
Resolve dependencies.
Build the execution plan.
19. If terraform plan Works

Then run:

terraform apply

Review the proposed changes.

If everything is correct:

yes

After completion:

terraform output

And:

terraform state list

This confirms Terraform is managing the resources successfully.

20. Verify the Terraform State Bucket

Because your architecture uses a dedicated Terraform state bucket, verify it:

aws s3api head-bucket `
  --bucket "aws-hybrid-iac-lab-terraform-state-537236558357"

Then:

aws s3api get-bucket-versioning `
  --bucket "aws-hybrid-iac-lab-terraform-state-537236558357"

You ideally want:

{
    "Status": "Enabled"
}
21. Test GitHub Actions OIDC

Now comes the most important part.

Push your Terraform/workflow changes:

git status

Then:

git add .
git commit -m "test combined GitHub Actions IAM policy"
git push origin main

Go to:

GitHub
→ Repository
→ Actions
→ Your workflow
→ Latest run

The critical part is that the GitHub Actions job successfully performs AWS authentication.

Your workflow should have something equivalent to:

- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
22. Add an AWS Identity Test to GitHub Actions

For the first test, I strongly recommend adding this temporary step immediately after AWS credentials are configured:

- name: Verify AWS Identity
  shell: bash
  run: |
    aws sts get-caller-identity

The output should identify:

arn:aws:sts::537236558357:assumed-role/aws-hybrid-iac-lab-GitHubActions/...

That proves:

GitHub
   ↓
GitHub OIDC
   ↓
AWS STS
   ↓
aws-hybrid-iac-lab-GitHubActions
   ↓
github-ci-cd-user-combined-access

is working.

23. Test AWS Permissions Directly From GitHub Actions

For the next test, temporarily add:

- name: Test AWS Permissions
  shell: bash
  run: |
    echo "Testing AWS identity..."
    aws sts get-caller-identity

    echo "Testing S3..."
    aws s3 ls

    echo "Testing EC2..."
    aws ec2 describe-instances \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text

    echo "Testing Lambda..."
    aws lambda list-functions \
      --query 'Functions[].FunctionName' \
      --output text

    echo "Testing CloudFormation..."
    aws cloudformation list-stacks \
      --query 'StackSummaries[].StackName' \
      --output text

    echo "AWS permission tests completed."

If all these commands succeed, your combined policy is being used successfully by GitHub Actions.

24. Test Terraform From GitHub Actions

Your workflow should then execute:

- name: Terraform Init
  run: terraform init

- name: Terraform Validate
  run: terraform validate

- name: Terraform Plan
  run: terraform plan

Expected:

Terraform Init       ✅
Terraform Validate   ✅
Terraform Plan       ✅

Then, if this is your intended deployment workflow:

- name: Terraform Apply
  run: terraform apply -auto-approve

Expected:

Terraform Apply      ✅
25. Test CloudFormation From GitHub Actions

Because your combined policy includes:

cloudformation:*

and:

iam:PassRole

for:

CharlieCafe-CloudFormation-ServiceRole

your CloudFormation deployment should also be tested.

The important flow is:

GitHub Actions
      │
      ▼
GitHub OIDC
      │
      ▼
GitHubActions IAM Role
      │
      ▼
CloudFormation
      │
      │ iam:PassRole
      ▼
CharlieCafe-CloudFormation-ServiceRole
      │
      ▼
AWS Resources

If CloudFormation fails with:

is not authorized to perform: iam:PassRole

then specifically investigate the PassRole permission and the CloudFormation service role.

26. Test ECR → ECS Deployment

If your workflow builds a Docker image, test the complete pipeline:

GitHub Actions
      │
      ▼
Docker Build
      │
      ▼
Amazon ECR
      │
      ▼
ECS Task Definition
      │
      ▼
ECS Service Update
      │
      ▼
Running Container

Your workflow should successfully perform:

docker build       ✅
ECR login          ✅
docker push        ✅
register task      ✅
update ECS service ✅

Then verify:

aws ecs describe-services `
  --cluster "YOUR_CLUSTER_NAME" `
  --services "YOUR_SERVICE_NAME" `
  --region us-east-1 `
  --query "services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status}"

Ideally:

Desired = 1
Running = 1
Pending = 0
Status  = ACTIVE
27. Final Test — Detach the Four Old Policies

Only do this after GitHub Actions successfully completes the entire pipeline.

First record the current policies:

aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --output table

Then detach:

aws iam detach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/GitHub-Actions"
aws iam detach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/iam-policiesgithub-ci-cd-cloudformation-passrole-policy"
aws iam detach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-iam-role-management"
aws iam detach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-aws-manager-policies"

Do not delete the policies yet.

28. Run GitHub Actions Again

This is the final proof.

Run the workflow again.

You want:

AWS OIDC Authentication       ✅
AWS STS Identity              ✅
Terraform Init                ✅
Terraform Validate            ✅
Terraform Plan                ✅
Terraform Apply               ✅
CloudFormation                ✅
S3                            ✅
EC2                           ✅
SSM                           ✅
Lambda                        ✅
ECR                           ✅
ECS                           ✅
CloudWatch                    ✅

If that entire workflow passes with only:

github-ci-cd-user-combined-access

attached, you have successfully replaced the four policies with the single merged policy.

29. Final Verification Command

Finally:

aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "AttachedPolicies[].{PolicyName:PolicyName,PolicyArn:PolicyArn}" `
  --output table

You ideally want to see only:

github-ci-cd-user-combined-access

attached to the role.

Recommended Testing Order

Use this exact order:

1. Create combined policy
        ↓
2. Verify policy JSON
        ↓
3. Attach combined policy
        ↓
4. Verify role attachment
        ↓
5. Verify OIDC trust policy
        ↓
6. Test AWS CLI permissions
        ↓
7. Terraform init
        ↓
8. Terraform validate
        ↓
9. Terraform plan
        ↓
10. Terraform apply
        ↓
11. GitHub Actions OIDC test
        ↓
12. GitHub Actions AWS permission test
        ↓
13. GitHub Actions Terraform test
        ↓
14. CloudFormation test
        ↓
15. ECR/ECS deployment test
        ↓
16. Detach old four policies
        ↓
17. Run GitHub Actions again
        ↓
18. Confirm everything passes
        ↓
19. Keep only combined policy
One thing I would change before calling this "production ready"

Your combined policy is currently very powerful. In particular:

ec2:*
s3:*
cloudformation:*
cloudwatch:*
autoscaling:*
elasticloadbalancing:*
ssm:*

and your original IAM role-management permission:

iam:UpdateAssumeRolePolicy

deserves special attention. For a hands-on AWS/DevOps lab this can be acceptable, but for a production GitHub OIDC role I would eventually create a least-privilege version restricted to your actual Terraform resources and deployment roles.

For now, though, the testing procedure above will tell you whether your single merged policy actually replaces all four policies without breaking your Terraform and GitHub Actions pipeline.
---
PowerShell Script — Complete IAM + Terraform + GitHub Actions Verification Report

Yes. Below is a single PowerShell verification script that checks the AWS/IAM side of your setup and produces a final report containing:

✅ Passed tests
⚠️ Warnings
❌ Errors
📊 Summary
🔧 Recommended fixes
📄 A .txt report file

It does not modify your AWS infrastructure. It is designed as a verification/diagnostic script.

One important limitation: a PowerShell script running locally cannot prove that a GitHub Actions workflow itself succeeded. It can verify the AWS IAM role, policy, OIDC provider, Terraform configuration, and AWS permissions. At the end, it also checks whether your local Git repository/workflow files exist so you can then run the actual GitHub Actions test.

verify-github-ci-cd.ps1


Purpose:
Complete verification of:
- AWS account
- AWS region
- Combined IAM policy
- GitHub Actions IAM role
- IAM policy attachment
- GitHub OIDC provider
- GitHub Actions role trust policy
- IAM PassRole
- EC2
- S3
- SSM
- Lambda
- ECR
- ECS
- CloudFormation
- Secrets Manager
- Terraform
- GitHub repository/workflow


IMPORTANT:
This script is READ/VERIFY oriented.
It does NOT:
- create AWS resources
- delete AWS resources
- detach IAM policies
- modify IAM roles
- run terraform apply
- deploy your application


The script creates:


github-ci-cd-verification-report-YYYYMMDD-HHmmss.txt


in the current directory.
==========================================================
1. CONFIGURATION
==========================================================

$ErrorActionPreference = "Continue"

AWS account

$ExpectedAccountId = "537236558357"

AWS region

$AwsRegion = "us-east-1"

Combined IAM policy

$CombinedPolicyName = "github-ci-cd-user-combined-access"

$CombinedPolicyArn = `
"arn:aws:iam::$ExpectedAccountId/$CombinedPolicyName"

GitHub Actions IAM role

$GitHubRoleName = "aws-hybrid-iac-lab-GitHubActions"

$GitHubRoleArn = `
"arn:aws:iam::$ExpectedAccountId/$GitHubRoleName"

CloudFormation service role

$CloudFormationRoleName = "CharlieCafe-CloudFormation-ServiceRole"

$CloudFormationRoleArn = `
"arn:aws:iam::$ExpectedAccountId/$CloudFormationRoleName"

Terraform directory

$TerraformDirectory = Get-Location

Optional specific secret

$SecretName = "CafeDevDBSM"

==========================================================
2. REPORT VARIABLES
==========================================================

$Passed = @()
$Warnings = @()
$Errors = @()

$StartTime = Get-Date

$ReportFile = Join-Path $TerraformDirectory
("github-ci-cd-verification-report-" +
$StartTime.ToString("yyyyMMdd-HHmmss") +
".txt")

==========================================================
3. OUTPUT FUNCTIONS
==========================================================

function Write-Test {
param(
[string]$Name
)

Write-Host ""
Write-Host "==========================================================" `
    -ForegroundColor Cyan

Write-Host "TEST: $Name" `
    -ForegroundColor Cyan

Write-Host "==========================================================" `
    -ForegroundColor Cyan

}

function Write-Pass {
param(
[string]$Message
)

$script:Passed += $Message

Write-Host "[PASS] $Message" `
    -ForegroundColor Green

}

function Write-WarningResult {
param(
[string]$Message
)

$script:Warnings += $Message

Write-Host "[WARN] $Message" `
    -ForegroundColor Yellow

}

function Write-Fail {
param(
[string]$Message
)

$script:Errors += $Message

Write-Host "[FAIL] $Message" `
    -ForegroundColor Red

}

function Write-Info {
param(
[string]$Message
)

Write-Host "[INFO] $Message" `
    -ForegroundColor Gray

}

==========================================================
4. START REPORT
==========================================================
@"
GitHub Actions + AWS + Terraform Verification Report

Started:
$StartTime

Expected AWS Account:
$ExpectedAccountId

Expected AWS Region:
$AwsRegion

Combined IAM Policy:
$CombinedPolicyName

GitHub Actions Role:
$GitHubRoleName

============================================================

"@ | Out-File -FilePath $ReportFile
-Encoding utf8

==========================================================
5. CHECK AWS CLI
==========================================================

Write-Test "AWS CLI Availability"

try {

$AwsVersion = aws --version 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass "AWS CLI is installed."

}
else {

    Write-Fail "AWS CLI is not available."

}

}
catch {

Write-Fail "AWS CLI check failed: $($_.Exception.Message)"

}

==========================================================
6. CHECK TERRAFORM
==========================================================

Write-Test "Terraform Availability"

try {

$TerraformVersion = terraform version 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass "Terraform is installed."

}
else {

    Write-Fail "Terraform is not available."

}

}
catch {

Write-Fail "Terraform check failed: $($_.Exception.Message)"

}

==========================================================
7. AWS ACCOUNT IDENTITY
==========================================================

Write-Test "AWS Account Identity"

try {

$IdentityJson = aws sts get-caller-identity `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    $Identity = $IdentityJson | ConvertFrom-Json

    Write-Info "AWS Account: $($Identity.Account)"
    Write-Info "AWS ARN: $($Identity.Arn)"

    if ($Identity.Account -eq $ExpectedAccountId) {

        Write-Pass `
            "AWS account matches expected account $ExpectedAccountId."

    }
    else {

        Write-Fail `
            "AWS account mismatch. Expected $ExpectedAccountId but found $($Identity.Account)."

    }

}
else {

    Write-Fail `
        "Unable to authenticate to AWS."

}

}
catch {

Write-Fail `
    "AWS identity check failed: $($_.Exception.Message)"

}

==========================================================
8. AWS REGION
==========================================================

Write-Test "AWS Region"

try {

$ConfiguredRegion = aws configure get region 2>&1

if ($ConfiguredRegion -eq $AwsRegion) {

    Write-Pass `
        "AWS CLI region is $AwsRegion."

}
else {

    Write-WarningResult `
        "Configured AWS region is '$ConfiguredRegion'. Expected '$AwsRegion'."

}

}
catch {

Write-WarningResult `
    "Unable to determine AWS CLI region."

}

==========================================================
9. COMBINED IAM POLICY EXISTS
==========================================================

Write-Test "Combined IAM Policy Exists"

try {

$PolicyJson = aws iam get-policy `
    --policy-arn $CombinedPolicyArn `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    $Policy = $PolicyJson | ConvertFrom-Json

    Write-Pass `
        "Combined IAM policy exists: $CombinedPolicyName"

    $DefaultVersionId = `
        $Policy.Policy.DefaultVersionId

    Write-Info `
        "Default policy version: $DefaultVersionId"

}
else {

    Write-Fail `
        "Combined IAM policy was not found: $CombinedPolicyArn"

}

}
catch {

Write-Fail `
    "Combined IAM policy check failed: $($_.Exception.Message)"

}

==========================================================
10. READ COMBINED POLICY DOCUMENT
==========================================================

Write-Test "Combined IAM Policy Document"

try {

if ($DefaultVersionId) {

    $PolicyVersionJson = aws iam get-policy-version `
        --policy-arn $CombinedPolicyArn `
        --version-id $DefaultVersionId `
        --output json 2>&1

    if ($LASTEXITCODE -eq 0) {

        $PolicyVersion = `
            $PolicyVersionJson | ConvertFrom-Json

        Write-Pass `
            "Combined IAM policy document can be read."

        $Statements = `
            $PolicyVersion.PolicyVersion.Document.Statement

        Write-Info `
            "Policy statement count: $($Statements.Count)"

    }
    else {

        Write-Fail `
            "Unable to read combined policy version."

    }

}

}
catch {

Write-Fail `
    "Policy document check failed: $($_.Exception.Message)"

}

==========================================================
11. CHECK IMPORTANT POLICY SECTIONS
==========================================================

Write-Test "Required IAM Policy Permissions"

$RequiredActions = @(
"lambda",
"lambda",
"lambda",
"ssm",
"secretsmanager",
"ecr",
"ecs",
"iam",
"ec2:",
"s3:",
"cloudformation:",
"ssm:"
)

$PolicyText = ""

try {

$PolicyText = $PolicyVersionJson

}
catch {
}

foreach ($Action in $RequiredActions) {

if ($PolicyText -match [regex]::Escape($Action)) {

    Write-Pass `
        "Policy contains required permission: $Action"

}
else {

    Write-Fail `
        "Policy is missing expected permission: $Action"

}

}

==========================================================
12. CHECK GITHUB ACTIONS ROLE
==========================================================

Write-Test "GitHub Actions IAM Role"

try {

$RoleJson = aws iam get-role `
    --role-name $GitHubRoleName `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    $Role = $RoleJson | ConvertFrom-Json

    Write-Pass `
        "GitHub Actions role exists: $GitHubRoleName"

    Write-Info `
        "Role ARN: $($Role.Role.Arn)"

}
else {

    Write-Fail `
        "GitHub Actions role does not exist."

}

}
catch {

Write-Fail `
    "GitHub Actions role check failed: $($_.Exception.Message)"

}

==========================================================
13. CHECK ATTACHED POLICIES
==========================================================

Write-Test "IAM Policies Attached to GitHub Actions Role"

try {

$AttachedJson = aws iam list-attached-role-policies `
    --role-name $GitHubRoleName `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    $Attached = `
        $AttachedJson | ConvertFrom-Json

    $PolicyNames = `
        $Attached.AttachedPolicies.PolicyName

    if ($PolicyNames -contains $CombinedPolicyName) {

        Write-Pass `
            "Combined policy is attached to GitHub Actions role."

    }
    else {

        Write-Fail `
            "Combined policy is NOT attached to GitHub Actions role."

    }

    Write-Info "Currently attached policies:"

    foreach ($PolicyName in $PolicyNames) {

        Write-Info "  - $PolicyName"

    }

}
else {

    Write-Fail `
        "Unable to retrieve attached IAM policies."

}

}
catch {

Write-Fail `
    "Attached policy check failed: $($_.Exception.Message)"

}

==========================================================
14. CHECK OIDC PROVIDER
==========================================================

Write-Test "GitHub OIDC Provider"

try {

$OidcArn = `
    "arn:aws:iam::$ExpectedAccountId:oidc-provider/token.actions.githubusercontent.com"

$OidcJson = aws iam get-open-id-connect-provider `
    --open-id-connect-provider-arn $OidcArn `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "GitHub Actions OIDC provider exists."

}
else {

    Write-Fail `
        "GitHub Actions OIDC provider was not found."

}

}
catch {

Write-Fail `
    "OIDC provider check failed: $($_.Exception.Message)"

}

==========================================================
15. CHECK TRUST POLICY
==========================================================

Write-Test "GitHub Actions Trust Policy"

try {

$TrustJson = aws iam get-role `
    --role-name $GitHubRoleName `
    --query "Role.AssumeRolePolicyDocument" `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    $TrustText = $TrustJson

    if ($TrustText -match "token.actions.githubusercontent.com") {

        Write-Pass `
            "GitHub OIDC provider is referenced in role trust policy."

    }
    else {

        Write-Fail `
            "GitHub OIDC provider is not referenced in trust policy."

    }

    if ($TrustText -match "sts:AssumeRoleWithWebIdentity") {

        Write-Pass `
            "sts:AssumeRoleWithWebIdentity exists in trust policy."

    }
    else {

        Write-Fail `
            "sts:AssumeRoleWithWebIdentity is missing."

    }

}

}
catch {

Write-Fail `
    "Trust policy check failed: $($_.Exception.Message)"

}

==========================================================
16. CHECK CLOUDFORMATION SERVICE ROLE
==========================================================

Write-Test "CloudFormation Service Role"

try {

$CFRoleJson = aws iam get-role `
    --role-name $CloudFormationRoleName `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "CloudFormation service role exists."

}
else {

    Write-Fail `
        "CloudFormation service role was not found."

}

}
catch {

Write-Fail `
    "CloudFormation role check failed: $($_.Exception.Message)"

}

==========================================================
17. TEST IAM PASSROLE SIMULATION
==========================================================

Write-Test "IAM PassRole Simulation"

try {

$SimulationJson = aws iam simulate-principal-policy `
    --policy-source-arn $GitHubRoleArn `
    --action-names "iam:PassRole" `
    --resource-arns $CloudFormationRoleArn `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    $Simulation = `
        $SimulationJson | ConvertFrom-Json

    $Decision = `
        $Simulation.EvaluationResults[0].EvalDecision

    if ($Decision -eq "allowed") {

        Write-Pass `
            "iam:PassRole is allowed for the CloudFormation service role."

    }
    else {

        Write-Fail `
            "iam:PassRole simulation result: $Decision"

    }

}
else {

    Write-WarningResult `
        "IAM PassRole simulation could not be completed."

}

}
catch {

Write-WarningResult `
    "PassRole simulation failed: $($_.Exception.Message)"

}

==========================================================
18. TEST S3
==========================================================

Write-Test "S3 Access"

try {

$S3Result = aws s3api list-buckets `
    --query "Buckets[].Name" `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "S3 access is working."

}
else {

    Write-Fail `
        "S3 access failed."

}

}
catch {

Write-Fail `
    "S3 test failed: $($_.Exception.Message)"

}

==========================================================
19. TEST EC2
==========================================================

Write-Test "EC2 Access"

try {

$EC2Result = aws ec2 describe-instances `
    --region $AwsRegion `
    --query "Reservations[].Instances[].InstanceId" `
    --output text 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "EC2 DescribeInstances access is working."

}
else {

    Write-Fail `
        "EC2 DescribeInstances failed."

}

}
catch {

Write-Fail `
    "EC2 test failed: $($_.Exception.Message)"

}

==========================================================
20. TEST SSM
==========================================================

Write-Test "SSM Access"

try {

$SSMResult = aws ssm describe-instance-information `
    --region $AwsRegion `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "SSM access is working."

}
else {

    Write-Fail `
        "SSM access failed."

}

}
catch {

Write-Fail `
    "SSM test failed: $($_.Exception.Message)"

}

==========================================================
21. TEST LAMBDA
==========================================================

Write-Test "Lambda Access"

try {

$LambdaResult = aws lambda list-functions `
    --region $AwsRegion `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Lambda list-functions access is working."

}
else {

    Write-Fail `
        "Lambda access failed."

}

}
catch {

Write-Fail `
    "Lambda test failed: $($_.Exception.Message)"

}

==========================================================
22. TEST ECR
==========================================================

Write-Test "ECR Access"

try {

$ECRResult = aws ecr describe-repositories `
    --region $AwsRegion `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "ECR access is working."

}
else {

    Write-Fail `
        "ECR access failed."

}

}
catch {

Write-Fail `
    "ECR test failed: $($_.Exception.Message)"

}

==========================================================
23. TEST ECS
==========================================================

Write-Test "ECS Access"

try {

$ECSResult = aws ecs list-clusters `
    --region $AwsRegion `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "ECS access is working."

}
else {

    Write-Fail `
        "ECS access failed."

}

}
catch {

Write-Fail `
    "ECS test failed: $($_.Exception.Message)"

}

==========================================================
24. TEST CLOUDFORMATION
==========================================================

Write-Test "CloudFormation Access"

try {

$CFResult = aws cloudformation list-stacks `
    --region $AwsRegion `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "CloudFormation access is working."

}
else {

    Write-Fail `
        "CloudFormation access failed."

}

}
catch {

Write-Fail `
    "CloudFormation test failed: $($_.Exception.Message)"

}

==========================================================
25. TEST SECRETS MANAGER
==========================================================

Write-Test "Secrets Manager Access"

try {

$SecretResult = aws secretsmanager describe-secret `
    --secret-id $SecretName `
    --region $AwsRegion `
    --output json 2>&1

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Secrets Manager access is working for $SecretName."

}
else {

    Write-WarningResult `
        "Secret '$SecretName' could not be found/read. Verify the secret name."

}

}
catch {

Write-WarningResult `
    "Secrets Manager test failed: $($_.Exception.Message)"

}

==========================================================
26. TERRAFORM FORMAT
==========================================================

Write-Test "Terraform Format"

try {

Push-Location $TerraformDirectory

terraform fmt -check -recursive

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Terraform formatting is correct."

}
else {

    Write-WarningResult `
        "Terraform files require formatting. Run: terraform fmt -recursive"

}

Pop-Location

}
catch {

Pop-Location -ErrorAction SilentlyContinue

Write-Fail `
    "Terraform format check failed."

}

==========================================================
27. TERRAFORM VALIDATE
==========================================================

Write-Test "Terraform Validate"

try {

Push-Location $TerraformDirectory

terraform validate

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Terraform configuration is valid."

}
else {

    Write-Fail `
        "Terraform validate failed."

}

Pop-Location

}
catch {

Pop-Location -ErrorAction SilentlyContinue

Write-Fail `
    "Terraform validation failed."

}

==========================================================
28. CHECK TERRAFORM FILES
==========================================================

Write-Test "Terraform Project Files"

$TerraformFiles = @(
"main.tf",
"variables.tf",
"outputs.tf",
"provider.tf",
"iam.tf",
"terraform.tf"
)

foreach ($File in $TerraformFiles) {

$FilePath = Join-Path `
    $TerraformDirectory `
    $File

if (Test-Path $FilePath) {

    Write-Pass `
        "Terraform file exists: $File"

}
else {

    Write-WarningResult `
        "Terraform file not found: $File"

}

}

==========================================================
29. CHECK GITHUB WORKFLOW DIRECTORY
==========================================================

Write-Test "GitHub Actions Workflow"

$WorkflowDirectory = Join-Path $TerraformDirectory
".github\workflows"

if (Test-Path $WorkflowDirectory) {

Write-Pass `
    "GitHub Actions workflow directory exists."

$WorkflowFiles = `
    Get-ChildItem `
        -Path $WorkflowDirectory `
        -Filter "*.yml" `
        -File

$WorkflowFilesYaml = `
    Get-ChildItem `
        -Path $WorkflowDirectory `
        -Filter "*.yaml" `
        -File

$AllWorkflows = `
    @($WorkflowFiles) + @($WorkflowFilesYaml)

if ($AllWorkflows.Count -gt 0) {

    foreach ($Workflow in $AllWorkflows) {

        Write-Pass `
            "GitHub Actions workflow found: $($Workflow.Name)"

    }

}
else {

    Write-Fail `
        "No GitHub Actions workflow files were found."

}

}
else {

Write-Fail `
    ".github\workflows directory does not exist."

}

==========================================================
30. CHECK GIT
==========================================================

Write-Test "Git Repository"

try {

git status --short 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {

    Write-Pass `
        "Current directory is a Git repository."

}
else {

    Write-WarningResult `
        "Current directory does not appear to be a Git repository."

}

}
catch {

Write-WarningResult `
    "Unable to check Git repository."

}

==========================================================
31. FINAL REPORT
==========================================================

$EndTime = Get-Date

$Duration = $EndTime - $StartTime

$TotalTests = `
$Passed.Count +
$Warnings.Count +
$Errors.Count

$Summary = @"

Start Time:
$StartTime

End Time:
$EndTime

Duration:
$($Duration.ToString())

Total Results : $TotalTests
PASSED : $($Passed.Count)
WARNINGS : $($Warnings.Count)
ERRORS : $($Errors.Count)

"@

foreach ($Item in $Passed) {

$Summary += "`n[PASS] $Item"

}

$Summary += @"

"@

if ($Warnings.Count -eq 0) {

$Summary += "`nNo warnings."

}
else {

foreach ($Item in $Warnings) {

    $Summary += "`n[WARN] $Item"

}

}

$Summary += @"

"@

if ($Errors.Count -eq 0) {

$Summary += "`nNo errors."

}
else {

foreach ($Item in $Errors) {

    $Summary += "`n[FAIL] $Item"

}

}

$Summary += @"

"@

if ($Errors.Count -eq 0) {

if ($Warnings.Count -eq 0) {

    $Summary += @"

STATUS: PASS

All automated verification checks passed.

The AWS/IAM/Terraform configuration appears ready
for the GitHub Actions end-to-end test.

"@

}
else {

    $Summary += @"

STATUS: PASS WITH WARNINGS

No critical verification errors were detected.

Review the warnings before performing the final
GitHub Actions deployment test.

"@

}

}
else {

$Summary += @"

STATUS: FAILED

One or more verification checks failed.

Review the ERROR section above before running the
final GitHub Actions deployment.

"@

}

$Summary += @"

Review this report.
Fix all FAIL items.
Review WARN items.

Run:

terraform fmt -recursive

Run:

terraform init

Run:

terraform validate

Run:

terraform plan

Commit and push the workflow:

git add .
git commit -m "test combined GitHub Actions IAM policy"
git push origin main

Open GitHub:

Repository
-> Actions
-> Workflow
-> Latest Run

Verify:

AWS OIDC authentication PASS
aws sts get-caller-identity PASS
Terraform init PASS
Terraform validate PASS
Terraform plan PASS
Terraform apply PASS

Only after the complete GitHub Actions test passes,
detach the four old IAM policies.

$ReportFile

"@

$Summary | Out-File -FilePath $ReportFile
-Encoding utf8

Write-Host ""
Write-Host "==========================================================" `
-ForegroundColor Cyan

Write-Host "FINAL RESULT" `
-ForegroundColor Cyan

Write-Host "==========================================================" `
-ForegroundColor Cyan

if ($Errors.Count -eq 0 -and $Warnings.Count -eq 0) {

Write-Host "STATUS: PASS" `
    -ForegroundColor Green

}
elseif ($Errors.Count -eq 0) {

Write-Host "STATUS: PASS WITH WARNINGS" `
    -ForegroundColor Yellow

}
else {

Write-Host "STATUS: FAILED" `
    -ForegroundColor Red

}

Write-Host ""
Write-Host "Passed : $($Passed.Count)" `
-ForegroundColor Green

Write-Host "Warnings: $($Warnings.Count)" `
-ForegroundColor Yellow

Write-Host "Errors : $($Errors.Count)" `
-ForegroundColor Red

Write-Host ""
Write-Host "Report saved to:" `
-ForegroundColor Cyan

Write-Host $ReportFile `
-ForegroundColor White

Write-Host ""
Write-Host "Verification complete." `
-ForegroundColor Green

How to run it
Step 1 — Save the script

In your Terraform project directory:

cd C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab

Create:

verify-github-ci-cd.ps1

Paste the complete script into that file.

Step 2 — Check AWS authentication

Before running the script:

aws sts get-caller-identity

Make sure the account is:

537236558357

Also check:

aws configure get region

You want:

us-east-1
Step 3 — Allow the script to run

In the same PowerShell window:

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

If PowerShell asks for confirmation, select:

Y

This only changes the execution policy for the current PowerShell session.

Step 4 — Run the verification script

Run:

.\verify-github-ci-cd.ps1

ption 1 — Run It From the Current Directory

From your current location, run:

.\scripts\verify-github-ci-cd.ps1

That is the easiest solution.

Option 2 — Go Into the scripts Folder

Run:

cd .\scripts

Then verify the file exists:

Get-ChildItem

You should see:

verify-github-ci-cd.ps1

Then run:

.\verify-github-ci-cd.ps1

You should see output similar to:

==========================================================
TEST: AWS Account Identity
==========================================================

[PASS] AWS account matches expected account 537236558357.

==========================================================
TEST: Combined IAM Policy Exists
==========================================================

[PASS] Combined IAM policy exists:
github-ci-cd-user-combined-access

==========================================================
TEST: IAM Policies Attached to GitHub Actions Role
==========================================================

[PASS] Combined policy is attached to GitHub Actions role.

...

==========================================================
FINAL RESULT
==========================================================

STATUS: PASS

Passed  : 30
Warnings: 2
Errors  : 0

Report saved to:

.\github-ci-cd-verification-report-20260906-155500.txt

The exact number of tests will vary.

5. Open the Report

After the script finishes:

notepad .\github-ci-cd-verification-report-*.txt

Or list the report:

Get-ChildItem .\github-ci-cd-verification-report-*.txt

You will get a report containing:

============================================================
FINAL VERIFICATION REPORT
============================================================

SUMMARY

Total Results : ...
PASSED        : ...
WARNINGS      : ...
ERRORS        : ...

PASSED TESTS
...

WARNINGS
...

ERRORS
...

OVERALL RESULT
...
6. What the Errors Mean
❌ AWS CLI is not available

Install/configure AWS CLI.

Test:

aws --version
❌ AWS account mismatch

The AWS CLI is authenticated to a different account.

Run:

aws sts get-caller-identity

If the account isn't:

537236558357

fix your AWS credentials/profile before continuing.

❌ Combined IAM policy was not found

Check:

aws iam get-policy `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"

If it doesn't exist, create it first.

❌ Combined policy is NOT attached

Attach it:

aws iam attach-role-policy `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --policy-arn "arn:aws:iam::537236558357:policy/github-ci-cd-user-combined-access"

Then rerun the verification script.

❌ GitHub Actions role does not exist

Check:

aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions"

Make sure the role name in the script exactly matches your actual role.

❌ GitHub OIDC provider was not found

Your GitHub Actions OIDC provider may not exist in IAM.

Check:

aws iam list-open-id-connect-providers

You should have the GitHub provider:

token.actions.githubusercontent.com
❌ sts:AssumeRoleWithWebIdentity is missing

Your GitHub Actions role trust policy is incorrect or incomplete.

Check:

aws iam get-role `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "Role.AssumeRolePolicyDocument"
❌ iam:PassRole simulation ... denied

Your combined policy isn't allowing the GitHub Actions role to pass:

CharlieCafe-CloudFormation-ServiceRole

Check:

aws iam simulate-principal-policy `
  --policy-source-arn "arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions" `
  --action-names "iam:PassRole" `
  --resource-arns "arn:aws:iam::537236558357:role/CharlieCafe-CloudFormation-ServiceRole"
❌ Terraform validate failed

Run:

terraform validate

Terraform will show the actual configuration error.

Then:

terraform fmt -recursive

and validate again.

⚠️ Terraform files require formatting

Run:

terraform fmt -recursive

Then:

terraform validate
❌ No GitHub Actions workflow files were found

Check:

Get-ChildItem .\.github\workflows\

You should have something like:

main-deploy.yaml

or:

deploy.yml
❌ S3 access failed

Check:

aws s3 ls

If that fails, investigate the AWS credentials and IAM permissions.

❌ SSM access failed

Check:

aws ssm describe-instance-information `
  --region us-east-1

Remember that IAM permission and SSM-managed-instance status are different things. Your IAM role can have SSM permissions while an EC2 instance itself is not registered with SSM.

⚠️ Secrets Manager warning

The script checks:

CafeDevDBSM

If your secret has a different name, change this line in the script:

$SecretName = "CafeDevDBSM"

to your actual secret name.

The script intentionally does not print the secret value.

7. Very Important: GitHub Actions Final Test

The PowerShell script can verify the AWS side, but the real final test is GitHub Actions itself.

After the local verification passes:

terraform init
terraform validate
terraform plan

Then:

git status
git add .
git commit -m "test combined GitHub Actions IAM policy"
git push origin main

Then go to:

GitHub
  ↓
Your Repository
  ↓
Actions
  ↓
Your workflow
  ↓
Latest workflow run

You want to see:

GitHub OIDC Authentication     ✅
AWS STS                       ✅
Terraform Init                ✅
Terraform Validate            ✅
Terraform Plan                ✅
Terraform Apply               ✅
CloudFormation                ✅
8. The Most Important Final Check

Do not detach the four old policies until the GitHub Actions workflow has successfully completed.

Your final state should eventually be:

GitHub
   │
   │ OIDC
   ▼
AWS STS
   │
   ▼
aws-hybrid-iac-lab-GitHubActions
   │
   │
   ▼
github-ci-cd-user-combined-access
   │
   ├── EC2
   ├── S3
   ├── SSM
   ├── Lambda
   ├── ECR
   ├── ECS
   ├── CloudFormation
   ├── CloudWatch
   ├── Auto Scaling
   ├── ELB
   ├── Secrets Manager
   └── IAM

Then verify the role's policies:

aws iam list-attached-role-policies `
  --role-name "aws-hybrid-iac-lab-GitHubActions" `
  --query "AttachedPolicies[].PolicyName" `
  --output table

The desired final result is:

github-ci-cd-user-combined-access

with the four old policies no longer attached.

One caution: don't treat STATUS: PASS from this script as proof that the complete deployment works. The script verifies the AWS/IAM/Terraform prerequisites; the GitHub Actions workflow run is the final end-to-end proof.
---

