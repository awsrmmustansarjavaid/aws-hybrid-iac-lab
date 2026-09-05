# lab architecture design

Your current iam.tf already explains the intended design:

```
GitHub Actions
      │
      │ OIDC
      ▼
GitHubActions Role
      │
      ▼
Terraform
      │
      ├── CloudFormation Execution Role
      │
      ├── Template S3 Bucket
      │
      └── CloudFormation Root Stack
```

And your main.yaml correctly does:

```
main.yaml
   │
   ├── VPCStack
   │      └── nested/vpc.yaml
   │
   ├── S3Stack
   │      └── nested/s3.yaml
   │
   ├── DynamoDBStack
   │      └── nested/dynamodb.yaml
   │
   └── ECRStack
          └── nested/ecr.yaml
```

That's a good hybrid-IaC design.

----

