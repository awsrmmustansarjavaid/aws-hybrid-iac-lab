Yes. This is a **very good lab architecture** for learning both Terraform and CloudFormation together.

The important design decision is:

> **Terraform = Front-end / orchestration IaC**
> **CloudFormation = Back-end / resource provisioning IaC**
> **S3 = template repository between Terraform and CloudFormation**
> **GitHub = source control**
> **Docker = application packaging**
> **ECR = Docker image registry**
> **ECS + EKS = container platforms**

I would build the lab in a way that lets you practice each technology without replacing the others.

## 1. Target architecture

```text
                         GitHub Repository
                               |
                               |
                        Terraform Pipeline
                               |
                 +-------------+-------------+
                 |                           |
                 v                           v
          Create CFN Template         Create IAM Roles
          S3 Bucket                   / Policies
                 |
                 v
       Upload CloudFormation
          templates to S3
                 |
                 v
       AWS CloudFormation
          Main Root Stack
                 |
       +---------+---------+---------+---------+
       |         |         |         |         |
       v         v         v         v         v
     VPC       Compute    Storage    App      Containers
       |         |          |         |         |
       |         |          |         |         |
       |        EC2         S3      Lambda   ECS/EKS
       |                               |
       |                         API Gateway
       |
       +------------------------------+
                                      |
                              RDS / DynamoDB
                                      |
                                    App
```

And for Docker:

```text
Developer
   |
   v
GitHub
   |
   v
GitHub Actions
   |
   v
Docker Build
   |
   v
Amazon ECR
   |
   +------------------+
   |                  |
   v                  v
  ECS                 EKS
```

The important point is that **ECS and EKS are not replacements for each other in this lab**.

You can deliberately deploy the same containerized application to:

```text
Docker
  |
  +----> ECR
          |
          +----> ECS
          |
          +----> EKS
```

That gives you excellent practice.

---

## 2. Recommended GitHub repository

I recommend starting with this structure:

```text
aws-hybrid-iac-lab/
│
├── README.md
│
├── .gitignore
│
├── docker/
│   └── app/
│       ├── Dockerfile
│       └── src/
│           └── index.html
│
├── infrastructure/
│
│   ├── terraform/
│   │   ├── versions.tf
│   │   ├── provider.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── iam.tf
│   │   ├── template_bucket.tf
│   │   ├── cloudformation.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   │
│   └── cloudformation/
│       │
│       ├── main.yaml
│       │
│       ├── nested/
│       │   ├── vpc.yaml
│       │   ├── ec2.yaml
│       │   ├── s3.yaml
│       │   ├── cloudfront.yaml
│       │   ├── api-gateway.yaml
│       │   ├── lambda.yaml
│       │   ├── rds.yaml
│       │   ├── dynamodb.yaml
│       │   ├── ecr.yaml
│       │   ├── ecs.yaml
│       │   └── eks.yaml
│       │
│       └── iam/
│           └── cloudformation-execution-role.yaml
│
├── kubernetes/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
│
├── scripts/
│   ├── validate-cfn.ps1
│   ├── terraform-plan.ps1
│   └── build-docker.ps1
│
└── .github/
    └── workflows/
        ├── terraform.yml
        ├── docker.yml
        └── kubernetes.yml
```

This separation is important.

You will know immediately:

```text
Terraform        → infrastructure/terraform
CloudFormation   → infrastructure/cloudformation
Docker           → docker
Kubernetes       → kubernetes
GitHub Actions   → .github/workflows
```

---

## 3. The Terraform → CloudFormation flow

This is the key part of your lab.

Terraform will do:

```text
1. Create S3 bucket
        ↓
2. Upload main.yaml
        ↓
3. Upload nested/*.yaml
        ↓
4. Create CloudFormation execution IAM role
        ↓
5. Create CloudFormation root stack
        ↓
6. Root stack reads nested templates from S3
        ↓
7. Nested stacks create AWS resources
```

So Terraform is **not directly creating your VPC, EC2, RDS, etc.**

Instead:

```text
Terraform
   |
   | creates bucket
   | uploads templates
   | creates CFN stack
   v
CloudFormation
   |
   +--> VPC
   +--> EC2
   +--> S3
   +--> CloudFront
   +--> API Gateway
   +--> Lambda
   +--> RDS
   +--> DynamoDB
   +--> ECR
   +--> ECS
   +--> EKS
```

That's exactly the architecture you described.

---

## 4. Terraform — versions.tf

Create:

`infrastructure/terraform/versions.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

This tells Terraform which provider it needs.

---

## 5. Terraform — provider.tf

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Lab         = "Terraform-CloudFormation-Hybrid"
    }
  }
}
```

---

## 6. Terraform — variables.tf

```hcl
variable "aws_region" {
  description = "AWS region where the lab will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "HybridIaCLab"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
```

---

## 7. Terraform — locals.tf

Create:

`infrastructure/terraform/locals.tf`

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  cloudformation_templates = {
    main = "${path.module}/../cloudformation/main.yaml"

    vpc = "${path.module}/../cloudformation/nested/vpc.yaml"

    ec2 = "${path.module}/../cloudformation/nested/ec2.yaml"

    s3 = "${path.module}/../cloudformation/nested/s3.yaml"

    cloudfront = "${path.module}/../cloudformation/nested/cloudfront.yaml"

    api_gateway = "${path.module}/../cloudformation/nested/api-gateway.yaml"

    lambda = "${path.module}/../cloudformation/nested/lambda.yaml"

    rds = "${path.module}/../cloudformation/nested/rds.yaml"

    dynamodb = "${path.module}/../cloudformation/nested/dynamodb.yaml"

    ecr = "${path.module}/../cloudformation/nested/ecr.yaml"

    ecs = "${path.module}/../cloudformation/nested/ecs.yaml"

    eks = "${path.module}/../cloudformation/nested/eks.yaml"
  }
}
```

This is useful because Terraform automatically knows where your CloudFormation files are.

---

## 8. Terraform creates the CloudFormation template bucket

This is one of the most important parts of your requirement.

Create:

`infrastructure/terraform/template_bucket.tf`

```hcl
resource "aws_s3_bucket" "cloudformation_templates" {
  bucket_prefix = "${local.name_prefix}-cfn-templates-"

  force_destroy = true
}

resource "aws_s3_bucket_versioning" "cloudformation_templates" {
  bucket = aws_s3_bucket.cloudformation_templates.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudformation_templates" {
  bucket = aws_s3_bucket.cloudformation_templates.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudformation_templates" {
  bucket = aws_s3_bucket.cloudformation_templates.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

This bucket is **created by Terraform**.

CloudFormation templates are then uploaded into it.

---

## 9. Terraform uploads all CloudFormation templates

Create:

`infrastructure/terraform/template_objects.tf`

```hcl
resource "aws_s3_object" "cloudformation_templates" {
  for_each = local.cloudformation_templates

  bucket = aws_s3_bucket.cloudformation_templates.id

  key = each.key == "main"
    ? "main.yaml"
    : "nested/${each.key}.yaml"

  source = each.value

  etag = filemd5(each.value)
}
```

This is a very nice Terraform exercise.

Terraform sees:

```text
cloudformation/
├── main.yaml
└── nested/
    ├── vpc.yaml
    ├── ec2.yaml
    ├── s3.yaml
    ...
```

and uploads them automatically.

You don't have to manually run:

```bash
aws s3 cp ...
```

Terraform does it.

---

## 10. Important S3 security point

Don't make this bucket public.

CloudFormation can access the templates using an appropriate IAM role/bucket policy.

Conceptually:

```text
S3
|
| private
|
CloudFormation execution role
|
v
CloudFormation
```

That is much better than:

```text
S3
|
| public-read
|
CloudFormation
```

---

## 11. IAM — CloudFormation execution role

This is where your "one IAM role with different policies" idea comes in.

I recommend:

```text
CloudFormationExecutionRole
        |
        +-- VPC permissions
        +-- EC2 permissions
        +-- S3 permissions
        +-- CloudFront permissions
        +-- Lambda permissions
        +-- API Gateway permissions
        +-- RDS permissions
        +-- DynamoDB permissions
        +-- ECR permissions
        +-- ECS permissions
        +-- EKS permissions
        +-- IAM PassRole
```

For a **learning lab**, we can start broad enough to make the lab manageable, then progressively tighten permissions.

But there is an important security lesson:

> Don't use `AdministratorAccess` just because it is easier.

For your lab, we'll create a dedicated role.

---

## 12. Terraform creates the CloudFormation execution role

Create:

`infrastructure/terraform/iam.tf`

```hcl
data "aws_iam_policy_document" "cloudformation_assume_role" {

  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "cloudformation.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "cloudformation_execution" {

  name = "${local.name_prefix}-CloudFormationExecutionRole"

  assume_role_policy = data.aws_iam_policy_document.cloudformation_assume_role.json
}
```

Now CloudFormation has a dedicated role.

---

## 13. CloudFormation permissions

For the first version of the lab, create:

```hcl
resource "aws_iam_role_policy" "cloudformation_lab_permissions" {

  name = "${local.name_prefix}-CloudFormationPermissions"

  role = aws_iam_role.cloudformation_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "iam:PassRole"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "s3:*",
          "cloudfront:*"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "lambda:*",
          "apigateway:*"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "rds:*",
          "dynamodb:*"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "ecr:*",
          "ecs:*",
          "eks:*"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "logs:*"
        ]

        Resource = "*"
      }
    ]
  })
}
```

**Important:** this is intentionally broad for a learning lab. Once everything works, we should tighten it to resource-specific permissions.

Also, EKS/ECS often require additional supporting IAM/service-linked permissions. We'll handle those when implementing the container stacks rather than pretending one policy is universally sufficient.

---

## 14. CloudFormation root stack

Now we reach the most important CloudFormation file.

Create:

`infrastructure/cloudformation/main.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  Main CloudFormation stack for the Hybrid Terraform +
  CloudFormation AWS DevOps Lab.

Parameters:

  ProjectName:
    Type: String
    Default: HybridIaCLab

  Environment:
    Type: String
    Default: dev

  TemplateBucket:
    Type: String

  TemplatePrefix:
    Type: String
    Default: ""

Resources:

  VPCStack:
    Type: AWS::CloudFormation::Stack

    Properties:
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/vpc.yaml

      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment


  S3Stack:
    Type: AWS::CloudFormation::Stack

    Properties:
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/s3.yaml

      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment


  DynamoDBStack:
    Type: AWS::CloudFormation::Stack

    Properties:
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/dynamodb.yaml

      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment


  ECRStack:
    Type: AWS::CloudFormation::Stack

    Properties:
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/ecr.yaml

      Parameters:
        ProjectName: !Ref ProjectName
        Environment: !Ref Environment
```

This is your **main stack**.

Later we'll add:

```text
EC2Stack
CloudFrontStack
LambdaStack
APIGatewayStack
RDSStack
ECSStack
EKSStack
```

---

## 15. Why I don't recommend creating everything immediately

Your requested lab has **11 AWS services**, but there are dependencies.

For example:

```text
VPC
 |
 +---- EC2
 |
 +---- RDS
 |
 +---- ECS
 |
 +---- EKS
```

and:

```text
Lambda
 |
 +---- API Gateway
 |
 +---- DynamoDB
 |
 +---- RDS
```

and:

```text
S3
 |
 +---- CloudFront
```

and:

```text
ECR
 |
 +---- ECS
 |
 +---- EKS
```

Therefore, build the lab in layers.

---

## 16. First nested stack — VPC

Create:

`infrastructure/cloudformation/nested/vpc.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: Network layer for the Hybrid IaC Lab

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

Resources:

  VPC:
    Type: AWS::EC2::VPC

    Properties:
      CidrBlock: 10.0.0.0/16

      EnableDnsSupport: true
      EnableDnsHostnames: true

      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-VPC"


  InternetGateway:
    Type: AWS::EC2::InternetGateway

    Properties:
      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-IGW"


  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment

    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway


  PublicSubnet1:
    Type: AWS::EC2::Subnet

    Properties:
      VpcId: !Ref VPC

      CidrBlock: 10.0.1.0/24

      AvailabilityZone:
        Fn::Select:
          - 0
          - Fn::GetAZs: !Ref AWS::Region

      MapPublicIpOnLaunch: true

      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-PublicSubnet1"


  PublicSubnet2:
    Type: AWS::EC2::Subnet

    Properties:
      VpcId: !Ref VPC

      CidrBlock: 10.0.2.0/24

      AvailabilityZone:
        Fn::Select:
          - 1
          - Fn::GetAZs: !Ref AWS::Region

      MapPublicIpOnLaunch: true

      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-PublicSubnet2"


  PrivateSubnet1:
    Type: AWS::EC2::Subnet

    Properties:
      VpcId: !Ref VPC

      CidrBlock: 10.0.11.0/24

      AvailabilityZone:
        Fn::Select:
          - 0
          - Fn::GetAZs: !Ref AWS::Region

      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-PrivateSubnet1"


  PrivateSubnet2:
    Type: AWS::EC2::Subnet

    Properties:
      VpcId: !Ref VPC

      CidrBlock: 10.0.12.0/24

      AvailabilityZone:
        Fn::Select:
          - 1
          - Fn::GetAZs: !Ref AWS::Region

      Tags:
        - Key: Name
          Value: !Sub "${ProjectName}-${Environment}-PrivateSubnet2"


  PublicRouteTable:
    Type: AWS::EC2::RouteTable

    Properties:
      VpcId: !Ref VPC


  DefaultPublicRoute:
    Type: AWS::EC2::Route

    DependsOn: VPCGatewayAttachment

    Properties:
      RouteTableId: !Ref PublicRouteTable

      DestinationCidrBlock: 0.0.0.0/0

      GatewayId: !Ref InternetGateway


  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation

    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable


  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation

    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable


Outputs:

  VpcId:
    Value: !Ref VPC

    Export:
      Name: !Sub "${ProjectName}-${Environment}-VpcId"


  PublicSubnet1Id:
    Value: !Ref PublicSubnet1


  PublicSubnet2Id:
    Value: !Ref PublicSubnet2


  PrivateSubnet1Id:
    Value: !Ref PrivateSubnet1


  PrivateSubnet2Id:
    Value: !Ref PrivateSubnet2
```

This gives you:

```text
VPC
 |
 +-- PublicSubnet1
 |
 +-- PublicSubnet2
 |
 +-- PrivateSubnet1
 |
 +-- PrivateSubnet2
 |
 +-- Internet Gateway
 |
 +-- Route Table
```

---

## 17. DynamoDB nested stack

`infrastructure/cloudformation/nested/dynamodb.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: DynamoDB layer

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

Resources:

  OrdersTable:
    Type: AWS::DynamoDB::Table

    Properties:

      TableName: !Sub "${ProjectName}-${Environment}-Orders"

      BillingMode: PAY_PER_REQUEST

      AttributeDefinitions:

        - AttributeName: OrderId
          AttributeType: S

      KeySchema:

        - AttributeName: OrderId
          KeyType: HASH

      PointInTimeRecoverySpecification:
        PointInTimeRecoveryEnabled: true

      Tags:

        - Key: Project
          Value: !Ref ProjectName

        - Key: Environment
          Value: !Ref Environment

Outputs:

  OrdersTableName:
    Value: !Ref OrdersTable

  OrdersTableArn:
    Value: !GetAtt OrdersTable.Arn
```

---

## 18. S3 application bucket

`infrastructure/cloudformation/nested/s3.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: Application S3 storage

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

Resources:

  ApplicationBucket:
    Type: AWS::S3::Bucket

    Properties:

      BucketEncryption:

        ServerSideEncryptionConfiguration:

          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256

      PublicAccessBlockConfiguration:

        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true

      VersioningConfiguration:
        Status: Enabled

      Tags:

        - Key: Project
          Value: !Ref ProjectName

        - Key: Environment
          Value: !Ref Environment

Outputs:

  BucketName:
    Value: !Ref ApplicationBucket

  BucketArn:
    Value: !GetAtt ApplicationBucket.Arn
```

Notice we now have **two different S3 buckets**:

```text
Bucket #1
Terraform creates
        |
        +-- CloudFormation templates

Bucket #2
CloudFormation creates
        |
        +-- Application data/static files
```

That's exactly what I recommend.

---

## 19. ECR nested stack

`infrastructure/cloudformation/nested/ecr.yaml`

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: ECR repositories for Docker images

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

Resources:

  ApplicationRepository:
    Type: AWS::ECR::Repository

    Properties:

      RepositoryName: !Sub "${ProjectName}-${Environment}-app"

      ImageScanningConfiguration:
        ScanOnPush: true

      ImageTagMutability: IMMUTABLE

      EncryptionConfiguration:
        EncryptionType: AES256

      Tags:

        - Key: Project
          Value: !Ref ProjectName

        - Key: Environment
          Value: !Ref Environment

Outputs:

  RepositoryUri:
    Value: !GetAtt ApplicationRepository.RepositoryUri

  RepositoryArn:
    Value: !GetAtt ApplicationRepository.Arn
```

Now your Docker workflow becomes:

```text
Dockerfile
    |
docker build
    |
docker tag
    |
docker push
    |
ECR
```

---

## 20. Terraform creates the CloudFormation root stack

Now create:

`infrastructure/terraform/cloudformation.tf`

```hcl
resource "aws_cloudformation_stack" "main" {

  name = "${local.name_prefix}-MainStack"

  template_url = "https://${aws_s3_bucket.cloudformation_templates.bucket_regional_domain_name}/main.yaml"

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM"
  ]

  parameters = {

    ProjectName = var.project_name

    Environment = var.environment

    TemplateBucket = aws_s3_bucket.cloudformation_templates.bucket

    TemplatePrefix = ""
  }

  role_arn = aws_iam_role.cloudformation_execution.arn

  depends_on = [

    aws_s3_object.cloudformation_templates,

    aws_iam_role_policy.cloudformation_lab_permissions
  ]
}
```

Now Terraform becomes the **orchestrator**.

---

## 21. Terraform outputs

Create:

`infrastructure/terraform/outputs.tf`

```hcl
output "cloudformation_template_bucket" {

  description = "S3 bucket containing CloudFormation templates"

  value = aws_s3_bucket.cloudformation_templates.bucket
}


output "cloudformation_stack_name" {

  description = "Main CloudFormation stack"

  value = aws_cloudformation_stack.main.name
}


output "cloudformation_execution_role_arn" {

  description = "CloudFormation execution role ARN"

  value = aws_iam_role.cloudformation_execution.arn
}
```

---

## 22. Terraform variables file

Create:

`infrastructure/terraform/terraform.tfvars`

```hcl
aws_region = "us-east-1"

project_name = "HybridIaCLab"

environment = "dev"
```

Don't commit secrets into this file.

Add:

```text
terraform.tfvars
*.tfstate
*.tfstate.*
.terraform/
```

to `.gitignore`.

---

## 23. Terraform initialization

From:

```text
infrastructure/terraform
```

run:

```powershell
terraform init
```

Then:

```powershell
terraform fmt -recursive
```

Then:

```powershell
terraform validate
```

Then:

```powershell
terraform plan
```

Finally:

```powershell
terraform apply
```

The sequence becomes:

```text
terraform apply
       |
       v
Create template bucket
       |
       v
Upload CFN files
       |
       v
Create IAM role
       |
       v
Create Main CloudFormation Stack
       |
       v
CloudFormation creates nested stacks
```

---

## 24. Docker part

Create:

`docker/app/Dockerfile`

```dockerfile
FROM nginx:alpine

COPY app/index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

And:

`docker/app/app/index.html`

```html
<!DOCTYPE html>

<html>

<head>

    <title>Hybrid IaC Lab</title>

</head>

<body>

    <h1>Hybrid Terraform + CloudFormation Lab</h1>

    <p>
        Docker application successfully deployed.
    </p>

</body>

</html>
```

Build:

```powershell
cd docker/app

docker build -t hybrid-iac-app:latest .
```

Run:

```powershell
docker run -d `
  --name hybrid-iac-app `
  -p 8080:80 `
  hybrid-iac-app:latest
```

Open:

```text
http://localhost:8080
```

---

## 25. Push Docker image to ECR

Later your GitHub Actions pipeline will do:

```text
GitHub
   |
   v
Docker Build
   |
   v
ECR
   |
   +------------+
   |            |
   v            v
  ECS          EKS
```

You can manually practice first:

```powershell
aws ecr get-login-password --region us-east-1 |
docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

Then:

```powershell
docker tag hybrid-iac-app:latest `
YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hybrid-iaclab-dev-app:latest
```

Then:

```powershell
docker push `
YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hybrid-iaclab-dev-app:latest
```

---

## 26. Kubernetes directory

Your Kubernetes manifests should be separate from CloudFormation.

```text
kubernetes/
│
├── namespace.yaml
├── deployment.yaml
├── service.yaml
└── configmap.yaml
```

For example:

`kubernetes/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace

metadata:
  name: hybrid-iac
```

`kubernetes/deployment.yaml`

```yaml
apiVersion: apps/v1

kind: Deployment

metadata:
  name: hybrid-iac-app
  namespace: hybrid-iac

spec:

  replicas: 2

  selector:
    matchLabels:
      app: hybrid-iac-app

  template:

    metadata:
      labels:
        app: hybrid-iac-app

    spec:

      containers:

        - name: app

          image: YOUR_ECR_IMAGE

          ports:

            - containerPort: 80
```

`kubernetes/service.yaml`

```yaml
apiVersion: v1

kind: Service

metadata:

  name: hybrid-iac-service

  namespace: hybrid-iac

spec:

  type: LoadBalancer

  selector:

    app: hybrid-iac-app

  ports:

    - port: 80
      targetPort: 80
```

Then:

```powershell
kubectl apply -f kubernetes/
```

---

## 27. Where EKS fits

This is an important architectural point.

**CloudFormation creates the EKS cluster.**

Then:

**kubectl/Kubernetes manages workloads inside the cluster.**

So don't try to put Kubernetes Deployment YAML inside CloudFormation.

Use:

```text
CloudFormation
       |
       v
     EKS
       |
       |
       v
   Kubernetes
       |
       +-- Deployment
       +-- Service
       +-- ConfigMap
       +-- Ingress
```

This gives you experience with the boundary between AWS infrastructure and Kubernetes workloads.

---

## 28. Where ECS fits

ECS is similar but doesn't require Kubernetes.

Your lab will intentionally have both:

```text
                         ECR
                          |
              +-----------+-----------+
              |                       |
              v                       v
             ECS                     EKS
              |                       |
       ECS Task Definition      Kubernetes Deployment
              |                       |
       ECS Service              Kubernetes Service
```

That allows you to learn:

**ECS**

```text
ECR
 ↓
Task Definition
 ↓
ECS Service
 ↓
ALB
```

versus:

**EKS**

```text
ECR
 ↓
Kubernetes Deployment
 ↓
Pod
 ↓
Service
 ↓
Load Balancer
```

---

## 29. API Gateway + Lambda

Another nested-stack relationship:

```text
API Gateway
     |
     v
   Lambda
     |
     +---------> DynamoDB
     |
     +---------> RDS
```

For example:

```text
POST /orders
       |
       v
API Gateway
       |
       v
CreateOrder Lambda
       |
       v
DynamoDB
```

Later we'll create:

```text
lambda.yaml
api-gateway.yaml
```

as separate nested stacks.

---

## 30. RDS

RDS should live inside private subnets:

```text
                 VPC
                  |
       +----------+----------+
       |                     |
 Public Subnets        Private Subnets
       |                     |
       |                     |
      ALB                    RDS
       |                     |
       v                     |
     ECS/EKS ----------------+
```

Do **not** put your production-style RDS database in a public subnet just to make the lab easier.

---

## 31. CloudFront

Your CloudFront layer can look like:

```text
User
 |
 v
CloudFront
 |
 v
S3
```

while APIs use:

```text
User
 |
 v
CloudFront
 |
 +---- /api/* ---> API Gateway
 |
 +---- /* -------> S3
```

That gives you a much more realistic architecture.

---

## 32. Final architecture

When we finish all the files, your lab will look approximately like this:

```text
                              GitHub
                                |
                                v
                         GitHub Actions
                                |
                                v
                         Terraform CLI
                                |
                +---------------+----------------+
                |                                |
                v                                v
        Terraform Resources              CloudFormation Stack
                |                                |
                v                                v
       CFN Template S3                    Main Stack
                                                 |
                 +-------------------------------+----------------+
                 |               |               |                |
                 v               v               v                v
                VPC             S3              ECR             DynamoDB
                 |
        +--------+--------+
        |        |        |
        v        v        v
       EC2      RDS      Containers
                          |
                  +-------+-------+
                  |               |
                  v               v
                 ECS             EKS
                  |               |
                  |               v
                  |        Kubernetes
                  |               |
                  +-------+-------+
                          |
                          v
                         App


Frontend:

User
 |
 v
CloudFront
 |
 +------> S3


API:

User
 |
 v
API Gateway
 |
 v
Lambda
 |
 +------> DynamoDB
 |
 +------> RDS


Container:

Developer
 |
 v
Docker
 |
 v
ECR
 |
 +------> ECS
 |
 +------> EKS
```

---

## 33. One change I strongly recommend

Don't try to make the first `terraform apply` create all 11 services.

Build this lab in **phases**.

### Phase 1 — IaC foundation

```text
Terraform
   |
   +-- S3 template bucket
   |
   +-- IAM
   |
   +-- CloudFormation root stack
```

### Phase 2 — Networking

```text
VPC
 ├── Public subnet 1
 ├── Public subnet 2
 ├── Private subnet 1
 └── Private subnet 2
```

### Phase 3 — Basic AWS

```text
EC2
S3
DynamoDB
```

### Phase 4 — Serverless

```text
Lambda
API Gateway
```

### Phase 5 — Database

```text
RDS
```

### Phase 6 — CDN

```text
CloudFront
S3
```

### Phase 7 — Docker

```text
Docker
 |
 ECR
```

### Phase 8 — ECS

```text
ECR
 ↓
ECS
 ↓
Service
 ↓
ALB
```

### Phase 9 — Kubernetes

```text
EKS
 ↓
kubectl
 ↓
Namespace
 ↓
Deployment
 ↓
Service
```

### Phase 10 — GitHub CI/CD

Finally:

```text
git push
   |
   v
GitHub Actions
   |
   +---- Terraform
   |       |
   |       +---- S3 templates
   |       +---- CloudFormation
   |
   +---- Docker
   |       |
   |       +---- ECR
   |
   +---- Kubernetes
           |
           +---- EKS
```

---

## 34. One more important IAM distinction

I would **not** put absolutely everything into one IAM role.

For learning, you can have:

```text
Terraform execution identity
        |
        v
Terraform
        |
        +---- S3
        +---- CloudFormation
        +---- IAM
```

Then:

```text
CloudFormationExecutionRole
        |
        +---- VPC
        +---- EC2
        +---- S3
        +---- Lambda
        +---- API Gateway
        +---- RDS
        +---- DynamoDB
        +---- ECR
        +---- ECS
        +---- EKS
```

And application roles separately:

```text
LambdaExecutionRole
ECSExecutionRole
ECSTaskRole
EKSNodeRole / Pod roles
```

This is actually an **excellent IAM learning exercise** because you'll learn why AWS applications normally don't use one giant role.

---

## 35. Your first milestone

I recommend that we **do not jump directly into ECS/EKS yet**.

Your first working milestone should be:

```text
GitHub
   ↓
Terraform
   ↓
Create S3 CFN-template bucket
   ↓
Upload main.yaml
   ↓
Upload nested templates
   ↓
Create CloudFormation execution role
   ↓
Create Main CloudFormation Stack
   ↓
Main Stack
   ↓
VPC Nested Stack
   ↓
S3 Nested Stack
   ↓
DynamoDB Nested Stack
   ↓
ECR Nested Stack
```

Once that works, we'll add:

```text
EC2
 ↓
Lambda
 ↓
API Gateway
 ↓
RDS
 ↓
CloudFront
 ↓
ECS
 ↓
EKS
```

This approach gives you a **real hybrid IaC lab**, rather than simply throwing 11 AWS services into one giant template.

And importantly, every time you run:

```powershell
terraform apply
```

you will be practicing the exact concept you wanted:

> **Terraform is the front door; CloudFormation is the backend IaC engine; S3 is the template delivery layer; nested CloudFormation stacks divide the infrastructure into manageable modules.**
