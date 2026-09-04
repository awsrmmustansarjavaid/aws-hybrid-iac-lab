#!/bin/bash

# =====================================================================
# ☕ Charlie Cafe — Automatic AWS RDS + Secrets Manager Lab
# =====================================================================
#
# Operating System:
#   Amazon Linux 2023
#
# Purpose:
#   Automatically discover ALL MySQL RDS instances in the selected
#   AWS region and use each RDS instance's own RDS-managed
#   Secrets Manager secret.
#
# IMPORTANT:
#
#   NO manual:
#       - RDS hostname
#       - RDS username
#       - RDS password
#       - Secret name
#
#   is required.
#
# Architecture:
#
#   EC2
#    |
#    | IAM Role
#    |
#    +----------------------+
#    |                      |
#    v                      v
# Secrets Manager          RDS
#    |                      |
#    | MasterUserSecret     |
#    +----------+-----------+
#               |
#               v
#        MySQL Authentication
#
#
# The script:
#
#   1. Checks AWS CLI
#   2. Checks Python
#   3. Installs MySQL-compatible client if required
#   4. Installs netcat if required
#   5. Verifies EC2 IAM identity
#   6. Discovers ALL MySQL RDS instances
#   7. Discovers each RDS-managed Secrets Manager secret
#   8. Retrieves username/password automatically
#   9. Gets RDS endpoint automatically
#  10. Tests DNS
#  11. Tests TCP 3306
#  12. Tests MySQL authentication
#  13. Creates CharlieCafeDB
#  14. Creates tables
#  15. Creates relationships
#  16. Creates indexes safely
#  17. Creates CHECK constraints
#  18. Creates order_summary view
#  19. Inserts sample data
#  20. Performs CRUD practice
#  21. Performs comprehensive verification
#  22. Continues processing if one RDS instance fails
#  23. Displays final RDS summary
#
# IMPORTANT:
#
# This script modifies the database layer by creating:
#
#   CharlieCafeDB
#
# inside each discovered MySQL RDS instance.
#
# It does NOT:
#
#   - Delete RDS instances
#   - Delete existing databases
#   - Modify RDS infrastructure
#   - Print passwords
#   - Require manual database credentials
#
# =====================================================================


# =====================================================================
# SECTION 1 — SCRIPT SETTINGS
# =====================================================================

set -u
set -o pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"

DB_NAME="${DB_NAME:-CharlieCafeDB}"

DEFAULT_RDS_PORT="${RDS_PORT:-3306}"

MYSQL_ERROR_FILE="/tmp/charlie_cafe_mysql_error.txt"

EXPECTED_TABLE_COUNT=8


# =====================================================================
# SECTION 2 — COLORS
# =====================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'


# =====================================================================
# SECTION 3 — LOGGING FUNCTIONS
# =====================================================================

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

failure() {
    echo -e "${RED}[FAIL]${NC} $1"
}

section() {

    echo
    echo "====================================================================="
    echo "$1"
    echo "====================================================================="
    echo

}


# =====================================================================
# SECTION 4 — GLOBAL RESULT TRACKING
# =====================================================================

TOTAL_RDS=0
SUCCESSFUL_RDS=0
FAILED_RDS=0
SKIPPED_RDS=0

declare -a SUCCESS_RDS_LIST
declare -a FAILED_RDS_LIST
declare -a SKIPPED_RDS_LIST


# =====================================================================
# SECTION 5 — HEADER
# =====================================================================

section "☕ CHARLIE CAFE — AUTOMATIC RDS + SECRETS MANAGER LAB"

echo "AWS Region : ${AWS_REGION}"
echo "Database   : ${DB_NAME}"
echo

echo "Automatic discovery:"
echo
echo "  • MySQL RDS instances"
echo "  • RDS-managed Secrets Manager secrets"
echo "  • RDS endpoints"
echo "  • Database usernames"
echo "  • Database passwords"
echo

echo "No password or endpoint needs to be entered manually."
echo


# =====================================================================
# SECTION 6 — CHECK AWS CLI
# =====================================================================

section "1. AWS CLI CHECK"

if ! command -v aws >/dev/null 2>&1; then

    failure "AWS CLI is not installed."

    echo
    echo "Install AWS CLI before running this script."
    exit 1

fi

success "AWS CLI detected."


# =====================================================================
# SECTION 7 — CHECK PYTHON
# =====================================================================

section "2. PYTHON CHECK"

if ! command -v python3 >/dev/null 2>&1; then

    failure "Python 3 is required."

    exit 1

fi

success "Python 3 detected."


# =====================================================================
# SECTION 8 — CHECK MYSQL CLIENT
# =====================================================================

section "3. MYSQL CLIENT CHECK"

if ! command -v mysql >/dev/null 2>&1; then

    log "MySQL-compatible client not found."

    log "Installing MariaDB client..."

    if sudo dnf install -y mariadb105; then

        success "MariaDB/MySQL-compatible client installed."

    else

        failure "Unable to install MariaDB client."
        exit 1

    fi

else

    success "MySQL/MariaDB client already installed."

fi


# =====================================================================
# SECTION 9 — CHECK NETCAT
# =====================================================================

section "4. NETWORK TOOL CHECK"

if ! command -v nc >/dev/null 2>&1; then

    log "netcat is not installed."

    if sudo dnf install -y nmap-ncat; then

        success "nmap-ncat installed."

    else

        failure "Unable to install nmap-ncat."
        exit 1

    fi

else

    success "netcat detected."

fi


# =====================================================================
# SECTION 10 — AWS IDENTITY
# =====================================================================

section "5. EC2 IAM ROLE VERIFICATION"

CALLER_IDENTITY=$(aws sts get-caller-identity \
    --region "${AWS_REGION}" \
    --output json 2>/tmp/charlie_cafe_sts_error.txt)

STS_STATUS=$?

if [[ ${STS_STATUS} -ne 0 ]]; then

    failure "Unable to verify AWS identity."

    cat /tmp/charlie_cafe_sts_error.txt 2>/dev/null || true

    exit 1

fi

echo "${CALLER_IDENTITY}"

success "EC2 AWS identity verified."


# =====================================================================
# SECTION 11 — DISCOVER RDS INSTANCES
# =====================================================================

section "6. DISCOVERING MYSQL RDS INSTANCES"

RDS_JSON=$(aws rds describe-db-instances \
    --region "${AWS_REGION}" \
    --query 'DBInstances[?Engine==`mysql`].[DBInstanceIdentifier,DBInstanceArn,Endpoint.Address,Endpoint.Port,DBName,DBInstanceStatus,MasterUsername,MasterUserSecret.SecretArn]' \
    --output json 2>/tmp/charlie_cafe_rds_error.txt)

RDS_STATUS_CODE=$?

if [[ ${RDS_STATUS_CODE} -ne 0 ]]; then

    failure "Unable to query RDS."

    cat /tmp/charlie_cafe_rds_error.txt 2>/dev/null || true

    exit 1

fi


RDS_COUNT=$(echo "${RDS_JSON}" | python3 -c '
import sys
import json

data = json.load(sys.stdin)

print(len(data))
')


if [[ "${RDS_COUNT}" -eq 0 ]]; then

    failure "No MySQL RDS instances found in ${AWS_REGION}."

    exit 1

fi


TOTAL_RDS="${RDS_COUNT}"

success "Found ${RDS_COUNT} MySQL RDS instance(s)."


# =====================================================================
# SECTION 12 — DISPLAY DISCOVERED RDS
# =====================================================================

echo

echo "${RDS_JSON}" | python3 -c '

import sys
import json

data = json.load(sys.stdin)

for row in data:

    identifier = row[0] or ""
    endpoint = row[2] or ""
    port = row[3] or ""
    dbname = row[4] or ""
    status = row[5] or ""
    secret = row[7] or ""

    print("------------------------------------------------------------")
    print(f"RDS Instance : {identifier}")
    print(f"Endpoint     : {endpoint}")
    print(f"Port         : {port}")
    print(f"DBName       : {dbname or "None"}")
    print(f"Status       : {status}")
    print(f"Secret ARN   : {secret or "None"}")
    print("------------------------------------------------------------")

'


# =====================================================================
# SECTION 13 — MYSQL EXECUTION FUNCTION
# =====================================================================
#
# This function uses MYSQL_PWD so that the password is NOT supplied
# as a command-line argument.
#
# The password is never echoed.
#
# =====================================================================

mysql_exec() {

    MYSQL_PWD="${DB_PASSWORD}" mysql \
        --host="${RDS_HOST}" \
        --port="${RDS_INSTANCE_PORT}" \
        --user="${DB_USER}" \
        --batch \
        --raw \
        "$@"

}


# =====================================================================
# SECTION 14 — CHECK INDEX
# =====================================================================

index_exists() {

    local TABLE_NAME="$1"
    local INDEX_NAME="$2"

    local COUNT

    COUNT=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM information_schema.STATISTICS

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        AND TABLE_NAME = '${TABLE_NAME}'

        AND INDEX_NAME = '${INDEX_NAME}';

    " 2>/dev/null)

    if [[ "${COUNT}" == "0" ]]; then
        return 1
    fi

    return 0

}


# =====================================================================
# SECTION 15 — CREATE INDEX IF MISSING
# =====================================================================

ensure_index() {

    local TABLE_NAME="$1"
    local INDEX_NAME="$2"
    local COLUMN_NAME="$3"

    if index_exists "${TABLE_NAME}" "${INDEX_NAME}"; then

        success "Index ${INDEX_NAME} already exists."

        return 0

    fi


    log "Creating index ${INDEX_NAME}..."


    mysql_exec "${DB_NAME}" -e "

        CREATE INDEX ${INDEX_NAME}

        ON ${TABLE_NAME}(${COLUMN_NAME});

    " 2>"${MYSQL_ERROR_FILE}"


    if [[ $? -eq 0 ]]; then

        success "Index ${INDEX_NAME} created."

        return 0

    fi


    failure "Unable to create index ${INDEX_NAME}."

    cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

    return 1

}


# =====================================================================
# SECTION 16 — PROCESS ONE RDS INSTANCE
# =====================================================================

process_rds() {

    local RDS_ROW="$1"

    # -----------------------------------------------------------------
    # Extract RDS information
    # -----------------------------------------------------------------

    RDS_IDENTIFIER=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[0] or "")
')

    RDS_ARN=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[1] or "")
')

    RDS_HOST=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[2] or "")
')

    RDS_INSTANCE_PORT=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[3] or "3306")
')

    RDS_EXISTING_DB=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[4] or "")
')

    RDS_STATUS=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[5] or "")
')

    SECRET_ARN=$(echo "${RDS_ROW}" | python3 -c '
import sys
import json

x = json.load(sys.stdin)

print(x[7] or "")
')


    # -----------------------------------------------------------------
    # RDS HEADER
    # -----------------------------------------------------------------

    section "PROCESSING RDS: ${RDS_IDENTIFIER}"

    echo "RDS Identifier : ${RDS_IDENTIFIER}"
    echo "RDS Status     : ${RDS_STATUS}"
    echo "RDS Endpoint   : ${RDS_HOST}"
    echo "RDS Port       : ${RDS_INSTANCE_PORT}"
    echo "Existing DB    : ${RDS_EXISTING_DB:-None}"
    echo "Secret ARN     : ${SECRET_ARN:-None}"
    echo


    # -----------------------------------------------------------------
    # RDS STATUS
    # -----------------------------------------------------------------

    if [[ "${RDS_STATUS}" != "available" ]]; then

        warning "RDS instance is not available."

        echo "Skipping ${RDS_IDENTIFIER}."

        SKIPPED_RDS=$((SKIPPED_RDS + 1))

        SKIPPED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 2

    fi

    success "RDS instance is available."


    # -----------------------------------------------------------------
    # CHECK ENDPOINT
    # -----------------------------------------------------------------

    if [[ -z "${RDS_HOST}" ]]; then

        failure "RDS endpoint is missing."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 1

    fi


    # -----------------------------------------------------------------
    # CHECK RDS-MANAGED SECRET
    # -----------------------------------------------------------------

    if [[ -z "${SECRET_ARN}" || "${SECRET_ARN}" == "None" ]]; then

        failure "No RDS-managed Secrets Manager secret found."

        echo
        echo "This RDS instance does not expose"
        echo "MasterUserSecret.SecretArn."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 1

    fi

    success "RDS-managed Secrets Manager secret discovered."


    # -----------------------------------------------------------------
    # RETRIEVE SECRET
    # -----------------------------------------------------------------

    log "Retrieving credentials from Secrets Manager..."


    SECRET_JSON=$(aws secretsmanager get-secret-value \
        --secret-id "${SECRET_ARN}" \
        --region "${AWS_REGION}" \
        --query SecretString \
        --output text 2>"${MYSQL_ERROR_FILE}")

    SECRET_STATUS_CODE=$?


    if [[ ${SECRET_STATUS_CODE} -ne 0 ]]; then

        failure "Unable to retrieve Secrets Manager secret."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 1

    fi


    if [[ -z "${SECRET_JSON}" || "${SECRET_JSON}" == "None" ]]; then

        failure "SecretString is empty."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 1

    fi


    success "Secrets Manager access successful."


    # -----------------------------------------------------------------
    # VALIDATE SECRET JSON
    # -----------------------------------------------------------------

    if ! echo "${SECRET_JSON}" | python3 -c '
import sys
import json

json.load(sys.stdin)

' >/dev/null 2>&1; then

        failure "Secrets Manager SecretString is not valid JSON."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 1

    fi


    # -----------------------------------------------------------------
    # EXTRACT USERNAME
    # -----------------------------------------------------------------

    DB_USER=$(echo "${SECRET_JSON}" | python3 -c '
import sys
import json

data = json.load(sys.stdin)

print(data.get("username", ""))

')


    # -----------------------------------------------------------------
    # EXTRACT PASSWORD
    # -----------------------------------------------------------------
    #
    # Password is stored only in DB_PASSWORD.
    #
    # It is NEVER printed.
    #
    # -----------------------------------------------------------------

    DB_PASSWORD=$(echo "${SECRET_JSON}" | python3 -c '
import sys
import json

data = json.load(sys.stdin)

print(data.get("password", ""))

')


    if [[ -z "${DB_USER}" || -z "${DB_PASSWORD}" ]]; then

        failure "Secret does not contain username/password."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        return 1

    fi


    success "Database credentials successfully retrieved."


    # -----------------------------------------------------------------
    # SECRET HOST
    # -----------------------------------------------------------------

    SECRET_HOST=$(echo "${SECRET_JSON}" | python3 -c '
import sys
import json

data = json.load(sys.stdin)

print(data.get("host", ""))

' 2>/dev/null || true)


    echo
    echo "Secrets Manager username : ${DB_USER}"
    echo "Secrets Manager host     : ${SECRET_HOST:-Not provided}"
    echo "Secrets Manager password : ********"
    echo


    # -----------------------------------------------------------------
    # DNS TEST
    # -----------------------------------------------------------------

    log "Testing DNS resolution..."


    if getent hosts "${RDS_HOST}" >/dev/null 2>&1; then

        success "RDS endpoint resolves successfully."

    else

        failure "RDS endpoint does not resolve."

        warning "Check VPC DNS and network configuration."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD
        return 1

    fi


    # -----------------------------------------------------------------
    # TCP TEST
    # -----------------------------------------------------------------

    log "Testing TCP port ${RDS_INSTANCE_PORT}..."


    if nc -z -w 5 "${RDS_HOST}" "${RDS_INSTANCE_PORT}" >/dev/null 2>&1; then

        success "TCP ${RDS_INSTANCE_PORT} is reachable."

    else

        failure "TCP ${RDS_INSTANCE_PORT} is NOT reachable."

        warning "Check the RDS Security Group inbound rule."

        echo
        echo "Expected network path:"
        echo
        echo "EC2"
        echo " │"
        echo " │ TCP ${RDS_INSTANCE_PORT}"
        echo " ▼"
        echo "RDS Security Group"
        echo " │"
        echo " ▼"
        echo "RDS MySQL"
        echo

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD
        return 1

    fi


    # -----------------------------------------------------------------
    # MYSQL AUTHENTICATION
    # -----------------------------------------------------------------

    log "Testing MySQL authentication..."


    MYSQL_VERSION=$(mysql_exec \
        -N \
        -e "SELECT VERSION();" \
        2>"${MYSQL_ERROR_FILE}")

    MYSQL_STATUS_CODE=$?


    if [[ ${MYSQL_STATUS_CODE} -ne 0 || -z "${MYSQL_VERSION}" ]]; then

        failure "MySQL authentication failed."

        echo
        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true
        echo

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "MySQL authentication successful."

    echo
    echo "MySQL Version: ${MYSQL_VERSION}"
    echo


    # =================================================================
    # DATABASE CREATION
    # =================================================================

    log "Creating ${DB_NAME}..."


    mysql_exec -e "

        CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`

        CHARACTER SET utf8mb4

        COLLATE utf8mb4_unicode_ci;

    " 2>"${MYSQL_ERROR_FILE}"


    if [[ $? -ne 0 ]]; then

        failure "Unable to create ${DB_NAME}."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "${DB_NAME} is ready."


    # =================================================================
    # TABLE CREATION
    # =================================================================

    log "Creating Charlie Cafe tables..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

-- ================================================================
-- CUSTOMERS
-- ================================================================

CREATE TABLE IF NOT EXISTS customers (

    customer_id INT AUTO_INCREMENT,

    first_name VARCHAR(50) NOT NULL,

    last_name VARCHAR(50) NOT NULL,

    email VARCHAR(150) NOT NULL,

    phone VARCHAR(30),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (customer_id),

    UNIQUE KEY uk_customer_email (email)

) ENGINE=InnoDB;


-- ================================================================
-- EMPLOYEES
-- ================================================================

CREATE TABLE IF NOT EXISTS employees (

    employee_id INT AUTO_INCREMENT,

    employee_code VARCHAR(30) NOT NULL,

    first_name VARCHAR(50) NOT NULL,

    last_name VARCHAR(50) NOT NULL,

    role VARCHAR(50) NOT NULL,

    email VARCHAR(150),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (employee_id),

    UNIQUE KEY uk_employee_code (employee_code),

    UNIQUE KEY uk_employee_email (email)

) ENGINE=InnoDB;


-- ================================================================
-- MENU
-- ================================================================

CREATE TABLE IF NOT EXISTS cafe_menu (

    item_id INT AUTO_INCREMENT,

    item_name VARCHAR(100) NOT NULL,

    category VARCHAR(50) NOT NULL,

    price DECIMAL(10,2) NOT NULL,

    available BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (item_id),

    UNIQUE KEY uk_menu_item_name (item_name),

    CONSTRAINT chk_menu_price

        CHECK (price >= 0)

) ENGINE=InnoDB;


-- ================================================================
-- CAFE TABLES
-- ================================================================

CREATE TABLE IF NOT EXISTS cafe_tables (

    table_id INT AUTO_INCREMENT,

    table_number INT NOT NULL,

    seats INT NOT NULL,

    status VARCHAR(30) DEFAULT 'available',

    PRIMARY KEY (table_id),

    UNIQUE KEY uk_table_number (table_number),

    CONSTRAINT chk_table_seats

        CHECK (seats > 0)

) ENGINE=InnoDB;


-- ================================================================
-- ORDERS
-- ================================================================

CREATE TABLE IF NOT EXISTS cafe_orders (

    order_id BIGINT AUTO_INCREMENT,

    order_number VARCHAR(40) NOT NULL,

    customer_id INT,

    table_id INT,

    employee_id INT,

    order_status VARCHAR(30) DEFAULT 'pending',

    payment_method VARCHAR(30),

    total_amount DECIMAL(10,2) DEFAULT 0.00,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (order_id),

    UNIQUE KEY uk_order_number (order_number),

    CONSTRAINT fk_order_customer

        FOREIGN KEY (customer_id)

        REFERENCES customers(customer_id),

    CONSTRAINT fk_order_table

        FOREIGN KEY (table_id)

        REFERENCES cafe_tables(table_id),

    CONSTRAINT fk_order_employee

        FOREIGN KEY (employee_id)

        REFERENCES employees(employee_id),

    CONSTRAINT chk_order_total

        CHECK (total_amount >= 0)

) ENGINE=InnoDB;


-- ================================================================
-- ORDER ITEMS
-- ================================================================

CREATE TABLE IF NOT EXISTS cafe_order_items (

    order_item_id BIGINT AUTO_INCREMENT,

    order_id BIGINT NOT NULL,

    item_id INT NOT NULL,

    quantity INT NOT NULL,

    unit_price DECIMAL(10,2) NOT NULL,

    subtotal DECIMAL(10,2) NOT NULL,

    PRIMARY KEY (order_item_id),

    CONSTRAINT fk_order_item_order

        FOREIGN KEY (order_id)

        REFERENCES cafe_orders(order_id)

        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_menu

        FOREIGN KEY (item_id)

        REFERENCES cafe_menu(item_id),

    CONSTRAINT chk_order_item_quantity

        CHECK (quantity > 0),

    CONSTRAINT chk_order_item_price

        CHECK (unit_price >= 0),

    CONSTRAINT chk_order_item_subtotal

        CHECK (subtotal >= 0)

) ENGINE=InnoDB;


-- ================================================================
-- PAYMENTS
-- ================================================================

CREATE TABLE IF NOT EXISTS cafe_payments (

    payment_id BIGINT AUTO_INCREMENT,

    order_id BIGINT NOT NULL,

    payment_method VARCHAR(30) NOT NULL,

    amount DECIMAL(10,2) NOT NULL,

    payment_status VARCHAR(30) DEFAULT 'pending',

    transaction_reference VARCHAR(100),

    paid_at TIMESTAMP NULL,

    PRIMARY KEY (payment_id),

    UNIQUE KEY uk_transaction_reference

        (transaction_reference),

    CONSTRAINT fk_payment_order

        FOREIGN KEY (order_id)

        REFERENCES cafe_orders(order_id),

    CONSTRAINT chk_payment_amount

        CHECK (amount >= 0)

) ENGINE=InnoDB;


-- ================================================================
-- ORDER STATUS HISTORY
-- ================================================================

CREATE TABLE IF NOT EXISTS order_status_history (

    history_id BIGINT AUTO_INCREMENT,

    order_id BIGINT NOT NULL,

    old_status VARCHAR(30),

    new_status VARCHAR(30) NOT NULL,

    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (history_id),

    CONSTRAINT fk_history_order

        FOREIGN KEY (order_id)

        REFERENCES cafe_orders(order_id)

        ON DELETE CASCADE

) ENGINE=InnoDB;

SQL


    if [[ $? -ne 0 ]]; then

        failure "Table creation failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Charlie Cafe tables created."


    # =================================================================
    # INDEXES
    # =================================================================

    section "INDEX MANAGEMENT — ${RDS_IDENTIFIER}"


    ensure_index \
        "cafe_orders" \
        "idx_orders_customer" \
        "customer_id" || true


    ensure_index \
        "cafe_orders" \
        "idx_orders_status" \
        "order_status" || true


    ensure_index \
        "cafe_orders" \
        "idx_orders_created" \
        "created_at" || true


    ensure_index \
        "cafe_order_items" \
        "idx_order_items_order" \
        "order_id" || true


    ensure_index \
        "cafe_menu" \
        "idx_menu_category" \
        "category" || true


    # =================================================================
    # VIEW
    # =================================================================

    log "Creating order_summary view..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

CREATE OR REPLACE VIEW order_summary AS

SELECT

    o.order_id,

    o.order_number,

    o.order_status,

    o.payment_method,

    o.total_amount,

    o.created_at,

    CONCAT(

        c.first_name,
        ' ',
        c.last_name

    ) AS customer_name,

    ct.table_number

FROM cafe_orders o

LEFT JOIN customers c

    ON o.customer_id = c.customer_id

LEFT JOIN cafe_tables ct

    ON o.table_id = ct.table_id;

SQL


    if [[ $? -ne 0 ]]; then

        failure "Unable to create order_summary view."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "order_summary view created."


    # =================================================================
    # SAMPLE CUSTOMERS
    # =================================================================

    log "Loading sample customers..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO customers
(
    first_name,
    last_name,
    email,
    phone
)

VALUES

(
    'Ali',
    'Khan',
    'ali@example.com',
    '03001234567'
),

(
    'Ahmed',
    'Raza',
    'ahmed@example.com',
    '03007654321'
),

(
    'Sara',
    'Malik',
    'sara@example.com',
    '03111234567'
);

SQL


    if [[ $? -ne 0 ]]; then

        failure "Customer data failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Customer data loaded."


    # =================================================================
    # SAMPLE EMPLOYEES
    # =================================================================

    log "Loading sample employees..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO employees
(
    employee_code,
    first_name,
    last_name,
    role,
    email
)

VALUES

(
    'EMP001',
    'John',
    'Smith',
    'Manager',
    'john@example.com'
),

(
    'EMP002',
    'Emma',
    'Brown',
    'Cashier',
    'emma@example.com'
),

(
    'EMP003',
    'David',
    'Wilson',
    'Barista',
    'david@example.com'
);

SQL


    if [[ $? -ne 0 ]]; then

        failure "Employee data failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Employee data loaded."


    # =================================================================
    # SAMPLE MENU
    # =================================================================

    log "Loading cafe menu..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO cafe_menu
(
    item_name,
    category,
    price,
    available
)

VALUES

(
    'Coffee',
    'Coffee',
    3.00,
    TRUE
),

(
    'Tea',
    'Tea',
    2.00,
    TRUE
),

(
    'Latte',
    'Coffee',
    4.00,
    TRUE
),

(
    'Cappuccino',
    'Coffee',
    4.00,
    TRUE
),

(
    'Fresh Juice',
    'Juice',
    5.00,
    TRUE
);

SQL


    if [[ $? -ne 0 ]]; then

        failure "Menu data failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Menu data loaded."


    # =================================================================
    # SAMPLE CAFE TABLES
    # =================================================================

    log "Loading cafe tables..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO cafe_tables
(
    table_number,
    seats,
    status
)

VALUES

(1, 2, 'available'),

(2, 2, 'available'),

(3, 4, 'available'),

(4, 4, 'available'),

(5, 6, 'available');

SQL


    if [[ $? -ne 0 ]]; then

        failure "Cafe table data failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Cafe tables loaded."


    # =================================================================
    # SAMPLE ORDERS
    # =================================================================

    log "Creating sample orders..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO cafe_orders
(
    order_number,
    customer_id,
    table_id,
    employee_id,
    order_status,
    payment_method,
    total_amount
)

SELECT

    'ORD-LAB-0001',

    c.customer_id,

    t.table_id,

    e.employee_id,

    'completed',

    'cash',

    7.00

FROM customers c

CROSS JOIN cafe_tables t

CROSS JOIN employees e

WHERE c.email = 'ali@example.com'

AND t.table_number = 1

AND e.employee_code = 'EMP002'

LIMIT 1;


INSERT IGNORE INTO cafe_orders
(
    order_number,
    customer_id,
    table_id,
    employee_id,
    order_status,
    payment_method,
    total_amount
)

SELECT

    'ORD-LAB-0002',

    c.customer_id,

    t.table_id,

    e.employee_id,

    'pending',

    'card',

    9.00

FROM customers c

CROSS JOIN cafe_tables t

CROSS JOIN employees e

WHERE c.email = 'sara@example.com'

AND t.table_number = 3

AND e.employee_code = 'EMP003'

LIMIT 1;

SQL


    if [[ $? -ne 0 ]]; then

        failure "Sample orders failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Sample orders created."


    # =================================================================
    # ORDER ITEMS
    # =================================================================

    log "Creating order items..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO cafe_order_items
(
    order_id,
    item_id,
    quantity,
    unit_price,
    subtotal
)

SELECT

    o.order_id,

    m.item_id,

    1,

    m.price,

    m.price

FROM cafe_orders o

JOIN cafe_menu m

WHERE o.order_number = 'ORD-LAB-0001'

AND m.item_name = 'Coffee'

LIMIT 1;


INSERT IGNORE INTO cafe_order_items
(
    order_id,
    item_id,
    quantity,
    unit_price,
    subtotal
)

SELECT

    o.order_id,

    m.item_id,

    1,

    m.price,

    m.price

FROM cafe_orders o

JOIN cafe_menu m

WHERE o.order_number = 'ORD-LAB-0002'

AND m.item_name = 'Fresh Juice'

LIMIT 1;

SQL


    if [[ $? -ne 0 ]]; then

        failure "Order item creation failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Order items created."


    # =================================================================
    # PAYMENTS
    # =================================================================

    log "Creating payment..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT IGNORE INTO cafe_payments
(
    order_id,
    payment_method,
    amount,
    payment_status,
    transaction_reference,
    paid_at
)

SELECT

    order_id,

    payment_method,

    total_amount,

    'completed',

    CONCAT('TXN-LAB-', order_id),

    CURRENT_TIMESTAMP

FROM cafe_orders

WHERE order_number = 'ORD-LAB-0001';

SQL


    if [[ $? -ne 0 ]]; then

        failure "Payment creation failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Payment created."


    # =================================================================
    # STATUS HISTORY
    # =================================================================

    log "Creating order status history..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT INTO order_status_history
(
    order_id,
    old_status,
    new_status
)

SELECT

    order_id,

    'pending',

    order_status

FROM cafe_orders

WHERE order_number = 'ORD-LAB-0001'

AND NOT EXISTS
(

    SELECT 1

    FROM order_status_history h

    WHERE h.order_id = cafe_orders.order_id

);

SQL


    if [[ $? -ne 0 ]]; then

        failure "Status history creation failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "Order status history created."


    # =================================================================
    # CRUD PRACTICE
    # =================================================================

    log "Running CRUD practice..."


    mysql_exec "${DB_NAME}" <<'SQL' 2>"${MYSQL_ERROR_FILE}"

INSERT INTO cafe_menu
(
    item_name,
    category,
    price,
    available
)

VALUES
(
    'Lab Special Coffee',
    'Lab',
    6.50,
    TRUE
)

ON DUPLICATE KEY UPDATE

price = 6.50;


SELECT

    item_id,
    item_name,
    category,
    price

FROM cafe_menu

WHERE item_name = 'Lab Special Coffee';


UPDATE cafe_menu

SET price = 6.75

WHERE item_name = 'Lab Special Coffee';


SELECT

    item_name,
    price

FROM cafe_menu

WHERE item_name = 'Lab Special Coffee';

SQL


    if [[ $? -ne 0 ]]; then

        failure "CRUD practice failed."

        cat "${MYSQL_ERROR_FILE}" 2>/dev/null || true

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    success "CRUD practice completed."


    # =================================================================
    # VERIFICATION
    # =================================================================

    section "VERIFICATION — ${RDS_IDENTIFIER}"


    # -----------------------------------------------------------------
    # DATABASE
    # -----------------------------------------------------------------

    echo "1. DATABASE"

    mysql_exec -e "

        SELECT

            SCHEMA_NAME AS database_name,

            DEFAULT_CHARACTER_SET_NAME AS character_set,

            DEFAULT_COLLATION_NAME AS collation

        FROM information_schema.SCHEMATA

        WHERE SCHEMA_NAME = '${DB_NAME}';

    "


    # -----------------------------------------------------------------
    # TABLES
    # -----------------------------------------------------------------

    echo
    echo "2. TABLES"

    mysql_exec "${DB_NAME}" -e "SHOW TABLES;"


    # -----------------------------------------------------------------
    # TABLE COUNT
    # -----------------------------------------------------------------

    echo
    echo "3. TABLE COUNT"


    TABLE_COUNT=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM information_schema.TABLES

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        AND TABLE_TYPE = 'BASE TABLE';

    ")


    echo "Base tables: ${TABLE_COUNT}"


    if [[ "${TABLE_COUNT}" == "${EXPECTED_TABLE_COUNT}" ]]; then

        success "Expected ${EXPECTED_TABLE_COUNT} base tables found."

    else

        failure "Expected ${EXPECTED_TABLE_COUNT} base tables but found ${TABLE_COUNT}."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    # -----------------------------------------------------------------
    # PRIMARY KEYS
    # -----------------------------------------------------------------

    echo
    echo "4. PRIMARY KEYS"

    mysql_exec "${DB_NAME}" -e "

        SELECT

            TABLE_NAME,

            COLUMN_NAME,

            CONSTRAINT_NAME

        FROM information_schema.KEY_COLUMN_USAGE

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        AND CONSTRAINT_NAME = 'PRIMARY'

        ORDER BY TABLE_NAME;

    "


    # -----------------------------------------------------------------
    # FOREIGN KEYS
    # -----------------------------------------------------------------

    echo
    echo "5. FOREIGN KEYS"

    mysql_exec "${DB_NAME}" -e "

        SELECT

            TABLE_NAME,

            COLUMN_NAME,

            CONSTRAINT_NAME,

            REFERENCED_TABLE_NAME,

            REFERENCED_COLUMN_NAME

        FROM information_schema.KEY_COLUMN_USAGE

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        AND REFERENCED_TABLE_NAME IS NOT NULL

        ORDER BY TABLE_NAME;

    "


    # -----------------------------------------------------------------
    # INDEXES
    # -----------------------------------------------------------------

    echo
    echo "6. INDEXES"

    mysql_exec "${DB_NAME}" -e "

        SELECT

            TABLE_NAME,

            INDEX_NAME,

            COLUMN_NAME,

            NON_UNIQUE

        FROM information_schema.STATISTICS

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        ORDER BY TABLE_NAME, INDEX_NAME;

    "


    # -----------------------------------------------------------------
    # CHECK CONSTRAINTS
    # -----------------------------------------------------------------
    #
    # IMPORTANT:
    #
    # MySQL 8 information_schema.CHECK_CONSTRAINTS does NOT expose
    # TABLE_NAME directly.
    #
    # Therefore we JOIN:
    #
    #   CHECK_CONSTRAINTS
    #
    # with:
    #
    #   TABLE_CONSTRAINTS
    #
    # using:
    #
    #   CONSTRAINT_SCHEMA
    #   CONSTRAINT_NAME
    #
    # -----------------------------------------------------------------

    echo
    echo "7. CHECK CONSTRAINTS"

    mysql_exec "${DB_NAME}" -e "

        SELECT

            tc.TABLE_NAME,

            cc.CONSTRAINT_NAME,

            cc.CHECK_CLAUSE

        FROM information_schema.CHECK_CONSTRAINTS cc

        INNER JOIN information_schema.TABLE_CONSTRAINTS tc

            ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA

            AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME

        WHERE cc.CONSTRAINT_SCHEMA = '${DB_NAME}'

        AND tc.CONSTRAINT_TYPE = 'CHECK'

        ORDER BY

            tc.TABLE_NAME,

            cc.CONSTRAINT_NAME;

    "


    # -----------------------------------------------------------------
    # CHECK CONSTRAINT COUNT
    # -----------------------------------------------------------------

    echo
    echo "7A. CHECK CONSTRAINT COUNT"


    CHECK_COUNT=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM information_schema.CHECK_CONSTRAINTS cc

        INNER JOIN information_schema.TABLE_CONSTRAINTS tc

            ON cc.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA

            AND cc.CONSTRAINT_NAME = tc.CONSTRAINT_NAME

        WHERE cc.CONSTRAINT_SCHEMA = '${DB_NAME}'

        AND tc.CONSTRAINT_TYPE = 'CHECK';

    ")


    echo "CHECK constraints: ${CHECK_COUNT}"


    if [[ "${CHECK_COUNT}" -ge 5 ]]; then

        success "CHECK constraints detected."

    else

        warning "Fewer CHECK constraints than expected."

    fi


    # -----------------------------------------------------------------
    # VIEWS
    # -----------------------------------------------------------------

    echo
    echo "8. VIEWS"

    mysql_exec "${DB_NAME}" -e "

        SELECT

            TABLE_NAME AS view_name

        FROM information_schema.VIEWS

        WHERE TABLE_SCHEMA = '${DB_NAME}';

    "


    VIEW_COUNT=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM information_schema.VIEWS

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        AND TABLE_NAME = 'order_summary';

    ")


    if [[ "${VIEW_COUNT}" == "1" ]]; then

        success "order_summary view exists."

    else

        failure "order_summary view is missing."

        FAILED_RDS=$((FAILED_RDS + 1))

        FAILED_RDS_LIST+=("${RDS_IDENTIFIER}")

        unset DB_PASSWORD

        return 1

    fi


    # -----------------------------------------------------------------
    # ROW COUNTS
    # -----------------------------------------------------------------

    echo
    echo "9. ROW COUNTS"


    for TABLE in \
        customers \
        employees \
        cafe_menu \
        cafe_tables \
        cafe_orders \
        cafe_order_items \
        cafe_payments \
        order_status_history

    do

        COUNT=$(mysql_exec "${DB_NAME}" -N -e "

            SELECT COUNT(*)

            FROM ${TABLE};

        ")


        printf "%-30s %s rows\n" "${TABLE}" "${COUNT}"

    done


    # -----------------------------------------------------------------
    # ORDER SUMMARY
    # -----------------------------------------------------------------

    echo
    echo "10. ORDER SUMMARY VIEW"


    mysql_exec "${DB_NAME}" -e "

        SELECT *

        FROM order_summary

        ORDER BY order_id;

    "


    # -----------------------------------------------------------------
    # RELATIONSHIP TEST
    # -----------------------------------------------------------------

    echo
    echo "11. RELATIONSHIP TEST"


    mysql_exec "${DB_NAME}" -e "

        SELECT

            o.order_number,

            CONCAT(

                c.first_name,

                ' ',

                c.last_name

            ) AS customer,

            ct.table_number,

            e.employee_code,

            o.order_status,

            o.total_amount

        FROM cafe_orders o

        LEFT JOIN customers c

            ON o.customer_id = c.customer_id

        LEFT JOIN cafe_tables ct

            ON o.table_id = ct.table_id

        LEFT JOIN employees e

            ON o.employee_id = e.employee_id

        ORDER BY o.order_id;

    "


    # -----------------------------------------------------------------
    # ORDER TOTAL CHECK
    # -----------------------------------------------------------------

    echo
    echo "12. ORDER TOTAL VERIFICATION"


    mysql_exec "${DB_NAME}" -e "

        SELECT

            o.order_number,

            o.total_amount AS order_total,

            COALESCE(

                SUM(oi.subtotal),

                0

            ) AS calculated_total,

            CASE

                WHEN o.total_amount =

                     COALESCE(SUM(oi.subtotal),0)

                THEN 'PASS'

                ELSE 'CHECK'

            END AS result

        FROM cafe_orders o

        LEFT JOIN cafe_order_items oi

            ON o.order_id = oi.order_id

        GROUP BY

            o.order_id,

            o.order_number,

            o.total_amount;

    "


    # -----------------------------------------------------------------
    # ORPHAN CHECK
    # -----------------------------------------------------------------

    echo
    echo "13. ORPHAN ORDER ITEM CHECK"


    ORPHANS=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM cafe_order_items oi

        LEFT JOIN cafe_orders o

            ON oi.order_id = o.order_id

        WHERE o.order_id IS NULL;

    ")


    echo "Orphan records: ${ORPHANS}"


    if [[ "${ORPHANS}" == "0" ]]; then

        success "No orphan order items."

    else

        warning "Orphan order items detected."

    fi


    # -----------------------------------------------------------------
    # DUPLICATE CUSTOMER EMAIL CHECK
    # -----------------------------------------------------------------

    echo
    echo "14. DUPLICATE CUSTOMER EMAIL CHECK"


    mysql_exec "${DB_NAME}" -e "

        SELECT

            email,

            COUNT(*) AS duplicate_count

        FROM customers

        GROUP BY email

        HAVING COUNT(*) > 1;

    "


    # -----------------------------------------------------------------
    # INVALID MENU PRICES
    # -----------------------------------------------------------------

    echo
    echo "15. INVALID MENU PRICE CHECK"


    INVALID_PRICES=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM cafe_menu

        WHERE price < 0;

    ")


    echo "Invalid menu prices: ${INVALID_PRICES}"


    if [[ "${INVALID_PRICES}" == "0" ]]; then

        success "No invalid menu prices."

    else

        warning "Invalid menu prices detected."

    fi


    # -----------------------------------------------------------------
    # INVALID ORDER TOTALS
    # -----------------------------------------------------------------

    echo
    echo "16. INVALID ORDER TOTAL CHECK"


    INVALID_TOTALS=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM cafe_orders

        WHERE total_amount < 0;

    ")


    echo "Invalid order totals: ${INVALID_TOTALS}"


    if [[ "${INVALID_TOTALS}" == "0" ]]; then

        success "No invalid order totals."

    else

        warning "Invalid order totals detected."

    fi


    # -----------------------------------------------------------------
    # DATABASE SIZE
    # -----------------------------------------------------------------

    echo
    echo "17. DATABASE SIZE"


    mysql_exec "${DB_NAME}" -e "

        SELECT

            ROUND(

                COALESCE(

                    SUM(data_length + index_length),

                    0

                ) / 1024 / 1024,

                2

            ) AS database_size_mb

        FROM information_schema.TABLES

        WHERE table_schema = '${DB_NAME}';

    "


    # -----------------------------------------------------------------
    # TABLE SIZES
    # -----------------------------------------------------------------

    echo
    echo "18. TABLE SIZES"


    mysql_exec "${DB_NAME}" -e "

        SELECT

            table_name,

            table_rows,

            ROUND(

                (

                    COALESCE(data_length,0)

                    +

                    COALESCE(index_length,0)

                ) / 1024 / 1024,

                2

            ) AS size_mb

        FROM information_schema.TABLES

        WHERE table_schema = '${DB_NAME}'

        ORDER BY size_mb DESC;

    "


    # -----------------------------------------------------------------
    # MYSQL VERSION
    # -----------------------------------------------------------------

    echo
    echo "19. MYSQL VERSION"


    mysql_exec "${DB_NAME}" -e "

        SELECT VERSION() AS mysql_version;

    "


    # -----------------------------------------------------------------
    # CURRENT DATABASE
    # -----------------------------------------------------------------

    echo
    echo "20. CURRENT DATABASE"


    mysql_exec "${DB_NAME}" -e "

        SELECT DATABASE();

    "


    # -----------------------------------------------------------------
    # FINAL DATABASE HEALTH
    # -----------------------------------------------------------------

    echo
    echo "21. FINAL DATABASE HEALTH"


    FINAL_TABLE_COUNT=$(mysql_exec "${DB_NAME}" -N -e "

        SELECT COUNT(*)

        FROM information_schema.TABLES

        WHERE TABLE_SCHEMA = '${DB_NAME}'

        AND TABLE_TYPE = 'BASE TABLE';

    ")


    mysql_exec "${DB_NAME}" -e "

        SELECT

            '${RDS_IDENTIFIER}' AS rds_instance,

            '${DB_NAME}' AS database_name,

            ${FINAL_TABLE_COUNT} AS total_tables,

            'PASS' AS result;

    "


    # -----------------------------------------------------------------
    # FINAL RDS SUCCESS
    # -----------------------------------------------------------------

    SUCCESSFUL_RDS=$((SUCCESSFUL_RDS + 1))

    SUCCESS_RDS_LIST+=("${RDS_IDENTIFIER}")


    echo

    success "RDS ${RDS_IDENTIFIER} completed successfully."

    echo
    echo "RDS:"
    echo "  ${RDS_IDENTIFIER}"

    echo
    echo "Endpoint:"
    echo "  ${RDS_HOST}"

    echo
    echo "Database:"
    echo "  ${DB_NAME}"

    echo
    echo "Secret:"
    echo "  ${SECRET_ARN}"

    echo
    echo "Connectivity:"
    echo "  DNS       : PASS"
    echo "  TCP       : PASS"
    echo "  MySQL     : PASS"
    echo "  Secrets   : PASS"

    echo


    # -----------------------------------------------------------------
    # SECURITY CLEANUP
    # -----------------------------------------------------------------

    unset DB_PASSWORD

    return 0

}


# =====================================================================
# SECTION 17 — PROCESS ALL RDS INSTANCES
# =====================================================================

section "7. PROCESSING ALL DISCOVERED RDS INSTANCES"


while IFS= read -r RDS_ROW
do

    [[ -z "${RDS_ROW}" ]] && continue


    process_rds "${RDS_ROW}"

    PROCESS_RESULT=$?


    if [[ ${PROCESS_RESULT} -eq 0 ]]; then

        log "Moving to next RDS instance."

    elif [[ ${PROCESS_RESULT} -eq 2 ]]; then

        warning "RDS instance skipped."

    else

        warning "RDS instance failed."

        warning "Continuing with the next RDS instance."

    fi


done < <(

    echo "${RDS_JSON}" |

    python3 -c '

import sys
import json

data = json.load(sys.stdin)

for row in data:

    print(json.dumps(row))

'
)


# =====================================================================
# SECTION 18 — CLEANUP
# =====================================================================

unset DB_PASSWORD 2>/dev/null || true

rm -f "${MYSQL_ERROR_FILE}" 2>/dev/null || true

rm -f /tmp/charlie_cafe_sts_error.txt 2>/dev/null || true

rm -f /tmp/charlie_cafe_rds_error.txt 2>/dev/null || true


# =====================================================================
# SECTION 19 — FINAL SUMMARY
# =====================================================================

section "☕ CHARLIE CAFE — FINAL RDS LAB SUMMARY"


echo "AWS Region       : ${AWS_REGION}"
echo "Database         : ${DB_NAME}"
echo
echo "Total RDS        : ${TOTAL_RDS}"
echo "Successful RDS   : ${SUCCESSFUL_RDS}"
echo "Failed RDS       : ${FAILED_RDS}"
echo "Skipped RDS      : ${SKIPPED_RDS}"
echo


# =====================================================================
# SUCCESSFUL RDS LIST
# =====================================================================

if [[ ${#SUCCESS_RDS_LIST[@]} -gt 0 ]]; then

    echo "Successful RDS instances:"
    echo

    for RDS in "${SUCCESS_RDS_LIST[@]}"
    do

        echo "  ✓ ${RDS}"

    done

    echo

fi


# =====================================================================
# FAILED RDS LIST
# =====================================================================

if [[ ${#FAILED_RDS_LIST[@]} -gt 0 ]]; then

    echo "Failed RDS instances:"
    echo

    for RDS in "${FAILED_RDS_LIST[@]}"
    do

        echo "  ✗ ${RDS}"

    done

    echo

fi


# =====================================================================
# SKIPPED RDS LIST
# =====================================================================

if [[ ${#SKIPPED_RDS_LIST[@]} -gt 0 ]]; then

    echo "Skipped RDS instances:"
    echo

    for RDS in "${SKIPPED_RDS_LIST[@]}"
    do

        echo "  ! ${RDS}"

    done

    echo

fi


# =====================================================================
# FINAL SECURITY MESSAGE
# =====================================================================

echo
echo "====================================================================="
echo "IMPORTANT SECURITY NOTE"
echo "====================================================================="
echo

echo "Passwords were never printed."

echo

echo "Credentials were retrieved dynamically from the"
echo "RDS-managed Secrets Manager secret associated with"
echo "each RDS instance."

echo

echo "No database password was required from the user."

echo

echo "====================================================================="


# =====================================================================
# FINAL RESULT
# =====================================================================

if [[ ${FAILED_RDS} -eq 0 && ${SKIPPED_RDS} -eq 0 ]]; then

    echo
    success "ALL DISCOVERED MYSQL RDS INSTANCES PASSED."
    success "Secrets Manager integration PASSED."
    success "RDS connectivity PASSED."
    success "MySQL authentication PASSED."
    success "Charlie Cafe database deployment PASSED."
    success "Database verification PASSED."
    echo

    echo "====================================================================="
    echo "☕ CHARLIE CAFE RDS LAB — COMPLETE"
    echo "====================================================================="

    exit 0

else

    echo
    warning "The lab completed with one or more RDS warnings/failures."
    echo
    echo "Successful : ${SUCCESSFUL_RDS}"
    echo "Failed     : ${FAILED_RDS}"
    echo "Skipped    : ${SKIPPED_RDS}"
    echo

    echo "The script intentionally continued processing other RDS"
    echo "instances even when one instance encountered a problem."

    echo

    echo "====================================================================="
    echo "☕ CHARLIE CAFE RDS LAB — COMPLETED WITH WARNINGS"
    echo "====================================================================="

    exit 1

fi