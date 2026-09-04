#!/bin/bash

# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# EC2 Initial Setup Script
# ==========================================================
#
# PURPOSE:
# This script prepares an Amazon Linux EC2 instance for
# DevOps and AWS practice.
#
# It installs:
#
#   1. Git
#   2. AWS CLI
#   3. Docker
#   4. Useful Linux utilities
#
# It also:
#
#   - Starts Docker
#   - Enables Docker at boot
#   - Adds ec2-user to the docker group
#
# ==========================================================

set -e

echo "=================================================="
echo " Hybrid IaC Lab - EC2 Setup"
echo "=================================================="

# ----------------------------------------------------------
# 1. Update system packages
# ----------------------------------------------------------

echo ""
echo ">>> Updating system packages..."

sudo dnf update -y


# ----------------------------------------------------------
# 2. Install required packages
# ----------------------------------------------------------

echo ""
echo ">>> Installing required packages..."

sudo dnf install -y \
    git \
    curl \
    unzip \
    wget \
    jq \
    tree \
    vim \
    nano


# ----------------------------------------------------------
# 3. Check AWS CLI
# ----------------------------------------------------------
#
# Amazon Linux 2023 normally includes AWS CLI v2.
# If it is already installed, we don't reinstall it.
#
# ----------------------------------------------------------

echo ""
echo ">>> Checking AWS CLI..."

if command -v aws >/dev/null 2>&1; then

    echo "AWS CLI is already installed."

    aws --version

else

    echo "AWS CLI not found."

    echo "Installing AWS CLI v2..."

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "/tmp/awscliv2.zip"

    unzip -q /tmp/awscliv2.zip -d /tmp

    sudo /tmp/aws/install

    aws --version

fi


# ----------------------------------------------------------
# 4. Install Docker
# ----------------------------------------------------------

echo ""
echo ">>> Installing Docker..."

sudo dnf install -y docker


# ----------------------------------------------------------
# 5. Start Docker
# ----------------------------------------------------------

echo ""
echo ">>> Starting Docker..."

sudo systemctl start docker


# ----------------------------------------------------------
# 6. Enable Docker at system startup
# ----------------------------------------------------------

echo ""
echo ">>> Enabling Docker at boot..."

sudo systemctl enable docker


# ----------------------------------------------------------
# 7. Add ec2-user to Docker group
# ----------------------------------------------------------

echo ""
echo ">>> Adding ec2-user to Docker group..."

sudo usermod -aG docker ec2-user


# ----------------------------------------------------------
# 8. Display Docker version
# ----------------------------------------------------------

echo ""
echo ">>> Docker version:"

sudo docker --version


# ----------------------------------------------------------
# 9. Display Git version
# ----------------------------------------------------------

echo ""
echo ">>> Git version:"

git --version


# ----------------------------------------------------------
# 10. Check Docker service
# ----------------------------------------------------------

echo ""
echo ">>> Docker service status:"

sudo systemctl is-active docker


# ----------------------------------------------------------
# 11. AWS identity check
# ----------------------------------------------------------
#
# This works when the EC2 instance has an IAM role attached.
#
# We prefer an IAM role over storing AWS access keys on EC2.
#
# ----------------------------------------------------------

echo ""
echo ">>> Checking AWS identity..."

if aws sts get-caller-identity; then

    echo ""
    echo "AWS authentication is working."

else

    echo ""
    echo "WARNING: AWS authentication is not configured."

    echo "Attach an IAM role to the EC2 instance."

fi


# ----------------------------------------------------------
# 12. Finish
# ----------------------------------------------------------

echo ""
echo "=================================================="
echo " EC2 setup completed."
echo "=================================================="

echo ""
echo "IMPORTANT:"
echo "Log out and log back in so the Docker group change"
echo "takes effect."

echo ""
echo "Then test:"
echo ""
echo "docker ps"
echo ""