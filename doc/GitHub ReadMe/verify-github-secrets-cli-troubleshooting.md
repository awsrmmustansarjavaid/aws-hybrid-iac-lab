# Verifying GitHub Actions Secrets/Variables and Fixing GitHub CLI PATH Issues

## Part 1 — Verify GitHub Actions Secret and Variable Using PowerShell

Yes. You can verify whether they exist from PowerShell without displaying the secret value.

### 1. Verify `AWS_ROLE_ARN` Secret

GitHub CLI (`gh`) does not allow you to retrieve the secret's value, but it can confirm whether the secret exists.

First make sure you're authenticated:

```powershell
gh auth status
```

Then run:

```powershell
gh secret list
```

Look for:

```text
AWS_ROLE_ARN
```

**More direct check**

Run:

```powershell
gh secret list --json name --jq ".[] | select(.name == \"AWS_ROLE_ARN\") | .name"
```

If it exists, you should get:

```text
AWS_ROLE_ARN
```

If nothing is returned, it doesn't exist.

You can therefore report:

```text
AWS_ROLE_ARN exists: YES
```

or:

```text
AWS_ROLE_ARN exists: NO
```

> **Important:** Do not run commands that attempt to print the secret value.

### 2. Verify `AWS_REGION` Repository Variable

Run:

```powershell
gh variable list
```

Look for:

```text
AWS_REGION
```

Or use this direct check:

```powershell
gh variable list --json name --jq ".[] | select(.name == \"AWS_REGION\") | .name"
```

If it exists:

```text
AWS_REGION
```

Then report:

```text
AWS_REGION exists: YES
```

If nothing is returned:

```text
AWS_REGION exists: NO
```

### 3. Check Both at Once

You can use this PowerShell block:

```powershell
Write-Host "Checking GitHub Actions configuration..."
Write-Host ""

$roleSecret = gh secret list --json name --jq ".[] | select(.name == `"AWS_ROLE_ARN`") | .name"
$regionVariable = gh variable list --json name --jq ".[] | select(.name == `"AWS_REGION`") | .name"

if ($roleSecret -eq "AWS_ROLE_ARN") {
    Write-Host "AWS_ROLE_ARN exists: YES"
} else {
    Write-Host "AWS_ROLE_ARN exists: NO"
}

if ($regionVariable -eq "AWS_REGION") {
    Write-Host "AWS_REGION exists: YES"
} else {
    Write-Host "AWS_REGION exists: NO"
}
```

Expected output:

```text
Checking GitHub Actions configuration...

AWS_ROLE_ARN exists: YES
AWS_REGION exists: YES
```

This checks only the names. It does not print the `AWS_ROLE_ARN` secret value, which is what you want.

### If `gh` Is Not Recognized

Check:

```powershell
gh --version
```

If PowerShell says that `gh` is not recognized, GitHub CLI isn't installed or isn't in your PATH.

---

## Part 2 — The Problem: GitHub CLI (`gh`) Is Not Installed

Your AWS/Git repository is not the problem.

PowerShell is telling you:

```
gh : The term 'gh' is not recognized...
```

That means GitHub CLI (`gh`) is either not installed or not available in your Windows PATH.

### Step 1 — Confirm GitHub CLI Is Missing

Run:

```powershell
Get-Command gh -ErrorAction SilentlyContinue
```

If it returns nothing, `gh` is not available.

### Step 2 — Install GitHub CLI

Since you're using Windows PowerShell, the easiest method is Windows Package Manager (`winget`).

Run:

```powershell
winget install --id GitHub.cli
```

If it asks you to accept agreements, answer:

```
Y
```

Wait until installation finishes.

### Step 3 — Restart PowerShell

Close your current PowerShell window completely.

Then open a new PowerShell window.

Go back to your project:

```powershell
cd "C:\Users\musta\Downloads\AWS-Labs\aws-hybrid-iac-lab"
```

Now verify:

```powershell
gh --version
```

You should see something similar to:

```
gh version 2.x.x
```

### Step 4 — Authenticate GitHub CLI

Run:

```powershell
gh auth login
```

Choose approximately:

```
GitHub.com
HTTPS
Login with a web browser
```

GitHub will give you a one-time code and open your browser.

After authentication, verify:

```powershell
gh auth status
```

You should see that you are logged in.

### Step 5 — Verify `AWS_ROLE_ARN`

Now run:

```powershell
gh secret list
```

You should see:

```
AWS_ROLE_ARN
```

Do not worry if the secret's value isn't displayed. That's intentional.

For a cleaner check:

```powershell
gh secret list --json name --jq '.[] | select(.name == "AWS_ROLE_ARN") | .name'
```

If it exists:

```
AWS_ROLE_ARN
```

Therefore:

```
AWS_ROLE_ARN exists: YES
```

If nothing is returned:

```
AWS_ROLE_ARN exists: NO
```

### Step 6 — Verify `AWS_REGION`

Run:

```powershell
gh variable list
```

Or directly:

```powershell
gh variable list --json name --jq '.[] | select(.name == "AWS_REGION") | .name'
```

If it returns:

```
AWS_REGION
```

then:

```
AWS_REGION exists: YES
```

### Step 7 — Check Both at Once

After `gh` is installed and authenticated, this is the simplest command I recommend:

```powershell
Write-Host "Checking GitHub Actions configuration..."
Write-Host ""

$role = gh secret list --json name --jq '.[] | select(.name == "AWS_ROLE_ARN") | .name'
$region = gh variable list --json name --jq '.[] | select(.name == "AWS_REGION") | .name'

if ($role -eq "AWS_ROLE_ARN") {
    Write-Host "AWS_ROLE_ARN exists: YES"
}
else {
    Write-Host "AWS_ROLE_ARN exists: NO"
}

if ($region -eq "AWS_REGION") {
    Write-Host "AWS_REGION exists: YES"
}
else {
    Write-Host "AWS_REGION exists: NO"
}
```

Expected:

```text
Checking GitHub Actions configuration...

AWS_ROLE_ARN exists: YES
AWS_REGION exists: YES
```

> **Important:** This procedure does not reveal your `AWS_ROLE_ARN` secret value. It only checks whether the secret name exists.

### Do This Now

First, run this now:

```powershell
winget install --id GitHub.cli
```

Then restart PowerShell and run:

```powershell
gh --version
```

If you paste the output of those two commands here, I can tell you the exact next command.

---

## Part 3 — GitHub CLI Installed, But PowerShell Cannot Find It

Good news: GitHub CLI installed successfully. Your problem now is only that the current PowerShell session does not have the updated PATH.

The important line is:

```
Successfully installed
```

But PowerShell still says:

```
gh : The term 'gh' is not recognized...
```

### Step 1 — Close PowerShell Completely

Close this PowerShell window.

Then open a brand-new PowerShell window.

Run:

```powershell
gh --version
```

You should now get something like:

```
gh version 2.100.0 (2026-...)
```

### If It Still Says `gh` Is Not Recognized

Don't reinstall it. Let's find exactly where Windows installed it.

Run:

```powershell
where.exe gh
```

If that returns nothing, run:

```powershell
Get-ChildItem "C:\Program Files\GitHub CLI" -Filter gh.exe -Recurse -ErrorAction SilentlyContinue
```

You should hopefully get something similar to:

```
C:\Program Files\GitHub CLI\gh.exe
```

### Step 2 — Test `gh.exe` Directly

If you get:

```
C:\Program Files\GitHub CLI\gh.exe
```

run:

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" --version
```

If that works, we have confirmed:

> GitHub CLI is installed correctly; only PATH is missing.

### Step 3 — Temporarily Fix PATH

Run:

```powershell
$env:Path += ";C:\Program Files\GitHub CLI"
```

Then:

```powershell
gh --version
```

If you now get:

```
gh version 2.100.0
```

you're ready.

### Step 4 — Make the PATH Fix Permanent

If the temporary fix works, run:

```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Program Files\GitHub CLI",
    "User"
)
```

Then close PowerShell and open it again.

Verify:

```powershell
gh --version
```

### Step 5 — Authenticate

Once `gh --version` works:

```powershell
gh auth login
```

Choose:

```
GitHub.com
HTTPS
Login with a web browser
```

Then verify:

```powershell
gh auth status
```

### Step 6 — Finally Check Your Secret and Variable

**Check `AWS_ROLE_ARN`**

```powershell
gh secret list --json name --jq '.[] | select(.name == "AWS_ROLE_ARN") | .name'
```

Expected:

```
AWS_ROLE_ARN
```

Therefore:

```
AWS_ROLE_ARN exists: YES
```

**Check `AWS_REGION`**

```powershell
gh variable list --json name --jq '.[] | select(.name == "AWS_REGION") | .name'
```

Expected:

```
AWS_REGION
```

Therefore:

```
AWS_REGION exists: YES
```

> Do not run any command that prints the secret value.

### Do This Now

I recommend not changing anything else yet. Run these three commands in your current PowerShell:

```powershell
where.exe gh
Get-ChildItem "C:\Program Files\GitHub CLI" -Filter gh.exe -Recurse -ErrorAction SilentlyContinue
& "C:\Program Files\GitHub CLI\gh.exe" --version
```

The third command is especially useful because it will tell us whether the installation itself is working, without depending on PATH.
