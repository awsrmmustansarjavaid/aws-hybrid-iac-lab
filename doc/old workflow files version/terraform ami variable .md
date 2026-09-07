# terraform ami variable 
---

```
# ============================================================
# 4. AMAZON LINUX 2023 AMI ID
# ============================================================
#
# The AMI is NOT created by the CloudFormation hierarchy.
#
# Therefore Terraform may still receive this as an external
# input.
#
# Example:
#
#   ami-0123456789abcdef0
#
#
# IMPORTANT:
#
# AMI IDs are region-specific.
#
# For this lab, the AMI must exist in:
#
#   us-east-1
#
# Recommended AWS CLI lookup:
#
# PowerShell:
#
#   aws ssm get-parameter `
#     --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
#     --query "Parameter.Value" `
#     --output text `
#     --region us-east-1
#
# ============================================================

variable "ami_id" {

  description = "Amazon Linux 2023 AMI ID used by the EC2 CloudFormation stack."

  type = string

  validation {

    condition = can(
      regex(
        "^ami-[0-9a-fA-F]{8,}$",
        trimspace(var.ami_id)
      )
    )

    error_message = "ami_id must be a valid AWS AMI ID such as ami-0123456789abcdef0."
  }
}
```

----
### terraform.tfvars


```
# ============================================================
# 4. AMAZON LINUX 2023 AMI ID
# ============================================================
#
# Replace with the current Amazon Linux 2023 AMI ID for
# your selected AWS region.
#
#
# Recommended command for us-east-1:
#
#   aws ssm get-parameter `
#     --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
#     --query "Parameter.Value" `
#     --output text `
#     --region us-east-1
#
#
# Example:
#
#   ami-0123456789abcdef0
#
# ============================================================

ami_id = data.aws_ami.amazon_linux_2023.id
```

### terraform.tfvars.example

```
# ============================================================
# 4. AMAZON LINUX 2023 AMI ID
# ============================================================
#
# Replace with the current Amazon Linux 2023 AMI ID for
# your selected AWS region.
#
#
# Recommended command for us-east-1:
#
#   aws ssm get-parameter `
#     --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" `
#     --query "Parameter.Value" `
#     --output text `
#     --region us-east-1
#
#
# Example:
#
#   ami-0123456789abcdef0
#
# ============================================================

ami_id = data.aws_ami.amazon_linux_2023.id
```

---

