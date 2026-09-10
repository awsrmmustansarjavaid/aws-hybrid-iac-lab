# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION LAB
# Docker Application Image
# ==========================================================
#
# File:
#   docker/app/Dockerfile
#
# PURPOSE:
#   Builds the Docker image used by the ECS Fargate service.
#
#   The image contains:
#
#     1. Nginx web server
#     2. Application HTML file
#     3. curl for ECS container health checks
#
# IMPORTANT:
#
#   The ECS CloudFormation template uses:
#
#     curl -f http://localhost/ || exit 1
#
#   Therefore curl MUST exist inside this final Docker image.
#
# ==========================================================


# ----------------------------------------------------------
# 1. Base Image
# ----------------------------------------------------------
#
# Use the lightweight Alpine-based Nginx image.
#
# Nginx provides the HTTP web server for this application.
#
# Alpine keeps the final image relatively small while still
# providing the functionality required by this lab.
#
# ----------------------------------------------------------

FROM nginx:alpine


# ----------------------------------------------------------
# 2. Install curl
# ----------------------------------------------------------
#
# IMPORTANT:
#
# The ECS health check defined in ecs.yaml uses:
#
#   curl -f http://localhost/
#
# Therefore curl must be installed INSIDE the container.
#
# nginx:alpine uses Alpine Linux, so the Alpine package
# manager 'apk' is used to install curl.
#
# --no-cache:
#   Prevents apk from storing unnecessary package-index files
#   in the final Docker image.
#
# ----------------------------------------------------------

RUN apk add --no-cache curl


# ----------------------------------------------------------
# 3. Application Files
# ----------------------------------------------------------
#
# Copy the application HTML file into Nginx's default
# web root.
#
# Nginx serves static web content from:
#
#   /usr/share/nginx/html
#
# The copied file becomes:
#
#   /usr/share/nginx/html/index.html
#
# Therefore:
#
#   http://localhost/
#
# should return the application page.
#
# ----------------------------------------------------------

COPY app/index.html /usr/share/nginx/html/index.html


# ----------------------------------------------------------
# 4. Container Port
# ----------------------------------------------------------
#
# Document that the application listens on HTTP port 80.
#
# IMPORTANT:
#
# EXPOSE does NOT publish the port to the host.
#
# It documents the port used by the container.
#
# ECS will configure the actual networking between the
# Application Load Balancer and the ECS task.
#
# ----------------------------------------------------------

EXPOSE 80


# ----------------------------------------------------------
# 5. Start Nginx
# ----------------------------------------------------------
#
# Start Nginx in the foreground.
#
# Docker containers need a foreground process to remain
# running.
#
# Therefore:
#
#   daemon off;
#
# prevents Nginx from going into the background.
#
# This allows the Nginx process to remain the main container
# process and keeps the ECS task running.
#
# ----------------------------------------------------------

CMD ["nginx", "-g", "daemon off;"]


# ==========================================================
# DOCKERFILE / ECS HEALTH-CHECK ALIGNMENT
# ==========================================================
#
# Dockerfile:
#
#   curl installed
#   Nginx installed
#   Nginx listens on port 80
#   index.html exists
#   Nginx starts automatically
#
# ECS health check:
#
#   curl -f http://localhost/ || exit 1
#
# These are now aligned.
#
# Expected result inside the running container:
#
#   curl -f http://localhost/
#
# should return HTTP 200 from Nginx.
#
# ==========================================================

