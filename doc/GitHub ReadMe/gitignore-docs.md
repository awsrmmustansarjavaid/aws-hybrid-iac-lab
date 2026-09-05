# Fixing `.gitignore` So Markdown Files Inside `doc/` Are Not Ignored

Yes — the problem is this section:

```gitignore
doc/*
*.pdf
*.doc
*.docx
```

The `doc/*` rule ignores **everything inside `doc/`**, including `.md` files and subdirectories such as:

```text
doc/
├── GitHub ReadMe/
│   ├── README.md
│   └── setup.md
├── Terraform/
│   └── terraform-guide.md
└── CloudFormation/
    └── cloudformation-guide.md
```

## Recommended Solution

If your goal is:

* Keep `doc/` in Git
* Keep **all `.md` files** inside `doc/`
* Keep `.md` files inside **subdirectories of `doc/`**
* Still ignore generated documents such as `.pdf`, `.doc`, `.docx`

Then **remove this line**:

```gitignore
doc/*
```

You don't need it.

Your documentation section should become:

```gitignore
# =======================================================
# DOCUMENTATION / GENERATED DOCUMENTS
# =======================================================
#
# Markdown documentation is intentionally tracked by Git.
#
# This includes Markdown files directly inside doc/
# and Markdown files inside any subdirectories of doc/.
#
# Generated binary documents are ignored.
# =======================================================

*.pdf
*.doc
*.docx
```

## Your `doc/` Directory Will Then Work Like This

For example:

```text
doc/
│
├── GitHub ReadMe/
│   ├── README.md
│   ├── GitHub-Setup.md
│   └── GitHub-Actions.md
│
├── Terraform/
│   ├── Terraform-Guide.md
│   └── Terraform-Commands.md
│
├── CloudFormation/
│   └── CloudFormation-Guide.md
│
├── AWS/
│   └── AWS-Architecture.md
│
└── generated-report.pdf
```

Git will track:

```text
doc/GitHub ReadMe/README.md
doc/GitHub ReadMe/GitHub-Setup.md
doc/GitHub ReadMe/GitHub-Actions.md
doc/Terraform/Terraform-Guide.md
doc/Terraform/Terraform-Commands.md
doc/CloudFormation/CloudFormation-Guide.md
doc/AWS/AWS-Architecture.md
```

But it will ignore:

```text
doc/generated-report.pdf
anything.pdf
anything.doc
anything.docx
```

---

## What About `*.md` Files Elsewhere?

Your current `.gitignore` **does not contain**:

```gitignore
*.md
```

So Markdown files are **not globally ignored**.

For example, these will also be tracked:

```text
README.md
CONTRIBUTING.md
docs.md
doc/GitHub ReadMe/README.md
doc/Terraform/terraform-guide.md
```

That's exactly what you want for a documentation-heavy project.

---

## If You Want to Keep `doc/*`

Technically, you can also use an exception rule.

For example:

```gitignore
doc/*
!doc/**/*.md
```

But I **do not recommend this for your project**.

Why?

Because Git's ignore rules can become unnecessarily complicated when you have nested directories.

For your structure, the cleanest solution is simply:

### Remove

```gitignore
doc/*
```

### Keep

```gitignore
*.pdf
*.doc
*.docx
```

Then Git naturally tracks your Markdown documentation.

---

## One More Important Point: Git Already Ignored the Files?

If you already ran `git add` previously while `doc/` was being ignored, changing `.gitignore` may not automatically make everything appear in your staging area depending on the existing Git state.

Run:

```powershell
git status
```

Then:

```powershell
git add .gitignore
git add doc
```

Check:

```powershell
git status
```

You should now see your Markdown files under `doc/`.

---

## Recommended Final Section

I would use this exact section in your `.gitignore`:

```gitignore
# =======================================================
# DOCUMENTATION / GENERATED DOCUMENTS
# =======================================================
#
# Markdown documentation files are intentionally tracked.
#
# This includes:
#   - Markdown files in doc/
#   - Markdown files in doc subdirectories
#   - README.md files
#   - Project documentation
#
# Generated binary documents are ignored.
# =======================================================

*.pdf
*.doc
*.docx
```

## Final Answer

**Delete this:**

```gitignore
doc/*
```

**Do not add `*.md` to `.gitignore`.**

Your `doc/` folder can then contain unlimited nested directories and Markdown files:

```text
doc/
├── GitHub ReadMe/
│   ├── README.md
│   └── GitHub-Actions.md
├── Terraform/
│   └── Terraform.md
├── CloudFormation/
│   └── CloudFormation.md
└── AWS/
    └── AWS-Services.md
```

All `.md` files will be committed normally.
