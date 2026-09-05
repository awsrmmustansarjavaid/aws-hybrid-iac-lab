# CloudFormation Execution Role — Complete Explanation

## 1. What does `cloudformation-execution-role.yaml` actually create?

This file does **not** create the actual EC2, VPC, RDS, Lambda, ECS, EKS, S3, or other application resources.

Instead, it creates **one IAM Role** that CloudFormation can assume and use to create, update, and delete infrastructure resources.

The role name is generated from these parameters:

```yaml
RoleName:
  !Sub "${ProjectName}-${Environment}-CFNExecutionRole"
```

With:

```text
ProjectName = HybridIaCLab
Environment = dev
```

the resulting role name is:

```text
HybridIaCLab-dev-CFNExecutionRole
```

---

## 2. Why do we need this role?

Normally, when you run:

```bash
aws cloudformation deploy ...
```

CloudFormation can operate using the permissions of the AWS identity initiating the deployment.

This template creates a dedicated **CloudFormation service role** so CloudFormation can be given its own set of permissions.

The basic architecture is:

```text
Developer
    |
    | AWS CLI
    v
CloudFormation
    |
    | AssumeRole
    v
+--------------------------------------+
| HybridIaCLab-dev-CFNExecutionRole    |
|                                      |
| Permissions:                         |
|   EC2 / VPC                          |
|   S3                                 |
|   Lambda                             |
|   API Gateway                        |
|   RDS                                |
|   DynamoDB                           |
|   ECR                                |
|   ECS                                |
|   EKS                                |
|   CloudWatch Logs                    |
|   CloudFront                         |
|   IAM PassRole                       |
+--------------------------------------+
    |
    +--> VPC
    +--> EC2
    +--> S3
    +--> Lambda
    +--> API Gateway
    +--> RDS
    +--> DynamoDB
    +--> ECR
    +--> ECS
    +--> EKS
    +--> CloudWatch Logs
    +--> CloudFront
```

---

# 3. The Trust Policy

The role contains:

```yaml
AssumeRolePolicyDocument:
  Version: "2012-10-17"
  Statement:
    - Effect: Allow
      Principal:
        Service:
          - cloudformation.amazonaws.com
      Action:
        - sts:AssumeRole
```

This answers the question:

> **Who is allowed to assume this role?**

The answer is:

```text
AWS CloudFormation
```

So the flow is:

```text
AWS CLI
   |
   v
CloudFormation
   |
   | sts:AssumeRole
   v
CloudFormationExecutionRole
   |
   v
AWS Services
```

The trust policy is different from the permissions policy:

- **Trust policy** = who can assume the role.
- **Permissions policy** = what the role is allowed to do after it is assumed.

---

# 4. What permissions does the role have?

The role contains an inline policy named:

```text
HybridIaCLabProvisioning
```

This policy provides the permissions required by the Hybrid IaC lab.

---

## 5. EC2 and Networking Permissions

The role can create and manage networking and EC2 resources such as:

```text
VPC
Subnets
Route Tables
Routes
Internet Gateways
Security Groups
EC2 Instances
Tags
```

Examples include:

```yaml
ec2:Describe*
ec2:CreateVpc
ec2:DeleteVpc
ec2:CreateSubnet
ec2:DeleteSubnet
ec2:CreateRouteTable
ec2:DeleteRouteTable
ec2:CreateRoute
ec2:DeleteRoute
ec2:CreateInternetGateway
ec2:DeleteInternetGateway
ec2:AttachInternetGateway
ec2:DetachInternetGateway
ec2:AssociateRouteTable
ec2:DisassociateRouteTable
ec2:CreateSecurityGroup
ec2:DeleteSecurityGroup
ec2:AuthorizeSecurityGroupIngress
ec2:AuthorizeSecurityGroupEgress
ec2:RevokeSecurityGroupIngress
ec2:RevokeSecurityGroupEgress
ec2:RunInstances
ec2:TerminateInstances
ec2:CreateTags
```

This allows CloudFormation to provision the networking foundation of the lab.

---

# 6. S3 Permissions

The role can create and manage S3 buckets and objects.

Examples:

```text
CreateBucket
DeleteBucket
GetBucket*
PutBucket*
DeleteBucketPolicy
PutBucketPolicy
GetObject
PutObject
DeleteObject
```

These permissions can be used for things such as:

- Application buckets
- Static website assets
- CloudFront origins

---

# 7. Lambda Permissions

The role can create and manage Lambda functions.

Examples:

```text
lambda:CreateFunction
lambda:DeleteFunction
lambda:GetFunction
lambda:UpdateFunctionCode
lambda:UpdateFunctionConfiguration
lambda:AddPermission
lambda:RemovePermission
lambda:TagResource
```

This means CloudFormation can deploy and update Lambda functions defined in CloudFormation templates.

---

# 8. API Gateway Permissions

The role contains:

```yaml
apigateway:*
```

with:

```text
Resource: "*"
```

This gives CloudFormation broad API Gateway permissions.

It can therefore manage the API Gateway resources defined by the lab templates.

---

# 9. RDS Permissions

The role can create and manage RDS resources.

Examples:

```text
rds:CreateDBInstance
rds:DeleteDBInstance
rds:ModifyDBInstance
rds:DescribeDBInstances
rds:CreateDBSubnetGroup
rds:DeleteDBSubnetGroup
rds:DescribeDBSubnetGroups
rds:AddTagsToResource
rds:ListTagsForResource
```

This allows CloudFormation to provision the database infrastructure used by the lab.

---

# 10. DynamoDB Permissions

The role can create and manage DynamoDB tables.

Examples:

```text
dynamodb:CreateTable
dynamodb:DeleteTable
dynamodb:DescribeTable
dynamodb:UpdateTable
dynamodb:TagResource
dynamodb:UntagResource
```

---

# 11. ECR Permissions

The role can manage ECR repositories and certain image operations.

Examples:

```text
ecr:CreateRepository
ecr:DeleteRepository
ecr:DescribeRepositories
ecr:PutImage
ecr:BatchGetImage
ecr:GetRepositoryPolicy
ecr:SetRepositoryPolicy
ecr:DeleteRepositoryPolicy
ecr:TagResource
```

The purpose is primarily to allow CloudFormation to manage ECR infrastructure.

Docker image build and push operations are normally handled by Docker, GitHub Actions, or other ECR clients rather than CloudFormation itself.

---

# 12. ECS Permissions

The role can manage ECS infrastructure such as:

```text
ECS Cluster
ECS Task Definitions
ECS Services
```

Examples:

```text
ecs:CreateCluster
ecs:DeleteCluster
ecs:DescribeClusters
ecs:RegisterTaskDefinition
ecs:DeregisterTaskDefinition
ecs:CreateService
ecs:DeleteService
ecs:UpdateService
ecs:DescribeServices
ecs:TagResource
```

---

# 13. EKS Permissions

The role can create and manage:

```text
EKS Cluster
EKS Managed Node Groups
```

Examples:

```text
eks:CreateCluster
eks:DeleteCluster
eks:DescribeCluster
eks:CreateNodegroup
eks:DeleteNodegroup
eks:DescribeNodegroup
eks:TagResource
```

---

# 14. The Very Important `iam:PassRole`

One of the most important permissions in this role is:

```yaml
- Effect: Allow
  Action:
    - iam:PassRole
  Resource: "*"
```

Why is this required?

Some AWS resources need their own IAM roles.

For example:

```text
EKS
 |
 +--> EKS Cluster Role
 |
 +--> EKS Node Role
```

or:

```text
ECS
 |
 +--> ECS Task Execution Role
```

or:

```text
Lambda
 |
 +--> Lambda Execution Role
```

CloudFormation may create those resources and needs permission to pass the appropriate IAM role to the AWS service.

Conceptually:

```text
CloudFormation
      |
      | PassRole
      v
AWS Service
      |
      +--> Uses its assigned IAM Role
```

Without the required `iam:PassRole` permission, CloudFormation deployments involving service-linked workload roles can fail.

### Important security point

The current lab configuration uses:

```text
iam:PassRole
Resource: "*"
```

That is intentionally broad for a learning lab.

In production, `iam:PassRole` should normally be restricted to only the specific roles that CloudFormation is allowed to pass.

---

# 15. CloudWatch Logs Permissions

The role can manage CloudWatch Logs resources such as log groups.

Examples:

```text
logs:CreateLogGroup
logs:DeleteLogGroup
logs:DescribeLogGroups
logs:PutRetentionPolicy
logs:DeleteRetentionPolicy
```

These can support:

- Lambda logging
- ECS logging
- Other application workloads

---

# 16. CloudFront Permissions

The role can create and manage CloudFront distributions and Origin Access Controls.

Examples:

```text
cloudfront:CreateDistribution
cloudfront:UpdateDistribution
cloudfront:DeleteDistribution
cloudfront:GetDistribution

cloudfront:CreateOriginAccessControl
cloudfront:DeleteOriginAccessControl
cloudfront:GetOriginAccessControl
cloudfront:UpdateOriginAccessControl

cloudfront:TagResource
```

This supports the CloudFront portion of the Hybrid IaC lab.

---

# 17. How do you deploy the execution role?

First, go to:

```text
infrastructure/cloudformation/
```

Then validate the template:

```bash
aws cloudformation validate-template \
  --template-body file://cloudformation-execution-role.yaml \
  --region us-east-1
```

Then deploy it:

```bash
aws cloudformation deploy \
  --template-file cloudformation-execution-role.yaml \
  --stack-name HybridIaCLab-CFN-ExecutionRole \
  --parameter-overrides \
    ProjectName=HybridIaCLab \
    Environment=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

The `CAPABILITY_NAMED_IAM` capability is required because the template creates a named IAM role.

---

# 18. Check the CloudFormation Stack

After deployment:

```bash
aws cloudformation describe-stacks \
  --stack-name HybridIaCLab-CFN-ExecutionRole \
  --region us-east-1
```

You can also inspect the stack events:

```bash
aws cloudformation describe-stack-events \
  --stack-name HybridIaCLab-CFN-ExecutionRole \
  --region us-east-1
```

---

# 19. Get the Execution Role ARN

The template provides an output called:

```text
ExecutionRoleArn
```

You can retrieve it with:

```bash
aws cloudformation describe-stacks \
  --stack-name HybridIaCLab-CFN-ExecutionRole \
  --query "Stacks[0].Outputs[?OutputKey=='ExecutionRoleArn'].OutputValue" \
  --output text \
  --region us-east-1
```

You will get something similar to:

```text
arn:aws:iam::123456789012:role/HybridIaCLab-dev-CFNExecutionRole
```

---

# 20. Check the IAM Role Directly

You can check the role with:

```bash
aws iam get-role \
  --role-name HybridIaCLab-dev-CFNExecutionRole
```

List its inline policies:

```bash
aws iam list-role-policies \
  --role-name HybridIaCLab-dev-CFNExecutionRole
```

Get the specific inline policy:

```bash
aws iam get-role-policy \
  --role-name HybridIaCLab-dev-CFNExecutionRole \
  --policy-name HybridIaCLabProvisioning
```

---

# 21. How do you use this role with another CloudFormation stack?

After creating the execution role, you can tell CloudFormation to use it with:

```text
--role-arn
```

For example:

```bash
aws cloudformation deploy \
  --template-file lambda.yaml \
  --stack-name HybridIaCLab-Lambda \
  --parameter-overrides \
    ProjectName=HybridIaCLab \
    Environment=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --role-arn arn:aws:iam::123456789012:role/HybridIaCLab-dev-CFNExecutionRole \
  --region us-east-1
```

Replace:

```text
123456789012
```

with your actual AWS account ID.

You can retrieve your account ID using:

```bash
aws sts get-caller-identity \
  --query Account \
  --output text
```

---

# 22. What happens during a deployment?

Suppose you deploy:

```text
lambda.yaml
```

The process is conceptually:

```text
You
 |
 | aws cloudformation deploy
 v
CloudFormation
 |
 | --role-arn
 v
HybridIaCLab-dev-CFNExecutionRole
 |
 | permissions
 v
Lambda
```

For another stack:

```text
You
 |
 v
CloudFormation
 |
 v
CFN Execution Role
 |
 +--> VPC
 +--> EC2
 +--> S3
 +--> RDS
 +--> Lambda
 +--> API Gateway
 +--> DynamoDB
 +--> ECR
 +--> ECS
 +--> EKS
 +--> CloudWatch
 +--> CloudFront
```

---

# 23. What happens if you delete the execution-role stack?

You can delete the stack with:

```bash
aws cloudformation delete-stack \
  --stack-name HybridIaCLab-CFN-ExecutionRole \
  --region us-east-1
```

This deletes the IAM resources managed by that CloudFormation stack.

It does **not** mean that every AWS resource previously created using that role will automatically be deleted.

For example:

```text
Delete CFN Execution Role Stack
             |
             v
Delete IAM Execution Role
             |
             +---- Does NOT automatically delete VPC
             |
             +---- Does NOT automatically delete EC2
             |
             +---- Does NOT automatically delete RDS
             |
             +---- Does NOT automatically delete EKS
             |
             +---- Does NOT automatically delete S3
```

Therefore, the execution-role stack should normally be deleted **after** the CloudFormation stacks that depend on it have been removed or no longer use it.

---

# 24. Why is this useful for a Hybrid Terraform + CloudFormation lab?

For a Hybrid IaC architecture, you can separate responsibilities:

```text
                         AWS ACCOUNT
                              |
               +--------------+--------------+
               |                             |
               v                             v
        CloudFormation                   Terraform
               |                             |
               v                             v
      CFN Execution Role             Terraform IAM Identity
               |                             |
               v                             v
       CFN-managed resources          TF-managed resources
```

For example:

```text
CloudFormation
    |
    +--> VPC
    +--> EC2
    +--> S3
    +--> Lambda
    +--> RDS
    +--> DynamoDB
    +--> CloudFront
```

while Terraform can manage other parts of the lab according to your chosen Hybrid IaC design.

The important concept is:

> **The execution role is the identity CloudFormation uses to perform infrastructure operations.**

---

# 25. Security Considerations

This file is designed as a **lab execution role**.

Some permissions are intentionally broad:

```text
Resource: "*"
```

and:

```text
iam:PassRole
```

with:

```text
Resource: "*"
```

This makes the lab easier to build and troubleshoot.

However, this should not be copied directly into a production environment.

For production, use:

- Least-privilege permissions
- Resource-level permissions where supported
- Restricted `iam:PassRole`
- Separate roles for different workloads
- Permission boundaries where appropriate
- Separate deployment identities for different environments

---

# 26. The Most Important Concept to Remember

Think of the file this way:

```text
cloudformation-execution-role.yaml
              |
              v
       Creates IAM Role
              |
              v
CloudFormation assumes the role
              |
              v
     Role provides permissions
              |
              v
CloudFormation can manage:
              |
    +---------+---------+
    |         |         |
    v         v         v
   EC2       S3       Lambda
    |
    +--> RDS
    +--> DynamoDB
    +--> ECR
    +--> ECS
    +--> EKS
    +--> CloudWatch
    +--> CloudFront
    +--> API Gateway
```

## In one sentence

**`cloudformation-execution-role.yaml` creates a dedicated IAM service role that CloudFormation can assume so it has the permissions required to create, update, and delete the AWS infrastructure used by the Hybrid IaC lab.**

---

## Quick Reference

| Component | Purpose |
|---|---|
| `AWS::IAM::Role` | Creates the CloudFormation execution role |
| `AssumeRolePolicyDocument` | Defines who can assume the role |
| `cloudformation.amazonaws.com` | Allows CloudFormation to assume it |
| `sts:AssumeRole` | Allows the role assumption |
| `HybridIaCLabProvisioning` | Main inline permissions policy |
| `ec2:*` selected actions | VPC/EC2 infrastructure |
| `s3:*` selected actions | S3 infrastructure |
| `lambda:*` selected actions | Lambda infrastructure |
| `apigateway:*` | API Gateway management |
| `rds:*` selected actions | RDS infrastructure |
| `dynamodb:*` selected actions | DynamoDB infrastructure |
| `ecr:*` selected actions | ECR infrastructure |
| `ecs:*` selected actions | ECS infrastructure |
| `eks:*` selected actions | EKS infrastructure |
| `iam:PassRole` | Allows CloudFormation to pass IAM roles to AWS services |
| `logs:*` selected actions | CloudWatch Logs |
| `cloudfront:*` selected actions | CloudFront infrastructure |
| `ExecutionRoleArn` | Outputs the role ARN for use with `--role-arn` |

---

## Final Mental Model

```text
                 YOU
                  |
                  | AWS CLI
                  v
          +----------------+
          | CloudFormation |
          +----------------+
                  |
                  | AssumeRole
                  v
     +--------------------------------+
     | HybridIaCLab-dev-CFNExecution |
     | Role                           |
     +--------------------------------+
                  |
                  | Permissions
                  v
     +--------------------------------+
     | AWS Infrastructure             |
     |                                |
     | VPC / EC2 / S3 / Lambda        |
     | API Gateway / RDS / DynamoDB   |
     | ECR / ECS / EKS / CloudWatch   |
     | CloudFront                     |
     +--------------------------------+
```

**Key takeaway:** the YAML file is an **IAM role factory for CloudFormation**, not the infrastructure itself.
