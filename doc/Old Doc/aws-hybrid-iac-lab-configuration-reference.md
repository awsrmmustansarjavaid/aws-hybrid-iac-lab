# AWS Hybrid IaC Lab — Configuration Reference

This document consolidates the current CloudFormation templates and GitHub Actions workflows for the **Hybrid IaC AWS DevOps Lab**.

---

## Table of Contents

1. [CloudFormation Templates](#1-cloudformation-templates)
   - 1.1 [ECR Repository — `infrastructure/cloudformation/nested/ecr.yaml`](#11-ecr-repository--infrastructurecloudformationnestedecryaml)
   - 1.2 [ECS Fargate Platform — `infrastructure/cloudformation/ecs.yaml`](#12-ecs-fargate-platform--infrastructurecloudformationecsyaml)
2. [GitHub Actions Workflows](#2-github-actions-workflows)
   - 2.1 [Main Deployment — `.github/workflows/main-deploy.yaml`](#21-main-deployment--githubworkflowsmain-deployyaml)
   - 2.2 [Terraform Infrastructure — `.github/workflows/terraform.yml`](#22-terraform-infrastructure--githubworkflowsterraformyml)
   - 2.3 [Docker Build and ECR — `.github/workflows/docker.yml`](#23-docker-build-and-ecr--githubworkflowsdockeryml)
   - 2.4 [Kubernetes Deployment — `.github/workflows/kubernetes.yml`](#24-kubernetes-deployment--githubworkflowskubernetesyml)

---

## 1. CloudFormation Templates

### 1.1 ECR Repository — `infrastructure/cloudformation/nested/ecr.yaml`

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

---

### 1.2 ECS Fargate Platform — `infrastructure/cloudformation/ecs.yaml`

```yaml
# ============================================================

# AWS HYBRID IaC LAB

# ECS FARGATE CONTAINER PLATFORM

# ============================================================

#

# File:

# infrastructure/cloudformation/ecs.yaml

#

# Purpose:

# Creates an Amazon ECS Fargate platform that runs a Docker

# container stored in Amazon Elastic Container Registry (ECR).

#

# Resources created:

#

# 1. ECS Cluster

# 2. ECS Security Group

# 3. ECS Task Execution IAM Role

# 4. CloudWatch Log Group

# 5. ECS Fargate Task Definition

# 6. ECS Fargate Service

#

#

# Architecture:

#

# Internet

# |

# | HTTP :80

# v

# +---------------+

# | ECS Fargate   |

# |    Service    |

# +---------------+

# |

# v

# +---------------+

# | Fargate Task  |

# |               |

# | Docker        |

# | Container     |

# +---------------+

# |

# +-----------+-----------+

# |                       |

# v                       v

# ECR                  CloudWatch

# Docker Image               Logs

#

#

# ============================================================

# IMPORTANT ARCHITECTURE NOTE

# ============================================================

#

# This is a basic ECS Fargate lab.

#

# The ECS task is currently assigned a public IP:

#

# AssignPublicIp: ENABLED

#

# and port 80 is open to the Internet.

#

# This makes the lab easy to test.

#

# A production architecture would normally use:

#

# Internet

# |

# v

# Application Load Balancer

# |

# v

# Private Fargate Tasks

#

# with:

#

# AssignPublicIp: DISABLED

#

#

# ============================================================

# ECR IMAGE REQUIREMENT

# ============================================================

#

# Before deploying this stack, a Docker image must already

# exist in Amazon ECR.

#

# Example:

#

# 123456789012.dkr.ecr.us-east-1.amazonaws.com/

# hybrid-iac-lab:latest

#

# The complete URI is passed using:

#

# EcrImageUri

#

#

# ============================================================

# AWS CLI COMMANDS

# ============================================================

#

# These commands assume you are running them from:

#

# infrastructure/cloudformation/

#

#

# ============================================================

# 1. VERIFY AWS CLI

# ============================================================

#

# aws --version

#

#

# ============================================================

# 2. VERIFY AWS ACCOUNT

# ============================================================

#

# aws sts get-caller-identity

#

#

# ============================================================

# 3. CHECK AWS REGION

# ============================================================

#

# aws configure get region

#

# Example:

#

# us-east-1

#

#

# ============================================================

# 4. FIND VPC

# ============================================================

#

# aws ec2 describe-vpcs \

# --query "Vpcs[].{VpcId:VpcId,Cidr:CidrBlock}" \

# --output table \

# --region us-east-1

#

#

# ============================================================

# 5. FIND PUBLIC SUBNETS

# ============================================================

#

# aws ec2 describe-subnets \

# --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,AZ:AvailabilityZone,Cidr:CidrBlock}" \

# --output table \

# --region us-east-1

#

#

# Select two suitable subnets.

#

#

# ============================================================

# 6. CHECK ECR REPOSITORIES

# ============================================================

#

# aws ecr describe-repositories \

# --region us-east-1

#

#

# ============================================================

# 7. LOGIN TO ECR

# ============================================================

#

# aws ecr get-login-password \

# --region us-east-1 |

# docker login \

# --username AWS \

# --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

#

#

# ============================================================

# 8. BUILD DOCKER IMAGE

# ============================================================

#

# From the project root:

#

# docker build \

# -t hybrid-iac-lab .

#

#

# ============================================================

# 9. TAG DOCKER IMAGE

# ============================================================

#

# docker tag \

# hybrid-iac-lab:latest \

# YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hybrid-iac-lab:latest

#

#

# ============================================================

# 10. PUSH IMAGE TO ECR

# ============================================================

#

# docker push \

# YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hybrid-iac-lab:latest

#

#

# ============================================================

# 11. VERIFY IMAGE

# ============================================================

#

# aws ecr describe-images \

# --repository-name hybrid-iac-lab \

# --region us-east-1

#

#

# ============================================================

# 12. VALIDATE CLOUDFORMATION TEMPLATE

# ============================================================

#

# aws cloudformation validate-template \

# --template-body file://ecs.yaml \

# --region us-east-1

#

#

# ============================================================

# 13. DEPLOY ECS STACK

# ============================================================

#

# Example:

#

# aws cloudformation deploy \

# --template-file ecs.yaml \

# --stack-name HybridIaCLab-ECS \

# --parameter-overrides \

# ProjectName=HybridIaCLab \

# Environment=dev \

# VpcId=vpc-xxxxxxxxxxxxxxxxx \

# PublicSubnet1Id=subnet-xxxxxxxxxxxxxxxxx \

# PublicSubnet2Id=subnet-yyyyyyyyyyyyyyyyy \

# EcrImageUri=YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hybrid-iac-lab:latest \

# --capabilities CAPABILITY_NAMED_IAM \

# --region us-east-1

#

#

# IMPORTANT:

#

# Replace the VPC, subnet and ECR image values with your

# actual resources.

#

#

# ============================================================

# 14. CHECK STACK

# ============================================================

#

# aws cloudformation describe-stacks \

# --stack-name HybridIaCLab-ECS \

# --region us-east-1

#

#

# ============================================================

# 15. WATCH CLOUDFORMATION EVENTS

# ============================================================

#

# aws cloudformation describe-stack-events \

# --stack-name HybridIaCLab-ECS \

# --region us-east-1

#

#

# ============================================================

# 16. GET STACK OUTPUTS

# ============================================================

#

# aws cloudformation describe-stacks \

# --stack-name HybridIaCLab-ECS \

# --query "Stacks[0].Outputs" \

# --output table \

# --region us-east-1

#

#

# ============================================================

# ECS CLI COMMANDS

# ============================================================

#

# ============================================================

# 17. LIST ECS CLUSTERS

# ============================================================

#

# aws ecs list-clusters \

# --region us-east-1

#

#

# ============================================================

# 18. DESCRIBE ECS CLUSTER

# ============================================================

#

# aws ecs describe-clusters \

# --clusters HybridIaCLab-dev-ECSCluster \

# --region us-east-1

#

#

# ============================================================

# 19. LIST ECS SERVICES

# ============================================================

#

# aws ecs list-services \

# --cluster HybridIaCLab-dev-ECSCluster \

# --region us-east-1

#

#

# ============================================================

# 20. DESCRIBE ECS SERVICE

# ============================================================

#

# aws ecs describe-services \

# --cluster HybridIaCLab-dev-ECSCluster \

# --services HybridIaCLab-dev-Service \

# --region us-east-1

#

#

# ============================================================

# 21. LIST RUNNING TASKS

# ============================================================

#

# aws ecs list-tasks \

# --cluster HybridIaCLab-dev-ECSCluster \

# --service-name HybridIaCLab-dev-Service \

# --desired-status RUNNING \

# --region us-east-1

#

#

# ============================================================

# 22. DESCRIBE ECS TASK

# ============================================================

#

# First obtain the task ARN:

#

# aws ecs list-tasks \

# --cluster HybridIaCLab-dev-ECSCluster \

# --service-name HybridIaCLab-dev-Service \

# --region us-east-1

#

#

# Then:

#

# aws ecs describe-tasks \

# --cluster HybridIaCLab-dev-ECSCluster \

# --tasks YOUR_TASK_ARN \

# --region us-east-1

#

#

# ============================================================

# 23. GET TASK PUBLIC IP

# ============================================================

#

# Because AssignPublicIp is ENABLED, the task receives a

# public IP.

#

# Get the task network interface:

#

# aws ecs describe-tasks \

# --cluster HybridIaCLab-dev-ECSCluster \

# --tasks YOUR_TASK_ARN \

# --query "tasks[0].attachments[0].details" \

# --output table \

# --region us-east-1

#

#

# Find:

#

# networkInterfaceId

#

# Then:

#

# aws ec2 describe-network-interfaces \

# --network-interface-ids YOUR_NETWORK_INTERFACE_ID \

# --query "NetworkInterfaces[0].Association.PublicIp" \

# --output text \

# --region us-east-1

#

#

# ============================================================

# 24. TEST CONTAINER

# ============================================================

#

# If the container listens on port 80:

#

# curl http://YOUR_TASK_PUBLIC_IP

#

#

# Or open:

#

# http://YOUR_TASK_PUBLIC_IP

#

#

# ============================================================

# CLOUDWATCH LOGGING

# ============================================================

#

# ECS sends container logs to:

#

# /ecs/HybridIaCLab-dev

#

#

# ============================================================

# 25. CHECK LOG GROUP

# ============================================================

#

# aws logs describe-log-groups \

# --log-group-name-prefix /ecs/HybridIaCLab-dev \

# --region us-east-1

#

#

# ============================================================

# 26. LIST LOG STREAMS

# ============================================================

#

# aws logs describe-log-streams \

# --log-group-name /ecs/HybridIaCLab-dev \

# --order-by LastEventTime \

# --descending \

# --region us-east-1

#

#

# ============================================================

# 27. READ CONTAINER LOGS

# ============================================================

#

# aws logs get-log-events \

# --log-group-name /ecs/HybridIaCLab-dev \

# --log-stream-name YOUR_LOG_STREAM \

# --region us-east-1

#

#

# ============================================================

# ECS TROUBLESHOOTING

# ============================================================

#

# If the ECS service cannot start a task:

#

# aws ecs describe-services \

# --cluster HybridIaCLab-dev-ECSCluster \

# --services HybridIaCLab-dev-Service \

# --query "services[0].events[0:10]" \

# --output table \

# --region us-east-1

#

#

# Check task stopped reason:

#

# aws ecs describe-tasks \

# --cluster HybridIaCLab-dev-ECSCluster \

# --tasks YOUR_TASK_ARN \

# --query "tasks[0].{LastStatus:lastStatus,StopCode:stopCode,StoppedReason:stoppedReason}" \

# --output table \

# --region us-east-1

#

#

# ============================================================

# 28. FORCE NEW ECS DEPLOYMENT

# ============================================================

#

# Useful after pushing a new Docker image with the same tag.

#

# aws ecs update-service \

# --cluster HybridIaCLab-dev-ECSCluster \

# --service HybridIaCLab-dev-Service \

# --force-new-deployment \

# --region us-east-1

#

#

# ============================================================

# 29. CHECK ECS SERVICE DESIRED/RUNNING COUNT

# ============================================================

#

# aws ecs describe-services \

# --cluster HybridIaCLab-dev-ECSCluster \

# --services HybridIaCLab-dev-Service \

# --query "services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}" \

# --output table \

# --region us-east-1

#

#

# Expected for this lab:

#

# Desired = 1

# Running = 1

# Pending = 0

#

#

# ============================================================

# CLEANUP

# ============================================================

#

# ============================================================

# 30. DELETE ECS CLOUDFORMATION STACK

# ============================================================

#

# aws cloudformation delete-stack \

# --stack-name HybridIaCLab-ECS \

# --region us-east-1

#

#

# ============================================================

# 31. CHECK STACK DELETION

# ============================================================

#

# aws cloudformation describe-stack-events \

# --stack-name HybridIaCLab-ECS \

# --region us-east-1

#

#

# ============================================================

# 32. OPTIONAL - DELETE ECR REPOSITORY

# ============================================================

#

# WARNING:

#

# This deletes the ECR repository and all images in it.

#

# aws ecr delete-repository \

# --repository-name hybrid-iac-lab \

# --force \

# --region us-east-1

#

#

# ============================================================

# CLOUDFORMATION TEMPLATE

# ============================================================

AWSTemplateFormatVersion: "2010-09-09"

Description: >
ECS Fargate container platform for the Hybrid IaC Lab.

# ============================================================

# PARAMETERS

# ============================================================

Parameters:

# ----------------------------------------------------------

# Project name

# ----------------------------------------------------------

ProjectName:
Type: String
Description: Project name

# ----------------------------------------------------------

# Environment

# ----------------------------------------------------------

Environment:
Type: String
Description: Deployment environment

# ----------------------------------------------------------

# VPC

# ----------------------------------------------------------

VpcId:
Type: AWS::EC2::VPC::Id
Description: VPC where ECS resources will run

# ----------------------------------------------------------

# PUBLIC SUBNET 1

# ----------------------------------------------------------

PublicSubnet1Id:
Type: AWS::EC2::Subnet::Id
Description: First public subnet for ECS Fargate

# ----------------------------------------------------------

# PUBLIC SUBNET 2

# ----------------------------------------------------------

PublicSubnet2Id:
Type: AWS::EC2::Subnet::Id
Description: Second public subnet for ECS Fargate

# ----------------------------------------------------------

# ECR IMAGE URI

# ----------------------------------------------------------

#

# Example:

#

# 123456789012.dkr.ecr.us-east-1.amazonaws.com/

# hybrid-iac-lab:latest

#

# ----------------------------------------------------------

EcrImageUri:
Type: String


Description: >
  Full URI of the Docker image stored in Amazon ECR.


# ============================================================

# RESOURCES

# ============================================================

Resources:

# ==========================================================

# ECS CLUSTER

# ==========================================================

#

# Logical container management environment.

#

# ==========================================================

ECSCluster:
Type: AWS::ECS::Cluster


Properties:


  # ------------------------------------------------------
  # Cluster name
  # ------------------------------------------------------

  ClusterName:
    !Sub "${ProjectName}-${Environment}-ECSCluster"


  # ------------------------------------------------------
  # CONTAINER INSIGHTS
  # ------------------------------------------------------
  #
  # Enables additional monitoring information for ECS.
  #
  # This is useful for learning CloudWatch + ECS
  # observability.
  #
  # ------------------------------------------------------

  ClusterSettings:

    - Name: containerInsights
      Value: enabled


# ==========================================================

# ECS SECURITY GROUP

# ==========================================================

#

# Controls network access to the Fargate task.

#

# ==========================================================

ECSSecurityGroup:
Type: AWS::EC2::SecurityGroup


Properties:


  # ------------------------------------------------------
  # Description
  # ------------------------------------------------------

  GroupDescription:
    !Sub "${ProjectName}-${Environment} ECS security group"


  # ------------------------------------------------------
  # VPC
  # ------------------------------------------------------

  VpcId: !Ref VpcId


  # ======================================================
  # INBOUND HTTP
  # ======================================================
  #
  # Allows Internet clients to reach the container on
  # TCP port 80.
  #
  # LAB ONLY:
  #
  # Production should normally place an Application Load
  # Balancer in front of private ECS tasks.
  #
  # ======================================================

  SecurityGroupIngress:

    - IpProtocol: tcp

      FromPort: 80

      ToPort: 80

      CidrIp: 0.0.0.0/0

      Description: HTTP access


  # ------------------------------------------------------
  # TAGS
  # ------------------------------------------------------

  Tags:

    - Key: Name

      Value:
        !Sub "${ProjectName}-${Environment}-ECS-SG"


# ==========================================================

# ECS TASK EXECUTION ROLE

# ==========================================================

#

# This IAM role is used by the ECS/Fargate infrastructure

# to perform actions required to start the task.

#

# For example:

#

# - Pull images from ECR

# - Send logs to CloudWatch

#

# ==========================================================

ECSTaskExecutionRole:
Type: AWS::IAM::Role


Properties:


  # ------------------------------------------------------
  # Role name
  # ------------------------------------------------------

  RoleName:
    !Sub "${ProjectName}-${Environment}-ECSTaskExecutionRole"


  # ======================================================
  # TRUST POLICY
  # ======================================================

  AssumeRolePolicyDocument:

    Version: "2012-10-17"

    Statement:

      - Effect: Allow

        Principal:

          Service:
            - ecs-tasks.amazonaws.com

        Action:
          - sts:AssumeRole


  # ======================================================
  # MANAGED POLICY
  # ======================================================
  #
  # Provides standard ECS task execution permissions.
  #
  # This includes permissions required to pull private
  # images from ECR and send container logs to CloudWatch.
  #
  # ======================================================

  ManagedPolicyArns:

    - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy


# ==========================================================

# CLOUDWATCH LOG GROUP

# ==========================================================

#

# Stores container logs.

#

# ==========================================================

LogGroup:
Type: AWS::Logs::LogGroup


Properties:


  # ------------------------------------------------------
  # Log group name
  # ------------------------------------------------------

  LogGroupName:
    !Sub "/ecs/${ProjectName}-${Environment}"


  # ------------------------------------------------------
  # LOG RETENTION
  # ------------------------------------------------------
  #
  # Logs are automatically retained for 7 days.
  #
  # This helps control lab costs and storage.
  #
  # ------------------------------------------------------

  RetentionInDays: 7


# ==========================================================

# ECS TASK DEFINITION

# ==========================================================

#

# Defines how the Docker container should run.

#

# ==========================================================

TaskDefinition:
Type: AWS::ECS::TaskDefinition


Properties:


  # ------------------------------------------------------
  # Task family
  # ------------------------------------------------------

  Family:
    !Sub "${ProjectName}-${Environment}-Task"


  # ------------------------------------------------------
  # NETWORK MODE
  # ------------------------------------------------------
  #
  # Fargate requires awsvpc networking.
  #
  NetworkMode: awsvpc


  # ------------------------------------------------------
  # FARGATE COMPATIBILITY
  # ------------------------------------------------------

  RequiresCompatibilities:

    - FARGATE


  # ------------------------------------------------------
  # CPU
  # ------------------------------------------------------
  #
  # 256 CPU units.
  #
  Cpu: "256"


  # ------------------------------------------------------
  # MEMORY
  # ------------------------------------------------------
  #
  # 512 MiB.
  #
  Memory: "512"


  # ------------------------------------------------------
  # EXECUTION ROLE
  # ------------------------------------------------------

  ExecutionRoleArn:
    !GetAtt ECSTaskExecutionRole.Arn


  # ======================================================
  # CONTAINER DEFINITION
  # ======================================================

  ContainerDefinitions:

    - Name: application


      # --------------------------------------------------
      # DOCKER IMAGE
      # --------------------------------------------------
      #
      # Pulled from Amazon ECR.
      #
      Image:
        !Ref EcrImageUri


      # --------------------------------------------------
      # ESSENTIAL CONTAINER
      # --------------------------------------------------
      #
      # If this container stops, ECS considers the task
      # unhealthy/stopped.
      #
      Essential: true


      # --------------------------------------------------
      # PORT MAPPING
      # --------------------------------------------------
      #
      # Container listens on:
      #
      #   TCP 80
      #
      PortMappings:

        - ContainerPort: 80

          Protocol: tcp


      # ==================================================
      # CLOUDWATCH LOGGING
      # ==================================================

      LogConfiguration:

        LogDriver: awslogs

        Options:


          # ------------------------------------------------
          # CloudWatch Log Group
          # ------------------------------------------------

          awslogs-group:
            !Ref LogGroup


          # ------------------------------------------------
          # AWS REGION
          # ------------------------------------------------

          awslogs-region:
            !Ref AWS::Region


          # ------------------------------------------------
          # LOG STREAM PREFIX
          # ------------------------------------------------

          awslogs-stream-prefix: ecs


# ==========================================================

# ECS SERVICE

# ==========================================================

#

# Maintains the desired number of running Fargate tasks.

#

# DesiredCount = 1

#

# ECS automatically attempts to replace a task if it stops.

#

# ==========================================================

ECSService:
Type: AWS::ECS::Service


# --------------------------------------------------------
# Ensure the ECS cluster exists before creating the service.
# --------------------------------------------------------

DependsOn:
  - ECSCluster


Properties:


  # ------------------------------------------------------
  # SERVICE NAME
  # ------------------------------------------------------

  ServiceName:
    !Sub "${ProjectName}-${Environment}-Service"


  # ------------------------------------------------------
  # ECS CLUSTER
  # ------------------------------------------------------

  Cluster:
    !Ref ECSCluster


  # ------------------------------------------------------
  # LAUNCH TYPE
  # ------------------------------------------------------
  #
  # AWS manages the underlying servers.
  #
  LaunchType: FARGATE


  # ------------------------------------------------------
  # DESIRED TASK COUNT
  # ------------------------------------------------------
  #
  # One task for this learning lab.
  #
  DesiredCount: 1


  # ------------------------------------------------------
  # TASK DEFINITION
  # ------------------------------------------------------

  TaskDefinition:
    !Ref TaskDefinition


  # ======================================================
  # NETWORK CONFIGURATION
  # ======================================================

  NetworkConfiguration:

    AwsvpcConfiguration:


      # --------------------------------------------------
      # PUBLIC IP
      # --------------------------------------------------
      #
      # ENABLED makes the task directly reachable through
      # its public IP when subnet routing/security rules
      # permit it.
      #
      # LAB configuration.
      #
      AssignPublicIp: ENABLED


      # --------------------------------------------------
      # SUBNETS
      # --------------------------------------------------

      Subnets:

        - !Ref PublicSubnet1Id
        - !Ref PublicSubnet2Id


      # --------------------------------------------------
      # SECURITY GROUP
      # --------------------------------------------------

      SecurityGroups:

        - !Ref ECSSecurityGroup


# ============================================================

# OUTPUTS

# ============================================================

Outputs:

# ==========================================================

# ECS CLUSTER NAME

# ==========================================================

ECSClusterName:


Description: ECS cluster name

Value:
  !Ref ECSCluster


# ==========================================================

# ECS SERVICE NAME

# ==========================================================

ECSServiceName:


Description: ECS service name

Value:
  !GetAtt ECSService.Name


# ==========================================================

# TASK DEFINITION ARN

# ==========================================================

TaskDefinitionArn:


Description: ECS task definition ARN

Value:
  !Ref TaskDefinition
```

---

## 2. GitHub Actions Workflows

### 2.1 Main Deployment — `.github/workflows/main-deploy.yaml`

```yaml
# ==========================================================
# WORKFLOW NAME
# ==========================================================
#
# This is the main GitHub Actions workflow for the project.
#
# It coordinates the complete deployment pipeline:
#
#   1. Terraform / CloudFormation
#   2. Docker / Amazon ECR
#   3. Kubernetes / Amazon EKS
#
# ==========================================================

name: Main Deployment


# ==========================================================
# GITHUB ACTIONS PERMISSIONS
# ==========================================================
#
# These permissions control what the GitHub Actions workflow
# is allowed to access.
#
# contents: read
#   Allows GitHub Actions to read the repository contents.
#
# id-token: write
#   Allows GitHub Actions to request an OIDC identity token.
#
#   This is required when GitHub Actions authenticates with
#   AWS using OIDC instead of storing long-term AWS access
#   keys inside GitHub Secrets.
#
# ==========================================================

permissions:
  contents: read
  id-token: write


# ==========================================================
# WORKFLOW TRIGGERS
# ==========================================================
#
# Defines when this workflow should start.
#
# ==========================================================

on:

  # --------------------------------------------------------
  # AUTOMATIC DEPLOYMENT
  # --------------------------------------------------------
  #
  # Run the workflow automatically whenever code is pushed
  # to the "main" branch.
  #
  # Example:
  #
  #   git add .
  #   git commit -m "Deploy application"
  #   git push origin main
  #
  # This push starts the workflow.
  #
  # --------------------------------------------------------

  push:
    branches:
      - main


  # --------------------------------------------------------
  # MANUAL DEPLOYMENT
  # --------------------------------------------------------
  #
  # Allows the workflow to be started manually from the
  # GitHub Actions interface.
  #
  # GitHub:
  #
  #   Actions
  #      ↓
  #   Main Deployment
  #      ↓
  #   Run workflow
  #
  # --------------------------------------------------------

  workflow_dispatch:


# ==========================================================
# JOBS
# ==========================================================
#
# The "jobs" section defines the individual deployment
# stages of the pipeline.
#
# This main workflow calls three reusable workflows:
#
#   terraform.yml
#   docker.yml
#   kubernetes.yml
#
# ==========================================================

jobs:


  # ========================================================
  # JOB 1 — TERRAFORM + CLOUDFORMATION
  # ========================================================
  #
  # This is the FIRST deployment stage.
  #
  # It calls:
  #
  #   .github/workflows/terraform.yml
  #
  # Terraform infrastructure must be created or updated
  # before the application/container deployment begins.
  #
  # --------------------------------------------------------
  # IMPORTANT:
  #
  # terraform.yml must be configured as a reusable workflow
  # using:
  #
  #   on:
  #     workflow_call:
  #
  # --------------------------------------------------------

  terraform:

    # ------------------------------------------------------
    # EXPLICIT GITHUB ACTIONS PERMISSIONS
    # ------------------------------------------------------
    #
    # These permissions are explicitly assigned to the
    # Terraform reusable workflow job.
    #
    # id-token: write
    #   Allows the Terraform workflow to request a GitHub
    #   OIDC token.
    #
    #   This is required when Terraform authenticates to AWS
    #   through GitHub Actions OIDC and an AWS IAM role.
    #
    # contents: read
    #   Allows the Terraform workflow to read repository
    #   files.
    #
    # These permissions reinforce the same permissions defined
    # at the workflow level above.
    #
    # ------------------------------------------------------

    permissions:
      id-token: write
      contents: read


    # ------------------------------------------------------
    # Call the Terraform reusable workflow.
    # ------------------------------------------------------

    uses: ./.github/workflows/terraform.yml


    # ------------------------------------------------------
    # Pass the repository's available GitHub Secrets to the
    # reusable Terraform workflow.
    #
    # This is useful when Terraform requires secrets such as
    # AWS-related configuration or other protected values.
    # ------------------------------------------------------

    secrets: inherit


  # ========================================================
  # JOB 2 — DOCKER + AMAZON ECR
  # ========================================================
  #
  # This is the SECOND deployment stage.
  #
  # It calls:
  #
  #   .github/workflows/docker.yml
  #
  # Docker should run ONLY after the Terraform job succeeds.
  #
  # The Docker workflow can:
  #
  #   1. Build the Docker image
  #   2. Authenticate with Amazon ECR
  #   3. Tag the Docker image
  #   4. Push the image to Amazon ECR
  #
  # ========================================================

  docker:

    # ------------------------------------------------------
    # DEPENDENCY
    # ------------------------------------------------------
    #
    # "needs" tells GitHub Actions that this job depends on
    # the Terraform job.
    #
    # Therefore:
    #
    #   Terraform SUCCESS
    #          ↓
    #       Docker
    #
    # If Terraform fails, Docker will not run.
    #
    # ------------------------------------------------------

    needs:
      - terraform


    # ------------------------------------------------------
    # Call the Docker reusable workflow.
    # ------------------------------------------------------

    uses: ./.github/workflows/docker.yml


    # ------------------------------------------------------
    # Pass GitHub Secrets to the Docker reusable workflow.
    # ------------------------------------------------------

    secrets: inherit


  # ========================================================
  # JOB 3 — KUBERNETES + AMAZON EKS
  # ========================================================
  #
  # This is the THIRD and FINAL deployment stage.
  #
  # It calls:
  #
  #   .github/workflows/kubernetes.yml
  #
  # Kubernetes/EKS deployment starts only after BOTH:
  #
  #   1. Terraform
  #   2. Docker
  #
  # have completed successfully.
  #
  # ========================================================

  kubernetes:

    # ------------------------------------------------------
    # DEPENDENCIES
    # ------------------------------------------------------
    #
    # Kubernetes depends on BOTH Terraform and Docker.
    #
    # Deployment flow:
    #
    #              Terraform
    #                 │
    #                 ▼
    #               Docker
    #                 │
    #                 ▼
    #             Kubernetes
    #
    # Kubernetes also explicitly depends on Terraform.
    #
    # ------------------------------------------------------

    needs:
      - terraform
      - docker


    # ------------------------------------------------------
    # Call the Kubernetes reusable workflow.
    # ------------------------------------------------------

    uses: ./.github/workflows/kubernetes.yml


    # ------------------------------------------------------
    # Pass GitHub Secrets to the Kubernetes reusable workflow.
    # ------------------------------------------------------

    secrets: inherit
```

---

### 2.2 Terraform Infrastructure — `.github/workflows/terraform.yml`

```yaml
# ============================================================
# GitHub Actions - Terraform Infrastructure Deployment
#
# Project:
#   aws-hybrid-iac-lab
#
# File:
#   .github/workflows/terraform.yml
#
# Purpose:
#
#   1. Checkout repository.
#   2. Run permanent pre-flight validation.
#   3. Verify GitHub OIDC runtime configuration.
#   4. Diagnose the actual GitHub OIDC JWT claims.
#   5. Configure AWS credentials using GitHub OIDC.
#   6. Verify AWS STS identity.
#   7. Bootstrap/verify Terraform S3 state bucket.
#   8. Install Terraform.
#   9. Initialize Terraform.
#   10. Check Terraform formatting.
#   11. Validate Terraform configuration.
#   12. Display Terraform state.
#   13. Generate Terraform plan.
#   14. Apply the exact generated Terraform plan.
#
# ============================================================
# AUTHENTICATION ARCHITECTURE
# ============================================================
#
#   GitHub Actions
#        |
#        | OIDC JWT
#        v
#   token.actions.githubusercontent.com
#        |
#        | sts:AssumeRoleWithWebIdentity
#        v
#   AWS IAM Role
#   aws-hybrid-iac-lab-GitHubActions
#        |
#        | Temporary AWS credentials
#        v
#   AWS Services
#
#
# IMPORTANT:
#
# This workflow does NOT use:
#
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY
#
# AWS credentials are obtained through GitHub OIDC.
#
# ============================================================
# IMPORTANT SECURITY NOTE
# ============================================================
#
# AWS_ROLE_ARN is intentionally stored as a workflow-level
# environment variable.
#
# An IAM role ARN is an identifier, NOT a password or credential.
#
# No long-lived AWS access keys should be added to this workflow.
#
# ============================================================


# ============================================================
# WORKFLOW NAME
# ============================================================

name: Terraform Infrastructure


# ============================================================
# WORKFLOW TRIGGERS
# ============================================================
#
# workflow_dispatch:
#   Allows manual execution.
#
# workflow_call:
#   Allows another GitHub Actions workflow to call this
#   workflow as a reusable workflow.
#
# IMPORTANT:
#
# This workflow itself does NOT contain a push trigger.
#
# If you see:
#
#   Event: push
#
# in the logs, that means another workflow triggered this
# reusable workflow through workflow_call.
#
# ============================================================

on:

  workflow_dispatch:

  workflow_call:


# ============================================================
# GLOBAL CONFIGURATION
# ============================================================
#
# IMPORTANT:
#
# Keep frequently changed configuration here.
#
# If you later need to change:
#
#   AWS region
#   AWS account
#   IAM role
#   OIDC audience
#   Terraform working directory
#   Terraform version
#   state bucket
#   state region
#   Terraform plan filename
#   project name
#   environment
#
# you can normally change it here instead of searching through
# the entire workflow.
#
# ============================================================

env:

  # ----------------------------------------------------------
  # AWS CONFIGURATION
  # ----------------------------------------------------------

  # AWS region used by Terraform and AWS CLI.
  AWS_REGION: us-east-1

  # AWS account that must receive the deployment.
  AWS_ACCOUNT_ID: "537236558357"

  # IAM role that GitHub Actions will assume.
  AWS_ROLE_ARN: arn:aws:iam::537236558357:role/aws-hybrid-iac-lab-GitHubActions

  # IAM role name used for post-authentication verification.
  AWS_EXPECTED_ROLE_NAME: aws-hybrid-iac-lab-GitHubActions

  # STS role session name.
  AWS_ROLE_SESSION_NAME: GitHubActions-Terraform


  # ----------------------------------------------------------
  # AWS OIDC CONFIGURATION
  # ----------------------------------------------------------
  #
  # GitHub requests an OIDC token with this audience.
  #
  # For AWS commercial regions the normal audience is:
  #
  #   sts.amazonaws.com
  #
  # AWS IAM must trust the same audience.
  #
  # This value is intentionally global so it is defined once
  # and reused by:
  #
  #   - Pre-flight validation
  #   - OIDC diagnostic
  #   - AWS credential configuration
  #
  # ----------------------------------------------------------

  AWS_OIDC_AUDIENCE: sts.amazonaws.com


  # ----------------------------------------------------------
  # PROJECT CONFIGURATION
  # ----------------------------------------------------------

  PROJECT_NAME: aws-hybrid-iac-lab

  ENVIRONMENT: dev


  # ----------------------------------------------------------
  # TERRAFORM CONFIGURATION
  # ----------------------------------------------------------

  TF_WORKING_DIRECTORY: infrastructure/terraform

  TF_VERSION: latest

  TF_PLAN_FILE: tfplan

  TF_IN_AUTOMATION: true

  TF_INPUT: false


  # ----------------------------------------------------------
  # TERRAFORM STATE CONFIGURATION
  # ----------------------------------------------------------
  #
  # This bucket is ONLY for Terraform state.
  #
  # It is separate from the CloudFormation template bucket.
  #
  # ----------------------------------------------------------

  TF_STATE_BUCKET: aws-hybrid-iac-lab-terraform-state-537236558357

  TF_STATE_REGION: us-east-1

  TF_STATE_KEY: aws-hybrid-iac-lab/terraform.tfstate


  # ----------------------------------------------------------
  # TERRAFORM APPLY CONFIGURATION
  # ----------------------------------------------------------

  # true = automatically apply the generated plan.
  # false = skip the Terraform Apply step.
  TF_AUTO_APPROVE: true


# ============================================================
# CONCURRENCY PROTECTION
# ============================================================
#
# Prevent multiple Terraform deployments from attempting to
# modify the same Terraform state simultaneously.
#
# ============================================================

concurrency:

  group: terraform-${{ github.repository }}-${{ github.ref }}

  cancel-in-progress: false


# ============================================================
# GITHUB ACTIONS PERMISSIONS
# ============================================================
#
# id-token: write
#
# REQUIRED for GitHub OIDC.
#
# This does NOT give AWS permissions.
#
# It only allows GitHub Actions to request an OIDC token.
#
#
# contents: read
#
# Required for actions/checkout.
#
# ============================================================

permissions:

  id-token: write

  contents: read


# ============================================================
# TERRAFORM DEPLOYMENT JOB
# ============================================================

jobs:

  terraform:

    name: Terraform Infrastructure Deployment

    runs-on: ubuntu-latest


    steps:


      # ======================================================
      # STEP 1
      # CHECKOUT REPOSITORY
      # ======================================================

      - name: Checkout Repository

        uses: actions/checkout@v4


      # ======================================================
      # STEP 2
      # PERMANENT PRE-FLIGHT VALIDATION
      # ======================================================
      #
      # This step runs BEFORE AWS authentication.
      #
      # At this point we intentionally do not have AWS
      # temporary credentials yet.
      #
      # Therefore this step validates the configuration needed
      # for OIDC rather than calling AWS APIs.
      #
      # Checks:
      #
      #   - AWS region
      #   - AWS account ID
      #   - IAM role ARN
      #   - IAM role name
      #   - IAM role session name
      #   - OIDC audience
      #   - GitHub repository
      #   - GitHub ref
      #   - OIDC runtime variables
      #   - AWS CLI
      #   - Terraform directory
      #   - Terraform state configuration
      #   - absence of long-lived AWS credentials
      #
      # ======================================================

      - name: Preflight Configuration Validation

        shell: bash

        run: |

          set -euo pipefail


          echo "=================================================="
          echo "PRE-FLIGHT CONFIGURATION VALIDATION"
          echo "=================================================="


          # --------------------------------------------------
          # Display important configuration.
          # --------------------------------------------------

          echo ""
          echo "Project:"
          echo "${PROJECT_NAME}"

          echo ""
          echo "Environment:"
          echo "${ENVIRONMENT}"

          echo ""
          echo "AWS Region:"
          echo "${AWS_REGION}"

          echo ""
          echo "AWS Account:"
          echo "${AWS_ACCOUNT_ID}"

          echo ""
          echo "AWS IAM Role:"
          echo "${AWS_ROLE_ARN}"

          echo ""
          echo "Expected IAM Role Name:"
          echo "${AWS_EXPECTED_ROLE_NAME}"

          echo ""
          echo "AWS Role Session:"
          echo "${AWS_ROLE_SESSION_NAME}"

          echo ""
          echo "AWS OIDC Audience:"
          echo "${AWS_OIDC_AUDIENCE}"

          echo ""
          echo "GitHub Repository:"
          echo "${GITHUB_REPOSITORY}"

          echo ""
          echo "GitHub Ref:"
          echo "${GITHUB_REF}"

          echo ""
          echo "GitHub Branch:"
          echo "${GITHUB_REF_NAME}"

          echo ""
          echo "Terraform Directory:"
          echo "${TF_WORKING_DIRECTORY}"

          echo ""
          echo "Terraform Version Configuration:"
          echo "${TF_VERSION}"

          echo ""
          echo "Terraform State Bucket:"
          echo "${TF_STATE_BUCKET}"

          echo ""
          echo "Terraform State Region:"
          echo "${TF_STATE_REGION}"

          echo ""
          echo "Terraform State Key:"
          echo "${TF_STATE_KEY}"


          # --------------------------------------------------
          # Validate AWS region.
          # --------------------------------------------------

          if [[ ! "${AWS_REGION}" =~ ^[a-z]{2}-[a-z0-9-]+-[0-9]+$ ]]; then

            echo ""
            echo "ERROR: Invalid AWS_REGION:"
            echo "${AWS_REGION}"

            exit 1

          fi


          # --------------------------------------------------
          # Validate AWS account ID.
          # --------------------------------------------------

          if [[ ! "${AWS_ACCOUNT_ID}" =~ ^[0-9]{12}$ ]]; then

            echo ""
            echo "ERROR: Invalid AWS_ACCOUNT_ID."

            echo ""
            echo "Expected a 12-digit AWS account ID."

            exit 1

          fi


          # --------------------------------------------------
          # Validate IAM role ARN.
          # --------------------------------------------------

          if [[ ! "${AWS_ROLE_ARN}" =~ ^arn:aws:iam::[0-9]{12}:role/.+ ]]; then

            echo ""
            echo "ERROR: Invalid AWS_ROLE_ARN format."

            echo "${AWS_ROLE_ARN}"

            exit 1

          fi


          # --------------------------------------------------
          # Verify that the role ARN belongs to the expected
          # AWS account.
          # --------------------------------------------------

          ROLE_ACCOUNT_ID="$(echo "${AWS_ROLE_ARN}" | cut -d ':' -f 5)"

          if [[ "${ROLE_ACCOUNT_ID}" != "${AWS_ACCOUNT_ID}" ]]; then

            echo ""
            echo "ERROR: IAM role ARN belongs to a different AWS account."

            echo ""
            echo "Expected account:"
            echo "${AWS_ACCOUNT_ID}"

            echo ""
            echo "Role ARN account:"
            echo "${ROLE_ACCOUNT_ID}"

            exit 1

          fi


          # --------------------------------------------------
          # Validate expected IAM role name.
          # --------------------------------------------------

          if [[ -z "${AWS_EXPECTED_ROLE_NAME}" ]]; then

            echo ""
            echo "ERROR: AWS_EXPECTED_ROLE_NAME is empty."

            exit 1

          fi


          # --------------------------------------------------
          # Verify that the role ARN ends with the expected
          # IAM role name.
          # --------------------------------------------------

          ROLE_NAME_FROM_ARN="${AWS_ROLE_ARN##*/}"

          if [[ "${ROLE_NAME_FROM_ARN}" != "${AWS_EXPECTED_ROLE_NAME}" ]]; then

            echo ""
            echo "ERROR: AWS_ROLE_ARN and AWS_EXPECTED_ROLE_NAME do not match."

            echo ""
            echo "Role from ARN:"
            echo "${ROLE_NAME_FROM_ARN}"

            echo ""
            echo "Expected role:"
            echo "${AWS_EXPECTED_ROLE_NAME}"

            exit 1

          fi


          # --------------------------------------------------
          # Validate AWS role session name.
          # --------------------------------------------------

          if [[ -z "${AWS_ROLE_SESSION_NAME}" ]]; then

            echo ""
            echo "ERROR: AWS_ROLE_SESSION_NAME is empty."

            exit 1

          fi


          # --------------------------------------------------
          # Validate AWS OIDC audience.
          #
          # WHY THIS CHECK EXISTS:
          #
          # The OIDC token contains an "aud" claim.
          #
          # AWS IAM validates that claim against the audience
          # configured for the GitHub OIDC provider/trust policy.
          #
          # For this AWS account we expect:
          #
          #   sts.amazonaws.com
          #
          # We validate it here BEFORE requesting the token so
          # a typo or missing variable is caught immediately.
          # --------------------------------------------------

          if [[ -z "${AWS_OIDC_AUDIENCE:-}" ]]; then

            echo ""
            echo "ERROR: AWS_OIDC_AUDIENCE is empty or undefined."

            echo ""
            echo "Expected:"
            echo "sts.amazonaws.com"

            exit 1

          fi


          if [[ "${AWS_OIDC_AUDIENCE}" != "sts.amazonaws.com" ]]; then

            echo ""
            echo "ERROR: Invalid AWS_OIDC_AUDIENCE."

            echo ""
            echo "Expected:"
            echo "sts.amazonaws.com"

            echo ""
            echo "Actual:"
            echo "${AWS_OIDC_AUDIENCE}"

            exit 1

          fi


          echo ""
          echo "AWS OIDC audience validation: PASSED"


          # --------------------------------------------------
          # Validate GitHub repository.
          # --------------------------------------------------

          EXPECTED_REPOSITORY="awsrmmustansarjavaid/aws-hybrid-iac-lab"

          if [[ "${GITHUB_REPOSITORY}" != "${EXPECTED_REPOSITORY}" ]]; then

            echo ""
            echo "ERROR: Unexpected GitHub repository."

            echo ""
            echo "Expected:"
            echo "${EXPECTED_REPOSITORY}"

            echo ""
            echo "Actual:"
            echo "${GITHUB_REPOSITORY}"

            exit 1

          fi


          # --------------------------------------------------
          # Validate workflow branch.
          #
          # The current IAM trust policy is configured for main.
          #
          # We issue a WARNING instead of failing here because
          # this workflow can also be called as a reusable workflow.
          # --------------------------------------------------

          if [[ "${GITHUB_REF}" != "refs/heads/main" ]]; then

            echo ""
            echo "WARNING: Workflow is not running from main."

            echo ""
            echo "Current ref:"
            echo "${GITHUB_REF}"

            echo ""
            echo "The current AWS IAM trust policy is expected to"
            echo "allow the main branch."

          fi


          # --------------------------------------------------
          # Verify AWS CLI exists.
          #
          # We do not call AWS APIs here.
          #
          # The actual AWS authentication happens later.
          # --------------------------------------------------

          if ! command -v aws >/dev/null 2>&1; then

            echo ""
            echo "ERROR: AWS CLI is not installed."

            exit 1

          fi


          echo ""
          echo "AWS CLI:"
          aws --version


          # --------------------------------------------------
          # Verify jq exists.
          #
          # jq is required by the permanent OIDC diagnostic
          # and AWS identity verification.
          # --------------------------------------------------

          if ! command -v jq >/dev/null 2>&1; then

            echo ""
            echo "ERROR: jq is not installed."

            exit 1

          fi


          echo ""
          echo "jq:"
          jq --version


          # --------------------------------------------------
          # Verify curl exists.
          #
          # curl is required to request the GitHub OIDC token
          # in the diagnostic step.
          # --------------------------------------------------

          if ! command -v curl >/dev/null 2>&1; then

            echo ""
            echo "ERROR: curl is not installed."

            exit 1

          fi


          # --------------------------------------------------
          # Verify Terraform directory exists.
          # --------------------------------------------------

          if [[ ! -d "${TF_WORKING_DIRECTORY}" ]]; then

            echo ""
            echo "ERROR: Terraform directory does not exist:"
            echo "${TF_WORKING_DIRECTORY}"

            exit 1

          fi


          # --------------------------------------------------
          # Verify Terraform configuration files exist.
          # --------------------------------------------------

          if ! find "${TF_WORKING_DIRECTORY}" \
            -maxdepth 1 \
            -name "*.tf" \
            -print \
            -quit |
            grep -q .
          then

            echo ""
            echo "ERROR: No Terraform .tf files found."

            echo "${TF_WORKING_DIRECTORY}"

            exit 1

          fi


          # --------------------------------------------------
          # Verify state bucket configuration.
          # --------------------------------------------------

          if [[ -z "${TF_STATE_BUCKET}" ]]; then

            echo ""
            echo "ERROR: TF_STATE_BUCKET is empty."

            exit 1

          fi


          if [[ -z "${TF_STATE_REGION}" ]]; then

            echo ""
            echo "ERROR: TF_STATE_REGION is empty."

            exit 1

          fi


          if [[ -z "${TF_STATE_KEY}" ]]; then

            echo ""
            echo "ERROR: TF_STATE_KEY is empty."

            exit 1

          fi


          # --------------------------------------------------
          # Verify state region matches AWS deployment region.
          #
          # This prevents accidentally creating the state bucket
          # in one region while Terraform operates in another.
          # --------------------------------------------------

          if [[ "${TF_STATE_REGION}" != "${AWS_REGION}" ]]; then

            echo ""
            echo "ERROR: Terraform state region does not match AWS region."

            echo ""
            echo "AWS_REGION:"
            echo "${AWS_REGION}"

            echo ""
            echo "TF_STATE_REGION:"
            echo "${TF_STATE_REGION}"

            exit 1

          fi


          # --------------------------------------------------
          # IMPORTANT:
          #
          # Verify that long-lived AWS credentials are NOT
          # being supplied.
          #
          # This workflow is designed for GitHub OIDC.
          # --------------------------------------------------

          if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then

            echo ""
            echo "ERROR: AWS_ACCESS_KEY_ID is present."

            echo ""
            echo "This workflow is designed to use GitHub OIDC."

            exit 1

          fi


          if [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then

            echo ""
            echo "ERROR: AWS_SECRET_ACCESS_KEY is present."

            echo ""
            echo "This workflow is designed to use GitHub OIDC."

            exit 1

          fi


          # --------------------------------------------------
          # Verify GitHub supplied the OIDC token runtime
          # variables.
          #
          # These are automatically supplied by GitHub when:
          #
          #   id-token: write
          #
          # is available.
          #
          # They are NOT GitHub repository secrets.
          # --------------------------------------------------

          if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]]; then

            echo ""
            echo "ERROR: ACTIONS_ID_TOKEN_REQUEST_TOKEN is unavailable."

            echo ""
            echo "Check:"
            echo "  permissions:"
            echo "    id-token: write"

            exit 1

          fi


          if [[ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then

            echo ""
            echo "ERROR: ACTIONS_ID_TOKEN_REQUEST_URL is unavailable."

            echo ""
            echo "Check:"
            echo "  permissions:"
            echo "    id-token: write"

            exit 1

          fi


          echo ""
          echo "=================================================="
          echo "PRE-FLIGHT VALIDATION PASSED"
          echo "=================================================="


      # ======================================================
      # STEP 3
      # PERMANENT GITHUB OIDC CLAIM DIAGNOSTIC
      # ======================================================
      #
      # IMPORTANT:
      #
      # This step MUST happen BEFORE AWS authentication.
      #
      # Its purpose is to show exactly what GitHub is sending
      # inside the OIDC token.
      #
      # This is especially important because AWS IAM validates:
      #
      #   issuer
      #   audience
      #   subject
      #
      # against the IAM role trust policy.
      #
      # We NEVER print the complete JWT.
      #
      # We only display safe diagnostic claims.
      #
      # ======================================================

      - name: Diagnose GitHub OIDC Claims

        shell: bash

        run: |

          set -euo pipefail


          echo ""
          echo "=================================================="
          echo "GITHUB OIDC CLAIM DIAGNOSTIC"
          echo "=================================================="


          # --------------------------------------------------
          # Display GitHub runtime information.
          # --------------------------------------------------

          echo ""
          echo "Repository:"
          echo "${GITHUB_REPOSITORY}"

          echo ""
          echo "Ref:"
          echo "${GITHUB_REF}"

          echo ""
          echo "Branch:"
          echo "${GITHUB_REF_NAME}"

          echo ""
          echo "Event:"
          echo "${GITHUB_EVENT_NAME}"

          echo ""
          echo "Workflow:"
          echo "${GITHUB_WORKFLOW}"

          echo ""
          echo "Job:"
          echo "${GITHUB_JOB}"


          # --------------------------------------------------
          # Verify GitHub supplied the OIDC environment variables.
          # --------------------------------------------------

          if [ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then

            echo ""
            echo "ERROR: ACTIONS_ID_TOKEN_REQUEST_TOKEN is not available."

            echo ""
            echo "Check that workflow/job permissions contain:"

            echo ""
            echo "permissions:"
            echo "  id-token: write"
            echo "  contents: read"

            exit 1

          fi


          if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then

            echo ""
            echo "ERROR: ACTIONS_ID_TOKEN_REQUEST_URL is not available."

            exit 1

          fi


          # --------------------------------------------------
          # Request a GitHub OIDC token.
          #
          # The audience is explicitly supplied as:
          #
          #   sts.amazonaws.com
          #
          # This must match AWS IAM's trusted audience.
          # --------------------------------------------------

          echo ""
          echo "Requesting OIDC token..."


          OIDC_RESPONSE="$(
            curl \
              --fail \
              --silent \
              --show-error \
              --location \
              --header "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
              --get \
              --data-urlencode "audience=${AWS_OIDC_AUDIENCE}" \
              "${ACTIONS_ID_TOKEN_REQUEST_URL}"
          )"


          # --------------------------------------------------
          # Validate that GitHub returned JSON.
          # --------------------------------------------------

          if ! echo "${OIDC_RESPONSE}" | jq empty >/dev/null 2>&1; then

            echo ""
            echo "ERROR: GitHub returned an invalid JSON response."

            exit 1

          fi


          # --------------------------------------------------
          # GitHub returns a JSON object similar to:
          #
          # {
          #   "value": "eyJhbGciOiJSUzI1NiIs..."
          # }
          #
          # We must extract .value.
          #
          # IMPORTANT:
          #
          # The previous diagnostic error:
          #
          #   Cannot index array with string "iss"
          #
          # happened because the token response was not being
          # decoded correctly before jq attempted to access
          # claims.
          #
          # --------------------------------------------------

          OIDC_TOKEN="$(
            echo "${OIDC_RESPONSE}" |
              jq -r '.value // empty'
          )"


          if [ -z "${OIDC_TOKEN}" ]; then

            echo ""
            echo "ERROR: OIDC token value was not found."

            echo ""
            echo "Returned JSON keys:"

            echo "${OIDC_RESPONSE}" | jq -r 'keys[]'

            exit 1

          fi


          # --------------------------------------------------
          # NEVER PRINT THE TOKEN.
          #
          # The JWT is a credential and must remain secret.
          # --------------------------------------------------

          echo ""
          echo "OIDC token received successfully."

          echo "JWT token itself will NOT be printed."


          # --------------------------------------------------
          # JWT format:
          #
          #   HEADER.PAYLOAD.SIGNATURE
          #
          # Extract only the payload.
          # --------------------------------------------------

          JWT_PAYLOAD_B64="$(
            echo "${OIDC_TOKEN}" |
              cut -d '.' -f 2
          )"


          if [ -z "${JWT_PAYLOAD_B64}" ]; then

            echo ""
            echo "ERROR: Could not extract JWT payload."

            exit 1

          fi


          # --------------------------------------------------
          # Decode Base64URL JWT payload.
          #
          # JWT uses Base64URL encoding rather than ordinary
          # Base64.
          #
          # Therefore:
          #
          #   - replace '-' with '+'
          #   - replace '_' with '/'
          #   - restore missing '=' padding
          #   - decode
          # --------------------------------------------------

          JWT_PAYLOAD="$(
            printf '%s' "${JWT_PAYLOAD_B64}" |
              tr '_-' '/+' |
              awk '
                {
                  remainder = length($0) % 4;

                  if (remainder == 2) {
                    $0 = $0 "==";
                  }
                  else if (remainder == 3) {
                    $0 = $0 "=";
                  }

                  print $0;
                }
              ' |
              base64 --decode
          )"


          # --------------------------------------------------
          # Verify decoded payload is valid JSON.
          # --------------------------------------------------

          if ! echo "${JWT_PAYLOAD}" | jq empty >/dev/null 2>&1; then

            echo ""
            echo "ERROR: Decoded OIDC payload is not valid JSON."

            exit 1

          fi


          echo ""
          echo "=================================================="
          echo "OIDC CLAIMS"
          echo "=================================================="


          # --------------------------------------------------
          # Display NON-SECRET claims.
          #
          # DO NOT print:
          #
          #   OIDC_TOKEN
          #   JWT signature
          #   ACTIONS_ID_TOKEN_REQUEST_TOKEN
          #
          # --------------------------------------------------

          echo "${JWT_PAYLOAD}" | jq -r '
            "iss: \(.iss // "<not present>")",
            "aud: \(.aud // "<not present>")",
            "sub: \(.sub // "<not present>")",
            "repository: \(.repository // "<not present>")",
            "repository_id: \(.repository_id // "<not present>")",
            "repository_owner: \(.repository_owner // "<not present>")",
            "repository_owner_id: \(.repository_owner_id // "<not present>")",
            "ref: \(.ref // "<not present>")",
            "ref_type: \(.ref_type // "<not present>")",
            "event_name: \(.event_name // "<not present>")",
            "job_workflow_ref: \(.job_workflow_ref // "<not present>")",
            "workflow: \(.workflow // "<not present>")",
            "workflow_ref: \(.workflow_ref // "<not present>")",
            "environment: \(.environment // "<not present>")"
          '


          # --------------------------------------------------
          # Extract important claims for validation.
          # --------------------------------------------------

          ISS="$(
            echo "${JWT_PAYLOAD}" |
              jq -r '.iss // empty'
          )"


          AUD="$(
            echo "${JWT_PAYLOAD}" |
              jq -r '.aud // empty'
          )"


          SUB="$(
            echo "${JWT_PAYLOAD}" |
              jq -r '.sub // empty'
          )"


          REPOSITORY="$(
            echo "${JWT_PAYLOAD}" |
              jq -r '.repository // empty'
          )"


          REF="$(
            echo "${JWT_PAYLOAD}" |
              jq -r '.ref // empty'
          )"


          # --------------------------------------------------
          # Expected issuer.
          # --------------------------------------------------

          EXPECTED_ISSUER="https://token.actions.githubusercontent.com"


          echo ""
          echo "=================================================="
          echo "OIDC VALIDATION"
          echo "=================================================="


          if [ "${ISS}" = "${EXPECTED_ISSUER}" ]; then

            echo "PASS: OIDC issuer is correct."

          else

            echo "FAIL: OIDC issuer is incorrect."

            echo "Expected: ${EXPECTED_ISSUER}"

            echo "Actual:   ${ISS}"

            exit 1

          fi


          # --------------------------------------------------
          # Expected audience.
          # --------------------------------------------------

          if [ "${AUD}" = "${AWS_OIDC_AUDIENCE}" ]; then

            echo "PASS: OIDC audience is correct."

          else

            echo "FAIL: OIDC audience is incorrect."

            echo "Expected: ${AWS_OIDC_AUDIENCE}"

            echo "Actual:   ${AUD}"

            exit 1

          fi


          # --------------------------------------------------
          # Expected repository.
          # --------------------------------------------------

          if [ "${REPOSITORY}" = "${GITHUB_REPOSITORY}" ]; then

            echo "PASS: Repository claim is correct."

          else

            echo "FAIL: Repository claim does not match workflow repository."

            echo "Expected: ${GITHUB_REPOSITORY}"

            echo "Actual:   ${REPOSITORY}"

            exit 1

          fi


          # --------------------------------------------------
          # Expected branch/ref.
          # --------------------------------------------------

          if [ "${REF}" = "${GITHUB_REF}" ]; then

            echo "PASS: Ref claim is correct."

          else

            echo "WARNING: Ref claim differs from GITHUB_REF."

            echo "GITHUB_REF: ${GITHUB_REF}"

            echo "OIDC ref:    ${REF}"

          fi


          # --------------------------------------------------
          # IMPORTANT SUBJECT CHECK
          #
          # Your current IAM trust policy expects the classic
          # GitHub subject format:
          #
          # repo:OWNER/REPOSITORY:ref:refs/heads/main
          #
          # However, GitHub now supports immutable subject
          # formats containing owner/repository IDs.
          #
          # Therefore we DISPLAY the comparison instead of
          # automatically changing or modifying IAM.
          #
          # The actual "sub" value printed above is the value
          # we will use if the IAM trust policy needs updating.
          #
          # --------------------------------------------------

          EXPECTED_CLASSIC_SUB="repo:${GITHUB_REPOSITORY}:ref:${GITHUB_REF}"


          echo ""
          echo "=================================================="
          echo "SUBJECT CLAIM ANALYSIS"
          echo "=================================================="


          echo ""
          echo "Actual OIDC sub:"
          echo "${SUB}"


          echo ""
          echo "Classic IAM expected sub:"
          echo "${EXPECTED_CLASSIC_SUB}"


          if [ "${SUB}" = "${EXPECTED_CLASSIC_SUB}" ]; then

            echo ""
            echo "PASS: OIDC sub matches the classic IAM trust policy format."

          else

            echo ""
            echo "WARNING: OIDC sub DOES NOT match the classic IAM trust policy."

            echo ""
            echo "This is important."

            echo "The IAM trust policy may need to be updated to match"
            echo "the actual GitHub OIDC subject claim."

            echo ""
            echo "DO NOT change IAM automatically."

            echo "Use the actual 'sub' value printed above."

          fi


          echo ""
          echo "=================================================="
          echo "OIDC DIAGNOSTIC COMPLETE"
          echo "=================================================="


      # ======================================================
      # STEP 4
      # DISPLAY AWS DEPLOYMENT CONFIGURATION
      # ======================================================

      - name: Display AWS Deployment Configuration

        shell: bash

        run: |

          set -euo pipefail


          echo "=================================================="
          echo "AWS DEPLOYMENT CONFIGURATION"
          echo "=================================================="


          echo ""
          echo "AWS Region:"
          echo "${AWS_REGION}"


          echo ""
          echo "AWS Account:"
          echo "${AWS_ACCOUNT_ID}"


          echo ""
          echo "AWS IAM Role:"
          echo "${AWS_ROLE_ARN}"


          echo ""
          echo "Expected IAM Role Name:"
          echo "${AWS_EXPECTED_ROLE_NAME}"


          echo ""
          echo "OIDC Audience:"
          echo "${AWS_OIDC_AUDIENCE}"


          echo ""
          echo "Role Session:"
          echo "${AWS_ROLE_SESSION_NAME}"


          echo ""
          echo "GitHub Repository:"
          echo "${GITHUB_REPOSITORY}"


          echo ""
          echo "GitHub Ref:"
          echo "${GITHUB_REF}"


          echo ""
          echo "GitHub Branch:"
          echo "${GITHUB_REF_NAME}"


          echo ""
          echo "Terraform Directory:"
          echo "${TF_WORKING_DIRECTORY}"


          echo ""
          echo "Terraform State Bucket:"
          echo "${TF_STATE_BUCKET}"


          echo ""
          echo "Terraform State Key:"
          echo "${TF_STATE_KEY}"


          echo ""
          echo "=================================================="
          echo "CONFIGURATION DISPLAY COMPLETED"
          echo "=================================================="


      # ======================================================
      # STEP 5
      # CONFIGURE AWS CREDENTIALS USING GITHUB OIDC
      # ======================================================
      #
      # GitHub:
      #
      #   1. Requests an OIDC JWT.
      #
      #   2. Sends the JWT to AWS STS.
      #
      #   3. AWS validates:
      #
      #        OIDC provider
      #        issuer
      #        audience
      #        subject
      #        IAM trust policy
      #
      #   4. AWS returns temporary credentials.
      #
      # The credentials are then exported for subsequent
      # Terraform/AWS CLI steps.
      #
      # ======================================================

      - name: Configure AWS Credentials Using OIDC
      # v5.1.1 is intentionally used here because this workflow
      # is called as a reusable workflow from Main Deployment.
      # v6 has a documented OIDC issue in some reusable-workflow
      # configurations resulting in:
      # Not authorized to perform sts:AssumeRoleWithWebIdentity

        uses: aws-actions/configure-aws-credentials@v5.1.1

        with:

          # AWS deployment region.
          aws-region: ${{ env.AWS_REGION }}

          # IAM role GitHub Actions will assume.
          role-to-assume: ${{ env.AWS_ROLE_ARN }}

          # CloudTrail/STS session name.
          role-session-name: ${{ env.AWS_ROLE_SESSION_NAME }}

          # Explicit OIDC audience.
          #
          # Must match:
          #
          #   sts.amazonaws.com
          #
          audience: ${{ env.AWS_OIDC_AUDIENCE }}

          # Extra safety:
          #
          # Only allow credentials from the expected AWS account.
          allowed-account-ids: ${{ env.AWS_ACCOUNT_ID }}


      # ======================================================
      # STEP 6
      # VERIFY AWS STS IDENTITY
      # ======================================================
      #
      # This is the first step that actually proves AWS
      # authentication succeeded.
      #
      # Expected result:
      #
      #   arn:aws:sts::<ACCOUNT_ID>:assumed-role/...
      #
      # If this step succeeds, GitHub OIDC successfully
      # exchanged the token for temporary AWS credentials.
      #
      # ======================================================

      - name: Verify AWS Identity

        shell: bash

        run: |

          set -euo pipefail


          echo "=================================================="
          echo "AWS STS IDENTITY"
          echo "=================================================="


          IDENTITY_JSON="$(aws sts get-caller-identity)"


          echo "${IDENTITY_JSON}" | jq .


          ACCOUNT_ID="$(
            echo "${IDENTITY_JSON}" |
              jq -r '.Account'
          )"


          ARN="$(
            echo "${IDENTITY_JSON}" |
              jq -r '.Arn'
          )"


          # --------------------------------------------------
          # Verify expected AWS account.
          # --------------------------------------------------

          EXPECTED_ACCOUNT_ID="${AWS_ACCOUNT_ID}"


          if [[ "${ACCOUNT_ID}" != "${EXPECTED_ACCOUNT_ID}" ]]; then

            echo ""
            echo "ERROR: Unexpected AWS account."

            echo "Expected: ${EXPECTED_ACCOUNT_ID}"

            echo "Actual:   ${ACCOUNT_ID}"

            exit 1

          fi


          # --------------------------------------------------
          # Verify that the assumed role is the expected role.
          # --------------------------------------------------

          EXPECTED_ROLE_NAME="${AWS_EXPECTED_ROLE_NAME}"


          if [[ "${ARN}" != *"${EXPECTED_ROLE_NAME}"* ]]; then

            echo ""
            echo "ERROR: Unexpected AWS IAM role."

            echo "Expected role: ${EXPECTED_ROLE_NAME}"

            echo "Actual ARN:    ${ARN}"

            exit 1

          fi


          echo ""
          echo "AWS account verification: PASSED"


          echo ""
          echo "AWS role verification: PASSED"


          echo ""
          echo "AWS OIDC authentication: PASSED"


          echo ""
          echo "=================================================="
          echo "AWS IDENTITY VERIFICATION COMPLETED"
          echo "=================================================="


      # ======================================================
      # STEP 7
      # BOOTSTRAP TERRAFORM STATE BUCKET
      # ======================================================
      #
      # The state bucket must exist before terraform init.
      #
      # This step:
      #
      #   - checks the bucket
      #   - creates it if missing
      #   - enables versioning
      #   - enables encryption
      #   - blocks public access
      #   - applies tags
      #   - verifies configuration
      #
      # ======================================================

      - name: Bootstrap Terraform State Bucket

        shell: bash

        run: |

          set -euo pipefail


          echo "=================================================="
          echo "TERRAFORM STATE BACKEND BOOTSTRAP"
          echo "=================================================="


          echo ""
          echo "State bucket:"
          echo "${TF_STATE_BUCKET}"


          echo ""
          echo "State region:"
          echo "${TF_STATE_REGION}"


          echo ""
          echo "State key:"
          echo "${TF_STATE_KEY}"


          # --------------------------------------------------
          # Check whether bucket exists.
          # --------------------------------------------------

          echo ""
          echo "Checking Terraform state bucket..."


          if aws s3api head-bucket \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            2>/dev/null
          then

            echo "Terraform state bucket already exists."

          else

            echo "Terraform state bucket does not exist."

            echo "Creating Terraform state bucket..."


            # ------------------------------------------------
            # us-east-1 does not use LocationConstraint.
            # ------------------------------------------------

            if [[ "${TF_STATE_REGION}" == "us-east-1" ]]; then

              aws s3api create-bucket \
                --bucket "${TF_STATE_BUCKET}" \
                --region "${TF_STATE_REGION}"

            else

              aws s3api create-bucket \
                --bucket "${TF_STATE_BUCKET}" \
                --region "${TF_STATE_REGION}" \
                --create-bucket-configuration \
                  LocationConstraint="${TF_STATE_REGION}"

            fi


            echo "Terraform state bucket created."

          fi


          # --------------------------------------------------
          # Enable versioning.
          # --------------------------------------------------

          echo ""
          echo "Enabling S3 versioning..."


          aws s3api put-bucket-versioning \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --versioning-configuration Status=Enabled


          # --------------------------------------------------
          # Enable SSE-S3 encryption.
          # --------------------------------------------------

          echo ""
          echo "Enabling S3 encryption..."


          aws s3api put-bucket-encryption \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --server-side-encryption-configuration \
            '{
              "Rules": [
                {
                  "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                  }
                }
              ]
            }'


          # --------------------------------------------------
          # Block public access.
          # --------------------------------------------------

          echo ""
          echo "Blocking public access..."


          aws s3api put-public-access-block \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true


          # --------------------------------------------------
          # Apply bucket tags.
          # --------------------------------------------------

          echo ""
          echo "Applying bucket tags..."


          aws s3api put-bucket-tagging \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}" \
            --tagging '{
              "TagSet": [
                {
                  "Key": "Name",
                  "Value": "aws-hybrid-iac-lab-terraform-state"
                },
                {
                  "Key": "Project",
                  "Value": "aws-hybrid-iac-lab"
                },
                {
                  "Key": "ManagedBy",
                  "Value": "GitHub-Actions-Bootstrap"
                },
                {
                  "Key": "Purpose",
                  "Value": "Terraform-State"
                },
                {
                  "Key": "Environment",
                  "Value": "dev"
                }
              ]
            }'


          # --------------------------------------------------
          # Verify bucket.
          # --------------------------------------------------

          echo ""
          echo "=================================================="
          echo "STATE BUCKET VERIFICATION"
          echo "=================================================="


          echo ""
          echo "Bucket:"


          aws s3api head-bucket \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"


          echo ""
          echo "Versioning:"


          aws s3api get-bucket-versioning \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"


          echo ""
          echo "Encryption:"


          aws s3api get-bucket-encryption \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"


          echo ""
          echo "Public Access Block:"


          aws s3api get-public-access-block \
            --bucket "${TF_STATE_BUCKET}" \
            --region "${TF_STATE_REGION}"


          echo ""
          echo "Terraform state backend bootstrap completed."


      # ======================================================
      # STEP 8
      # SETUP TERRAFORM
      # ======================================================

      - name: Setup Terraform

        uses: hashicorp/setup-terraform@v3

        with:

          terraform_version: ${{ env.TF_VERSION }}


      # ======================================================
      # STEP 9
      # TERRAFORM INIT
      # ======================================================

      - name: Terraform Init

        working-directory: ${{ env.TF_WORKING_DIRECTORY }}

        run: |

          terraform init \
            -input=false


      # ======================================================
      # STEP 10
      # TERRAFORM FORMAT CHECK
      # ======================================================

      - name: Terraform Format Check

        working-directory: ${{ env.TF_WORKING_DIRECTORY }}

        run: |

          terraform fmt \
            -check \
            -recursive


      # ======================================================
      # STEP 11
      # TERRAFORM VALIDATE
      # ======================================================

      - name: Terraform Validate

        working-directory: ${{ env.TF_WORKING_DIRECTORY }}

        run: |

          terraform validate


      # ======================================================
      # STEP 12
      # TERRAFORM STATE INFORMATION
      # ======================================================

      - name: Terraform State Information

        working-directory: ${{ env.TF_WORKING_DIRECTORY }}

        run: |

          echo "=================================================="
          echo "TERRAFORM STATE"
          echo "=================================================="


          terraform state list || true


      # ======================================================
      # STEP 13
      # TERRAFORM PLAN
      # ======================================================
      #
      # The generated plan is stored in:
      #
      #   TF_PLAN_FILE
      #
      # ======================================================

      - name: Terraform Plan

        working-directory: ${{ env.TF_WORKING_DIRECTORY }}

        run: |

          terraform plan \
            -input=false \
            -out="${TF_PLAN_FILE}"


      # ======================================================
      # STEP 14
      # TERRAFORM APPLY
      # ======================================================
      #
      # Applies the EXACT plan generated by Step 13.
      #
      # This prevents a different plan from being generated
      # between the plan and apply stages.
      #
      # ======================================================

      - name: Terraform Apply

        if: ${{ env.TF_AUTO_APPROVE == 'true' }}

        working-directory: ${{ env.TF_WORKING_DIRECTORY }}

        run: |

          terraform apply \
            -input=false \
            -auto-approve \
            "${TF_PLAN_FILE}"
```

---

### 2.3 Docker Build and ECR — `.github/workflows/docker.yml`

```yaml
# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# Docker + Amazon ECR Workflow
# ==========================================================
#
# This workflow is responsible for:
#
#   Dockerfile
#       |
#       v
#   Docker Image
#       |
#       v
#   Amazon ECR
#       |
#       +----> ECS
#       |
#       +----> EKS
#
# This workflow is called by:
#
#   main-deploy.yaml
#
# ==========================================================

name: Docker Build and ECR


# ==========================================================
# TRIGGERS
# ==========================================================

on:

  # --------------------------------------------------------
  # Allows main-deploy.yaml to call this workflow.
  # --------------------------------------------------------

  workflow_call:

  # --------------------------------------------------------
  # Allows manual execution.
  # --------------------------------------------------------

  workflow_dispatch:


# ==========================================================
# PERMISSIONS
# ==========================================================

permissions:

  id-token: write

  contents: read


# ==========================================================
# JOB
# ==========================================================

jobs:

  docker:

    name: Build Docker Image and Push to ECR

    runs-on: ubuntu-latest

    steps:

      # ----------------------------------------------------
      # 1. Checkout repository
      # ----------------------------------------------------

      - name: Checkout Repository

        uses: actions/checkout@v4


      # ----------------------------------------------------
      # 2. Configure AWS
      # ----------------------------------------------------

      - name: Configure AWS Credentials

        uses: aws-actions/configure-aws-credentials@v4

        with:

          aws-region: ${{ vars.AWS_REGION }}

          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}


      # ----------------------------------------------------
      # 3. Login to Amazon ECR
      # ----------------------------------------------------

      - name: Login to Amazon ECR

        id: login-ecr

        uses: aws-actions/amazon-ecr-login@v2


      # ----------------------------------------------------
      # 4. Get AWS Account ID
      # ----------------------------------------------------

      - name: Get AWS Account ID

        id: aws-account

        run: |

          ACCOUNT_ID=$(aws sts get-caller-identity \
            --query Account \
            --output text)

          echo "ACCOUNT_ID=$ACCOUNT_ID" >> "$GITHUB_OUTPUT"


      # ----------------------------------------------------
      # 5. Build Docker Image
      # ----------------------------------------------------
      #
      # Dockerfile:
      #
      # docker/app/Dockerfile
      #
      # Context:
      #
      # docker/app
      #
      # ----------------------------------------------------

      - name: Build Docker Image

        working-directory: docker/app

        run: |

          docker build \
            -t hybrid-iac-app:${GITHUB_SHA} \
            -t hybrid-iac-app:latest \
            .


      # ----------------------------------------------------
      # 6. Get ECR Repository
      # ----------------------------------------------------
      #
      # Our CloudFormation ECR repository is:
      #
      # HybridIaCLab-dev-app
      #
      # ----------------------------------------------------

      - name: Get ECR Repository URI

        id: ecr

        run: |

          ECR_URI=$(aws ecr describe-repositories \
            --repository-names HybridIaCLab-dev-app \
            --query 'repositories[0].repositoryUri' \
            --output text)

          echo "ECR_URI=$ECR_URI" >> "$GITHUB_OUTPUT"


      # ----------------------------------------------------
      # 7. Tag Docker Image
      # ----------------------------------------------------

      - name: Tag Docker Image

        run: |

          docker tag \
            hybrid-iac-app:${GITHUB_SHA} \
            ${{ steps.ecr.outputs.ECR_URI }}:${GITHUB_SHA}

          docker tag \
            hybrid-iac-app:latest \
            ${{ steps.ecr.outputs.ECR_URI }}:latest


      # ----------------------------------------------------
      # 8. Push Image to ECR
      # ----------------------------------------------------

      - name: Push Docker Image to ECR

        run: |

          docker push \
            ${{ steps.ecr.outputs.ECR_URI }}:${GITHUB_SHA}

          docker push \
            ${{ steps.ecr.outputs.ECR_URI }}:latest
```

---

### 2.4 Kubernetes Deployment — `.github/workflows/kubernetes.yml`

```yaml
# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# Kubernetes / Amazon EKS Deployment Workflow
# ==========================================================
#
# This workflow is responsible for deploying Kubernetes
# resources INSIDE the EKS cluster.
#
# IMPORTANT:
#
# CloudFormation creates the EKS infrastructure.
#
# Kubernetes manages the applications running inside EKS.
#
# Therefore:
#
# CloudFormation
#       |
#       v
#      EKS
#       |
#       v
# Kubernetes
#       |
#       +--> Namespace
#       +--> ConfigMap
#       +--> Deployment
#       +--> Service
#
# ==========================================================

name: Kubernetes Deployment


# ==========================================================
# TRIGGERS
# ==========================================================

on:

  # --------------------------------------------------------
  # Allows main-deploy.yaml to call this workflow.
  # --------------------------------------------------------

  workflow_call:

  # --------------------------------------------------------
  # Allows manual execution.
  # --------------------------------------------------------

  workflow_dispatch:


# ==========================================================
# PERMISSIONS
# ==========================================================

permissions:

  id-token: write

  contents: read


# ==========================================================
# JOB
# ==========================================================

jobs:

  kubernetes:

    name: Deploy Application to Amazon EKS

    runs-on: ubuntu-latest

    steps:

      # ----------------------------------------------------
      # 1. Checkout repository
      # ----------------------------------------------------

      - name: Checkout Repository

        uses: actions/checkout@v4


      # ----------------------------------------------------
      # 2. Configure AWS
      # ----------------------------------------------------

      - name: Configure AWS Credentials

        uses: aws-actions/configure-aws-credentials@v4

        with:

          aws-region: ${{ vars.AWS_REGION }}

          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}


      # ----------------------------------------------------
      # 3. Install kubectl
      # ----------------------------------------------------

      - name: Install kubectl

        uses: azure/setup-kubectl@v4

        with:

          version: latest


      # ----------------------------------------------------
      # 4. Configure kubectl for EKS
      # ----------------------------------------------------
      #
      # This connects kubectl to our EKS cluster.
      #
      # ----------------------------------------------------

      - name: Configure kubectl

        run: |

          aws eks update-kubeconfig \
            --region ${{ vars.AWS_REGION }} \
            --name HybridIaCLab-dev-eks


      # ----------------------------------------------------
      # 5. Verify EKS connection
      # ----------------------------------------------------

      - name: Verify Kubernetes Connection

        run: |

          kubectl get nodes


      # ----------------------------------------------------
      # 6. Create Namespace
      # ----------------------------------------------------

      - name: Deploy Namespace

        run: |

          kubectl apply \
            -f kubernetes/namespace.yaml


      # ----------------------------------------------------
      # 7. Deploy ConfigMap
      # ----------------------------------------------------

      - name: Deploy ConfigMap

        run: |

          kubectl apply \
            -f kubernetes/configmap.yaml


      # ----------------------------------------------------
      # 8. Deploy Application
      # ----------------------------------------------------

      - name: Deploy Application

        run: |

          kubectl apply \
            -f kubernetes/deployment.yaml


      # ----------------------------------------------------
      # 9. Deploy Service
      # ----------------------------------------------------

      - name: Deploy Service

        run: |

          kubectl apply \
            -f kubernetes/service.yaml


      # ----------------------------------------------------
      # 10. Check Kubernetes Resources
      # ----------------------------------------------------

      - name: Verify Deployment

        run: |

          kubectl get namespace

          kubectl get deployments \
            -n hybrid-iac

          kubectl get pods \
            -n hybrid-iac

          kubectl get services \
            -n hybrid-iac
```
