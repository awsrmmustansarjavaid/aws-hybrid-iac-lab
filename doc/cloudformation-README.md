# CloudFormation README — Hybrid Terraform + CloudFormation Lab

This document walks through every CloudFormation template in `infrastructure/cloudformation/`: the root stack, each nested stack, and how they fit together.

## Folder overview

```text
infrastructure/
└── cloudformation/
    │
    ├── main.yaml
    │
    ├── nested/
    │   ├── vpc.yaml
    │   ├── ec2.yaml
    │   ├── s3.yaml
    │   ├── cloudfront.yaml
    │   ├── api-gateway.yaml
    │   ├── lambda.yaml
    │   ├── rds.yaml
    │   ├── dynamodb.yaml
    │   ├── ecr.yaml
    │   ├── ecs.yaml
    │   └── eks.yaml
    │
    └── iam/
        └── cloudformation-execution-role.yaml
```

The root stack (`main.yaml`) doesn't create AWS resources directly — it launches nested stacks, each of which owns one slice of the architecture:

```text
main.yaml
│
├── VPCStack        → nested/vpc.yaml
├── S3Stack         → nested/s3.yaml
├── DynamoDBStack   → nested/dynamodb.yaml
└── ECRStack        → nested/ecr.yaml
```

Later phases add `ec2.yaml`, `lambda.yaml`, `api-gateway.yaml`, `rds.yaml`, `cloudfront.yaml`, `ecs.yaml`, and `eks.yaml` as additional nested stacks under the same root.

The CloudFormation templates themselves are uploaded to S3 by Terraform (see the Terraform README, `template_bucket.tf` / `template_objects.tf`). CloudFormation's `TemplateURL` properties pull the nested templates from that bucket at deploy time.

---

## main.yaml — Root Stack

Path: `infrastructure/cloudformation/main.yaml`

This is the entry point. It does not create AWS resources itself — it calls nested stacks via `AWS::CloudFormation::Stack` and passes them common parameters (`ProjectName`, `Environment`).

```yaml
AWSTemplateFormatVersion: "2010-09-09"

# ============================================================
# HYBRID IaC AWS DEVOPS LAB
# ============================================================
#
# File:
#   infrastructure/cloudformation/main.yaml
#
# Purpose:
#   This is the ROOT CloudFormation stack for the lab.
#
#   The root stack does NOT directly create the AWS resources.
#   Instead, it calls multiple nested CloudFormation stacks.
#
# Architecture:
#
#   main.yaml
#       |
#       +----> nested/vpc.yaml
#       |
#       +----> nested/s3.yaml
#       |
#       +----> nested/dynamodb.yaml
#       |
#       +----> nested/ecr.yaml
#
# This gives us a modular CloudFormation architecture.
#
# The CloudFormation templates are stored in an S3 bucket.
# CloudFormation downloads the nested templates from S3
# using TemplateURL.
#
# ============================================================


# ============================================================
# TEMPLATE DESCRIPTION
# ============================================================

Description: >
  Root CloudFormation stack for the Hybrid Terraform +
  CloudFormation AWS DevOps Lab.


# ============================================================
# PARAMETERS
# ============================================================
#
# Parameters allow values to be supplied when the stack is
# deployed instead of hard-coding them inside the template.
#
# ============================================================

Parameters:

  # ----------------------------------------------------------
  # ProjectName
  # ----------------------------------------------------------
  #
  # Common name used by the nested CloudFormation stacks.
  #
  # Example:
  #   HybridIaCLab
  #
  ProjectName:
    Type: String

    Default: HybridIaCLab

    Description: >
      Name of the project used by the nested CloudFormation
      stacks for resource naming and tagging.


  # ----------------------------------------------------------
  # Environment
  # ----------------------------------------------------------
  #
  # Identifies the deployment environment.
  #
  # Example:
  #   dev
  #   test
  #   prod
  #
  Environment:
    Type: String

    Default: dev

    Description: >
      Deployment environment for the lab.


  # ----------------------------------------------------------
  # TemplateBucket
  # ----------------------------------------------------------
  #
  # S3 bucket containing the CloudFormation nested templates.
  #
  # Example:
  #
  #   hybrid-iac-lab-cfn-templates
  #
  # CloudFormation uses this bucket to download:
  #
  #   nested/vpc.yaml
  #   nested/s3.yaml
  #   nested/dynamodb.yaml
  #   nested/ecr.yaml
  #
  TemplateBucket:
    Type: String

    Description: >
      S3 bucket containing the CloudFormation nested stack
      templates.


  # ----------------------------------------------------------
  # TemplatePrefix
  # ----------------------------------------------------------
  #
  # Optional S3 prefix/folder before the nested directory.
  #
  # If the templates are stored like this:
  #
  #   s3://bucket/nested/vpc.yaml
  #
  # then TemplatePrefix should be:
  #
  #   ""
  #
  # If they are stored like this:
  #
  #   s3://bucket/cloudformation/nested/vpc.yaml
  #
  # then TemplatePrefix should be:
  #
  #   cloudformation/
  #
  TemplatePrefix:
    Type: String

    Default: ""

    Description: >
      Optional S3 key prefix used before the nested template
      directory.


# ============================================================
# RESOURCES
# ============================================================
#
# The root stack creates four nested CloudFormation stacks.
#
# Nested stacks allow us to divide infrastructure into smaller,
# reusable CloudFormation templates.
#
# ============================================================

Resources:


  # ==========================================================
  # VPC NESTED STACK
  # ==========================================================
  #
  # Responsible for networking infrastructure.
  #
  # The actual resources are defined inside:
  #
  #   nested/vpc.yaml
  #
  # Possible resources created by that template include:
  #
  #   - VPC
  #   - Internet Gateway
  #   - Subnets
  #   - Route Tables
  #   - Security Groups
  #
  # ==========================================================

  VPCStack:

    # Tell CloudFormation that this resource is another
    # CloudFormation stack.
    Type: AWS::CloudFormation::Stack

    Properties:

      # --------------------------------------------------------
      # TemplateURL
      # --------------------------------------------------------
      #
      # CloudFormation downloads the nested template from S3.
      #
      # !Sub allows us to dynamically insert:
      #
      #   ${TemplateBucket}
      #   ${AWS::Region}
      #   ${TemplatePrefix}
      #
      # Example resulting URL:
      #
      # https://my-bucket.s3.us-east-1.amazonaws.com/nested/vpc.yaml
      #
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/vpc.yaml


      # --------------------------------------------------------
      # PARAMETERS PASSED TO VPC STACK
      # --------------------------------------------------------
      #
      # These values are sent from the root stack to the
      # nested VPC template.
      #
      Parameters:

        # Pass the project name to nested/vpc.yaml
        ProjectName: !Ref ProjectName

        # Pass the environment name to nested/vpc.yaml
        Environment: !Ref Environment


  # ==========================================================
  # S3 NESTED STACK
  # ==========================================================
  #
  # Responsible for S3 infrastructure.
  #
  # The actual resources are defined inside:
  #
  #   nested/s3.yaml
  #
  # Depending on the lab design, this stack can contain:
  #
  #   - S3 bucket
  #   - Bucket policies
  #   - Versioning
  #   - Encryption
  #
  # ==========================================================

  S3Stack:

    # Create a nested CloudFormation stack.
    Type: AWS::CloudFormation::Stack

    Properties:

      # Location of the S3 nested template.
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/s3.yaml


      # Parameters passed from the root stack to the S3 stack.
      Parameters:

        # Project name used by the S3 template.
        ProjectName: !Ref ProjectName

        # Environment used by the S3 template.
        Environment: !Ref Environment


  # ==========================================================
  # DYNAMODB NESTED STACK
  # ==========================================================
  #
  # Responsible for DynamoDB infrastructure.
  #
  # The actual resources are defined inside:
  #
  #   nested/dynamodb.yaml
  #
  # This keeps database-related infrastructure separate from
  # networking and storage infrastructure.
  #
  # ==========================================================

  DynamoDBStack:

    # Create a nested CloudFormation stack.
    Type: AWS::CloudFormation::Stack

    Properties:

      # Location of the DynamoDB nested template.
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/dynamodb.yaml


      # Parameters passed from the root stack to DynamoDB.
      Parameters:

        # Project name used by the DynamoDB template.
        ProjectName: !Ref ProjectName

        # Environment used by the DynamoDB template.
        Environment: !Ref Environment


  # ==========================================================
  # ECR NESTED STACK
  # ==========================================================
  #
  # Responsible for Amazon ECR infrastructure.
  #
  # The actual resources are defined inside:
  #
  #   nested/ecr.yaml
  #
  # ECR will store Docker container images used by the lab.
  #
  # Example future flow:
  #
  #   Developer
  #       |
  #       v
  #   GitHub
  #       |
  #       v
  #   Docker Build
  #       |
  #       v
  #   Amazon ECR
  #       |
  #       v
  #   ECS / Kubernetes
  #
  # ==========================================================

  ECRStack:

    # Create a nested CloudFormation stack.
    Type: AWS::CloudFormation::Stack

    Properties:

      # Location of the ECR nested template.
      TemplateURL: !Sub >
        https://${TemplateBucket}.s3.${AWS::Region}.amazonaws.com/
        ${TemplatePrefix}nested/ecr.yaml


      # Parameters passed from the root stack to ECR.
      Parameters:

        # Project name used by the ECR template.
        ProjectName: !Ref ProjectName

        # Environment used by the ECR template.
        Environment: !Ref Environment


# ============================================================
# OUTPUTS
# ============================================================
#
# Outputs allow us to retrieve useful information after the
# root CloudFormation stack has been deployed.
#
# The values below expose the nested stack resources.
#
# ============================================================

Outputs:


  # ----------------------------------------------------------
  # VPC STACK OUTPUT
  # ----------------------------------------------------------

  VPCStackId:

    Description: >
      ID of the nested VPC CloudFormation stack.

    Value: !Ref VPCStack


  # ----------------------------------------------------------
  # S3 STACK OUTPUT
  # ----------------------------------------------------------

  S3StackId:

    Description: >
      ID of the nested S3 CloudFormation stack.

    Value: !Ref S3Stack


  # ----------------------------------------------------------
  # DYNAMODB STACK OUTPUT
  # ----------------------------------------------------------

  DynamoDBStackId:

    Description: >
      ID of the nested DynamoDB CloudFormation stack.

    Value: !Ref DynamoDBStack


  # ----------------------------------------------------------
  # ECR STACK OUTPUT
  # ----------------------------------------------------------

  ECRStackId:

    Description: >
      ID of the nested ECR CloudFormation stack.

    Value: !Ref ECRStack
```

**How this root stack works:**

The four nested stacks are siblings, all controlled by `main.yaml`:

```text
main.yaml
│
├── VPCStack
│   └── nested/vpc.yaml
│
├── S3Stack
│   └── nested/s3.yaml
│
├── DynamoDBStack
│   └── nested/dynamodb.yaml
│
└── ECRStack
    └── nested/ecr.yaml
```

And the S3 template bucket should eventually contain:

```text
s3://<template-bucket>/
│
└── nested/
    ├── vpc.yaml
    ├── s3.yaml
    ├── dynamodb.yaml
    └── ecr.yaml
```

> **Important:** `main.yaml` itself does not need to be inside that S3 `nested/` folder. The root template can be deployed from your local machine, GitHub Actions, or another CI/CD system. The nested templates referenced by `TemplateURL` must be reachable by CloudFormation from S3.

This gives a clean separation:

- **Terraform** → AWS infrastructure that Terraform owns (S3 bucket, IAM role)
- **CloudFormation root stack** → CloudFormation nested stacks
- **Nested stacks** → individual AWS service groups

That's a much better structure than putting every AWS resource into one giant CloudFormation file.

---

## nested/vpc.yaml — Networking Layer

Path: `infrastructure/cloudformation/nested/vpc.yaml`

Creates the VPC, an Internet Gateway, two public subnets, two private subnets, a public route table, and the associations tying it together.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

# ============================================================
# HYBRID IaC AWS DEVOPS LAB
# ============================================================
#
# File:
#   infrastructure/cloudformation/nested/vpc.yaml
#
# Purpose:
#   This nested CloudFormation stack creates the NETWORK layer
#   of the Hybrid IaC AWS DevOps Lab.
#
# Architecture:
#
#                       Internet
#                           |
#                           v
#                   Internet Gateway
#                           |
#                           v
#                    +-------------+
#                    |     VPC     |
#                    | 10.0.0.0/16 |
#                    +-------------+
#                       /       \
#                      /         \
#                     v           v
#              Public Subnet   Public Subnet
#               10.0.1.0/24    10.0.2.0/24
#                    |               |
#                    +-------+-------+
#                            |
#                      Public Route Table
#
#              Private Subnet   Private Subnet
#               10.0.11.0/24    10.0.12.0/24
#
#
# IMPORTANT:
#
# This template creates:
#
#   1. VPC
#   2. Internet Gateway
#   3. Internet Gateway attachment
#   4. Two public subnets
#   5. Two private subnets
#   6. Public route table
#   7. Default internet route
#   8. Public subnet route associations
#
# The private subnets intentionally do NOT have a route to the
# Internet Gateway.
#
# A NAT Gateway can be added later if private resources need
# outbound Internet access.
#
# ============================================================


# ============================================================
# DESCRIPTION
# ============================================================

Description: >
  Network layer for the Hybrid IaC Lab.
  Creates a VPC with two public and two private subnets
  distributed across two Availability Zones.


# ============================================================
# PARAMETERS
# ============================================================
#
# These parameters are received from the ROOT STACK:
#
#   infrastructure/cloudformation/main.yaml
#
# The root stack passes:
#
#   ProjectName
#   Environment
#
# ============================================================

Parameters:


  # ----------------------------------------------------------
  # PROJECT NAME
  # ----------------------------------------------------------
  #
  # Example:
  #
  #   HybridIaCLab
  #
  # This value is used when creating resource names.
  #
  ProjectName:
    Type: String

    Description: >
      Name of the project used for resource naming and tagging.


  # ----------------------------------------------------------
  # ENVIRONMENT
  # ----------------------------------------------------------
  #
  # Example:
  #
  #   dev
  #
  # Other possible values:
  #
  #   test
  #   staging
  #   prod
  #
  Environment:
    Type: String

    Description: >
      Deployment environment for the infrastructure.


# ============================================================
# RESOURCES
# ============================================================

Resources:


  # ==========================================================
  # VPC
  # ==========================================================
  #
  # The VPC is the main private networking boundary for our
  # AWS infrastructure.
  #
  # CIDR:
  #
  #   10.0.0.0/16
  #
  # This provides 65,536 IPv4 addresses before AWS subnet
  # reservations and allows us to divide the network into
  # multiple subnets.
  #
  # ==========================================================

  VPC:
    Type: AWS::EC2::VPC

    Properties:

      # --------------------------------------------------------
      # VPC CIDR RANGE
      # --------------------------------------------------------
      #
      # Entire network:
      #
      #   10.0.0.0/16
      #
      CidrBlock: 10.0.0.0/16


      # --------------------------------------------------------
      # DNS SUPPORT
      # --------------------------------------------------------
      #
      # Allows instances in the VPC to resolve DNS hostnames.
      #
      EnableDnsSupport: true


      # --------------------------------------------------------
      # DNS HOSTNAMES
      # --------------------------------------------------------
      #
      # Enables DNS hostnames for resources in the VPC.
      #
      # This is useful for EC2 instances and other AWS services
      # that rely on DNS names.
      #
      EnableDnsHostnames: true


      # --------------------------------------------------------
      # TAGS
      # --------------------------------------------------------
      #
      # Tags make resources easier to identify in the AWS
      # Console, CLI, billing reports, and automation.
      #
      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-VPC"


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # INTERNET GATEWAY
  # ==========================================================
  #
  # The Internet Gateway provides a path between the VPC and
  # the public Internet.
  #
  # IMPORTANT:
  #
  # Creating an Internet Gateway alone does NOT make a subnet
  # public.
  #
  # A subnet becomes public when:
  #
  #   1. Its route table has a route to the Internet Gateway.
  #   2. Resources have appropriate public IP addressing.
  #
  # ==========================================================

  InternetGateway:
    Type: AWS::EC2::InternetGateway

    Properties:

      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-IGW"


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # VPC / INTERNET GATEWAY ATTACHMENT
  # ==========================================================
  #
  # An Internet Gateway must be attached to the VPC before
  # traffic can flow through it.
  #
  # Relationship:
  #
  #   VPC
  #    |
  #    +---- Internet Gateway
  #
  # ==========================================================

  VPCGatewayAttachment:
    Type: AWS::EC2::VPCGatewayAttachment

    Properties:

      # VPC that will use the Internet Gateway.
      VpcId: !Ref VPC

      # Internet Gateway being attached to the VPC.
      InternetGatewayId: !Ref InternetGateway


  # ==========================================================
  # PUBLIC SUBNET 1
  # ==========================================================
  #
  # CIDR:
  #
  #   10.0.1.0/24
  #
  # Availability Zone:
  #
  #   First AZ returned by AWS for the selected region.
  #
  # Example:
  #
  #   us-east-1a
  #
  # The exact AZ depends on the AWS region.
  #
  # ==========================================================

  PublicSubnet1:
    Type: AWS::EC2::Subnet

    Properties:

      # Attach the subnet to our VPC.
      VpcId: !Ref VPC


      # Network range for Public Subnet 1.
      CidrBlock: 10.0.1.0/24


      # --------------------------------------------------------
      # AVAILABILITY ZONE
      # --------------------------------------------------------
      #
      # Fn::GetAZs returns the Availability Zones available in
      # the current AWS region.
      #
      # Fn::Select:
      #
      #   0 = first Availability Zone
      #
      # --------------------------------------------------------

      AvailabilityZone:
        Fn::Select:

          - 0

          - Fn::GetAZs: !Ref AWS::Region


      # --------------------------------------------------------
      # PUBLIC IPv4 ADDRESS
      # --------------------------------------------------------
      #
      # EC2 instances launched into this subnet will receive a
      # public IPv4 address automatically when supported by the
      # launch configuration.
      #
      MapPublicIpOnLaunch: true


      # Resource tags.
      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-PublicSubnet1"


        - Key: Tier

          Value: Public


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # PUBLIC SUBNET 2
  # ==========================================================
  #
  # CIDR:
  #
  #   10.0.2.0/24
  #
  # This subnet is placed in the SECOND Availability Zone.
  #
  # Using multiple AZs improves availability and allows us to
  # practice Multi-AZ AWS architectures.
  #
  # ==========================================================

  PublicSubnet2:
    Type: AWS::EC2::Subnet

    Properties:

      # Attach subnet to the VPC.
      VpcId: !Ref VPC


      # Network range for Public Subnet 2.
      CidrBlock: 10.0.2.0/24


      # Select the second Availability Zone.
      AvailabilityZone:
        Fn::Select:

          - 1

          - Fn::GetAZs: !Ref AWS::Region


      # Automatically assign public IPv4 addresses where
      # supported.
      MapPublicIpOnLaunch: true


      # Resource tags.
      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-PublicSubnet2"


        - Key: Tier

          Value: Public


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # PRIVATE SUBNET 1
  # ==========================================================
  #
  # CIDR:
  #
  #   10.0.11.0/24
  #
  # Availability Zone:
  #
  #   First AZ
  #
  # This subnet does NOT automatically assign public IP
  # addresses.
  #
  # It also has no Internet Gateway route in this template.
  #
  # Suitable future resources:
  #
  #   - RDS
  #   - ECS tasks
  #   - Internal application servers
  #   - Lambda ENIs
  #   - Other private workloads
  #
  # ==========================================================

  PrivateSubnet1:
    Type: AWS::EC2::Subnet

    Properties:

      # Attach subnet to VPC.
      VpcId: !Ref VPC


      # Private network range.
      CidrBlock: 10.0.11.0/24


      # Place the subnet in the first AZ.
      AvailabilityZone:
        Fn::Select:

          - 0

          - Fn::GetAZs: !Ref AWS::Region


      # Do NOT automatically assign public IPv4 addresses.
      MapPublicIpOnLaunch: false


      # Resource tags.
      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-PrivateSubnet1"


        - Key: Tier

          Value: Private


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # PRIVATE SUBNET 2
  # ==========================================================
  #
  # CIDR:
  #
  #   10.0.12.0/24
  #
  # Availability Zone:
  #
  #   Second AZ
  #
  # This provides a second private subnet for Multi-AZ
  # architectures.
  #
  # ==========================================================

  PrivateSubnet2:
    Type: AWS::EC2::Subnet

    Properties:

      # Attach subnet to VPC.
      VpcId: !Ref VPC


      # Private network range.
      CidrBlock: 10.0.12.0/24


      # Place the subnet in the second AZ.
      AvailabilityZone:
        Fn::Select:

          - 1

          - Fn::GetAZs: !Ref AWS::Region


      # Private subnet does not automatically assign public IPs.
      MapPublicIpOnLaunch: false


      # Resource tags.
      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-PrivateSubnet2"


        - Key: Tier

          Value: Private


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # PUBLIC ROUTE TABLE
  # ==========================================================
  #
  # A route table controls where network traffic from a subnet
  # is sent.
  #
  # This route table will contain:
  #
  #   0.0.0.0/0 --> Internet Gateway
  #
  # Therefore, subnets associated with this route table are
  # public subnets.
  #
  # ==========================================================

  PublicRouteTable:
    Type: AWS::EC2::RouteTable

    Properties:

      # Route table belongs to our VPC.
      VpcId: !Ref VPC


      # Tags for easier identification.
      Tags:

        - Key: Name

          Value: !Sub "${ProjectName}-${Environment}-PublicRouteTable"


        - Key: Tier

          Value: Public


        - Key: Project

          Value: !Ref ProjectName


        - Key: Environment

          Value: !Ref Environment


  # ==========================================================
  # DEFAULT PUBLIC ROUTE
  # ==========================================================
  #
  # This creates the default route:
  #
  #   Destination:
  #
  #       0.0.0.0/0
  #
  #   Target:
  #
  #       Internet Gateway
  #
  # Meaning:
  #
  #   Traffic destined for anywhere on the Internet is sent
  #   through the Internet Gateway.
  #
  # ==========================================================

  DefaultPublicRoute:
    Type: AWS::EC2::Route


    # --------------------------------------------------------
    # DEPENDS ON
    # --------------------------------------------------------
    #
    # Make sure the Internet Gateway is attached to the VPC
    # before CloudFormation creates this route.
    #
    DependsOn: VPCGatewayAttachment


    Properties:

      # Route table receiving this route.
      RouteTableId: !Ref PublicRouteTable


      # Default IPv4 route.
      DestinationCidrBlock: 0.0.0.0/0


      # Send traffic to the Internet Gateway.
      GatewayId: !Ref InternetGateway


  # ==========================================================
  # PUBLIC SUBNET 1 ROUTE TABLE ASSOCIATION
  # ==========================================================
  #
  # Associates PublicSubnet1 with PublicRouteTable.
  #
  # Therefore:
  #
  #   PublicSubnet1
  #          |
  #          v
  #   PublicRouteTable
  #          |
  #          v
  #   Internet Gateway
  #
  # ==========================================================

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation

    Properties:

      # Subnet being associated.
      SubnetId: !Ref PublicSubnet1

      # Public route table being assigned.
      RouteTableId: !Ref PublicRouteTable


  # ==========================================================
  # PUBLIC SUBNET 2 ROUTE TABLE ASSOCIATION
  # ==========================================================
  #
  # Associates PublicSubnet2 with PublicRouteTable.
  #
  # Both public subnets therefore use the same public route
  # table in this simple lab design.
  #
  # ==========================================================

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation

    Properties:

      # Subnet being associated.
      SubnetId: !Ref PublicSubnet2

      # Public route table being assigned.
      RouteTableId: !Ref PublicRouteTable


# ============================================================
# OUTPUTS
# ============================================================
#
# Outputs expose important resource IDs to the parent stack
# and to users/automation.
#
# The ROOT STACK can later consume these values if needed.
#
# ============================================================

Outputs:


  # ==========================================================
  # VPC ID
  # ==========================================================

  VpcId:

    Description: >
      ID of the VPC created by this nested stack.

    Value: !Ref VPC

    # Export allows other CloudFormation stacks in the same
    # AWS account and region to reference this value using
    # Fn::ImportValue.
    #
    # Example:
    #
    #   !ImportValue
    #     !Sub "${ProjectName}-${Environment}-VpcId"
    #
    Export:

      Name: !Sub "${ProjectName}-${Environment}-VpcId"


  # ==========================================================
  # PUBLIC SUBNET 1 ID
  # ==========================================================

  PublicSubnet1Id:

    Description: >
      ID of Public Subnet 1.

    Value: !Ref PublicSubnet1


  # ==========================================================
  # PUBLIC SUBNET 2 ID
  # ==========================================================

  PublicSubnet2Id:

    Description: >
      ID of Public Subnet 2.

    Value: !Ref PublicSubnet2


  # ==========================================================
  # PRIVATE SUBNET 1 ID
  # ==========================================================

  PrivateSubnet1Id:

    Description: >
      ID of Private Subnet 1.

    Value: !Ref PrivateSubnet1


  # ==========================================================
  # PRIVATE SUBNET 2 ID
  # ==========================================================

  PrivateSubnet2Id:

    Description: >
      ID of Private Subnet 2.

    Value: !Ref PrivateSubnet2


  # ==========================================================
  # INTERNET GATEWAY ID
  # ==========================================================
  #
  # Exposing this ID is useful for troubleshooting and
  # verification from the AWS CLI.
  #
  # ==========================================================

  InternetGatewayId:

    Description: >
      ID of the Internet Gateway attached to the VPC.

    Value: !Ref InternetGateway


  # ==========================================================
  # PUBLIC ROUTE TABLE ID
  # ==========================================================

  PublicRouteTableId:

    Description: >
      ID of the public route table.

    Value: !Ref PublicRouteTable
```

**What this nested stack gives you:**

```text
                         INTERNET
                            |
                            |
                    Internet Gateway
                            |
                            |
                  +-------------------+
                  |       VPC         |
                  |   10.0.0.0/16     |
                  |                   |
                  |                   |
       +----------+-------------------+----------+
       |                                      |
       |                                      |
       v                                      v

+----------------------+          +----------------------+
|   Availability Zone 1|          |   Availability Zone 2|
|                      |          |                      |
| PublicSubnet1        |          | PublicSubnet2        |
| 10.0.1.0/24          |          | 10.0.2.0/24          |
|                      |          |                      |
| PUBLIC               |          | PUBLIC               |
+----------------------+          +----------------------+

+----------------------+          +----------------------+
|   Availability Zone 1|          |   Availability Zone 2|
|                      |          |                      |
| PrivateSubnet1       |          | PrivateSubnet2       |
| 10.0.11.0/24         |          | 10.0.12.0/24         |
|                      |          |                      |
| PRIVATE              |          | PRIVATE              |
+----------------------+          +----------------------+
```

The public subnet path is:

```text
EC2 → Public Subnet → Public Route Table → 0.0.0.0/0 → Internet Gateway → Internet
```

The private subnet currently has no Internet Gateway route — that's intentional:

```text
Private Subnet → No Internet Gateway route → Private
```

Don't add a NAT Gateway yet if the goal of this stage is to learn the basic VPC architecture; add one later when you reach the private application/database architecture. `MapPublicIpOnLaunch` is set explicitly to `false` on the private subnets so the public/private distinction is obvious rather than implicit.

---

## nested/s3.yaml — Application Storage

Path: `infrastructure/cloudformation/nested/s3.yaml`

Creates the application's S3 storage bucket. The bucket is private: public access is blocked, encryption is enabled, and versioning is enabled.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

# ============================================================
# HYBRID IaC AWS DEVOPS LAB
# ============================================================
#
# File:
#   infrastructure/cloudformation/nested/s3.yaml
#
# Purpose:
#   Creates the application's S3 storage layer.
#
# Resources created:
#
#   - S3 application bucket
#   - Server-side encryption
#   - S3 versioning
#   - Public access blocking
#   - Resource tags
#
# Security model:
#
#   The bucket is PRIVATE.
#
#   Public ACLs and public bucket policies are blocked.
#
#   Applications or AWS services should access the bucket
#   through IAM permissions or controlled AWS integrations.
#
# ============================================================


# ============================================================
# DESCRIPTION
# ============================================================

Description: >
  Application S3 storage layer for the Hybrid IaC AWS DevOps Lab.


# ============================================================
# PARAMETERS
# ============================================================
#
# Values are passed from:
#
#   infrastructure/cloudformation/main.yaml
#
# ============================================================

Parameters:


  # ----------------------------------------------------------
  # PROJECT NAME
  # ----------------------------------------------------------

  ProjectName:
    Type: String

    Description: >
      Name of the project used for resource tagging.


  # ----------------------------------------------------------
  # ENVIRONMENT
  # ----------------------------------------------------------

  Environment:
    Type: String

    Description: >
      Deployment environment such as dev, test, or prod.


# ============================================================
# RESOURCES
# ============================================================

Resources:


  # ==========================================================
  # APPLICATION S3 BUCKET
  # ==========================================================
  #
  # This bucket provides object storage for the application.
  #
  # Possible future uses include:
  #
  #   - Application files
  #   - Uploaded files
  #   - Build artifacts
  #   - Reports
  #   - Logs
  #   - Static assets
  #
  # ==========================================================

  ApplicationBucket:

    # Create an Amazon S3 bucket.
    Type: AWS::S3::Bucket

    Properties:


      # --------------------------------------------------------
      # BUCKET ENCRYPTION
      # --------------------------------------------------------
      #
      # Enables server-side encryption for objects stored in
      # this bucket.
      #
      # AES256 uses Amazon S3 managed encryption keys.
      #
      # This is a simple and cost-effective encryption option
      # for the lab.
      #
      BucketEncryption:

        ServerSideEncryptionConfiguration:

          - ServerSideEncryptionByDefault:

              SSEAlgorithm: AES256


      # --------------------------------------------------------
      # PUBLIC ACCESS BLOCK
      # --------------------------------------------------------
      #
      # These four settings prevent accidental public access.
      #
      # BlockPublicAcls:
      #
      #   Blocks new public ACLs.
      #
      # BlockPublicPolicy:
      #
      #   Blocks public bucket policies.
      #
      # IgnorePublicAcls:
      #
      #   Ignores public ACLs that might already exist.
      #
      # RestrictPublicBuckets:
      #
      #   Restricts access when a bucket has a public policy.
      #
      # --------------------------------------------------------

      PublicAccessBlockConfiguration:

        BlockPublicAcls: true

        BlockPublicPolicy: true

        IgnorePublicAcls: true

        RestrictPublicBuckets: true


      # --------------------------------------------------------
      # VERSIONING
      # --------------------------------------------------------
      #
      # Versioning keeps multiple versions of objects.
      #
      # Example:
      #
      #   index.html
      #
      #   version 1
      #   version 2
      #   version 3
      #
      # This is useful for:
      #
      #   - Accidental deletion recovery
      #   - File rollback
      #   - Deployment safety
      #   - CI/CD artifact management
      #
      VersioningConfiguration:

        Status: Enabled


      # --------------------------------------------------------
      # TAGS
      # --------------------------------------------------------

      Tags:

        # Project identifier
        - Key: Project

          Value: !Ref ProjectName


        # Environment identifier
        - Key: Environment

          Value: !Ref Environment


        # AWS service identifier
        - Key: Service

          Value: S3


        # Resource purpose
        - Key: Purpose

          Value: ApplicationStorage


# ============================================================
# OUTPUTS
# ============================================================
#
# These outputs expose the bucket information to CloudFormation,
# CLI commands, CI/CD pipelines, and future infrastructure.
#
# ============================================================

Outputs:


  # ==========================================================
  # BUCKET NAME
  # ==========================================================

  BucketName:

    Description: >
      Name of the application S3 bucket.

    # !Ref AWS::S3::Bucket returns the bucket name.
    Value: !Ref ApplicationBucket


  # ==========================================================
  # BUCKET ARN
  # ==========================================================

  BucketArn:

    Description: >
      ARN of the application S3 bucket.

    # !GetAtt retrieves the bucket ARN.
    Value: !GetAtt ApplicationBucket.Arn
```

> **Important:** This application bucket is not the same bucket as the CloudFormation template bucket. The root stack's `TemplateBucket` parameter points to the bucket containing `nested/vpc.yaml`, `nested/s3.yaml`, etc. `ApplicationBucket` above is an application-storage resource. Keeping those purposes separate is cleaner for the lab.

---

## nested/dynamodb.yaml — Database Layer

Path: `infrastructure/cloudformation/nested/dynamodb.yaml`

Creates a DynamoDB `Orders` table with an on-demand billing mode, a single partition key, and point-in-time recovery.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

# ============================================================
# HYBRID IaC AWS DEVOPS LAB
# ============================================================
#
# File:
#   infrastructure/cloudformation/nested/dynamodb.yaml
#
# Purpose:
#   This nested CloudFormation stack creates the DynamoDB
#   database layer for the Hybrid IaC AWS DevOps Lab.
#
# Architecture:
#
#                         Application
#                              |
#                              v
#                       +--------------+
#                       |  DynamoDB    |
#                       |              |
#                       | OrdersTable  |
#                       +--------------+
#                              |
#                              v
#                           OrderId
#
#
# This stack creates:
#
#   1. DynamoDB Orders table
#   2. Partition key: OrderId
#   3. On-demand billing
#   4. Point-in-time recovery
#   5. Resource tags
#
# ============================================================


# ============================================================
# DESCRIPTION
# ============================================================

Description: >
  DynamoDB database layer for the Hybrid IaC AWS DevOps Lab.


# ============================================================
# PARAMETERS
# ============================================================
#
# These parameters are received from the ROOT CloudFormation
# stack:
#
#   infrastructure/cloudformation/main.yaml
#
# The root stack passes:
#
#   ProjectName
#   Environment
#
# ============================================================

Parameters:


  # ----------------------------------------------------------
  # PROJECT NAME
  # ----------------------------------------------------------
  #
  # Used to create a consistent DynamoDB table name.
  #
  # Example:
  #
  #   HybridIaCLab
  #
  ProjectName:
    Type: String

    Description: >
      Name of the project used for DynamoDB resource naming
      and tagging.


  # ----------------------------------------------------------
  # ENVIRONMENT
  # ----------------------------------------------------------
  #
  # Identifies the environment where the table is deployed.
  #
  # Example:
  #
  #   dev
  #
  Environment:
    Type: String

    Description: >
      Deployment environment for the DynamoDB table.


# ============================================================
# RESOURCES
# ============================================================

Resources:


  # ==========================================================
  # ORDERS TABLE
  # ==========================================================
  #
  # This DynamoDB table stores application order records.
  #
  # Example table name:
  #
  #   HybridIaCLab-dev-Orders
  #
  # ==========================================================

  OrdersTable:

    # Tell CloudFormation to create a DynamoDB table.
    Type: AWS::DynamoDB::Table

    Properties:


      # --------------------------------------------------------
      # TABLE NAME
      # --------------------------------------------------------
      #
      # !Sub dynamically combines:
      #
      #   ProjectName
      #   Environment
      #
      # Example:
      #
      #   HybridIaCLab-dev-Orders
      #
      # Keeping the project and environment in the name makes
      # the resource easy to identify.
      #
      TableName: !Sub "${ProjectName}-${Environment}-Orders"


      # --------------------------------------------------------
      # BILLING MODE
      # --------------------------------------------------------
      #
      # PAY_PER_REQUEST means DynamoDB uses on-demand capacity.
      #
      # Advantages for this lab:
      #
      #   - No need to configure read capacity.
      #   - No need to configure write capacity.
      #   - Automatically handles traffic changes.
      #   - Good for development and unpredictable workloads.
      #
      BillingMode: PAY_PER_REQUEST


      # --------------------------------------------------------
      # ATTRIBUTE DEFINITIONS
      # --------------------------------------------------------
      #
      # Defines the attributes used by the table's key schema.
      #
      # IMPORTANT:
      #
      # DynamoDB does NOT require every possible application
      # attribute to be declared here.
      #
      # Only attributes participating in the primary key or
      # index key definitions are declared.
      #
      # OrderId:
      #
      #   S = String
      #
      AttributeDefinitions:

        - AttributeName: OrderId
          AttributeType: S


      # --------------------------------------------------------
      # KEY SCHEMA
      # --------------------------------------------------------
      #
      # Defines the primary key of the DynamoDB table.
      #
      # HASH means partition key.
      #
      # Therefore:
      #
      #   Partition Key = OrderId
      #
      # Example:
      #
      #   OrderId = ORD-1001
      #   OrderId = ORD-1002
      #   OrderId = ORD-1003
      #
      # Each OrderId should uniquely identify an order.
      #
      KeySchema:

        - AttributeName: OrderId
          KeyType: HASH


      # --------------------------------------------------------
      # POINT-IN-TIME RECOVERY
      # --------------------------------------------------------
      #
      # Enables continuous backups for the DynamoDB table.
      #
      # This allows the table to be restored to a previous point
      # in time within the supported recovery window.
      #
      # This is an important production-style data protection
      # feature for the lab.
      #
      PointInTimeRecoverySpecification:

        PointInTimeRecoveryEnabled: true


      # --------------------------------------------------------
      # TAGS
      # --------------------------------------------------------
      #
      # Tags help identify and manage AWS resources.
      #
      # We use:
      #
      #   Project
      #   Environment
      #
      # These can later be useful for:
      #
      #   - Cost allocation
      #   - Resource filtering
      #   - Automation
      #   - Operations
      #
      Tags:


        # Project tag
        - Key: Project

          Value: !Ref ProjectName


        # Environment tag
        - Key: Environment

          Value: !Ref Environment


        # Service tag
        - Key: Service

          Value: DynamoDB


# ============================================================
# OUTPUTS
# ============================================================
#
# Outputs expose information about the DynamoDB table.
#
# These values can be viewed after deployment and can also be
# consumed by automation.
#
# ============================================================

Outputs:


  # ==========================================================
  # ORDERS TABLE NAME
  # ==========================================================

  OrdersTableName:

    Description: >
      Name of the DynamoDB Orders table.

    # !Ref on AWS::DynamoDB::Table returns the table name.
    Value: !Ref OrdersTable


  # ==========================================================
  # ORDERS TABLE ARN
  # ==========================================================
  #
  # !GetAtt retrieves an attribute from the DynamoDB table.
  #
  # Here we retrieve:
  #
  #   Arn
  #
  # Example:
  #
  #   arn:aws:dynamodb:region:account-id:table/...
  #
  # ==========================================================

  OrdersTableArn:

    Description: >
      ARN of the DynamoDB Orders table.

    Value: !GetAtt OrdersTable.Arn


  # ==========================================================
  # PARTITION KEY
  # ==========================================================
  #
  # This output documents the primary partition key used by
  # the table.
  #
  # It is not required for CloudFormation itself, but is useful
  # when inspecting stack outputs during the lab.
  #
  # ==========================================================

  OrdersTablePartitionKey:

    Description: >
      Partition key used by the Orders DynamoDB table.

    Value: OrderId
```

Application records could conceptually look like:

```json
{
  "OrderId": "ORD-1001",
  "CustomerName": "Charlie",
  "Item": "Coffee",
  "Quantity": 2,
  "Status": "PLACED"
}
```

Only `OrderId` is declared in `AttributeDefinitions`. That's intentional: DynamoDB's `AttributeDefinitions` section describes attributes used in the table's key schema/indexes, not every field you might store in an item. `PAY_PER_REQUEST` is a good fit for hands-on labs because you don't have to guess provisioned read/write capacity while experimenting.

---

## nested/ecr.yaml — Container Image Registry

Path: `infrastructure/cloudformation/nested/ecr.yaml`

Creates an ECR repository with scan-on-push, immutable tags, and AES-256 encryption.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

# ============================================================
# HYBRID IaC AWS DEVOPS LAB
# ============================================================
#
# File:
#   infrastructure/cloudformation/nested/ecr.yaml
#
# Purpose:
#   Creates the Amazon ECR container image repository for the
#   Hybrid IaC AWS DevOps Lab.
#
# Architecture:
#
#   Developer
#       |
#       v
#   Application Source Code
#       |
#       v
#   Docker Build
#       |
#       v
#   Docker Image
#       |
#       v
#   Amazon ECR
#       |
#       +----------------------+
#       |                      |
#       v                      v
#     Amazon ECS          Kubernetes / EKS
#
#
# This stack creates:
#
#   1. ECR repository
#   2. Image scanning on push
#   3. Immutable image tags
#   4. AES-256 encryption
#   5. Resource tags
#
# ============================================================


# ============================================================
# DESCRIPTION
# ============================================================

Description: >
  Amazon ECR repository layer for Docker images used by the
  Hybrid IaC AWS DevOps Lab.


# ============================================================
# PARAMETERS
# ============================================================
#
# These parameters are passed from the ROOT CloudFormation
# stack:
#
#   infrastructure/cloudformation/main.yaml
#
# ============================================================

Parameters:


  # ----------------------------------------------------------
  # PROJECT NAME
  # ----------------------------------------------------------
  #
  # Example:
  #
  #   HybridIaCLab
  #
  # Used to construct the ECR repository name.
  #
  ProjectName:
    Type: String

    Description: >
      Name of the project used for ECR repository naming
      and resource tagging.


  # ----------------------------------------------------------
  # ENVIRONMENT
  # ----------------------------------------------------------
  #
  # Example:
  #
  #   dev
  #
  # Repository example:
  #
  #   HybridIaCLab-dev-app
  #
  Environment:
    Type: String

    Description: >
      Deployment environment for the ECR repository.


# ============================================================
# RESOURCES
# ============================================================

Resources:


  # ==========================================================
  # APPLICATION ECR REPOSITORY
  # ==========================================================
  #
  # Stores Docker images for the application.
  #
  # Example repository name:
  #
  #   HybridIaCLab-dev-app
  #
  # Example image:
  #
  #   HybridIaCLab-dev-app:1.0.0
  #
  # ==========================================================

  ApplicationRepository:

    # Tell CloudFormation to create an Amazon ECR repository.
    Type: AWS::ECR::Repository

    Properties:


      # --------------------------------------------------------
      # REPOSITORY NAME
      # --------------------------------------------------------
      #
      # !Sub combines:
      #
      #   ProjectName
      #   Environment
      #   app
      #
      # Example:
      #
      #   HybridIaCLab-dev-app
      #
      RepositoryName: !Sub "${ProjectName}-${Environment}-app"


      # --------------------------------------------------------
      # IMAGE SCANNING
      # --------------------------------------------------------
      #
      # Scan Docker images automatically when they are pushed
      # into the repository.
      #
      # This helps identify known vulnerabilities in the image.
      #
      # Example workflow:
      #
      #   Docker push
      #       |
      #       v
      #   ECR
      #       |
      #       v
      #   Image Scan
      #
      ImageScanningConfiguration:

        ScanOnPush: true


      # --------------------------------------------------------
      # IMAGE TAG MUTABILITY
      # --------------------------------------------------------
      #
      # IMMUTABLE means an existing image tag cannot be reused
      # to point to a different image.
      #
      # Example:
      #
      #   app:1.0.0
      #
      # Once pushed, another image cannot overwrite the same
      # tag.
      #
      # This is useful for reliable deployments because the
      # meaning of a tag does not unexpectedly change.
      #
      ImageTagMutability: IMMUTABLE


      # --------------------------------------------------------
      # ENCRYPTION
      # --------------------------------------------------------
      #
      # ECR stores images using server-side encryption.
      #
      # AES256 uses an AWS-managed encryption key.
      #
      # This provides encryption at rest for the container
      # images stored in the repository.
      #
      EncryptionConfiguration:

        EncryptionType: AES256


      # --------------------------------------------------------
      # TAGS
      # --------------------------------------------------------
      #
      # Tags make AWS resources easier to identify, organize,
      # automate, and manage.
      #
      Tags:


        # Project identifier
        - Key: Project

          Value: !Ref ProjectName


        # Environment identifier
        - Key: Environment

          Value: !Ref Environment


        # AWS service identifier
        - Key: Service

          Value: ECR


        # Resource purpose
        - Key: Purpose

          Value: ContainerImages


# ============================================================
# OUTPUTS
# ============================================================
#
# Outputs expose information about the ECR repository.
#
# These values can be used by:
#
#   - AWS CLI
#   - Terraform
#   - GitHub Actions
#   - Jenkins
#   - ECS
#   - EKS / Kubernetes
#   - Other CloudFormation stacks
#
# ============================================================

Outputs:


  # ==========================================================
  # REPOSITORY URI
  # ==========================================================
  #
  # Example:
  #
  #   123456789012.dkr.ecr.us-east-1.amazonaws.com/
  #   HybridIaCLab-dev-app
  #
  # This is the value normally used when tagging and pushing
  # Docker images.
  #
  # Example Docker workflow:
  #
  #   docker tag app:latest <RepositoryUri>:1.0.0
  #
  #   docker push <RepositoryUri>:1.0.0
  #
  # ==========================================================

  RepositoryUri:

    Description: >
      URI of the ECR repository used to store application
      Docker images.

    Value: !GetAtt ApplicationRepository.RepositoryUri


  # ==========================================================
  # REPOSITORY ARN
  # ==========================================================
  #
  # The ARN uniquely identifies the ECR repository.
  #
  # Example:
  #
  #   arn:aws:ecr:region:account-id:repository/...
  #
  # This can be useful when creating IAM policies.
  #
  # ==========================================================

  RepositoryArn:

    Description: >
      ARN of the application ECR repository.

    Value: !GetAtt ApplicationRepository.Arn


  # ==========================================================
  # REPOSITORY NAME
  # ==========================================================
  #
  # !Ref on AWS::ECR::Repository returns the repository name.
  #
  # This output is useful for CLI commands and CI/CD pipelines.
  #
  # ==========================================================

  RepositoryName:

    Description: >
      Name of the application ECR repository.

    Value: !Ref ApplicationRepository
```

**ECR's role in the Docker/Kubernetes part:**

```text
                    GitHub
                       |
                       v
                GitHub Actions
                       |
                       v
                 Docker Build
                       |
                       v
                 Docker Image
                       |
                       v
              Amazon ECR Repository
                       |
             +---------+---------+
             |                   |
             v                   v
          Amazon ECS          Kubernetes
                                |
                                v
                               EKS
```

`IMMUTABLE` tags are particularly useful for the lab. It forces a better CI/CD practice: instead of repeatedly pushing `latest`, the pipeline can publish versioned tags such as `1.0.0`, `1.0.1`, `1.0.2` — making deployments and rollbacks much easier to reason about.

**At this point, the four nested stacks form the first working milestone:** `VPC → S3 → DynamoDB → ECR`, with `main.yaml` as the parent/orchestrator for all four.

```text
infrastructure/
└── cloudformation/
    │
    ├── main.yaml
    │
    └── nested/
        │
        ├── vpc.yaml
        │       │
        │       ├── VPC
        │       ├── Internet Gateway
        │       ├── Public Subnet 1
        │       ├── Public Subnet 2
        │       ├── Private Subnet 1
        │       └── Private Subnet 2
        │
        ├── s3.yaml
        │       │
        │       └── Application S3 Bucket
        │
        ├── dynamodb.yaml
        │       │
        │       └── OrdersTable
        │
        └── ecr.yaml
                │
                └── ApplicationRepository
```

---

## Phase 2 nested stacks

The following templates extend the lab beyond the first milestone. They add compute, serverless, database, and container-platform layers.

### nested/api-gateway.yaml

Path: `infrastructure/cloudformation/nested/api-gateway.yaml`

Creates a REST API and integrates it with a Lambda function via `AWS_PROXY`.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  API Gateway REST API for the Hybrid Terraform +
  CloudFormation AWS DevOps Lab.

Parameters:

  ProjectName:
    Type: String
    Description: Project name

  Environment:
    Type: String
    Description: Deployment environment

  LambdaFunctionArn:
    Type: String
    Description: ARN of the Lambda function to invoke


Resources:

  # ------------------------------------------------------------
  # REST API
  # ------------------------------------------------------------

  RestApi:
    Type: AWS::ApiGateway::RestApi

    Properties:
      Name: !Sub "${ProjectName}-${Environment}-API"

      Description: !Sub >
        API Gateway for ${ProjectName} ${Environment}

      EndpointConfiguration:
        Types:
          - REGIONAL


  # ------------------------------------------------------------
  # /orders resource
  # ------------------------------------------------------------

  OrdersResource:
    Type: AWS::ApiGateway::Resource

    Properties:
      RestApiId: !Ref RestApi
      ParentId: !GetAtt RestApi.RootResourceId
      PathPart: orders


  # ------------------------------------------------------------
  # POST /orders
  # ------------------------------------------------------------

  CreateOrderMethod:
    Type: AWS::ApiGateway::Method

    Properties:

      RestApiId: !Ref RestApi

      ResourceId: !Ref OrdersResource

      HttpMethod: POST

      AuthorizationType: NONE

      Integration:

        Type: AWS_PROXY

        IntegrationHttpMethod: POST

        Uri:
          !Sub >
            arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/
            functions/${LambdaFunctionArn}/invocations


  # ------------------------------------------------------------
  # Lambda permission for API Gateway
  # ------------------------------------------------------------

  LambdaInvokePermission:
    Type: AWS::Lambda::Permission

    Properties:

      Action: lambda:InvokeFunction

      FunctionName: !Ref LambdaFunctionArn

      Principal: apigateway.amazonaws.com

      SourceArn:
        !Sub >
          arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:
          ${RestApi}/*/POST/orders


  # ------------------------------------------------------------
  # API deployment
  # ------------------------------------------------------------

  ApiDeployment:
    Type: AWS::ApiGateway::Deployment

    DependsOn:
      - CreateOrderMethod

    Properties:

      RestApiId: !Ref RestApi


  # ------------------------------------------------------------
  # API stage
  # ------------------------------------------------------------

  ApiStage:
    Type: AWS::ApiGateway::Stage

    Properties:

      RestApiId: !Ref RestApi

      DeploymentId: !Ref ApiDeployment

      StageName: !Ref Environment


Outputs:

  ApiId:
    Description: API Gateway REST API ID
    Value: !Ref RestApi


  ApiEndpoint:
    Description: API Gateway endpoint
    Value:
      !Sub >
        https://${RestApi}.execute-api.${AWS::Region}.amazonaws.com/
        ${Environment}


  OrdersEndpoint:
    Description: POST orders endpoint
    Value:
      !Sub >
        https://${RestApi}.execute-api.${AWS::Region}.amazonaws.com/
        ${Environment}/orders
```

### nested/lambda.yaml

Path: `infrastructure/cloudformation/nested/lambda.yaml`

A simple Python Lambda with an execution role that includes basic execution permissions plus DynamoDB access.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  Lambda application layer for the Hybrid IaC Lab.

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String


Resources:

  # ------------------------------------------------------------
  # IAM execution role
  # ------------------------------------------------------------

  LambdaExecutionRole:
    Type: AWS::IAM::Role

    Properties:

      RoleName:
        !Sub "${ProjectName}-${Environment}-LambdaRole"

      AssumeRolePolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Effect: Allow

            Principal:
              Service:
                - lambda.amazonaws.com

            Action:
              - sts:AssumeRole


      ManagedPolicyArns:

        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole


      Policies:

        - PolicyName: DynamoDBAccess

          PolicyDocument:

            Version: "2012-10-17"

            Statement:

              - Effect: Allow

                Action:

                  - dynamodb:PutItem
                  - dynamodb:GetItem
                  - dynamodb:UpdateItem
                  - dynamodb:Query
                  - dynamodb:Scan

                Resource: "*"


  # ------------------------------------------------------------
  # Lambda function
  # ------------------------------------------------------------

  ApplicationFunction:
    Type: AWS::Lambda::Function

    Properties:

      FunctionName:
        !Sub "${ProjectName}-${Environment}-ApplicationLambda"

      Runtime: python3.12

      Handler: index.handler

      Role:
        !GetAtt LambdaExecutionRole.Arn

      Timeout: 30

      MemorySize: 256

      Code:

        ZipFile: |

          import json

          def handler(event, context):

              print("Received event:")
              print(json.dumps(event))

              return {
                  "statusCode": 200,
                  "headers": {
                      "Content-Type": "application/json"
                  },
                  "body": json.dumps({
                      "message": "Hello from Hybrid IaC Lambda",
                      "project": "HybridIaCLab"
                  })
              }


Outputs:

  LambdaFunctionName:
    Description: Lambda function name
    Value: !Ref ApplicationFunction


  LambdaFunctionArn:
    Description: Lambda function ARN
    Value: !GetAtt ApplicationFunction.Arn
```

Together, `api-gateway.yaml` and `lambda.yaml` give you:

```text
API Gateway
     |
     v
 Lambda
```

### nested/ec2.yaml

Path: `infrastructure/cloudformation/nested/ec2.yaml`

Creates a security group, an EC2 instance role/profile, and a web server EC2 instance inside a public subnet.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  EC2 compute layer for the Hybrid IaC Lab.

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

  VpcId:
    Type: AWS::EC2::VPC::Id

  PublicSubnetId:
    Type: AWS::EC2::Subnet::Id

  AmiId:
    Type: AWS::EC2::Image::Id

    Description: >
      Amazon Linux 2023 AMI ID for the selected AWS region.

  InstanceType:
    Type: String
    Default: t3.micro

    AllowedValues:
      - t3.micro
      - t3.small


Resources:

  # ------------------------------------------------------------
  # Security Group
  # ------------------------------------------------------------

  WebSecurityGroup:
    Type: AWS::EC2::SecurityGroup

    Properties:

      GroupDescription:
        !Sub "${ProjectName}-${Environment} EC2 security group"

      VpcId: !Ref VpcId

      SecurityGroupIngress:

        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0

          Description: SSH access


        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0

          Description: HTTP access

      Tags:

        - Key: Name
          Value:
            !Sub "${ProjectName}-${Environment}-EC2-SG"


  # ------------------------------------------------------------
  # EC2 IAM role
  # ------------------------------------------------------------

  EC2Role:
    Type: AWS::IAM::Role

    Properties:

      RoleName:
        !Sub "${ProjectName}-${Environment}-EC2Role"

      AssumeRolePolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Effect: Allow

            Principal:
              Service:
                - ec2.amazonaws.com

            Action:
              - sts:AssumeRole


      ManagedPolicyArns:

        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore


  # ------------------------------------------------------------
  # Instance profile
  # ------------------------------------------------------------

  EC2InstanceProfile:
    Type: AWS::IAM::InstanceProfile

    Properties:

      InstanceProfileName:
        !Sub "${ProjectName}-${Environment}-EC2Profile"

      Roles:
        - !Ref EC2Role


  # ------------------------------------------------------------
  # EC2 instance
  # ------------------------------------------------------------

  WebServer:
    Type: AWS::EC2::Instance

    Properties:

      ImageId: !Ref AmiId

      InstanceType: !Ref InstanceType

      SubnetId: !Ref PublicSubnetId

      SecurityGroupIds:

        - !Ref WebSecurityGroup

      IamInstanceProfile:
        !Ref EC2InstanceProfile

      UserData:
        Fn::Base64: |
          #!/bin/bash

          dnf update -y

          dnf install -y nginx

          systemctl enable nginx

          systemctl start nginx

          echo "<h1>Hybrid IaC Lab - EC2</h1>" \
            > /usr/share/nginx/html/index.html

      Tags:

        - Key: Name

          Value:
            !Sub "${ProjectName}-${Environment}-EC2"


Outputs:

  InstanceId:
    Description: EC2 instance ID
    Value: !Ref WebServer


  PublicIp:
    Description: EC2 public IP
    Value: !GetAtt WebServer.PublicIp


  SecurityGroupId:
    Description: EC2 security group
    Value: !Ref WebSecurityGroup
```

> **Important:** The AMI is intentionally a parameter (`AmiId`) because AMI IDs are region-specific. Terraform will eventually pass the correct AMI ID.

### nested/rds.yaml

Path: `infrastructure/cloudformation/nested/rds.yaml`

Creates a private MySQL database in the private subnets, with a DB subnet group and its own security group.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  RDS MySQL database layer.

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

  VpcId:
    Type: AWS::EC2::VPC::Id

  PrivateSubnet1Id:
    Type: AWS::EC2::Subnet::Id

  PrivateSubnet2Id:
    Type: AWS::EC2::Subnet::Id

  DatabaseUsername:
    Type: String
    Default: admin

    NoEcho: true

  DatabasePassword:
    Type: String

    NoEcho: true

    MinLength: 8


Resources:

  # ------------------------------------------------------------
  # Database subnet group
  # ------------------------------------------------------------

  DatabaseSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup

    Properties:

      DBSubnetGroupDescription:
        !Sub "${ProjectName}-${Environment} database subnet group"

      SubnetIds:

        - !Ref PrivateSubnet1Id
        - !Ref PrivateSubnet2Id

      Tags:

        - Key: Name
          Value:
            !Sub "${ProjectName}-${Environment}-DBSubnetGroup"


  # ------------------------------------------------------------
  # Database security group
  # ------------------------------------------------------------

  DatabaseSecurityGroup:
    Type: AWS::EC2::SecurityGroup

    Properties:

      GroupDescription:
        !Sub "${ProjectName}-${Environment} RDS security group"

      VpcId: !Ref VpcId

      Tags:

        - Key: Name
          Value:
            !Sub "${ProjectName}-${Environment}-RDS-SG"


  # ------------------------------------------------------------
  # RDS MySQL
  # ------------------------------------------------------------

  Database:
    Type: AWS::RDS::DBInstance

    DeletionPolicy: Snapshot

    UpdateReplacePolicy: Snapshot

    Properties:

      DBInstanceIdentifier:
        !Sub "${ProjectName}-${Environment}-mysql"

      Engine: mysql

      EngineVersion: "8.0"

      DBInstanceClass: db.t3.micro

      AllocatedStorage: 20

      StorageType: gp3

      StorageEncrypted: true

      MasterUsername:
        !Ref DatabaseUsername

      MasterUserPassword:
        !Ref DatabasePassword

      DBName: hybridlab

      Port: 3306

      MultiAZ: false

      PubliclyAccessible: false

      BackupRetentionPeriod: 1

      DeleteAutomatedBackups: true

      DBSubnetGroupName:
        !Ref DatabaseSubnetGroup

      VPCSecurityGroups:

        - !Ref DatabaseSecurityGroup

      Tags:

        - Key: Project
          Value: !Ref ProjectName

        - Key: Environment
          Value: !Ref Environment


Outputs:

  DatabaseEndpoint:
    Description: RDS database endpoint
    Value: !GetAtt Database.Endpoint.Address


  DatabasePort:
    Description: RDS database port
    Value: !GetAtt Database.Endpoint.Port


  DatabaseSecurityGroupId:
    Description: RDS security group ID
    Value: !Ref DatabaseSecurityGroup
```

> **Later improvement:** Move the RDS password into AWS Secrets Manager instead of passing it directly as a CloudFormation parameter — a good security exercise once the basics work.

### nested/cloudfront.yaml

Path: `infrastructure/cloudformation/nested/cloudfront.yaml`

Connects CloudFront to the application S3 bucket using Origin Access Control (OAC), with a bucket policy that only allows the specific distribution to read.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  CloudFront CDN layer for the Hybrid IaC Lab.

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

  ApplicationBucketName:
    Type: String


Resources:

  # ------------------------------------------------------------
  # CloudFront Origin Access Control
  # ------------------------------------------------------------

  OriginAccessControl:
    Type: AWS::CloudFront::OriginAccessControl

    Properties:

      OriginAccessControlConfig:

        Name:
          !Sub "${ProjectName}-${Environment}-OAC"

        Description:
          !Sub "OAC for ${ProjectName}-${Environment}"

        OriginAccessControlOriginType: s3

        SigningBehavior: always

        SigningProtocol: sigv4


  # ------------------------------------------------------------
  # CloudFront distribution
  # ------------------------------------------------------------

  Distribution:
    Type: AWS::CloudFront::Distribution

    Properties:

      DistributionConfig:

        Enabled: true

        Comment:
          !Sub "${ProjectName}-${Environment} CloudFront distribution"

        DefaultRootObject: index.html

        PriceClass: PriceClass_100

        Origins:

          - Id: S3Origin

            DomainName:
              !Sub "${ApplicationBucketName}.s3.${AWS::Region}.amazonaws.com"

            OriginAccessControlId:
              !Ref OriginAccessControl

            S3OriginConfig: {}


        DefaultCacheBehavior:

          TargetOriginId: S3Origin

          ViewerProtocolPolicy: redirect-to-https

          AllowedMethods:

            - GET
            - HEAD

          CachedMethods:

            - GET
            - HEAD

          ForwardedValues:

            QueryString: false

            Cookies:
              Forward: none


        ViewerCertificate:

          CloudFrontDefaultCertificate: true


  # ------------------------------------------------------------
  # S3 bucket policy
  # ------------------------------------------------------------

  BucketPolicy:
    Type: AWS::S3::BucketPolicy

    Properties:

      Bucket: !Ref ApplicationBucketName

      PolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Sid: AllowCloudFrontRead

            Effect: Allow

            Principal:
              Service: cloudfront.amazonaws.com

            Action:
              - s3:GetObject

            Resource:
              !Sub "arn:${AWS::Partition}:s3:::${ApplicationBucketName}/*"

            Condition:

              StringEquals:

                AWS:SourceArn:
                  !Sub >
                    arn:${AWS::Partition}:cloudfront::
                    ${AWS::AccountId}:distribution/${Distribution}


Outputs:

  DistributionId:
    Description: CloudFront distribution ID
    Value: !Ref Distribution


  CloudFrontDomainName:
    Description: CloudFront domain name
    Value: !GetAtt Distribution.DomainName
```

This gives:

```text
User
  |
  v
CloudFront
  |
  v
Private S3 bucket
```

### nested/ecs.yaml

Path: `infrastructure/cloudformation/nested/ecs.yaml`

Creates an ECS cluster running a Fargate service — cluster, security group, task execution role, task definition, log group, and service.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  ECS Fargate container platform for the Hybrid IaC Lab.

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

  VpcId:
    Type: AWS::EC2::VPC::Id

  PublicSubnet1Id:
    Type: AWS::EC2::Subnet::Id

  PublicSubnet2Id:
    Type: AWS::EC2::Subnet::Id

  EcrImageUri:
    Type: String

    Description: >
      Full URI of the Docker image stored in Amazon ECR.


Resources:

  # ------------------------------------------------------------
  # ECS cluster
  # ------------------------------------------------------------

  ECSCluster:
    Type: AWS::ECS::Cluster

    Properties:

      ClusterName:
        !Sub "${ProjectName}-${Environment}-ECSCluster"

      ClusterSettings:

        - Name: containerInsights
          Value: enabled


  # ------------------------------------------------------------
  # Security group
  # ------------------------------------------------------------

  ECSSecurityGroup:
    Type: AWS::EC2::SecurityGroup

    Properties:

      GroupDescription:
        !Sub "${ProjectName}-${Environment} ECS security group"

      VpcId: !Ref VpcId

      SecurityGroupIngress:

        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0


  # ------------------------------------------------------------
  # ECS task execution role
  # ------------------------------------------------------------

  ECSTaskExecutionRole:
    Type: AWS::IAM::Role

    Properties:

      RoleName:
        !Sub "${ProjectName}-${Environment}-ECSTaskExecutionRole"

      AssumeRolePolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Effect: Allow

            Principal:

              Service:
                - ecs-tasks.amazonaws.com

            Action:
              - sts:AssumeRole


      ManagedPolicyArns:

        - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy


  # ------------------------------------------------------------
  # Task definition
  # ------------------------------------------------------------

  TaskDefinition:
    Type: AWS::ECS::TaskDefinition

    Properties:

      Family:
        !Sub "${ProjectName}-${Environment}-Task"

      NetworkMode: awsvpc

      RequiresCompatibilities:

        - FARGATE

      Cpu: "256"

      Memory: "512"

      ExecutionRoleArn:
        !GetAtt ECSTaskExecutionRole.Arn

      ContainerDefinitions:

        - Name: application

          Image: !Ref EcrImageUri

          Essential: true

          PortMappings:

            - ContainerPort: 80

              Protocol: tcp

          LogConfiguration:

            LogDriver: awslogs

            Options:

              awslogs-group:
                !Ref LogGroup

              awslogs-region:
                !Ref AWS::Region

              awslogs-stream-prefix: ecs


  # ------------------------------------------------------------
  # CloudWatch log group
  # ------------------------------------------------------------

  LogGroup:
    Type: AWS::Logs::LogGroup

    Properties:

      LogGroupName:
        !Sub "/ecs/${ProjectName}-${Environment}"

      RetentionInDays: 7


  # ------------------------------------------------------------
  # ECS service
  # ------------------------------------------------------------

  ECSService:
    Type: AWS::ECS::Service

    DependsOn:
      - ECSCluster

    Properties:

      ServiceName:
        !Sub "${ProjectName}-${Environment}-Service"

      Cluster:
        !Ref ECSCluster

      LaunchType: FARGATE

      DesiredCount: 1

      TaskDefinition:
        !Ref TaskDefinition

      NetworkConfiguration:

        AwsvpcConfiguration:

          AssignPublicIp: ENABLED

          Subnets:

            - !Ref PublicSubnet1Id
            - !Ref PublicSubnet2Id

          SecurityGroups:

            - !Ref ECSSecurityGroup


Outputs:

  ECSClusterName:
    Description: ECS cluster name
    Value: !Ref ECSCluster


  ECSServiceName:
    Description: ECS service name
    Value: !GetAtt ECSService.Name


  TaskDefinitionArn:
    Description: ECS task definition ARN
    Value: !Ref TaskDefinition
```

This version deliberately keeps ECS simple. Later you can add an ALB in front:

```text
ALB
 |
ECS Service
 |
Fargate Tasks
```

### nested/eks.yaml

Path: `infrastructure/cloudformation/nested/eks.yaml`

Creates an EKS cluster (in private subnets) plus a managed node group, with dedicated cluster and node IAM roles.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  Amazon EKS Kubernetes cluster for the Hybrid IaC Lab.

Parameters:

  ProjectName:
    Type: String

  Environment:
    Type: String

  VpcId:
    Type: AWS::EC2::VPC::Id

  PrivateSubnet1Id:
    Type: AWS::EC2::Subnet::Id

  PrivateSubnet2Id:
    Type: AWS::EC2::Subnet::Id


Resources:

  # ------------------------------------------------------------
  # EKS cluster IAM role
  # ------------------------------------------------------------

  EKSClusterRole:
    Type: AWS::IAM::Role

    Properties:

      RoleName:
        !Sub "${ProjectName}-${Environment}-EKSClusterRole"

      AssumeRolePolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Effect: Allow

            Principal:

              Service:
                - eks.amazonaws.com

            Action:
              - sts:AssumeRole


      ManagedPolicyArns:

        - arn:aws:iam::aws:policy/AmazonEKSClusterPolicy


  # ------------------------------------------------------------
  # EKS node IAM role
  # ------------------------------------------------------------

  EKSNodeRole:
    Type: AWS::IAM::Role

    Properties:

      RoleName:
        !Sub "${ProjectName}-${Environment}-EKSNodeRole"

      AssumeRolePolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Effect: Allow

            Principal:

              Service:
                - ec2.amazonaws.com

            Action:
              - sts:AssumeRole


      ManagedPolicyArns:

        - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

        - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly

        - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy


  # ------------------------------------------------------------
  # EKS cluster
  # ------------------------------------------------------------

  EKSCluster:
    Type: AWS::EKS::Cluster

    Properties:

      Name:
        !Sub "${ProjectName}-${Environment}-EKS"

      Version: "1.33"

      RoleArn:
        !GetAtt EKSClusterRole.Arn

      ResourcesVpcConfig:

        VpcId:
          !Ref VpcId

        SubnetIds:

          - !Ref PrivateSubnet1Id
          - !Ref PrivateSubnet2Id

        EndpointPublicAccess: true

        EndpointPrivateAccess: true


      Tags:

        - Key: Project
          Value: !Ref ProjectName

        - Key: Environment
          Value: !Ref Environment


  # ------------------------------------------------------------
  # Managed node group
  # ------------------------------------------------------------

  EKSNodeGroup:
    Type: AWS::EKS::Nodegroup

    DependsOn:
      - EKSCluster

    Properties:

      ClusterName:
        !Ref EKSCluster

      NodegroupName:
        !Sub "${ProjectName}-${Environment}-NodeGroup"

      NodeRole:
        !GetAtt EKSNodeRole.Arn

      Subnets:

        - !Ref PrivateSubnet1Id
        - !Ref PrivateSubnet2Id

      InstanceTypes:

        - t3.medium

      AmiType: AL2023_x86_64_STANDARD

      CapacityType: ON_DEMAND

      ScalingConfig:

        MinSize: 1

        DesiredSize: 1

        MaxSize: 2


Outputs:

  ClusterName:
    Description: EKS cluster name
    Value: !Ref EKSCluster


  ClusterEndpoint:
    Description: EKS Kubernetes API endpoint
    Value: !GetAtt EKSCluster.Endpoint
```

> **Important — cost control:** EKS is substantially more expensive/heavier than the other services in this lab. Keep `desired = 1`, `min = 1`, `max = 2`, and delete the stack when you're finished practicing.

---

## iam/cloudformation-execution-role.yaml

Path: `infrastructure/cloudformation/iam/cloudformation-execution-role.yaml`

A standalone CloudFormation-based version of the execution role, useful as an IAM learning template.

> **Architectural note:** In this lab's actual design, the CloudFormation execution role is created and owned by **Terraform** (see the Terraform README, `iam.tf`). This template is included as a reference/learning artifact only — don't deploy both Terraform and this template trying to independently own the same role.

```yaml
AWSTemplateFormatVersion: "2010-09-09"

Description: >
  CloudFormation execution role for the Hybrid IaC Lab.

Parameters:

  ProjectName:
    Type: String
    Default: HybridIaCLab

  Environment:
    Type: String
    Default: dev


Resources:

  CloudFormationExecutionRole:
    Type: AWS::IAM::Role

    Properties:

      RoleName:
        !Sub "${ProjectName}-${Environment}-CFNExecutionRole"

      AssumeRolePolicyDocument:

        Version: "2012-10-17"

        Statement:

          - Effect: Allow

            Principal:

              Service:
                - cloudformation.amazonaws.com

            Action:
              - sts:AssumeRole


      Policies:

        - PolicyName: HybridIaCLabProvisioning

          PolicyDocument:

            Version: "2012-10-17"

            Statement:

              # ------------------------------------------------
              # Networking
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - ec2:Describe*
                  - ec2:CreateVpc
                  - ec2:DeleteVpc
                  - ec2:CreateSubnet
                  - ec2:DeleteSubnet
                  - ec2:CreateRouteTable
                  - ec2:DeleteRouteTable
                  - ec2:CreateRoute
                  - ec2:DeleteRoute
                  - ec2:CreateInternetGateway
                  - ec2:DeleteInternetGateway
                  - ec2:AttachInternetGateway
                  - ec2:DetachInternetGateway
                  - ec2:AssociateRouteTable
                  - ec2:DisassociateRouteTable
                  - ec2:CreateSecurityGroup
                  - ec2:DeleteSecurityGroup
                  - ec2:AuthorizeSecurityGroupIngress
                  - ec2:AuthorizeSecurityGroupEgress
                  - ec2:RevokeSecurityGroupIngress
                  - ec2:RevokeSecurityGroupEgress
                  - ec2:RunInstances
                  - ec2:TerminateInstances
                  - ec2:CreateTags

                Resource: "*"


              # ------------------------------------------------
              # S3
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - s3:CreateBucket
                  - s3:DeleteBucket
                  - s3:GetBucket*
                  - s3:PutBucket*
                  - s3:DeleteBucketPolicy
                  - s3:PutBucketPolicy
                  - s3:GetObject
                  - s3:PutObject
                  - s3:DeleteObject

                Resource: "*"


              # ------------------------------------------------
              # Lambda
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - lambda:CreateFunction
                  - lambda:DeleteFunction
                  - lambda:GetFunction
                  - lambda:UpdateFunctionCode
                  - lambda:UpdateFunctionConfiguration
                  - lambda:AddPermission
                  - lambda:RemovePermission
                  - lambda:TagResource

                Resource: "*"


              # ------------------------------------------------
              # API Gateway
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - apigateway:*

                Resource: "*"


              # ------------------------------------------------
              # RDS
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - rds:CreateDBInstance
                  - rds:DeleteDBInstance
                  - rds:ModifyDBInstance
                  - rds:DescribeDBInstances
                  - rds:CreateDBSubnetGroup
                  - rds:DeleteDBSubnetGroup
                  - rds:DescribeDBSubnetGroups
                  - rds:AddTagsToResource
                  - rds:ListTagsForResource

                Resource: "*"


              # ------------------------------------------------
              # DynamoDB
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - dynamodb:CreateTable
                  - dynamodb:DeleteTable
                  - dynamodb:DescribeTable
                  - dynamodb:UpdateTable
                  - dynamodb:TagResource
                  - dynamodb:UntagResource

                Resource: "*"


              # ------------------------------------------------
              # ECR
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - ecr:CreateRepository
                  - ecr:DeleteRepository
                  - ecr:DescribeRepositories
                  - ecr:PutImage
                  - ecr:BatchGetImage
                  - ecr:GetRepositoryPolicy
                  - ecr:SetRepositoryPolicy
                  - ecr:DeleteRepositoryPolicy
                  - ecr:TagResource

                Resource: "*"


              # ------------------------------------------------
              # ECS
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - ecs:CreateCluster
                  - ecs:DeleteCluster
                  - ecs:DescribeClusters
                  - ecs:RegisterTaskDefinition
                  - ecs:DeregisterTaskDefinition
                  - ecs:CreateService
                  - ecs:DeleteService
                  - ecs:UpdateService
                  - ecs:DescribeServices
                  - ecs:TagResource

                Resource: "*"


              # ------------------------------------------------
              # EKS
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - eks:CreateCluster
                  - eks:DeleteCluster
                  - eks:DescribeCluster
                  - eks:CreateNodegroup
                  - eks:DeleteNodegroup
                  - eks:DescribeNodegroup
                  - eks:TagResource

                Resource: "*"


              # ------------------------------------------------
              # IAM PassRole
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - iam:PassRole

                Resource: "*"


              # ------------------------------------------------
              # CloudWatch Logs
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - logs:CreateLogGroup
                  - logs:DeleteLogGroup
                  - logs:DescribeLogGroups
                  - logs:PutRetentionPolicy
                  - logs:DeleteRetentionPolicy

                Resource: "*"


              # ------------------------------------------------
              # CloudFront
              # ------------------------------------------------

              - Effect: Allow

                Action:

                  - cloudfront:CreateDistribution
                  - cloudfront:UpdateDistribution
                  - cloudfront:DeleteDistribution
                  - cloudfront:GetDistribution
                  - cloudfront:CreateOriginAccessControl
                  - cloudfront:DeleteOriginAccessControl
                  - cloudfront:GetOriginAccessControl
                  - cloudfront:UpdateOriginAccessControl
                  - cloudfront:TagResource

                Resource: "*"


Outputs:

  ExecutionRoleArn:
    Description: CloudFormation execution role ARN

    Value:
      !GetAtt CloudFormationExecutionRole.Arn
```

Again: for the actual lab architecture, let **Terraform** own this role. Use this file only as a reference for understanding scoped, service-by-service CloudFormation IAM permissions.

---

## Summary of the full nested-stack structure

```text
infrastructure/
└── cloudformation/
    │
    ├── main.yaml                            ← Root stack (orchestrator)
    │
    ├── nested/
    │   ├── vpc.yaml           ✅ Phase 1     VPC, subnets, IGW, routes
    │   ├── s3.yaml            ✅ Phase 1     Application S3 bucket
    │   ├── dynamodb.yaml      ✅ Phase 1     Orders table
    │   ├── ecr.yaml           ✅ Phase 1     Docker image repository
    │   ├── ec2.yaml           ✅ Phase 2     Web server EC2 instance
    │   ├── lambda.yaml        ✅ Phase 2     Serverless application function
    │   ├── api-gateway.yaml   ✅ Phase 2     REST API in front of Lambda
    │   ├── rds.yaml           ✅ Phase 2     Private MySQL database
    │   ├── cloudfront.yaml    ✅ Phase 2     CDN in front of S3
    │   ├── ecs.yaml           ✅ Phase 2     Fargate container platform
    │   └── eks.yaml           ✅ Phase 2     Kubernetes cluster + node group
    │
    └── iam/
        └── cloudformation-execution-role.yaml   (reference only — Terraform owns this role)
```

This gives the lab a complete, modular CloudFormation layer that Terraform provisions the S3 template bucket and IAM execution role for, and that in turn stands up every AWS service the hybrid lab is meant to exercise.
