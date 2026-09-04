#!/bin/bash

# ================================================================
# ☕ Charlie Cafe — Amazon Linux 2023 EC2 Diagnostic Script
# ================================================================
#
# PURPOSE
# ----------------------------------------------------------------
# This script performs a READ-ONLY diagnostic of an Amazon Linux
# 2023 EC2 instance before running the final Charlie Cafe bootstrap.
#
# IMPORTANT
# ----------------------------------------------------------------
# THIS SCRIPT DOES NOT:
#
#   - install packages
#   - remove packages
#   - update packages
#   - change configuration
#   - start services
#   - stop services
#   - restart services
#   - modify users
#   - modify groups
#   - modify Docker
#
# It ONLY checks and reports the current state.
#
# ================================================================
#
# WHAT THIS SCRIPT CHECKS
# ----------------------------------------------------------------
#
# Operating System
#   - Amazon Linux 2023
#   - Architecture
#   - Kernel
#
# Package Manager
#   - DNF
#
# Linux Tools
#   - git
#   - htop
#   - curl
#   - curl-minimal
#   - curl-full
#   - libcurl-minimal
#   - libcurl-full
#   - wget
#   - unzip
#   - tar
#   - gzip
#   - bzip2
#   - xz
#   - jq
#   - vim
#   - nano
#   - bind-utils
#   - iproute
#   - iputils
#
# Web Stack
#   - httpd
#   - PHP
#   - PHP-FPM
#   - PHP extensions
#
# Database
#   - MariaDB
#   - MySQL-compatible client
#
# Containers
#   - Docker
#   - Docker Compose
#   - Docker service
#   - ec2-user Docker group
#
# AWS
#   - AWS CLI
#   - AWS CLI version
#
# Kubernetes
#   - kubectl
#   - eksctl
#   - Helm
#   - kind
#
# Services
#   - httpd
#   - php-fpm
#   - docker
#
# Network
#   - Apache localhost test
#   - PHP localhost test
#
# Existing Charlie Cafe files
#   - bootstrap log
#   - completion marker
#   - index.html
#   - info.php
#
# ================================================================


# ================================================================
# 1. ROOT CHECK
# ================================================================

if [[ "${EUID}" -ne 0 ]]; then

    echo
    echo "ERROR: Please run this diagnostic as root."
    echo
    echo "Correct command:"
    echo
    echo "  sudo bash diagnose-charlie-cafe-ec2.sh"
    echo

    exit 1

fi


# ================================================================
# 2. VARIABLES
# ================================================================

LOG_FILE="/var/log/charlie-cafe-diagnostic.log"

WEB_ROOT="/var/www/html"

COMPLETION_FILE="/var/log/charlie-cafe-bootstrap-complete.txt"

ARCH="$(uname -m)"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0


# ================================================================
# 3. LOGGING
# ================================================================
#
# Everything printed by this diagnostic is also saved here:
#
#   /var/log/charlie-cafe-diagnostic.log
#
# ================================================================

touch "${LOG_FILE}"

exec > >(tee -a "${LOG_FILE}") 2>&1


# ================================================================
# 4. STRICT MODE
# ================================================================
#
# We intentionally do NOT use "set -e".
#
# Why?
#
# A diagnostic script must continue checking everything even when
# one tool is missing.
#
# ================================================================

set -uo pipefail


# ================================================================
# 5. RESULT HELPERS
# ================================================================

pass() {

    echo "[PASS] $1"

    PASS_COUNT=$((PASS_COUNT + 1))

}


fail() {

    echo "[FAIL] $1"

    FAIL_COUNT=$((FAIL_COUNT + 1))

}


warn() {

    echo "[WARN] $1"

    WARN_COUNT=$((WARN_COUNT + 1))

}


info() {

    echo "[INFO] $1"

}


section() {

    echo
    echo
    echo "==============================================================="
    echo "$1"
    echo "==============================================================="

}


# ================================================================
# 6. START
# ================================================================

section "☕ CHARLIE CAFE EC2 DIAGNOSTIC STARTED"

echo
echo "Date:"
date

echo
echo "Hostname:"
hostname

echo
echo "Current user:"
whoami

echo
echo "UID:"
id -u

echo
echo "Architecture:"
uname -m

echo
echo "Kernel:"
uname -r

echo
echo "Diagnostic log:"
echo "${LOG_FILE}"


# ================================================================
# 7. OPERATING SYSTEM
# ================================================================

section "1. OPERATING SYSTEM CHECK"


if [[ -f /etc/os-release ]]; then

    source /etc/os-release

    echo
    echo "NAME:"
    echo "${NAME:-unknown}"

    echo
    echo "VERSION:"
    echo "${VERSION:-unknown}"

    echo
    echo "ID:"
    echo "${ID:-unknown}"

    echo
    echo "VERSION_ID:"
    echo "${VERSION_ID:-unknown}"

    if [[ "${ID:-}" == "amzn" ]]; then

        pass "Amazon Linux detected."

    else

        fail "Operating system is not Amazon Linux."

    fi


    if [[ "${VERSION_ID:-}" == "2023" ]]; then

        pass "Amazon Linux 2023 detected."

    else

        fail "Operating system is not Amazon Linux 2023."

    fi

else

    fail "/etc/os-release does not exist."

fi


# ================================================================
# 8. ARCHITECTURE
# ================================================================

section "2. CPU ARCHITECTURE"


case "${ARCH}" in

    x86_64)

        pass "x86_64 architecture detected."

        ;;

    aarch64)

        pass "aarch64 / ARM64 architecture detected."

        ;;

    *)

        fail "Unsupported architecture: ${ARCH}"

        ;;

esac


# ================================================================
# 9. DNF
# ================================================================

section "3. DNF PACKAGE MANAGER"


if command -v dnf >/dev/null 2>&1; then

    pass "DNF command exists."

    echo
    echo "DNF version:"
    dnf --version | head -n 1

else

    fail "DNF command is missing."

fi


# ================================================================
# 10. DNF PACKAGE DATABASE
# ================================================================

section "4. DNF / RPM PACKAGE STATE"


echo
echo "Installed curl-related RPM packages:"
echo "---------------------------------------------------------------"

rpm -qa | grep -Ei '^(curl|libcurl)' || true


echo
echo "Installed packages containing curl:"
echo "---------------------------------------------------------------"

dnf list installed 2>/dev/null \
    | grep -Ei '^(curl|libcurl)' \
    || true


echo
echo "Installed package details:"
echo "---------------------------------------------------------------"


for PACKAGE in \
    curl \
    curl-minimal \
    curl-full \
    libcurl \
    libcurl-minimal \
    libcurl-full
do

    if rpm -q "${PACKAGE}" >/dev/null 2>&1; then

        echo "[INSTALLED] ${PACKAGE}"
        rpm -q "${PACKAGE}"

    else

        echo "[NOT INSTALLED] ${PACKAGE}"

    fi

done


# ================================================================
# 11. CRITICAL CURL DIAGNOSTIC
# ================================================================

section "5. CRITICAL CURL / CURL-MINIMAL DIAGNOSTIC"


echo
echo "curl executable:"
echo "---------------------------------------------------------------"

if command -v curl >/dev/null 2>&1; then

    pass "curl command exists."

    echo
    echo "curl location:"
    command -v curl

    echo
    echo "curl version:"
    curl --version | head -n 1

else

    fail "curl command does NOT exist."

fi


echo
echo "RPM owning curl executable:"
echo "---------------------------------------------------------------"

CURL_PATH="$(command -v curl 2>/dev/null || true)"

if [[ -n "${CURL_PATH}" ]]; then

    rpm -qf "${CURL_PATH}" 2>/dev/null || true

fi


echo
echo "Checking whether FULL curl is installed:"
echo "---------------------------------------------------------------"

if rpm -q curl >/dev/null 2>&1; then

    warn "FULL curl package is installed."

    rpm -q curl

else

    info "FULL curl package is not installed."

fi


echo
echo "Checking curl-minimal:"
echo "---------------------------------------------------------------"

if rpm -q curl-minimal >/dev/null 2>&1; then

    pass "curl-minimal is installed."

    rpm -q curl-minimal

else

    warn "curl-minimal is not installed."

fi


echo
echo "Checking libcurl-minimal:"
echo "---------------------------------------------------------------"

if rpm -q libcurl-minimal >/dev/null 2>&1; then

    pass "libcurl-minimal is installed."

    rpm -q libcurl-minimal

else

    info "libcurl-minimal is not installed."

fi


echo
echo "Checking full libcurl:"
echo "---------------------------------------------------------------"

if rpm -q libcurl-full >/dev/null 2>&1; then

    warn "libcurl-full is installed."

    rpm -q libcurl-full

else

    info "libcurl-full is not installed."

fi


# ================================================================
# 12. TEST CURL HTTPS
# ================================================================

section "6. CURL HTTPS TEST"


if command -v curl >/dev/null 2>&1; then

    if curl \
        --silent \
        --show-error \
        --fail \
        --connect-timeout 10 \
        --max-time 20 \
        https://aws.amazon.com/ \
        -o /dev/null
    then

        pass "curl HTTPS connection works."

    else

        fail "curl exists but HTTPS test failed."

    fi

else

    fail "Cannot test curl because curl is missing."

fi


# ================================================================
# 13. LINUX TOOL CHECK
# ================================================================

section "7. LINUX / UTILITY TOOLS"


COMMANDS=(
    git
    htop
    curl
    wget
    unzip
    tar
    gzip
    bzip2
    xz
    jq
    vim
    nano
    nslookup
    dig
    ip
    ping
    ss
    which
)


for COMMAND in "${COMMANDS[@]}"; do

    if command -v "${COMMAND}" >/dev/null 2>&1; then

        pass "${COMMAND} is installed."

        echo "       Path: $(command -v "${COMMAND}")"

    else

        fail "${COMMAND} is missing."

    fi

done


# ================================================================
# 14. PACKAGE CHECK FOR SPECIFIC UTILITIES
# ================================================================

section "8. RPM PACKAGE CHECK — BASE UTILITIES"


PACKAGES=(
    git
    htop
    wget
    unzip
    tar
    gzip
    bzip2
    xz
    jq
    vim-enhanced
    nano
    ca-certificates
    openssl
    findutils
    procps-ng
    iproute
    iputils
    bind-utils
    which
    util-linux
    shadow-utils
)


for PACKAGE in "${PACKAGES[@]}"; do

    if rpm -q "${PACKAGE}" >/dev/null 2>&1; then

        pass "RPM package installed: ${PACKAGE}"

    else

        fail "RPM package missing: ${PACKAGE}"

    fi

done


# ================================================================
# 15. APACHE
# ================================================================

section "9. APACHE HTTP SERVER"


if command -v httpd >/dev/null 2>&1; then

    pass "Apache httpd command exists."

    echo
    httpd -v | head -n 1

else

    fail "Apache httpd command is missing."

fi


echo
echo "Apache RPM:"


if rpm -q httpd >/dev/null 2>&1; then

    pass "Apache RPM installed."

    rpm -q httpd

else

    fail "Apache RPM is not installed."

fi


echo
echo "Apache configuration test:"


if command -v httpd >/dev/null 2>&1; then

    if httpd -t; then

        pass "Apache configuration is valid."

    else

        fail "Apache configuration test failed."

    fi

fi


# ================================================================
# 16. APACHE SERVICE
# ================================================================

section "10. APACHE SERVICE"


if systemctl is-enabled --quiet httpd 2>/dev/null; then

    pass "Apache service is enabled."

else

    warn "Apache service is not enabled."

fi


if systemctl is-active --quiet httpd 2>/dev/null; then

    pass "Apache service is running."

else

    warn "Apache service is NOT running."

fi


# ================================================================
# 17. PHP
# ================================================================

section "11. PHP"


if command -v php >/dev/null 2>&1; then

    pass "PHP command exists."

    echo
    php -v | head -n 1

else

    fail "PHP command is missing."

fi


# ================================================================
# 18. PHP-FPM
# ================================================================

section "12. PHP-FPM"


if command -v php-fpm >/dev/null 2>&1; then

    pass "php-fpm command exists."

    echo
    php-fpm -v | head -n 1

else

    fail "php-fpm command is missing."

fi


if rpm -q php-fpm >/dev/null 2>&1; then

    pass "php-fpm RPM installed."

else

    fail "php-fpm RPM is not installed."

fi


# ================================================================
# 19. PHP EXTENSIONS
# ================================================================

section "13. PHP EXTENSIONS"


REQUIRED_PHP_EXTENSIONS=(
    mysqli
    mysqlnd
    mbstring
    xml
    json
    opcache
    pdo_mysql
)


if command -v php >/dev/null 2>&1; then

    PHP_MODULES="$(php -m 2>/dev/null || true)"

    for EXTENSION in "${REQUIRED_PHP_EXTENSIONS[@]}"; do

        if echo "${PHP_MODULES}" \
            | grep -qi "^${EXTENSION}$"
        then

            pass "PHP extension installed: ${EXTENSION}"

        else

            fail "PHP extension missing: ${EXTENSION}"

        fi

    done

else

    fail "Cannot check PHP extensions because PHP is missing."

fi


# ================================================================
# 20. PHP-FPM CONFIGURATION
# ================================================================

section "14. PHP-FPM CONFIGURATION"


PHP_FPM_CONFIG="/etc/php-fpm.d/www.conf"


if [[ -f "${PHP_FPM_CONFIG}" ]]; then

    pass "PHP-FPM configuration exists."

    echo
    echo "PHP-FPM configuration:"
    echo "${PHP_FPM_CONFIG}"

    echo
    echo "Relevant PHP-FPM settings:"
    echo "---------------------------------------------------------------"

    grep -E \
        '^[[:space:]]*(user|group|listen|listen.owner|listen.group|listen.mode)[[:space:]]*=' \
        "${PHP_FPM_CONFIG}" \
        || true

else

    fail "PHP-FPM configuration does not exist."

fi


# ================================================================
# 21. PHP-FPM SOCKET
# ================================================================

section "15. PHP-FPM SOCKET"


PHP_SOCKET="/run/php-fpm/www.sock"


if [[ -S "${PHP_SOCKET}" ]]; then

    pass "PHP-FPM socket exists."

    ls -l "${PHP_SOCKET}"

else

    warn "PHP-FPM socket does not exist."

fi


# ================================================================
# 22. PHP-FPM SERVICE
# ================================================================

section "16. PHP-FPM SERVICE"


if systemctl is-enabled --quiet php-fpm 2>/dev/null; then

    pass "PHP-FPM service is enabled."

else

    warn "PHP-FPM service is not enabled."

fi


if systemctl is-active --quiet php-fpm 2>/dev/null; then

    pass "PHP-FPM service is running."

else

    warn "PHP-FPM service is NOT running."

fi


# ================================================================
# 23. MARIADB / MYSQL
# ================================================================

section "17. MARIADB / MYSQL CLIENT"


if command -v mariadb >/dev/null 2>&1; then

    pass "MariaDB client command exists."

    mariadb --version

elif command -v mysql >/dev/null 2>&1; then

    pass "MySQL-compatible client command exists."

    mysql --version

else

    fail "MariaDB/MySQL client command is missing."

fi


echo
echo "MariaDB/MySQL related RPM packages:"
echo "---------------------------------------------------------------"

rpm -qa \
    | grep -Ei 'mariadb|mysql' \
    || true


# ================================================================
# 24. DOCKER
# ================================================================

section "18. DOCKER"


if command -v docker >/dev/null 2>&1; then

    pass "Docker command exists."

    echo
    docker --version

else

    fail "Docker command is missing."

fi


if rpm -q docker >/dev/null 2>&1; then

    pass "Docker RPM installed."

    rpm -q docker

else

    fail "Docker RPM is not installed."

fi


# ================================================================
# 25. DOCKER SERVICE
# ================================================================

section "19. DOCKER SERVICE"


if systemctl is-enabled --quiet docker 2>/dev/null; then

    pass "Docker service is enabled."

else

    warn "Docker service is not enabled."

fi


if systemctl is-active --quiet docker 2>/dev/null; then

    pass "Docker service is running."

else

    warn "Docker service is NOT running."

fi


# ================================================================
# 26. DOCKER DAEMON
# ================================================================

section "20. DOCKER DAEMON"


if command -v docker >/dev/null 2>&1; then

    if docker info >/dev/null 2>&1; then

        pass "Docker daemon is responding."

    else

        warn "Docker command exists but Docker daemon is not responding."

    fi

fi


# ================================================================
# 27. EC2 USER DOCKER GROUP
# ================================================================

section "21. EC2-USER DOCKER PERMISSIONS"


if id ec2-user >/dev/null 2>&1; then

    pass "ec2-user exists."

    echo
    echo "ec2-user groups:"
    id ec2-user

    echo

    if id -nG ec2-user | tr ' ' '\n' | grep -qx docker; then

        pass "ec2-user belongs to docker group."

    else

        warn "ec2-user is NOT currently in docker group."

    fi

else

    fail "ec2-user does not exist."

fi


# ================================================================
# 28. DOCKER COMPOSE
# ================================================================

section "22. DOCKER COMPOSE V2"


if docker compose version >/dev/null 2>&1; then

    pass "Docker Compose v2 command works."

    docker compose version

else

    fail "Docker Compose v2 is missing or not working."

fi


echo
echo "Docker CLI plugins:"
echo "---------------------------------------------------------------"

DOCKER_PLUGIN_DIR="/usr/local/lib/docker/cli-plugins"

if [[ -d "${DOCKER_PLUGIN_DIR}" ]]; then

    ls -lah "${DOCKER_PLUGIN_DIR}"

else

    info "Docker CLI plugin directory does not exist."

fi


# ================================================================
# 29. AWS CLI
# ================================================================

section "23. AWS CLI"


if command -v aws >/dev/null 2>&1; then

    pass "AWS CLI command exists."

    aws --version

else

    fail "AWS CLI command is missing."

fi


# ================================================================
# 30. AWS CLI VERSION
# ================================================================

section "24. AWS CLI VERSION CHECK"


if command -v aws >/dev/null 2>&1; then

    AWS_VERSION_OUTPUT="$(aws --version 2>&1 || true)"

    echo "${AWS_VERSION_OUTPUT}"

    if echo "${AWS_VERSION_OUTPUT}" | grep -q 'aws-cli/2'; then

        pass "AWS CLI v2 detected."

    else

        warn "AWS CLI v2 was not detected."

    fi

fi


# ================================================================
# 31. AWS IDENTITY
# ================================================================

section "25. EC2 IAM ROLE CHECK"


if command -v aws >/dev/null 2>&1; then

    echo
    echo "Testing STS GetCallerIdentity..."

    if aws sts get-caller-identity --output json 2>/dev/null; then

        pass "AWS credentials / EC2 IAM role are available."

    else

        warn "AWS CLI works but GetCallerIdentity failed."

        echo
        echo "This can happen if the EC2 instance does not have"
        echo "an IAM role attached."

        echo
        echo "This is NOT an installation failure."

    fi

else

    warn "Cannot test IAM identity because AWS CLI is missing."

fi


# ================================================================
# 32. KUBECTL
# ================================================================

section "26. KUBECTL"


if command -v kubectl >/dev/null 2>&1; then

    pass "kubectl command exists."

    echo
    kubectl version --client 2>&1 || true

else

    fail "kubectl is missing."

fi


# ================================================================
# 33. EKSCTL
# ================================================================

section "27. EKSCTL"


if command -v eksctl >/dev/null 2>&1; then

    pass "eksctl command exists."

    echo
    eksctl version 2>&1 || true

else

    fail "eksctl is missing."

fi


# ================================================================
# 34. HELM
# ================================================================

section "28. HELM"


if command -v helm >/dev/null 2>&1; then

    pass "Helm command exists."

    echo
    helm version --short 2>&1 || true

else

    fail "Helm is missing."

fi


# ================================================================
# 35. KIND
# ================================================================

section "29. KIND"


if command -v kind >/dev/null 2>&1; then

    pass "kind command exists."

    echo
    kind version 2>&1 || true

else

    fail "kind is missing."

fi


# ================================================================
# 36. KUBERNETES BINARY LOCATIONS
# ================================================================

section "30. KUBERNETES TOOL LOCATIONS"


for TOOL in kubectl eksctl helm kind; do

    if command -v "${TOOL}" >/dev/null 2>&1; then

        echo "[FOUND] ${TOOL}"
        echo "        $(command -v "${TOOL}")"

    else

        echo "[MISSING] ${TOOL}"

    fi

done


# ================================================================
# 37. WEB FILES
# ================================================================

section "31. CHARLIE CAFE WEB FILES"


if [[ -d "${WEB_ROOT}" ]]; then

    pass "Web root exists: ${WEB_ROOT}"

    echo
    echo "Web root contents:"
    ls -lah "${WEB_ROOT}"

else

    warn "Web root does not exist: ${WEB_ROOT}"

fi


echo
echo "Checking index.html:"


if [[ -f "${WEB_ROOT}/index.html" ]]; then

    pass "index.html exists."

    echo
    echo "First 20 lines:"
    sed -n '1,20p' "${WEB_ROOT}/index.html"

else

    warn "index.html does not exist."

fi


echo
echo "Checking info.php:"


if [[ -f "${WEB_ROOT}/info.php" ]]; then

    pass "info.php exists."

else

    warn "info.php does not exist."

fi


# ================================================================
# 38. APACHE PHP-FPM CONFIG
# ================================================================

section "32. APACHE PHP-FPM CONFIGURATION"


PHP_APACHE_CONFIG="/etc/httpd/conf.d/php-fpm.conf"


if [[ -f "${PHP_APACHE_CONFIG}" ]]; then

    pass "Apache PHP-FPM configuration exists."

    echo
    echo "Configuration:"
    echo "---------------------------------------------------------------"

    cat "${PHP_APACHE_CONFIG}"

else

    warn "Apache PHP-FPM configuration does not exist."

fi


# ================================================================
# 39. LOCAL APACHE TEST
# ================================================================

section "33. LOCAL APACHE HTTP TEST"


if command -v curl >/dev/null 2>&1 && \
   systemctl is-active --quiet httpd 2>/dev/null
then

    HTTP_OUTPUT="/tmp/charlie-diagnostic-http.html"

    HTTP_STATUS="$(
        curl \
            --silent \
            --show-error \
            --output "${HTTP_OUTPUT}" \
            --write-out "%{http_code}" \
            --max-time 15 \
            http://127.0.0.1/ \
            2>/dev/null \
            || true
    )"


    echo
    echo "HTTP status:"
    echo "${HTTP_STATUS}"


    if [[ "${HTTP_STATUS}" == "200" ]]; then

        pass "Apache localhost HTTP request returned 200."

    else

        warn "Apache localhost HTTP test returned ${HTTP_STATUS}."

    fi


    if [[ -f "${HTTP_OUTPUT}" ]]; then

        echo
        echo "Response preview:"
        sed -n '1,20p' "${HTTP_OUTPUT}"

        rm -f "${HTTP_OUTPUT}"

    fi

else

    warn "Apache localhost test skipped because Apache or curl is unavailable."

fi


# ================================================================
# 40. LOCAL PHP TEST
# ================================================================

section "34. LOCAL PHP / PHP-FPM HTTP TEST"


if command -v curl >/dev/null 2>&1 && \
   systemctl is-active --quiet httpd 2>/dev/null && \
   [[ -f "${WEB_ROOT}/info.php" ]]
then

    PHP_OUTPUT="/tmp/charlie-diagnostic-php.html"

    PHP_STATUS="$(
        curl \
            --silent \
            --show-error \
            --output "${PHP_OUTPUT}" \
            --write-out "%{http_code}" \
            --max-time 15 \
            http://127.0.0.1/info.php \
            2>/dev/null \
            || true
    )


    echo
    echo "PHP HTTP status:"
    echo "${PHP_STATUS}"


    if [[ "${PHP_STATUS}" == "200" ]]; then

        pass "PHP page returned HTTP 200."

    else

        warn "PHP page returned HTTP ${PHP_STATUS}."

    fi


    if [[ -f "${PHP_OUTPUT}" ]]; then

        if grep -qi "PHP Version" "${PHP_OUTPUT}"; then

            pass "PHP is executing through Apache."

        else

            warn "PHP page returned content but PHP Version text was not detected."

        fi

        rm -f "${PHP_OUTPUT}"

    fi

else

    warn "PHP HTTP test skipped."

fi


# ================================================================
# 41. LISTENING PORTS
# ================================================================

section "35. LISTENING NETWORK PORTS"


if command -v ss >/dev/null 2>&1; then

    echo
    ss -lntp || true

else

    warn "ss command is unavailable."

fi


# ================================================================
# 42. PORT 80
# ================================================================

section "36. PORT 80 CHECK"


if command -v ss >/dev/null 2>&1; then

    if ss -lnt | grep -q ':80 '; then

        pass "Port 80 is listening."

    else

        warn "Port 80 is not listening."

    fi

fi


# ================================================================
# 43. COMPLETION MARKER
# ================================================================

section "37. PREVIOUS BOOTSTRAP COMPLETION MARKER"


if [[ -f "${COMPLETION_FILE}" ]]; then

    warn "Previous bootstrap completion marker exists."

    echo
    echo "File:"
    echo "${COMPLETION_FILE}"

    echo
    echo "Contents:"
    echo "---------------------------------------------------------------"

    cat "${COMPLETION_FILE}"

else

    info "No previous bootstrap completion marker exists."

fi


# ================================================================
# 44. BOOTSTRAP LOG
# ================================================================

section "38. PREVIOUS BOOTSTRAP LOG"


PREVIOUS_LOG="/var/log/charlie-cafe-bootstrap.log"


if [[ -f "${PREVIOUS_LOG}" ]]; then

    warn "Previous bootstrap log exists."

    echo
    echo "Log:"
    echo "${PREVIOUS_LOG}"

    echo
    echo "Last 100 lines:"
    echo "---------------------------------------------------------------"

    tail -n 100 "${PREVIOUS_LOG}"

else

    info "No previous Charlie Cafe bootstrap log exists."

fi


# ================================================================
# 45. PACKAGE TRANSACTION HISTORY
# ================================================================

section "39. RECENT DNF TRANSACTION HISTORY"


if command -v dnf >/dev/null 2>&1; then

    echo
    echo "Recent DNF history:"
    echo "---------------------------------------------------------------"

    dnf history list 2>/dev/null | head -n 20 || true

fi


# ================================================================
# 46. CHECK FOR DNF LOCK / PACKAGE PROCESSES
# ================================================================

section "40. ACTIVE PACKAGE MANAGER PROCESSES"


echo
echo "Checking active DNF/YUM/package processes:"
echo "---------------------------------------------------------------"

ps aux \
    | grep -E '[d]nf|[y]um|[p]ackagekit' \
    || true


# ================================================================
# 47. RPM DATABASE CHECK
# ================================================================

section "41. RPM DATABASE CHECK"


if rpm --verifydb >/dev/null 2>&1; then

    pass "RPM database verification completed."

else

    warn "RPM database verification reported a problem."

fi


# ================================================================
# 48. PACKAGE SUMMARY
# ================================================================

section "42. IMPORTANT INSTALLED PACKAGE SUMMARY"


echo
echo "curl packages:"
rpm -qa | grep -Ei 'curl' || true

echo
echo "PHP packages:"
rpm -qa | grep -Ei '^php' || true

echo
echo "Docker packages:"
rpm -qa | grep -Ei '^docker' || true

echo
echo "MariaDB packages:"
rpm -qa | grep -Ei 'mariadb' || true

echo
echo "Apache packages:"
rpm -qa | grep -Ei '^httpd' || true


# ================================================================
# 49. REQUIRED TOOL SUMMARY
# ================================================================

section "43. REQUIRED TOOL SUMMARY"


REQUIRED_TOOLS=(
    git
    htop
    curl
    wget
    unzip
    tar
    gzip
    bzip2
    xz
    jq
    vim
    nano
    nslookup
    dig
    ip
    ping
    php
    php-fpm
    httpd
    mariadb
    mysql
    docker
    aws
    kubectl
    eksctl
    helm
    kind
)


echo

for TOOL in "${REQUIRED_TOOLS[@]}"; do

    if command -v "${TOOL}" >/dev/null 2>&1; then

        echo "[FOUND]   ${TOOL}"

    else

        echo "[MISSING] ${TOOL}"

    fi

done


# ================================================================
# 50. SERVICE SUMMARY
# ================================================================

section "44. SERVICE SUMMARY"


SERVICES=(
    httpd
    php-fpm
    docker
)


for SERVICE in "${SERVICES[@]}"; do

    if systemctl is-active --quiet "${SERVICE}" 2>/dev/null; then

        echo "[RUNNING] ${SERVICE}"

    else

        echo "[STOPPED] ${SERVICE}"

    fi

done


# ================================================================
# 51. FINAL RESULT
# ================================================================

section "45. FINAL DIAGNOSTIC RESULT"


echo
echo "PASS COUNT : ${PASS_COUNT}"
echo "WARN COUNT : ${WARN_COUNT}"
echo "FAIL COUNT : ${FAIL_COUNT}"

echo
echo "Diagnostic log:"
echo "${LOG_FILE}"


# ================================================================
# 52. IMPORTANT CURL CONCLUSION
# ================================================================

echo
echo "---------------------------------------------------------------"
echo "CURL DIAGNOSTIC CONCLUSION"
echo "---------------------------------------------------------------"

if rpm -q curl-minimal >/dev/null 2>&1 && \
   ! rpm -q curl >/dev/null 2>&1
then

    echo
    echo "[INFO] The system has curl-minimal instead of full curl."

    echo
    echo "[INFO] This is NORMAL for Amazon Linux 2023."

    echo
    echo "[IMPORTANT]"
    echo "The final bootstrap script should NOT execute:"
    echo
    echo "    dnf install -y curl"
    echo
    echo "because that requests the full curl package and can conflict"
    echo "with curl-minimal."

elif rpm -q curl >/dev/null 2>&1; then

    echo
    echo "[WARN] Full curl package is currently installed."

    echo
    echo "This information will be used when fixing the bootstrap."

else

    echo
    echo "[WARN] curl-minimal/full curl state requires investigation."

fi


# ================================================================
# 53. FINAL INTERPRETATION
# ================================================================

echo
echo "==============================================================="
echo "☕ CHARLIE CAFE EC2 DIAGNOSTIC COMPLETED"
echo "==============================================================="

echo
echo "The diagnostic script made NO package or configuration changes."

echo
echo "Please send me the COMPLETE output of this command:"
echo
echo "  sudo bash diagnose-charlie-cafe-ec2.sh"

echo
echo "Also send the final:"
echo
echo "  PASS COUNT"
echo "  WARN COUNT"
echo "  FAIL COUNT"

echo
echo "I will use that exact output to produce the final corrected"
echo "Charlie Cafe bootstrap script."

echo
echo "Diagnostic log saved at:"
echo "  ${LOG_FILE}"

echo
echo "==============================================================="