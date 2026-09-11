# GitHub Repository Setup Guide — AWS Hybrid IaC Lab

Your local repository is fine. The problem is simply that GitHub CLI (`gh`) is not installed or isn't in your Windows PATH.

You already have normal Git installed:

```
git version 2.50.1.windows.1
```

You have two good ways to create/push the GitHub repository. Since you're learning Git/GitHub, **Option 1** is recommended because it doesn't require installing another tool.

---

## Option 1 — Use Git + GitHub Website

### Step 1 — Initialize the Local Repository

You're already inside:

```
C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab
```

Run:

```
git init
```

Then:

```
git branch -M main
```

### Step 2 — Check What Git Sees

```
git status
```

You should see your folders such as:

```
.github
doc
docker
infrastructure
kubernetes
scripts
README.md
.dockerignore
.gitignore
```

### Step 3 — Add Everything

```
git add .
```

Then check:

```
git status
```

Everything you want committed should appear under:

```
Changes to be committed:
```

### Step 4 — Create Your First Commit

```
git commit -m "Initial commit - AWS Hybrid IaC Lab"
```

### Step 5 — Create the GitHub Repository

Open GitHub in your browser and create a new repository named exactly:

```
aws-hybrid-iac-lab
```

Recommended settings:

- **Repository name:** `aws-hybrid-iac-lab`
- **Description:** AWS Hybrid Infrastructure as Code and DevOps Lab
- **Visibility:** Public if this is your portfolio
- **Do NOT** initialize with README
- **Do NOT** add `.gitignore`
- **Do NOT** add a license

The reason is that you already have `README.md` and `.gitignore` locally.

### Step 6 — Connect Your Local Repo to GitHub

After creating the empty GitHub repository, GitHub will show you a repository URL similar to:

```
https://github.com/YOUR-USERNAME/aws-hybrid-iac-lab.git
```

Run:

```
git remote add origin https://github.com/YOUR-USERNAME/aws-hybrid-iac-lab.git
```

For example, if your GitHub username is `awsrmmustansarjavaid`:

```
git remote add origin https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git
```

Verify:

```
git remote -v
```

You should get something like:

```
origin  https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git (fetch)
origin  https://github.com/awsrmmustansarjavaid/aws-hybrid-iac-lab.git (push)
```

### Step 7 — Push Your Local Repository

Run:

```
git push -u origin main
```

GitHub may ask you to authenticate.

> **Note:** Do not use your GitHub account password as the Git password. GitHub's normal HTTPS Git authentication uses a credential mechanism such as Git Credential Manager or a personal access token.

Once authentication succeeds, you should see something similar to:

```
Enumerating objects...
Counting objects...
Writing objects...
branch 'main' set up to track 'origin/main'
```

Then refresh your GitHub repository. Your structure should appear online:

```
aws-hybrid-iac-lab/
│
├── .github/
├── doc/
├── docker/
├── infrastructure/
├── kubernetes/
├── scripts/
│
├── .dockerignore
├── .gitignore
└── README.md
```

---

## Option 2 — Install GitHub CLI (gh)

Your error:

```
gh : The term 'gh' is not recognized
```

means Windows cannot find the GitHub CLI.

You can install GitHub CLI from the official GitHub documentation (GitHub CLI installation page).

After installing it, close PowerShell and open a new PowerShell window.

Check:

```
gh --version
```

Then:

```
gh auth login
```

Choose:

- GitHub.com
- HTTPS
- Login with a web browser

After authentication:

```
gh auth status
```

Then from your repository:

```
gh repo create aws-hybrid-iac-lab --public --source=. --remote=origin --push
```

That single command can create the GitHub repository and push your existing local repository.

---

## Recommended Sequence

Because your local project is already prepared, use this sequence:

```
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"

git init
git branch -M main
git status
git add .
git status
git commit -m "Initial commit - AWS Hybrid IaC Lab"
```

Then create the empty `aws-hybrid-iac-lab` repository on GitHub, followed by:

```
git remote add origin https://github.com/YOUR-USERNAME/aws-hybrid-iac-lab.git
git remote -v
git push -u origin main
```

Don't install `gh` just to accomplish this. Normal Git is already installed and is enough.

---

## Important Note on Secrets

Before running `git add .`, because this is an AWS/Terraform project, make sure your `.gitignore` excludes things such as:

- `.terraform/`
- `*.tfstate`
- `*.tfstate.*`
- `.env`
- Private keys
- AWS credentials

Your displayed `.gitignore` is already present, so verify it before you push if you want to avoid accidentally committing secrets.
