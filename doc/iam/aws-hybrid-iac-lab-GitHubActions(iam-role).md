#aws-hybrid-iac-lab-GitHubActions


## trust policy

```
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
```


## IAM Policy 

- 1. aws-hybrid-iac-lab-GitHubActionsPolicy

- 2. github-actions-terraform-backend-policy

- 

----

