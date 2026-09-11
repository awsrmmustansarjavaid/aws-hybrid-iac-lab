# Publishing an Existing Local Repository via PowerShell + GitHub CLI

Since you already have the complete local folder **`aws-hybrid-iac-lab`**, you can create the GitHub repository and push everything directly from **PowerShell**.

The easiest method is **GitHub CLI (`gh`)**. GitHub officially supports publishing an existing local repository this way. ([GitHub Docs][1])

---

## Option 1 — Recommended: PowerShell + GitHub CLI

### 1. Open PowerShell and Enter Your Project Directory

For example, if your project is under `Downloads\AWS-Labs`:

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"
```

Verify:

```powershell
Get-ChildItem
```

You should see something like:

```text
README.md
docker
infrastructure
scripts
...
```

---

### 2. Check Git

```powershell
git --version
```

You should get something like:

```text
git version 2.x.x
```

Also check GitHub CLI:

```powershell
gh --version
```

If `gh` is installed, continue.

If not, install **GitHub CLI** from the official GitHub documentation/site. ([GitHub Docs][2])

---

### 3. Login to GitHub

Run:

```powershell
gh auth login
```

You'll be asked something similar to:

```text
? What account do you want to log into?
> GitHub.com

? What is your preferred protocol for Git operations?
> HTTPS

? Authenticate Git with your GitHub credentials?
> Yes

? How would you like to authenticate GitHub CLI?
> Login with a web browser
```

Choose:

```text
GitHub.com
HTTPS
Yes
Login with a web browser
```

Then follow the browser authentication.

Verify:

```powershell
gh auth status
```

You should see that you're logged in.

---

### 4. Initialize Your Local Repository

From inside:

```text
aws-hybrid-iac-lab
```

run:

```powershell
git init -b main
```

GitHub recommends initializing an existing local project and then committing the files before pushing them. ([GitHub Docs][1])

Check:

```powershell
git status
```

You should see your files listed as untracked if this directory wasn't already a Git repository.

---

### 5. VERY IMPORTANT — Check for Secrets

Because your project is an **AWS/Terraform lab**, do this **before** `git add`.

Run:

```powershell
Get-ChildItem -Force
```

Look for:

```text
.env
terraform.tfvars
*.pem
*.key
credentials
secrets
```

For Terraform specifically, make sure you aren't committing things such as:

```text
terraform.tfstate
terraform.tfstate.backup
*.tfvars
```

if they contain credentials, secrets, or other sensitive values.

A good `.gitignore` for your project could include:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
crash.log
crash.*.log

# AWS credentials
.aws/
credentials
config

# Environment / secrets
.env
.env.*
!.env.example

# Private keys
*.pem
*.key

# OS files
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/

# Logs
*.log
```

**Do not commit AWS access keys, secret keys, passwords, database credentials, private keys, or Terraform state containing secrets.** GitHub explicitly warns against pushing sensitive information. ([GitHub Docs][3])

---

### 6. Stage Your Project

Once your `.gitignore` is correct:

```powershell
git add .
```

Check what will be committed:

```powershell
git status
```

This step is **very important**.

You want to see your project files, for example:

```text
new file:   README.md
new file:   infrastructure/terraform/main.tf
new file:   infrastructure/terraform/variables.tf
new file:   docker/app/Dockerfile
...
```

You **do not** want to see:

```text
terraform.tfstate
terraform.tfstate.backup
.aws/credentials
.env
something.pem
```

---

### 7. Create Your First Commit

```powershell
git commit -m "Initial commit - AWS Hybrid IaC Lab"
```

Then:

```powershell
git branch -M main
```

---

### 8. Create the GitHub Repository and Push Everything

This is the nice part.

Run:

```powershell
gh repo create aws-hybrid-iac-lab --public --source=. --remote=origin --push
```

This tells GitHub CLI:

```text
gh repo create
        │
        ├── aws-hybrid-iac-lab
        │
        ├── --public
        │      Create a public repository
        │
        ├── --source=.
        │      Use current local directory
        │
        ├── --remote=origin
        │      Configure GitHub as origin
        │
        └── --push
               Push local commits
```

GitHub documents this exact approach for pushing an existing local repository with `gh repo create --source=.`, a visibility flag, `--remote`, and `--push`. ([GitHub Docs][1])

---

### 9. Verify the Remote

Run:

```powershell
git remote -v
```

You should see something like:

```text
origin  https://github.com/YOUR-USERNAME/aws-hybrid-iac-lab.git (fetch)
origin  https://github.com/YOUR-USERNAME/aws-hybrid-iac-lab.git (push)
```

Then:

```powershell
git branch
```

You should see:

```text
* main
```

And:

```powershell
git status
```

Ideally:

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

---

### 10. Open Your GitHub Repository

You can also run:

```powershell
gh repo view --web
```

That should open your new repository in your browser.

Your final structure will essentially be:

```text
GitHub
   │
   ▼
aws-hybrid-iac-lab
   │
   ├── README.md
   ├── .gitignore
   │
   ├── docker/
   │   └── app/
   │
   ├── infrastructure/
   │   ├── terraform/
   │   └── ...
   │
   └── ...
```

---

## Option 2 — If You DON'T Have GitHub CLI

You can also do it using normal Git.

First create an **empty** repository on GitHub named:

```text
aws-hybrid-iac-lab
```

When creating it, **do not select**:

- Add README
- Add `.gitignore`
- Add license

because you already have the project locally. GitHub recommends leaving those initialization options unchecked when importing an existing local repository to avoid unnecessary merge conflicts. ([GitHub Docs][4])

Then PowerShell:

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"

git init -b main

git add .

git commit -m "Initial commit - AWS Hybrid IaC Lab"

git remote add origin https://github.com/YOUR-GITHUB-USERNAME/aws-hybrid-iac-lab.git

git push -u origin main
```

Verify:

```powershell
git remote -v
git status
```

GitHub's official instructions use the same `git remote add origin` and `git push -u origin main` workflow. ([GitHub Docs][1])

---

## My Recommendation for Your Lab

Since you're building **`aws-hybrid-iac-lab`** as a portfolio/DevOps project, I'd use:

```powershell
git init -b main
git add .
git commit -m "Initial commit - AWS Hybrid IaC Lab"
gh repo create aws-hybrid-iac-lab --public --source=. --remote=origin --push
```

**But check `.gitignore` and `git status` before the `git add .` step**, especially because this is an AWS + Terraform repository.

---

## References

[1]: https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github "Adding locally hosted code to GitHub - GitHub Docs"
[2]: https://docs.github.com/en/github-cli/github-cli/quickstart "GitHub CLI quickstart - GitHub Docs"
[3]: https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository "Adding a file to a repository - GitHub Docs"
[4]: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository "Creating a new repository - GitHub Docs"
