#!/bin/bash

# =============================================================================
# Charlie Cafe EC2 - ULTRA FAST FORCE CLEANUP
# Amazon Linux 2023
# =============================================================================
#
# PURPOSE
# -------
# Aggressively remove Charlie Cafe lab software without waiting for DNF
# dependency transactions.
#
# IMPORTANT DESIGN CHANGE
# -----------------------
# This script DOES NOT use:
#
#     dnf remove
#     dnf autoremove
#
# because those operations can wait for the RPM database lock:
#
#     Waiting for process with pid XXXXX to finish.
#
# Instead:
#
#     1. Stop DNF/RPM automatic services.
#     2. FORCE-KILL active package-manager processes.
#     3. Remove lab RPMs using rpm -e --nodeps.
#     4. Delete lab files/directories directly.
#
# This is intentionally aggressive and intended for a disposable LAB EC2.
#
# =============================================================================
#
# SOFTWARE CLEANED
# ----------------
#
# Apache
# PHP
# PHP-FPM
# MariaDB client
# Docker
# Docker data
# AWS CLI v2
# kubectl
# eksctl
# Helm
# kind
# Kubernetes configuration
# Docker configuration
# Charlie Cafe web files
# Charlie Cafe logs
#
# =============================================================================
#
# THIS SCRIPT DOES NOT REMOVE
# ---------------------------
#
# systemd
# SSH
# cloud-init
# SSM Agent
# NetworkManager
# kernel
# RPM
# DNF
# Amazon Linux core packages
#
# =============================================================================
#
# TRUE FACTORY RESET
# ------------------
#
# If you want the EC2 to be exactly like a newly launched Amazon Linux AMI,
# terminate the instance and launch a fresh Amazon Linux 2023 instance.
#
# =============================================================================

set -u

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_FILE="/var/log/charlie-cafe-force-cleanup.log"

touch "$LOG_FILE" 2>/dev/null || true

exec > >(tee -a "$LOG_FILE") 2>&1


# =============================================================================
# 1. HEADER
# =============================================================================

echo
echo "======================================================================"
echo "       CHARLIE CAFE - ULTRA FAST FORCE CLEANUP"
echo "======================================================================"
echo
date
echo


# =============================================================================
# 2. ROOT CHECK
# =============================================================================

if [ "$(id -u)" -ne 0 ]; then

    echo "ERROR: This script must run as root."
    echo
    echo "Run:"
    echo
    echo "sudo bash force-clean-charlie-cafe.sh"
    echo

    exit 1

fi


# =============================================================================
# 3. OPERATING SYSTEM CHECK
# =============================================================================

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "ERROR: Cannot detect operating system."
    exit 1
fi

echo "Operating System:"
echo "  ${PRETTY_NAME:-Unknown}"
echo

if [ "${ID:-}" != "amzn" ]; then

    echo "WARNING:"
    echo "This script is designed for Amazon Linux."
    echo

fi


# =============================================================================
# 4. STOP DNF AUTOMATIC SERVICES
# =============================================================================
#
# These services can start another DNF operation while cleanup is running.
#
# We stop and disable them temporarily.
#
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "STOPPING PACKAGE-MANAGER AUTOMATIC SERVICES"
echo "----------------------------------------------------------------------"
echo


PACKAGE_TIMERS=(
    dnf-makecache.timer
    dnf5-makecache.timer
    dnf-automatic.timer
    dnf-automatic-install.timer
    dnf-automatic-download.timer
    dnf-automatic-notifyonly.timer
)

for TIMER in "${PACKAGE_TIMERS[@]}"; do

    systemctl stop "$TIMER" 2>/dev/null || true
    systemctl disable "$TIMER" 2>/dev/null || true

done


# Stop PackageKit if installed.

systemctl stop packagekit.service 2>/dev/null || true
systemctl disable packagekit.service 2>/dev/null || true


echo "Package-manager automatic services stopped."


# =============================================================================
# 5. FORCE-KILL PACKAGE MANAGERS
# =============================================================================
#
# THIS IS THE CRITICAL SECTION.
#
# It prevents:
#
#     Waiting for process with pid XXXXX to finish.
#
# We terminate known package-manager processes BEFORE touching packages.
#
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FORCE-KILLING PACKAGE MANAGER PROCESSES"
echo "----------------------------------------------------------------------"
echo


echo "Processes before cleanup:"
echo

ps -eo pid,ppid,user,stat,etime,cmd 2>/dev/null \
    | grep -E '(^|/)(dnf|dnf5|rpm|packagekitd)( |$)' \
    | grep -v grep \
    || echo "  No DNF/RPM processes found."


echo
echo "Sending SIGTERM..."

pkill -TERM -x dnf 2>/dev/null || true
pkill -TERM -x dnf5 2>/dev/null || true
pkill -TERM -x rpm 2>/dev/null || true
pkill -TERM -x packagekitd 2>/dev/null || true


# VERY SHORT pause.

sleep 0.2


echo "Sending SIGKILL..."

pkill -KILL -x dnf 2>/dev/null || true
pkill -KILL -x dnf5 2>/dev/null || true
pkill -KILL -x rpm 2>/dev/null || true
pkill -KILL -x packagekitd 2>/dev/null || true


# Kill common Python DNF wrappers.

pkill -KILL -f '/usr/libexec/platform-python.*dnf' 2>/dev/null || true


# Kill DNF helper processes.

pkill -KILL -f 'dnf5.*makecache' 2>/dev/null || true
pkill -KILL -f 'dnf.*makecache' 2>/dev/null || true


echo
echo "Package-manager processes after force kill:"
echo

ps -eo pid,ppid,user,stat,etime,cmd 2>/dev/null \
    | grep -E '(^|/)(dnf|dnf5|rpm|packagekitd)( |$)' \
    | grep -v grep \
    || echo "  NONE"


# =============================================================================
# 6. FORCE STOP LAB SERVICES
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FORCE STOPPING LAB SERVICES"
echo "----------------------------------------------------------------------"
echo


systemctl stop httpd 2>/dev/null || true
systemctl disable httpd 2>/dev/null || true

systemctl stop php-fpm 2>/dev/null || true
systemctl disable php-fpm 2>/dev/null || true

systemctl stop docker 2>/dev/null || true
systemctl disable docker 2>/dev/null || true

systemctl stop containerd 2>/dev/null || true
systemctl disable containerd 2>/dev/null || true


# =============================================================================
# 7. FORCE-KILL LAB PROCESSES
# =============================================================================

echo
echo "Force-killing lab processes..."

pkill -KILL -x httpd 2>/dev/null || true
pkill -KILL -x php-fpm 2>/dev/null || true

pkill -KILL -x dockerd 2>/dev/null || true
pkill -KILL -x containerd 2>/dev/null || true
pkill -KILL -x docker-proxy 2>/dev/null || true

pkill -KILL -x containerd-shim 2>/dev/null || true
pkill -KILL -x containerd-shim-runc-v2 2>/dev/null || true

echo "Lab processes stopped."


# =============================================================================
# 8. DOCKER CONTAINER CLEANUP
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "REMOVING DOCKER CONTAINERS"
echo "----------------------------------------------------------------------"
echo


if command -v docker >/dev/null 2>&1; then

    docker ps -aq 2>/dev/null \
        | xargs -r docker rm -f 2>/dev/null || true

    echo "Docker containers removed."

else

    echo "Docker command not available."

fi


# =============================================================================
# 9. FORCE REMOVE DOCKER STORAGE
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "REMOVING DOCKER STORAGE"
echo "----------------------------------------------------------------------"
echo


rm -rf /var/lib/docker
rm -rf /var/lib/containerd

rm -rf /etc/docker

rm -rf /root/.docker
rm -rf /home/ec2-user/.docker

rm -rf /usr/local/lib/docker
rm -rf /usr/local/libexec/docker

rm -rf /run/docker
rm -rf /run/containerd

rm -f /usr/local/bin/docker-compose

echo "Docker storage removed."


# =============================================================================
# 10. REMOVE DOCKER GROUP
# =============================================================================

echo
echo "Removing docker group..."

if getent group docker >/dev/null 2>&1; then

    gpasswd -d ec2-user docker 2>/dev/null || true
    groupdel docker 2>/dev/null || true

fi


# =============================================================================
# 11. CLEAN APACHE WEB ROOT
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "CLEANING APACHE"
echo "----------------------------------------------------------------------"
echo


rm -rf /var/www/html/*

rm -rf /var/log/httpd/*

rm -f /etc/httpd/conf.d/php-fpm.conf
rm -f /etc/httpd/conf.d/charlie-cafe.conf
rm -f /etc/httpd/conf.d/cafe.conf

rm -rf /etc/httpd/conf.d/*charlie*
rm -rf /etc/httpd/conf.d/*cafe*


# =============================================================================
# 12. CLEAN PHP-FPM
# =============================================================================

echo
echo "Cleaning PHP-FPM..."

rm -rf /run/php-fpm

rm -rf /var/lib/php/session/*
rm -rf /var/lib/php/wsdlcache/*
rm -rf /var/lib/php/opcache/*

rm -rf /var/log/php-fpm

rm -f /etc/php-fpm.d/www.conf


# =============================================================================
# 13. REMOVE BOOTSTRAP FILES
# =============================================================================

echo
echo "Removing Charlie Cafe logs..."

rm -f /var/log/charlie-cafe-bootstrap.log
rm -f /var/log/charlie-cafe-bootstrap-complete.txt
rm -f /var/log/charlie-cafe-verification.log
rm -f /var/log/charlie-cafe-cleanup.log

rm -f /var/log/charlie-cafe-force-cleanup.log


# =============================================================================
# 14. REMOVE AWS CLI V2
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "REMOVING AWS CLI V2"
echo "----------------------------------------------------------------------"
echo


rm -rf /usr/local/aws-cli

rm -f /usr/local/bin/aws
rm -f /usr/local/bin/aws_completer


# =============================================================================
# 15. REMOVE KUBECTL
# =============================================================================

echo
echo "Removing kubectl..."

rm -f /usr/local/bin/kubectl


# =============================================================================
# 16. REMOVE EKSCTL
# =============================================================================

echo
echo "Removing eksctl..."

rm -f /usr/local/bin/eksctl


# =============================================================================
# 17. REMOVE HELM
# =============================================================================

echo
echo "Removing Helm..."

rm -f /usr/local/bin/helm

rm -rf /root/.cache/helm
rm -rf /root/.config/helm
rm -rf /root/.local/share/helm

rm -rf /home/ec2-user/.cache/helm
rm -rf /home/ec2-user/.config/helm
rm -rf /home/ec2-user/.local/share/helm


# =============================================================================
# 18. REMOVE KIND
# =============================================================================

echo
echo "Removing kind..."

rm -f /usr/local/bin/kind

rm -rf /root/.kind
rm -rf /home/ec2-user/.kind


# =============================================================================
# 19. REMOVE KUBERNETES CONFIGURATION
# =============================================================================

echo
echo "Removing Kubernetes configuration..."

rm -rf /root/.kube
rm -rf /home/ec2-user/.kube


# =============================================================================
# 20. REMOVE LAB PATH MODIFICATIONS
# =============================================================================

echo
echo "Cleaning shell configuration..."

if [ -f /home/ec2-user/.bashrc ]; then

    sed -i '/Charlie Cafe/d' /home/ec2-user/.bashrc 2>/dev/null || true
    sed -i '/charlie-cafe/d' /home/ec2-user/.bashrc 2>/dev/null || true

fi


if [ -f /root/.bashrc ]; then

    sed -i '/Charlie Cafe/d' /root/.bashrc 2>/dev/null || true
    sed -i '/charlie-cafe/d' /root/.bashrc 2>/dev/null || true

fi


# =============================================================================
# 21. FORCE REMOVE LAB RPM PACKAGES
# =============================================================================
#
# NO DNF.
#
# NO DNF TRANSACTION.
#
# NO "Waiting for process..."
#
# We query installed packages locally using RPM and erase only known lab
# packages.
#
# --nodeps intentionally makes this aggressive.
#
# =============================================================================

echo
echo "======================================================================"
echo "FORCE REMOVING LAB RPM PACKAGES"
echo "======================================================================"
echo


LAB_PACKAGES=(

    httpd
    httpd-tools

    php
    php-cli
    php-common
    php-fpm
    php-mysqlnd
    php-mbstring
    php-xml
    php-opcache
    php-json

    mariadb
    mariadb105
    mariadb1011
    mariadb114
    mariadb118
    mariadb123

    docker
    docker-client
    docker-common
    docker-engine
    docker-buildx
    docker-compose
    docker-compose-plugin

    containerd
    containerd.io

    runc

)


for PACKAGE in "${LAB_PACKAGES[@]}"; do

    if rpm -q "$PACKAGE" >/dev/null 2>&1; then

        echo
        echo "FORCE REMOVING: $PACKAGE"

        rpm -e --nodeps "$PACKAGE" 2>&1 || true

    fi

done


# =============================================================================
# 22. REMOVE PACKAGES BY NAME PATTERN
# =============================================================================
#
# Some package versions/names may differ.
#
# We discover installed packages locally.
#
# NO repository access.
#
# NO DNF.
#
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "CHECKING FOR REMAINING LAB RPMs"
echo "----------------------------------------------------------------------"
echo


REMAINING_PACKAGES=$(rpm -qa 2>/dev/null \
    | grep -E '^(php|php-[^ ]*|httpd|httpd-[^ ]*|mariadb|mariadb-[^ ]*|docker|docker-[^ ]*|containerd|runc)(-|$)' \
    || true)


if [ -n "$REMAINING_PACKAGES" ]; then

    echo "Remaining matching packages:"
    echo "$REMAINING_PACKAGES"

    echo
    echo "Force removing remaining matching packages..."

    while IFS= read -r PACKAGE; do

        [ -z "$PACKAGE" ] && continue

        rpm -e --nodeps "$PACKAGE" 2>&1 || true

    done <<< "$REMAINING_PACKAGES"

else

    echo "No remaining matching lab packages."

fi


# =============================================================================
# 23. CLEAN PACKAGE CACHE
# =============================================================================
#
# IMPORTANT:
#
# We DO NOT execute:
#
#     dnf clean all
#
# because DNF itself can attempt to obtain a package-manager lock.
#
# Instead, delete cache directories directly.
#
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "REMOVING DNF CACHE DIRECTLY"
echo "----------------------------------------------------------------------"
echo


rm -rf /var/cache/dnf/* 2>/dev/null || true

rm -rf /var/cache/yum/* 2>/dev/null || true

echo "Package cache removed."


# =============================================================================
# 24. CLEAN TEMPORARY DIRECTORIES
# =============================================================================

echo
echo "Cleaning temporary files..."

find /tmp -mindepth 1 -maxdepth 1 \
    -exec rm -rf {} + 2>/dev/null || true

find /var/tmp -mindepth 1 -maxdepth 1 \
    -exec rm -rf {} + 2>/dev/null || true


# =============================================================================
# 25. REMOVE RUNTIME FILES
# =============================================================================

rm -rf /run/php-fpm
rm -rf /run/docker
rm -rf /run/containerd

rm -rf /var/log/httpd
rm -rf /var/log/php-fpm


# =============================================================================
# 26. RECREATE EMPTY WEB ROOT
# =============================================================================

mkdir -p /var/www/html

chmod 755 /var/www
chmod 755 /var/www/html


# =============================================================================
# 27. FORCE STOP PACKAGE MANAGERS ONE MORE TIME
# =============================================================================
#
# In case something restarted during cleanup.
#
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FINAL PACKAGE MANAGER FORCE CHECK"
echo "----------------------------------------------------------------------"
echo


pkill -KILL -x dnf 2>/dev/null || true
pkill -KILL -x dnf5 2>/dev/null || true
pkill -KILL -x rpm 2>/dev/null || true
pkill -KILL -x packagekitd 2>/dev/null || true


# =============================================================================
# 28. FINAL LAB PROCESS CHECK
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FINAL PROCESS CHECK"
echo "----------------------------------------------------------------------"
echo


LAB_PROCESS_FOUND=0


for PROCESS in \
    httpd \
    php-fpm \
    dockerd \
    containerd \
    docker-proxy \
    dnf \
    dnf5 \
    rpm \
    packagekitd
do

    if pgrep -x "$PROCESS" >/dev/null 2>&1; then

        echo "WARNING: $PROCESS is still running"

        LAB_PROCESS_FOUND=1

    else

        echo "OK: $PROCESS not running"

    fi

done


# =============================================================================
# 29. FINAL SERVICE CHECK
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FINAL SERVICE CHECK"
echo "----------------------------------------------------------------------"
echo


for SERVICE in \
    httpd \
    php-fpm \
    docker \
    containerd
do

    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then

        echo "WARNING: $SERVICE is active"

    else

        echo "OK: $SERVICE is inactive"

    fi

done


# =============================================================================
# 30. FINAL COMMAND CHECK
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FINAL COMMAND CHECK"
echo "----------------------------------------------------------------------"
echo


for COMMAND in \
    httpd \
    apachectl \
    php \
    docker \
    aws \
    kubectl \
    eksctl \
    helm \
    kind
do

    if command -v "$COMMAND" >/dev/null 2>&1; then

        echo "WARNING: $COMMAND still exists"

    else

        echo "OK: $COMMAND removed"

    fi

done


# =============================================================================
# 31. FINAL FILE CHECK
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "FINAL FILE CHECK"
echo "----------------------------------------------------------------------"
echo


FILES=(

    /usr/local/bin/aws
    /usr/local/bin/aws_completer

    /usr/local/bin/kubectl
    /usr/local/bin/eksctl
    /usr/local/bin/helm
    /usr/local/bin/kind
    /usr/local/bin/docker-compose

    /usr/local/aws-cli

    /var/lib/docker
    /var/lib/containerd

    /root/.kube
    /home/ec2-user/.kube

)


for FILE in "${FILES[@]}"; do

    if [ -e "$FILE" ]; then

        echo "WARNING: STILL EXISTS: $FILE"

    else

        echo "OK: removed: $FILE"

    fi

done


# =============================================================================
# 32. WEB ROOT CHECK
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "WEB ROOT CHECK"
echo "----------------------------------------------------------------------"
echo


if find /var/www/html \
    -mindepth 1 \
    -print -quit 2>/dev/null \
    | grep -q .
then

    echo "WARNING: /var/www/html is not empty"

else

    echo "OK: /var/www/html is empty"

fi


# =============================================================================
# 33. RPM DATABASE CHECK
# =============================================================================
#
# We check the database without running DNF.
#
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "RPM DATABASE CHECK"
echo "----------------------------------------------------------------------"
echo


if rpm -qa >/dev/null 2>&1; then

    echo "OK: RPM database is readable."

else

    echo "WARNING: RPM database returned an error."

fi


# =============================================================================
# 34. REMAINING LAB RPM CHECK
# =============================================================================

echo
echo "----------------------------------------------------------------------"
echo "REMAINING LAB PACKAGE CHECK"
echo "----------------------------------------------------------------------"
echo


FINAL_LAB_PACKAGES=$(rpm -qa 2>/dev/null \
    | grep -E '^(php|php-[^ ]*|httpd|httpd-[^ ]*|mariadb|mariadb-[^ ]*|docker|docker-[^ ]*|containerd|runc)(-|$)' \
    || true)


if [ -n "$FINAL_LAB_PACKAGES" ]; then

    echo "WARNING: Some matching packages remain:"
    echo
    echo "$FINAL_LAB_PACKAGES"

else

    echo "OK: No matching Charlie Cafe lab RPM packages remain."

fi


# =============================================================================
# 35. FINAL SUMMARY
# =============================================================================

echo
echo
echo "======================================================================"
echo "              CHARLIE CAFE FORCE CLEANUP COMPLETE"
echo "======================================================================"
echo
echo "NO DNF REMOVE WAS USED."
echo "NO DNF AUTOREMOVE WAS USED."
echo "NO DNF CLEAN WAS USED."
echo
echo "Lab software and lab files were aggressively removed."
echo
echo "Cleanup log:"
echo "  $LOG_FILE"
echo
echo "======================================================================"
echo


# =============================================================================
# 36. OPTIONAL REBOOT
# =============================================================================
#
# If you want the EC2 to restart automatically after cleanup, uncomment:
#
# echo "Rebooting EC2 in 3 seconds..."
# sleep 3
# reboot
#
# =============================================================================

exit 0