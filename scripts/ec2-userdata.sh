#!/bin/bash
# ============================================================
# Charlie Cafe - Amazon Linux 2023 EC2 User Data
# ============================================================
# Installs:
#   Git, Linux utilities
#   Apache HTTPD + PHP + PHP-FPM
#   MariaDB 10.11
#   Docker + Docker Compose
#   kubectl
#   eksctl
#   Helm
#   kind
#
# Notes:
#   - Designed for Amazon Linux 2023
#   - Runs as root through EC2 User Data
#   - curl is NOT installed or required
#   - Uses wget for external downloads
# ============================================================

set -e

echo "============================================================"
echo " Charlie Cafe EC2 Bootstrap Started"
echo "============================================================"

# ------------------------------------------------------------
# 1. Linux Utilities
# ------------------------------------------------------------
echo "[1/10] Installing Linux utilities..."

dnf install -y \
  git \
  htop \
  wget \
  unzip \
  tar \
  gzip \
  bzip2 \
  jq \
  vim \
  nano \
  bind-utils \
  iproute

# ------------------------------------------------------------
# 2. Apache + PHP
# ------------------------------------------------------------
echo "[2/10] Installing Apache and PHP..."

dnf install -y \
  httpd \
  php \
  php-fpm \
  php-mysqli \
  php-json \
  php-mbstring \
  php-xml \
  php-opcache \
  php-devel

systemctl enable --now httpd
systemctl enable --now php-fpm

# ------------------------------------------------------------
# 3. MariaDB 10.11
# ------------------------------------------------------------
echo "[3/10] Installing MariaDB 10.11..."

dnf install -y mariadb1011

# ------------------------------------------------------------
# 4. Docker
# ------------------------------------------------------------
echo "[4/10] Installing Docker..."

dnf install -y docker

systemctl enable --now docker

usermod -aG docker ec2-user

# ------------------------------------------------------------
# 5. Docker Compose v2
# ------------------------------------------------------------
echo "[5/10] Installing Docker Compose..."

mkdir -p /usr/local/lib/docker/cli-plugins

wget -q \
  https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -O /usr/local/lib/docker/cli-plugins/docker-compose

chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# ------------------------------------------------------------
# 6. kubectl
# ------------------------------------------------------------
echo "[6/10] Installing kubectl..."

cd /tmp

KUBECTL_VERSION=$(wget -qO- https://dl.k8s.io/release/stable.txt)

wget -q \
  "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
  -O /tmp/kubectl

install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

rm -f /tmp/kubectl

# ------------------------------------------------------------
# 7. eksctl
# ------------------------------------------------------------
echo "[7/10] Installing eksctl..."

cd /tmp

wget -q \
  https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz \
  -O /tmp/eksctl.tar.gz

tar -xzf /tmp/eksctl.tar.gz -C /tmp

install -m 0755 /tmp/eksctl /usr/local/bin/eksctl

rm -f /tmp/eksctl /tmp/eksctl.tar.gz

# ------------------------------------------------------------
# 8. Helm
# ------------------------------------------------------------
echo "[8/10] Installing Helm..."

wget -q \
  https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
  -O /tmp/get_helm.sh

chmod 700 /tmp/get_helm.sh

/tmp/get_helm.sh

rm -f /tmp/get_helm.sh

# ------------------------------------------------------------
# 9. kind
# ------------------------------------------------------------
echo "[9/10] Installing kind..."

cd /tmp

wget -q \
  https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64 \
  -O /tmp/kind

chmod +x /tmp/kind

mv /tmp/kind /usr/local/bin/kind

# ------------------------------------------------------------
# 10. Charlie Cafe Test Page
# ------------------------------------------------------------
echo "[10/10] Creating Apache test page..."

cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Charlie Cafe</title>
</head>
<body>
    <h1>Charlie Cafe</h1>
    <p>EC2 Bootstrap Successful</p>
    <p>Apache: OK</p>
    <p>PHP: OK</p>
    <p>MariaDB: OK</p>
    <p>Docker: OK</p>
    <p>Docker Compose: OK</p>
    <p>Kubernetes Tools: OK</p>
</body>
</html>
EOF

cat > /var/www/html/info.php <<'EOF'
<?php
phpinfo();
?>
EOF

chown -R apache:apache /var/www/html

# ------------------------------------------------------------
# Restart services
# ------------------------------------------------------------
systemctl restart php-fpm
systemctl restart httpd
systemctl restart docker

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------
echo ""
echo "============================================================"
echo " Charlie Cafe EC2 Bootstrap Complete"
echo "============================================================"

echo ""
echo "===== Installed Versions ====="

echo "--- Git ---"
git --version

echo "--- Apache ---"
httpd -v | head -n 1

echo "--- PHP ---"
php -v | head -n 1

echo "--- MariaDB ---"
mariadb --version

echo "--- Docker ---"
docker --version

echo "--- Docker Compose ---"
docker compose version

echo "--- kubectl ---"
kubectl version --client

echo "--- eksctl ---"
eksctl version

echo "--- Helm ---"
helm version --short

echo "--- kind ---"
kind version

echo ""
echo "===== Service Status ====="

echo "Apache:"
systemctl is-active httpd

echo "PHP-FPM:"
systemctl is-active php-fpm

echo "Docker:"
systemctl is-active docker

echo ""
echo "===== Docker Group ====="
id ec2-user

echo ""
echo "============================================================"
echo " ALL CHARLIE CAFE TOOLS INSTALLED SUCCESSFULLY"
echo "============================================================"