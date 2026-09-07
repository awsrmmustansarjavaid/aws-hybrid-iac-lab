GitHub Variables you need to create

At the top of the workflow comments, I added instructions explaining:

Go to your GitHub repository.
Settings → Secrets and variables → Actions
Select Variables
Create:
Name: AWS_ACCOUNT_ID
Value: XXXX11233467
Create:
Name: AWS_ROLE_ARN
Value: arn:aws:iam::your aws account id:role/aws-hybrid-iac-lab-GitHubActions

The workflow then receives them with:

${{ vars.AWS_ACCOUNT_ID }}
${{ vars.AWS_ROLE_ARN }}

I deliberately keep them out of the workflow-level env: block. Instead, they are mapped at the job level from GitHub Variables so your existing Bash validation can continue using $AWS_ACCOUNT_ID and $AWS_ROLE_ARN.