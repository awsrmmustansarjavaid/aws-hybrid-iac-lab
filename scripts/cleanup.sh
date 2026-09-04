#!/bin/bash

# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# Docker Cleanup Script
# ==========================================================
#
# IMPORTANT:
#
# This script only cleans Docker resources on the EC2
# machine.
#
# It does NOT delete AWS infrastructure.
#
# AWS infrastructure should be destroyed using:
#
# GitHub Actions
#       |
#       v
# delete.yml
#
# or:
#
# terraform destroy
#
# ==========================================================

set -e


echo "=================================================="
echo " Docker Cleanup"
echo "=================================================="


# ----------------------------------------------------------
# Stop application container
# ----------------------------------------------------------

echo ""
echo ">>> Stopping application container..."

docker rm -f hybrid-iac-app 2>/dev/null || true


# ----------------------------------------------------------
# Remove dangling images
# ----------------------------------------------------------

echo ""
echo ">>> Removing dangling Docker images..."

docker image prune -f


# ----------------------------------------------------------
# Display remaining containers
# ----------------------------------------------------------

echo ""
echo ">>> Remaining containers:"

docker ps -a


# ----------------------------------------------------------
# Display remaining images
# ----------------------------------------------------------

echo ""
echo ">>> Remaining images:"

docker images


echo ""
echo "=================================================="
echo " Docker cleanup completed."
echo "=================================================="