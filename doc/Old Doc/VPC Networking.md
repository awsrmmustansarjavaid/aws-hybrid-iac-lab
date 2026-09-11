# aws-hybrid-iac-lab Networking

## VPC Networking

---
### CloudFormation outputs

Your main.yaml exposes:

```
Outputs:
  VpcId:
  ApplicationBucketName:
  ECRRepositoryUri:
  EKSClusterName:
  RDSDatabaseEndpoint:
  ...
```

### Terraform outputs

Your output.tf exposes Terraform-level information.

You don't need to duplicate every CloudFormation output into Terraform.

So:

output.tf → no change required.

---
## EKS Networking

### Does EKS always use private subnets?

**No, not always.** But for a **production EKS cluster**, worker nodes are commonly placed in **private subnets** for security.

Private subnets have **no direct Internet Gateway route**, so nodes need another way to reach AWS services or the Internet.

### What should you attach to private subnets?

**For your lab: use a NAT Gateway.**

| Option           | Purpose                               | Recommendation                             |
| ---------------- | ------------------------------------- | ------------------------------------------ |
| **NAT Gateway**  | Private nodes → Internet              | ✅ Best for your EKS lab                    |
| **VPC Endpoint** | Private nodes → specific AWS services | ✅ Add later for cost/security optimization |

### Recommended Route

```text
Private Subnet
      |
      v
Private Route Table
      |
      v
NAT Gateway
      |
      v
Internet Gateway
      |
   Internet
```

For your **EKS lab**, use:

**Private Subnet → NAT Gateway → Internet Gateway**

Then optionally add **VPC Endpoints** for services such as S3, ECR, and CloudWatch to reduce NAT dependency and improve security.
---
## Very important: your EKS networking

This is the biggest thing I would pay attention to.

Your VPC currently has:

```
PrivateSubnet1
       |
       v
PrivateRouteTable
       |
       X
   No Internet
```

and:

```
PrivateSubnet2
       |
       v
PrivateRouteTable
       |
       X
   No Internet
```

You explicitly designed it this way.

That is technically valid.

But now that your lab contains EKS, we need to examine what your eks.yaml does.

For example, if your EKS managed node group is inside:

```
PrivateSubnet1
PrivateSubnet2
```

the worker nodes may need outbound connectivity to AWS services such as ECR/S3 and other endpoints during bootstrap and operation.

There are two common approaches.


### Option A — NAT Gateway

```
             Internet
                |
                v
         Internet Gateway
                |
        +-------+-------+
        |               |
 Public Subnet 1   Public Subnet 2
        |
   NAT Gateway
        |
        v
 Private Route Table
        |
   +----+----+
   |         |
Private  Private
Subnet 1 Subnet 2
```

This is the simpler traditional architecture.

### Option B — VPC endpoints

You can keep the private subnets without NAT and create the required VPC endpoints for AWS services.

That's more advanced and potentially more cost-efficient for some workloads, but it adds complexity.

### Should you add NAT Gateway right now?

For your lab, I would say:

If your goal is simply to create the VPC + EKS cluster:

You don't necessarily need to modify the VPC yet.

If your goal is:

```
EKS
+
Managed Node Group
+
Docker images from ECR
+
Kubernetes workloads
+
AWS integrations
```

then I would strongly consider adding private-subnet egress, either through NAT or appropriate VPC endpoints.

For a learning lab, one NAT Gateway is a reasonable compromise:

```
PrivateSubnet1 ──┐
                 │
PrivateSubnet2 ──┤
                 ↓
          PrivateRouteTable
                 |
                 v
             NAT Gateway
                 |
                 v
          PublicRouteTable
                 |
                 v
          Internet Gateway
                 |
                 v
             Internet
```

But remember:

one NAT Gateway is not fully highly available.

A production design would normally use one NAT Gateway per AZ:

```
AZ-1                         AZ-2

Private 1                    Private 2
   |                             |
   v                             v
NAT Gateway 1              NAT Gateway 2
   |                             |
   v                             v
Public Subnet 1             Public Subnet 2
```

For your small lab, one NAT Gateway is much cheaper.

10. Another important point: one shared private route table

You intentionally use:

```
PrivateSubnet1
      |
      +---- PrivateRouteTable
      |
PrivateSubnet2
      |
      +---- PrivateRouteTable
```

This is valid.

You don't have to create:

```
PrivateRouteTable1
PrivateRouteTable2
```
just because you have two AZs.

For a learning lab, your design is easy to understand.

However, if you eventually add NAT Gateway HA, I would change to:

```
PrivateSubnet1
      |
PrivateRouteTable1
      |
NAT Gateway 1
```

```
PrivateSubnet2
      |
PrivateRouteTable2
      |
NAT Gateway 2
```
That gives proper AZ-level routing.

For now:

one private route table = acceptable for your lab.
---
# NAT Gateway

Based on your eks.yaml, your EKS managed node group runs in PrivateSubnet1 and PrivateSubnet2 and the nodes do not receive public IPs. Therefore, adding a NAT Gateway in a public subnet and adding a 0.0.0.0/0 route from the private route table to the NAT Gateway is the correct design for this lab.

For your current architecture, I recommend one NAT Gateway to keep the lab simple and cost-conscious:

```
                    Internet
                       |
                       v
              Internet Gateway
                       |
              +--------+--------+
              |                 |
              v                 v
       PublicSubnet1     PublicSubnet2
        10.0.1.0/24       10.0.2.0/24
              |
              v
          NAT Gateway
              |
              v
      PrivateRouteTable
              |
        +-----+-----+
        |           |
        v           v
 PrivateSubnet1  PrivateSubnet2
 10.0.11.0/24    10.0.12.0/24
        |           |
        +-----+-----+
              |
              v
          EKS Nodes
```

This allows your private EKS nodes to reach services such as ECR, S3, package repositories, Docker registries, and other Internet endpoints without giving the nodes public IP addresses.

Important: one NAT Gateway is appropriate for your learning lab and reduces cost, but it is not the most highly available production design. Production would normally use one NAT Gateway per AZ with separate private route tables.

### What happens without NAT?

For example:

```
EKS Node
   |
   | Pull container image
   v
ECR
```

Your node has ECR permissions.

But your private subnet currently has no general outbound route.

So:

```
IAM permission     ✅
Network path       ❌
```

Similarly, your node may need access to AWS services during its lifecycle.

Therefore, I would not call the current VPC + EKS architecture fully operational yet.

### What changed for EKS

The important additions are these four resources:

```
| Resource                                 | Purpose                                                                    |
| ---------------------------------------- | -------------------------------------------------------------------------- |
| `NATGatewayEIP`                          | Allocates the public Elastic IP for NAT                                    |
| `NATGateway`                             | Provides outbound Internet access from private subnets                     |
| `DefaultPrivateRoute`                    | Sends `0.0.0.0/0` from private subnets to NAT                              |
| `NatGatewayId` / `NatGatewayEip` outputs | Makes NAT information available for troubleshooting and future integration |

```
Your final EKS traffic path is now:

```
                 INTERNET
                    ^
                    |
             Internet Gateway
                    ^
                    |
             NAT Gateway
                    ^
                    |
          Private Route Table
          0.0.0.0/0 -> NAT
              ^             ^
              |             |
              |             |
     PrivateSubnet1   PrivateSubnet2
              |             |
              v             v
          EKS Node 1     EKS Node 2
              |             |
              +------+------+
                     |
                  Kubernetes
```

So your existing eks.yaml does not need to be modified just to use the NAT Gateway. It already receives:

```
PrivateSubnet1Id
PrivateSubnet2Id
```

and those subnets now have outbound Internet connectivity through the VPC's private route table.

One important architectural point

Your current design has one private route table shared by both AZs and one NAT Gateway in AZ 1:

```
AZ 1                         AZ 2

PrivateSubnet1              PrivateSubnet2
     |                            |
     +------------+---------------+
                  |
          PrivateRouteTable
                  |
                  v
             NAT Gateway
              AZ 1
                  |
                  v
          Internet Gateway
```

That is perfectly reasonable for your learning lab and saves NAT Gateway cost.

For a production-style HA design later, I would change it to:

```
AZ 1                              AZ 2

PrivateSubnet1                    PrivateSubnet2
      |                                  |
      v                                  v
PrivateRouteTable1              PrivateRouteTable2
      |                                  |
      v                                  v
NAT Gateway 1                    NAT Gateway 2
      |                                  |
      +------------+---------------------+
                   |
            Internet Gateways
```

But I would not add that complexity to your current lab yet. Your one-NAT design is a good fit for the EKS lab you're building.
---
### RDS does NOT need Internet access

This is important because you might think:

"If private subnets have no Internet, RDS will fail."

No.

RDS does not need Internet access for normal database connectivity.

Your application can communicate:

```
EC2
 |
 | TCP 3306
 v
RDS
```

because both are inside the VPC.

So:

```
Private subnet
      |
      X Internet
```

does not mean:

```
Private subnet
      X internal VPC communication
```

Your VPC still provides private networking between resources.

Result: ✅ RDS design is fine without NAT

---
### Final dependency map

Your current architecture now looks like this:

```
                    Terraform
                        |
                        | creates/manages
                        v
              CloudFormation Main Stack
                        |
        +---------------+----------------+
        |               |                |
        v               v                v
     VPCStack         EC2Stack        EKSStack
        |               |                |
        |               |                |
        |               |                |
        |         PublicSubnet1    PrivateSubnet1
        |               |          PrivateSubnet2
        |               |                |
        |               v                v
        |              EC2             EKS
        |               |
        |               |
        |               +------3306------+
        |                              |
        v                              v
PrivateSubnet1 ---------------------- RDS
PrivateSubnet2
        |
        v
   RDS Subnet Group
```

And:

```
EC2 Security Group
       |
       | TCP 3306
       v
RDS Security Group
```

This part is very good.

### VPC verdict

Your new VPC design is correct for this lab:

```
Internet
   |
  IGW
   |
Public Subnets
   |
   +--> EC2
   |
   +--> NAT Gateway
          |
          v
    Private Route Table
          |
    +-----+-----+
    |           |
Private 1   Private 2
    |           |
   EKS         RDS
```

#### The important improvements are:

✅ PublicSubnet1/2 have MapPublicIpOnLaunch: true
✅ Public route → IGW
✅ Private subnets have MapPublicIpOnLaunch: false
✅ Private route → NAT Gateway
✅ NAT Gateway is correctly inside PublicSubnet1
✅ Private subnets are in two AZs
✅ EKS private nodes now have outbound Internet access
✅ RDS remains private
✅ EC2 gets PublicSubnet1Id
✅ EKS gets both private subnet IDs
✅ RDS gets both private subnet IDs
✅ Required VPC outputs still match main.yaml

---
### ECS & VPC Networking

#### Your vpc.yaml already supports this

You do not need to redesign the VPC for this ECS/ALB architecture.

Your existing subnets map perfectly:

```
VPC 10.0.0.0/16
│
├── PublicSubnet1  10.0.1.0/24
│      └── ALB
│
├── PublicSubnet2  10.0.2.0/24
│      └── ALB
│
├── PrivateSubnet1 10.0.11.0/24
│      └── ECS Fargate
│
└── PrivateSubnet2 10.0.12.0/24
       └── ECS Fargate
```

And your existing NAT architecture gives the private ECS tasks outbound connectivity:

```
ECS Task
   |
   v
Private Subnet
   |
   v
Private Route Table
   |
   v
NAT Gateway
   |
   v
Public Subnet 1
   |
   v
Internet Gateway
   |
   v
Internet
```

```
Internet → ALB → Target Group → private ECS Fargate → NAT → ECR/AWS APIs
```

The important point is that NAT is outbound only. Internet users cannot use the NAT Gateway to directly reach your ECS tasks.

### ECS — important things to verify

Your network must actually match this:

```
                    INTERNET
                       |
                       v
                Internet Gateway
                       |
                +------+------+
                |             |
           Public Subnet  Public Subnet
                |             |
                +------+------+
                       |
                      ALB
                       |
                 Target Group
                       |
                TCP 80 only
                       |
              +--------+--------+
              |                 |
        Private Subnet     Private Subnet
              |                 |
          ECS Task          ECS Task
              |                 |
              +--------+--------+
                       |
                  NAT Gateway
                       |
                  Internet
```

#### Verify:

- Public subnets have route → Internet Gateway ✅

- Private subnets have route → NAT Gateway ✅
- NAT Gateway exists in your vpc.yaml ✅

- ALB is in public subnets ✅

- ECS is in private subnets ✅

- ECS SG allows port 80 only from ALB SG ✅

- ALB SG allows port 80 from internet ✅

Your ECS template assumes all of these.
---
### EKS

Your EKS architecture is valid:

```
EKS
 |
 +-- Control Plane
 |
 +-- Private Subnet 1
 |
 +-- Private Subnet 2
 |
 +-- Managed Node Group
```

And you're correctly using:

```
AmiType: AL2023_x86_64_STANDARD
```

That's good. AWS recommends AL2023 rather than the now-retired EKS AL2 path.
---
### ECS & ECR Architecture

```
                 HYBRID IaC LAB
                       |
          +------------+------------+
          |                         |
          v                         v
       ECR STACK                ECS STACK
       ecr.yaml                 ecs.yaml
          |                         |
          |                         |
          v                         v
   ECR Repository             ECS Cluster
   hybridiaclab-dev-app            |
          |                         |
          |                         v
          |                    Task Definition
          |                         |
          |                    EcrImageUri
          |                         |
          +-------------------------+
                                    |
                                    v
                              ECS Fargate
                                    |
                                    v
                            Private Subnets
                                    |
                                    v
                                  ALB
                                    |
                                    v
                                Internet
```

The important interface between them is:

```
ECR Output
    |
    | RepositoryUri
    v
GitHub Actions
    |
    | RepositoryUri + COMMIT_SHA
    v
EcrImageUri
    |
    v
ecs.yaml
```
## NAT & ECS

For your lab, I suggest this mental model:

Internet
   |
Internet Gateway
   |
Public Subnet
   |
NAT Gateway
   |
Private Route Table
   |
Private Subnet
   |
ECS Fargate
Professional approach
vpc.yaml → owns VPC, subnets, route tables, IGW, NAT Gateway, and private routes.
ecs.yaml → only consumes the private subnet IDs.
ecr.yaml → owns ECR repository and lifecycle policy.
eks.yaml → consumes the VPC/private subnets and uses its node IAM role.
iam.tf → owns the IAM permissions/trust relationships that Terraform manages.

So I would not add NAT resources to ecs.yaml.

The important thing is to verify that vpc.yaml actually has:

```
Private Route Table
        |
        +--> 0.0.0.0/0
                 |
                 v
            NAT Gateway
                 |
                 v
         Internet Gateway
```
One important learning point

NAT Gateway is not strictly required for every ECS private-subnet workload. For example, you can use VPC endpoints for services such as ECR/CloudWatch Logs and avoid Internet NAT for those paths.

But with your current architecture, where private ECS tasks may need general outbound Internet access, NAT Gateway is the correct design.

My recommendation: keep your ecs.yaml as the application/container layer and make vpc.yaml responsible for proving the private-subnet → NAT connectivity. That separation is the more professional IaC design.

do not attach the NAT Gateway directly to ECS.

Professional design:

```
ECS tasks → Private Subnet → Private Route Table → NAT Gateway → Internet Gateway → Internet
```

VPC owns the NAT Gateway and routing.
ECS only uses the private subnets.
AssignPublicIp: DISABLED remains correct.

So your current separation is correct.
---
### Your ECS private-subnet design is correct

You do not need to modify ECS to attach NAT Gateway.

Your flow is correct:

```
Internet
   ↓
ALB — Public Subnets
   ↓
ECS Fargate — Private Subnets
   ↓
Private Route Table
   ↓
NAT Gateway
   ↓
Internet
```

---
### Recommended final architecture

After fixing the workflow, your complete deployment flow will be:

```
                    GitHub
                       |
                       v
              GitHub Actions
                       |
                 OIDC Authentication
                       |
                       v
                AWS IAM Role
                       |
             +---------+---------+
             |                   |
             v                   v
          Docker                AWS
          Build                 APIs
             |                   |
             v                   |
          ECR Push <-------------+
             |
             | Image: GITHUB_SHA
             v
       ECR Repository
       hybridiaclab-dev-app
             |
             v
     Get CloudFormation
        Network Outputs
             |
       +-----+-----+
       |           |
       v           v
    Public       Private
    Subnet       Subnet
       |           |
       |           v
       |       ECS Fargate
       |           |
       v           |
       ALB <-------+
       |
       v
    Internet
```

### ECR + ECS + Docker

```
                 VPC
                  |
       +----------+----------+
       |                     |
       v                     v
 PUBLIC SUBNETS         PRIVATE SUBNETS
       |                     |
       v                     v
      ALB                ECS Fargate
                             |
                             v
                       NAT Gateway
                             |
                             v
                          Internet
```
Final 100% Match Contract

After that correction, your intended contract is:

┌──────────────────────────────────────────────┐
│                 ecr.yaml                     │
│                                              │
│ Creates:                                     │
│   hybridiaclab-dev-app                       │
│                                              │
│ Outputs:                                     │
│   RepositoryUri                              │
│   RepositoryArn                              │
│   RepositoryName                             │
└───────────────────┬──────────────────────────┘
                    │
                    │ RepositoryUri
                    ▼
┌──────────────────────────────────────────────┐
│               docker.yml                     │
│                                              │
│ Gets RepositoryUri from AWS                  │
│                                              │
│ GITHUB_SHA                                   │
│     │                                        │
│     ▼                                        │
│ Docker Build                                 │
│     │                                        │
│     ▼                                        │
│ RepositoryUri:GITHUB_SHA                     │
│     │                                        │
│     ▼                                        │
│ ECR Push                                     │
│                                              │
│ Then passes:                                 │
│                                              │
│ EcrRepositoryUri = RepositoryUri             │
│ ImageTag         = GITHUB_SHA                │
└───────────────────┬──────────────────────────┘
                    │
                    │
                    ▼
┌──────────────────────────────────────────────┐
│                  ecs.yaml                    │
│                                              │
│ Parameters:                                  │
│   EcrRepositoryUri                           │
│   ImageTag                                   │
│                                              │
│ Image:                                       │
│   ${EcrRepositoryUri}:${ImageTag}             │
│                                              │
│     ▼                                        │
│ ECS Task Definition                           │
│     ▼                                        │
│ ECS Fargate                                   │
│     ▼                                        │
│ Target Group                                  │
│     ▼                                        │
│ ALB                                           │
└──────────────────────────────────────────────┘
```

