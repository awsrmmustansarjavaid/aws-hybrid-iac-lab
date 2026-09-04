#!/bin/bash

# ==========================================================
# HYBRID TERRAFORM + CLOUDFORMATION AWS LAB
# EC2 Docker Application Setup
# ==========================================================

set -e

echo "=================================================="
echo " EC2 Docker Application Setup"
echo "=================================================="


# ----------------------------------------------------------
# 1. Check Docker
# ----------------------------------------------------------

echo ""
echo ">>> Checking Docker..."

docker --version


# ----------------------------------------------------------
# 2. Create application directory
# ----------------------------------------------------------

echo ""
echo ">>> Creating application directory..."

mkdir -p ~/hybrid-iac-app

cd ~/hybrid-iac-app


# ----------------------------------------------------------
# 3. Create simple HTML application
# ----------------------------------------------------------

echo ""
echo ">>> Creating test application..."

cat > index.html <<'EOF'

<!DOCTYPE html>

<html>

<head>

    <title>Hybrid IaC Lab</title>

</head>

<body>

    <h1>Hybrid Terraform + CloudFormation Lab</h1>

    <p>
        This application is running inside Docker on EC2.
    </p>

    <p>
        The same container image can later be deployed to:
    </p>

    <ul>
        <li>Amazon ECS</li>
        <li>Amazon EKS</li>
    </ul>

</body>

</html>

EOF


# ----------------------------------------------------------
# 4. Create Dockerfile
# ----------------------------------------------------------

echo ""
echo ">>> Creating Dockerfile..."

cat > Dockerfile <<'EOF'

FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

EOF


# ----------------------------------------------------------
# 5. Build Docker image
# ----------------------------------------------------------

echo ""
echo ">>> Building Docker image..."

docker build \
    -t hybrid-iac-app:latest \
    .


# ----------------------------------------------------------
# 6. Stop old container if it exists
# ----------------------------------------------------------

echo ""
echo ">>> Removing old container if necessary..."

docker rm -f hybrid-iac-app 2>/dev/null || true


# ----------------------------------------------------------
# 7. Start container
# ----------------------------------------------------------

echo ""
echo ">>> Starting Docker container..."

docker run -d \
    --name hybrid-iac-app \
    -p 8080:80 \
    hybrid-iac-app:latest


# ----------------------------------------------------------
# 8. Verify container
# ----------------------------------------------------------

echo ""
echo ">>> Running containers:"

docker ps


# ----------------------------------------------------------
# 9. Test application
# ----------------------------------------------------------

echo ""
echo ">>> Testing application..."

curl http://localhost:8080


echo ""
echo ""
echo "=================================================="
echo " Docker application deployed successfully."
echo "=================================================="

echo ""
echo "Application:"
echo "http://<EC2-PUBLIC-IP>:8080"
echo ""