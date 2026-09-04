#!/bin/bash
# ============================================================
# Charlie Cafe - EC2 Verification Script
# Amazon Linux 2023
# ============================================================
#
# PURPOSE:
#   Verify the Charlie Cafe EC2 User Data installation.
#
# CHECKS:
#   1. Operating System
#   2. Linux utilities
#   3. Apache HTTPD
#   4. PHP + PHP-FPM
#   5. MariaDB 10.11
#   6. Docker
#   7. Docker Compose
#   8. kubectl
#   9. eksctl
#  10. Helm
#  11. kind
#  12. Apache test files
#  13. Docker group
#  14. curl absence
#  15. Service status
#
# IMPORTANT:
#   - READ-ONLY verification
#   - Does NOT install packages
#   - Does NOT change configuration
#   - Does NOT restart services
#   - Does NOT create/delete resources
#   - Designed for Amazon Linux 2023 x86_64
#
# ============================================================

echo "============================================================"
echo " Charlie Cafe EC2 Verification Started"
echo "============================================================"

PASS=0
FAIL=0

# ------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------

check_command() {
    NAME="$1"
    COMMAND="$2"

    if command -v "$COMMAND" >/dev/null 2>&1; then
        echo "[PASS] $NAME"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $NAME"
        FAIL=$((FAIL + 1))
    fi
}

check_package() {
    NAME="$1"
    PACKAGE="$2"

    if rpm -q "$PACKAGE" >/dev/null 2>&1; then
        echo "[PASS] $NAME package installed"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $NAME package missing"
        FAIL=$((FAIL + 1))
    fi
}

check_service() {
    NAME="$1"
    SERVICE="$2"

    if systemctl is-active --quiet "$SERVICE"; then
        echo "[PASS] $NAME service is active"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $NAME service is NOT active"
        FAIL=$((FAIL + 1))
    fi
}

check_file() {
    NAME="$1"
    FILE="$2"

    if [ -f "$FILE" ]; then
        echo "[PASS] $NAME"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $NAME"
        FAIL=$((FAIL + 1))
    fi
}

# ------------------------------------------------------------
# 1. Operating System
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 1. Operating System"
echo "============================================================"

echo "Hostname:"
hostname

echo ""
echo "Current User:"
whoami

echo ""
echo "Architecture:"
uname -m

echo ""
echo "Kernel:"
uname -r

echo ""
echo "Operating System:"
cat /etc/os-release | grep PRETTY_NAME

if grep -q "Amazon Linux 2023" /etc/os-release; then
    echo "[PASS] Amazon Linux 2023 detected"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Amazon Linux 2023 not detected"
    FAIL=$((FAIL + 1))
fi

if [ "$(uname -m)" = "x86_64" ]; then
    echo "[PASS] x86_64 architecture"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Expected x86_64 architecture"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# 2. Linux Utilities
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 2. Linux Utilities"
echo "============================================================"

check_command "Git" git
check_command "htop" htop
check_command "wget" wget
check_command "unzip" unzip
check_command "tar" tar
check_command "gzip" gzip
check_command "bzip2" bzip2
check_command "jq" jq
check_command "vim" vim
check_command "nano" nano
check_command "dig" dig
check_command "ip" ip

# ------------------------------------------------------------
# 3. Apache
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 3. Apache HTTPD"
echo "============================================================"

check_package "Apache HTTPD" httpd
check_command "Apache httpd command" httpd

echo ""
echo "Apache Version:"
httpd -v 2>/dev/null | head -n 1

check_service "Apache HTTPD" httpd

# ------------------------------------------------------------
# 4. PHP + PHP-FPM
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 4. PHP + PHP-FPM"
echo "============================================================"

check_package "PHP" php
check_package "PHP-FPM" php-fpm
check_package "PHP MySQLi" php-mysqli
check_package "PHP JSON" php-json
check_package "PHP mbstring" php-mbstring
check_package "PHP XML" php-xml
check_package "PHP OPcache" php-opcache
check_package "PHP development package" php-devel

check_command "PHP command" php

echo ""
echo "PHP Version:"
php -v 2>/dev/null | head -n 1

check_service "PHP-FPM" php-fpm

# ------------------------------------------------------------
# 5. MariaDB
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 5. MariaDB"
echo "============================================================"

check_package "MariaDB 10.11" mariadb1011
check_command "MariaDB client" mariadb

echo ""
echo "MariaDB Version:"
mariadb --version 2>/dev/null

# ------------------------------------------------------------
# 6. Docker
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 6. Docker"
echo "============================================================"

check_package "Docker" docker
check_command "Docker command" docker

echo ""
echo "Docker Version:"
docker --version 2>/dev/null

check_service "Docker" docker

# ------------------------------------------------------------
# 7. Docker Compose
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 7. Docker Compose"
echo "============================================================"

COMPOSE="/usr/local/lib/docker/cli-plugins/docker-compose"

if [ -x "$COMPOSE" ]; then
    echo "[PASS] Docker Compose plugin exists"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Docker Compose plugin missing"
    FAIL=$((FAIL + 1))
fi

if docker compose version >/dev/null 2>&1; then
    echo "[PASS] Docker Compose command works"
    PASS=$((PASS + 1))

    echo ""
    echo "Docker Compose Version:"
    docker compose version
else
    echo "[FAIL] Docker Compose command failed"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# 8. kubectl
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 8. kubectl"
echo "============================================================"

check_command "kubectl" kubectl

if command -v kubectl >/dev/null 2>&1; then
    echo ""
    echo "kubectl Version:"
    kubectl version --client 2>/dev/null
fi

# ------------------------------------------------------------
# 9. eksctl
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 9. eksctl"
echo "============================================================"

check_command "eksctl" eksctl

if command -v eksctl >/dev/null 2>&1; then
    echo ""
    echo "eksctl Version:"
    eksctl version 2>/dev/null
fi

# ------------------------------------------------------------
# 10. Helm
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 10. Helm"
echo "============================================================"

check_command "Helm" helm

if command -v helm >/dev/null 2>&1; then
    echo ""
    echo "Helm Version:"
    helm version --short 2>/dev/null
fi

# ------------------------------------------------------------
# 11. kind
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 11. kind"
echo "============================================================"

check_command "kind" kind

if command -v kind >/dev/null 2>&1; then
    echo ""
    echo "kind Version:"
    kind version 2>/dev/null
fi

# ------------------------------------------------------------
# 12. Apache Test Files
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 12. Apache Test Files"
echo "============================================================"

check_file "Charlie Cafe index.html" /var/www/html/index.html
check_file "PHP info.php" /var/www/html/info.php

echo ""
echo "Apache Document Root:"
ls -la /var/www/html/

# ------------------------------------------------------------
# 13. Apache File Ownership
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 13. Apache File Ownership"
echo "============================================================"

if [ -d /var/www/html ]; then

    OWNER=$(stat -c '%U:%G' /var/www/html)

    echo "Document Root Owner:"
    echo "$OWNER"

    if [ "$OWNER" = "apache:apache" ]; then
        echo "[PASS] Document root owned by apache:apache"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Document root is not owned by apache:apache"
        FAIL=$((FAIL + 1))
    fi

else
    echo "[FAIL] Apache document root does not exist"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# 14. Docker Group
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 14. Docker Group"
echo "============================================================"

if getent group docker >/dev/null 2>&1; then
    echo "[PASS] Docker group exists"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Docker group does not exist"
    FAIL=$((FAIL + 1))
fi

if id ec2-user >/dev/null 2>&1; then

    echo ""
    echo "ec2-user Groups:"
    id ec2-user

    if id -nG ec2-user | grep -qw docker; then
        echo "[PASS] ec2-user belongs to docker group"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] ec2-user does NOT belong to docker group"
        FAIL=$((FAIL + 1))
    fi

else
    echo "[FAIL] ec2-user does not exist"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# 15. curl Check
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 15. curl Check"
echo "============================================================"

if command -v curl >/dev/null 2>&1; then
    echo "[FAIL] curl is installed"
    FAIL=$((FAIL + 1))
else
    echo "[PASS] curl command is NOT installed"
    PASS=$((PASS + 1))
fi

if rpm -q curl >/dev/null 2>&1; then
    echo "[FAIL] curl RPM package is installed"
    FAIL=$((FAIL + 1))
else
    echo "[PASS] curl RPM package is NOT installed"
    PASS=$((PASS + 1))
fi

# ------------------------------------------------------------
# 16. wget Check
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 16. wget Check"
echo "============================================================"

check_command "wget" wget

# ------------------------------------------------------------
# 17. Service Status
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 17. Service Status"
echo "============================================================"

echo ""
echo "Apache:"
systemctl is-active httpd

echo ""
echo "PHP-FPM:"
systemctl is-active php-fpm

echo ""
echo "Docker:"
systemctl is-active docker

# ------------------------------------------------------------
# 18. Service Enablement
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 18. Service Enablement"
echo "============================================================"

if systemctl is-enabled --quiet httpd; then
    echo "[PASS] Apache enabled at boot"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Apache is not enabled at boot"
    FAIL=$((FAIL + 1))
fi

if systemctl is-enabled --quiet php-fpm; then
    echo "[PASS] PHP-FPM enabled at boot"
    PASS=$((PASS + 1))
else
    echo "[FAIL] PHP-FPM is not enabled at boot"
    FAIL=$((FAIL + 1))
fi

if systemctl is-enabled --quiet docker; then
    echo "[PASS] Docker enabled at boot"
    PASS=$((PASS + 1))
else
    echo "[FAIL] Docker is not enabled at boot"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# 19. Local Apache HTTP Test
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 19. Apache HTTP Test"
echo "============================================================"

if command -v wget >/dev/null 2>&1; then

    HTTP_TEST=$(wget -qO- http://127.0.0.1/ 2>/dev/null || true)

    if echo "$HTTP_TEST" | grep -q "Charlie Cafe"; then
        echo "[PASS] Apache serves Charlie Cafe page"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] Charlie Cafe page was not detected"
        FAIL=$((FAIL + 1))
    fi

else
    echo "[FAIL] Cannot perform HTTP test because wget is missing"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# 20. PHP Test
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " 20. PHP Test"
echo "============================================================"

if [ -f /var/www/html/info.php ]; then
    echo "[PASS] PHP test file exists"
    PASS=$((PASS + 1))
else
    echo "[FAIL] PHP test file missing"
    FAIL=$((FAIL + 1))
fi

# ------------------------------------------------------------
# Final Summary
# ------------------------------------------------------------

echo ""
echo "============================================================"
echo " Charlie Cafe EC2 Verification Summary"
echo "============================================================"

echo ""
echo "Checks Passed : $PASS"
echo "Checks Failed : $FAIL"

echo ""

if [ "$FAIL" -eq 0 ]; then

    echo "============================================================"
    echo " RESULT: PASS"
    echo "============================================================"
    echo ""
    echo "Charlie Cafe EC2 environment is correctly configured."
    echo "All required tools and services passed verification."
    echo ""

    exit 0

else

    echo "============================================================"
    echo " RESULT: FAIL"
    echo "============================================================"
    echo ""
    echo "One or more checks failed."
    echo "Review the [FAIL] entries above."
    echo ""

    exit 1

fi