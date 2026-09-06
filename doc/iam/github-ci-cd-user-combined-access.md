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
