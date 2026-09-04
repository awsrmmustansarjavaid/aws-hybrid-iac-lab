#!/bin/bash

# ==============================================================================
# ☕ Charlie Cafe — Professional GitHub ↔ EC2 Automation Script v2
# ==============================================================================
#
# PURPOSE
# -------
# This script prepares an Amazon Linux EC2 instance to securely communicate
# with GitHub using SSH and automatically clone/update a GitHub repository.
#
# MAIN FEATURES
# -------------
# 1. Detect current Linux user
# 2. Verify the script is not accidentally running as root
# 3. Install Git if required
# 4. Configure Git username/email
# 5. Create ~/.ssh with secure permissions
# 6. Create a dedicated GitHub SSH key:
#
#       ~/.ssh/github_ec2
#       ~/.ssh/github_ec2.pub
#
# 7. Configure ~/.ssh/config
# 8. Configure GitHub known_hosts
# 9. Test GitHub SSH authentication
# 10. If authentication fails:
#       - Display GitHub key title
#       - Display public SSH key
#       - Ask user to register it in GitHub
#       - Require explicit YES confirmation
# 11. Verify repository access using git ls-remote
# 12. Clone repository if it does not exist
# 13. Pull repository if it already exists
# 14. Verify Git remote, branch and working tree
# 15. Check AWS CLI
# 16. Check AWS identity
# 17. Collect EC2 information
# 18. Generate log and reports
# 19. Provide a professional PASS/FAIL summary
#
# IMPORTANT SECURITY NOTE
# -----------------------
# The GitHub SSH private key is intentionally created WITHOUT a passphrase
# because this script is designed for EC2 automation.
#
# This means:
#
#     ssh-keygen ... -N ""
#
# No password/passphrase will be requested during automated Git operations.
#
# Protect the EC2 instance and ~/.ssh/github_ec2 carefully.
#
# ==============================================================================


# ==============================================================================
# SECTION 01 — SAFETY SETTINGS
# ==============================================================================

# -E
#   Preserve ERR traps inside functions/subshells.
#
# -e
#   Stop when an unexpected command fails.
#
# -u
#   Treat undefined variables as errors.
#
# pipefail
#   Make a pipeline fail if any command inside the pipeline fails.
#
set -Eeuo pipefail


# ==============================================================================
# SECTION 02 — SCRIPT VERSION
# ==============================================================================

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="2.0.0"


# ==============================================================================
# SECTION 03 — DEFAULT CONFIGURATION
# ==============================================================================
#
# You can override these values through environment variables or command-line
# arguments.
#
# Example:
#
#   ./github-ec2-setup.sh --repo charlie-cafe --branch main
#
# ==============================================================================

GITHUB_HOST="${GITHUB_HOST:-github.com}"

# GitHub repository settings.
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# Git identity.
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"

# Dedicated SSH key for this EC2 machine.
#
# IMPORTANT:
# Do NOT change this to id_ed25519 unless you intentionally want to use
# your general-purpose SSH key.
#
SSH_KEY_NAME="${SSH_KEY_NAME:-github_ec2}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/$SSH_KEY_NAME}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-${SSH_KEY_PATH}.pub}"

# Human-readable GitHub SSH key title.
#
# This is NOT stored inside the SSH key itself.
# It is simply the title you enter in:
#
# GitHub → Settings → SSH and GPG keys → New SSH key
#
GITHUB_SSH_KEY_TITLE="${GITHUB_SSH_KEY_TITLE:-Charlie Cafe EC2}"

# Comment stored inside the SSH public key.
GITHUB_SSH_KEY_COMMENT="${GITHUB_SSH_KEY_COMMENT:-github-ec2}"

# SSH configuration files.
SSH_CONFIG_FILE="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"
SSH_KNOWN_HOSTS_FILE="${SSH_KNOWN_HOSTS_FILE:-$HOME/.ssh/known_hosts}"

# Repository location.
#
# By default:
#
#   /home/ec2-user/<repository>
#
# when the script is run by ec2-user.
#
REPOSITORY_PARENT_DIR="${REPOSITORY_PARENT_DIR:-$HOME}"

# Report/log files.
LOG_FILE="${LOG_FILE:-$HOME/github-ec2-setup.log}"
REPORT_FILE="${REPORT_FILE:-$HOME/github-ec2-setup-report.txt}"
JSON_REPORT_FILE="${JSON_REPORT_FILE:-$HOME/github-ec2-setup-report.json}"

# Behavior flags.
DRY_RUN=false
FORCE_KEY=false
SKIP_AWS=false


# ==============================================================================
# SECTION 04 — RUNTIME VARIABLES
# ==============================================================================

CURRENT_USER="$(id -un)"
CURRENT_UID="$(id -u)"
CURRENT_HOME="$HOME"

REPOSITORY_DIR=""

START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"

# Counters used by the final report.
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0


# ==============================================================================
# SECTION 05 — COLORS
# ==============================================================================
#
# Colors make terminal output easier to read.
#
# They automatically become disabled when the terminal does not support them.
#
# ==============================================================================

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi


# ==============================================================================
# SECTION 06 — LOGGING FUNCTIONS
# ==============================================================================

# Create the log directory/file before writing.
initialize_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    chmod 600 "$LOG_FILE" 2>/dev/null || true
}


# Write a message to both terminal and log file.
log() {
    local level="$1"
    shift

    local message="$*"
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        PASS)
            echo -e "${GREEN}[PASS]${NC} $message"
            PASS_COUNT=$((PASS_COUNT + 1))
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} $message"
            WARN_COUNT=$((WARN_COUNT + 1))
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            ;;
        *)
            echo "$message"
            ;;
    esac
}


# Print a large section heading.
section() {
    local number="$1"
    local title="$2"

    echo
    echo "======================================================================"
    echo "[$number] $title"
    echo "======================================================================"

    echo
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SECTION] [$number] $title" >> "$LOG_FILE"
}


# ==============================================================================
# SECTION 07 — ERROR HANDLING
# ==============================================================================

on_error() {
    local exit_code="$?"
    local line_number="$1"
    local command="${2:-unknown}"

    echo
    echo "======================================================================"
    echo -e "${RED}SCRIPT FAILED${NC}"
    echo "======================================================================"
    echo
    echo "Line       : $line_number"
    echo "Exit Code  : $exit_code"
    echo "Command    : $command"
    echo "Log File   : $LOG_FILE"
    echo
    echo "Please review the log file for detailed diagnostics."
    echo

    exit "$exit_code"
}

trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR


# ==============================================================================
# SECTION 08 — HELP
# ==============================================================================

show_help() {

    cat <<EOF

======================================================================
$SCRIPT_NAME v$SCRIPT_VERSION
Professional GitHub ↔ EC2 Automation
======================================================================

USAGE

    $SCRIPT_NAME [OPTIONS]

OPTIONS

    --repo NAME
        GitHub repository name.

        Example:
            --repo charlie-cafe

    --branch NAME
        Git branch.

        Default:
            main

    --username NAME
        GitHub username.

    --git-name NAME
        Git commit author name.

    --git-email EMAIL
        Git commit author email.

    --dry-run
        Show what the script would do without making changes.

    --force-key
        Regenerate github_ec2 SSH key.

        WARNING:
        The old public key may still exist in GitHub.

    --skip-aws
        Skip AWS CLI and EC2 verification.

    --help
        Display this help message.

EXAMPLES

    Basic:

        ./$SCRIPT_NAME

    Specify repository:

        ./$SCRIPT_NAME --repo charlie-cafe

    Specify repository and branch:

        ./$SCRIPT_NAME --repo charlie-cafe --branch main

    Dry run:

        ./$SCRIPT_NAME --repo charlie-cafe --dry-run

    Force SSH key regeneration:

        ./$SCRIPT_NAME --force-key

    Skip AWS checks:

        ./$SCRIPT_NAME --skip-aws

ENVIRONMENT VARIABLES

    GITHUB_USERNAME
    GITHUB_REPOSITORY
    GITHUB_BRANCH
    GIT_USER_NAME
    GIT_USER_EMAIL

EXAMPLES

    GITHUB_USERNAME=myuser \\
    GITHUB_REPOSITORY=charlie-cafe \\
    ./$SCRIPT_NAME

FILES CREATED

    ~/.ssh/github_ec2
    ~/.ssh/github_ec2.pub
    ~/.ssh/config
    ~/.ssh/known_hosts

    ~/github-ec2-setup.log
    ~/github-ec2-setup-report.txt
    ~/github-ec2-setup-report.json

======================================================================

EOF
}


# ==============================================================================
# SECTION 09 — COMMAND-LINE ARGUMENT PARSER
# ==============================================================================

parse_arguments() {

    while [[ $# -gt 0 ]]; do

        case "$1" in

            --repo)
                if [[ $# -lt 2 ]]; then
                    echo "[ERROR] --repo requires a value."
                    exit 1
                fi

                GITHUB_REPOSITORY="$2"
                shift 2
                ;;

            --branch)
                if [[ $# -lt 2 ]]; then
                    echo "[ERROR] --branch requires a value."
                    exit 1
                fi

                GITHUB_BRANCH="$2"
                shift 2
                ;;

            --username)
                if [[ $# -lt 2 ]]; then
                    echo "[ERROR] --username requires a value."
                    exit 1
                fi

                GITHUB_USERNAME="$2"
                shift 2
                ;;

            --git-name)
                if [[ $# -lt 2 ]]; then
                    echo "[ERROR] --git-name requires a value."
                    exit 1
                fi

                GIT_USER_NAME="$2"
                shift 2
                ;;

            --git-email)
                if [[ $# -lt 2 ]]; then
                    echo "[ERROR] --git-email requires a value."
                    exit 1
                fi

                GIT_USER_EMAIL="$2"
                shift 2
                ;;

            --dry-run)
                DRY_RUN=true
                shift
                ;;

            --force-key)
                FORCE_KEY=true
                shift
                ;;

            --skip-aws)
                SKIP_AWS=true
                shift
                ;;

            --help|-h)
                show_help
                exit 0
                ;;

            *)
                echo
                echo "[ERROR] Unknown option: $1"
                echo
                show_help
                exit 1
                ;;

        esac

    done
}


# ==============================================================================
# SECTION 10 — UTILITY FUNCTIONS
# ==============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}


run_command() {

    if [[ "$DRY_RUN" == true ]]; then
        log INFO "[DRY-RUN] $*"
        return 0
    fi

    "$@"
}


# ==============================================================================
# SECTION 11 — ENVIRONMENT VALIDATION
# ==============================================================================

check_current_user() {

    section "01" "CURRENT USER VALIDATION"

    log INFO "Current user : $CURRENT_USER"
    log INFO "UID          : $CURRENT_UID"
    log INFO "Home         : $CURRENT_HOME"

    # This script is designed to configure the current user's SSH key.
    #
    # Running it as root can accidentally create:
    #
    #     /root/.ssh/github_ec2
    #
    # instead of:
    #
    #     /home/ec2-user/.ssh/github_ec2
    #
    # Therefore we intentionally stop when executed as root.

    if [[ "$CURRENT_UID" -eq 0 ]]; then

        log ERROR "Do not run this script as root."

        echo
        echo "Run it as your normal EC2 user, for example:"
        echo
        echo "    sudo -iu ec2-user"
        echo "    ./github-ec2-setup.sh"
        echo

        exit 1
    fi

    log PASS "Running as non-root user: $CURRENT_USER"
}


# ==============================================================================
# SECTION 12 — OPERATING SYSTEM DETECTION
# ==============================================================================

detect_operating_system() {

    section "02" "OPERATING SYSTEM DETECTION"

    if [[ -f /etc/os-release ]]; then

        # shellcheck disable=SC1091
        source /etc/os-release

        log INFO "Operating system : ${PRETTY_NAME:-Unknown}"
        log INFO "OS ID            : ${ID:-Unknown}"
        log INFO "OS version       : ${VERSION_ID:-Unknown}"

    else

        log WARN "/etc/os-release was not found."

    fi
}


# ==============================================================================
# SECTION 13 — PACKAGE MANAGER DETECTION
# ==============================================================================

detect_package_manager() {

    section "03" "PACKAGE MANAGER DETECTION"

    if command_exists dnf; then

        PACKAGE_MANAGER="dnf"

    elif command_exists yum; then

        PACKAGE_MANAGER="yum"

    elif command_exists apt-get; then

        PACKAGE_MANAGER="apt-get"

    else

        log ERROR "No supported package manager was found."
        exit 1

    fi

    log PASS "Package manager detected: $PACKAGE_MANAGER"
}


# ==============================================================================
# SECTION 14 — INSTALL GIT
# ==============================================================================

install_git_if_required() {

    section "04" "GIT INSTALLATION"

    if command_exists git; then

        log PASS "Git is already installed."

        git --version

        return 0
    fi

    log INFO "Git is not installed."

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Git would be installed using $PACKAGE_MANAGER."
        return 0

    fi

    log INFO "Installing Git..."

    case "$PACKAGE_MANAGER" in

        dnf)
            sudo dnf install -y git
            ;;

        yum)
            sudo yum install -y git
            ;;

        apt-get)
            sudo apt-get update
            sudo apt-get install -y git
            ;;

    esac

    if command_exists git; then
        log PASS "Git installation completed."
    else
        log ERROR "Git installation failed."
        exit 1
    fi
}


# ==============================================================================
# SECTION 15 — COLLECT CONFIGURATION
# ==============================================================================

collect_configuration() {

    section "05" "CONFIGURATION"

    # If repository was not supplied as an argument or environment variable,
    # ask the user.
    if [[ -z "$GITHUB_REPOSITORY" && "$DRY_RUN" == false ]]; then

        read -r -p "Enter GitHub repository name: " GITHUB_REPOSITORY

    fi

    # If GitHub username is not known, ask for it.
    if [[ -z "$GITHUB_USERNAME" && "$DRY_RUN" == false ]]; then

        read -r -p "Enter GitHub username: " GITHUB_USERNAME

    fi

    # Git name.
    if [[ -z "$GIT_USER_NAME" && "$DRY_RUN" == false ]]; then

        read -r -p "Enter Git user name: " GIT_USER_NAME

    fi

    # Git email.
    if [[ -z "$GIT_USER_EMAIL" && "$DRY_RUN" == false ]]; then

        read -r -p "Enter Git user email: " GIT_USER_EMAIL

    fi

    # Dry-run may not have interactive values.
    if [[ -z "$GITHUB_REPOSITORY" ]]; then
        GITHUB_REPOSITORY="example-repository"
    fi

    if [[ -z "$GITHUB_USERNAME" ]]; then
        GITHUB_USERNAME="example-user"
    fi

    if [[ -z "$GIT_USER_NAME" ]]; then
        GIT_USER_NAME="$CURRENT_USER"
    fi

    if [[ -z "$GIT_USER_EMAIL" ]]; then
        GIT_USER_EMAIL="${CURRENT_USER}@localhost"
    fi

    REPOSITORY_DIR="$REPOSITORY_PARENT_DIR/$GITHUB_REPOSITORY"

    log INFO "GitHub username : $GITHUB_USERNAME"
    log INFO "GitHub repository: $GITHUB_REPOSITORY"
    log INFO "GitHub branch    : $GITHUB_BRANCH"
    log INFO "Git SSH title    : $GITHUB_SSH_KEY_TITLE"
    log INFO "SSH key          : $SSH_KEY_PATH"
    log INFO "Repository path  : $REPOSITORY_DIR"
}


# ==============================================================================
# SECTION 16 — CONFIGURATION VALIDATION
# ==============================================================================

validate_configuration() {

    section "06" "CONFIGURATION VALIDATION"

    if [[ "$GITHUB_REPOSITORY" =~ [[:space:]] ]]; then

        log ERROR "Repository name must not contain spaces."
        exit 1

    fi

    if [[ "$GITHUB_BRANCH" =~ [[:space:]] ]]; then

        log ERROR "Branch name must not contain spaces."
        exit 1

    fi

    if [[ "$GITHUB_REPOSITORY" == "" ]]; then

        log ERROR "GitHub repository is required."
        exit 1

    fi

    log PASS "Configuration validation successful."
}


# ==============================================================================
# SECTION 17 — GIT IDENTITY
# ==============================================================================

configure_git_identity() {

    section "07" "GIT IDENTITY"

    log INFO "Configuring Git identity for current user."

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] git config --global user.name \"$GIT_USER_NAME\""
        log INFO "[DRY-RUN] git config --global user.email \"$GIT_USER_EMAIL\""

        return 0
    fi

    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"

    log PASS "Git user.name configured."
    log PASS "Git user.email configured."

    echo
    git config --global --get user.name
    git config --global --get user.email
}


# ==============================================================================
# SECTION 18 — SSH DIRECTORY
# ==============================================================================

prepare_ssh_directory() {

    section "08" "SSH DIRECTORY"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] mkdir -p $HOME/.ssh"
        log INFO "[DRY-RUN] chmod 700 $HOME/.ssh"

        return 0
    fi

    mkdir -p "$HOME/.ssh"

    chmod 700 "$HOME/.ssh"

    log PASS "SSH directory exists with permission 700."
}


# ==============================================================================
# SECTION 19 — SSH KEY GENERATION
# ==============================================================================

generate_ssh_key() {

    section "09" "GITHUB SSH KEY"

    # --------------------------------------------------------------------------
    # IMPORTANT:
    #
    # We intentionally reuse an existing github_ec2 key.
    #
    # Generating a new key every time would require the user to register every
    # new public key in GitHub.
    # --------------------------------------------------------------------------

    if [[ -f "$SSH_KEY_PATH" && -f "$SSH_PUBLIC_KEY_PATH" && "$FORCE_KEY" == false ]]; then

        log PASS "Existing GitHub EC2 SSH key found."
        log INFO "Reusing: $SSH_KEY_PATH"

        return 0
    fi


    # --------------------------------------------------------------------------
    # If --force-key was supplied, require an explicit confirmation.
    # --------------------------------------------------------------------------

    if [[ "$FORCE_KEY" == true ]]; then

        if [[ -f "$SSH_KEY_PATH" || -f "$SSH_PUBLIC_KEY_PATH" ]]; then

            echo
            echo -e "${YELLOW}WARNING${NC}"
            echo "The existing GitHub EC2 SSH key will be replaced."
            echo
            echo "Current key:"
            echo "    $SSH_KEY_PATH"
            echo
            echo "The old public key may still be registered in GitHub."
            echo

            if [[ "$DRY_RUN" == false ]]; then

                read -r -p "Type REGENERATE to continue: " confirmation

                if [[ "$confirmation" != "REGENERATE" ]]; then

                    log INFO "Key regeneration cancelled."
                    exit 0

                fi

            fi

            if [[ "$DRY_RUN" == false ]]; then

                rm -f "$SSH_KEY_PATH" "$SSH_PUBLIC_KEY_PATH"

            fi

        fi

    fi


    # --------------------------------------------------------------------------
    # If private key exists but public key is missing, reconstruct the public
    # key instead of generating a completely new key.
    # --------------------------------------------------------------------------

    if [[ -f "$SSH_KEY_PATH" && ! -f "$SSH_PUBLIC_KEY_PATH" ]]; then

        log WARN "Private key exists but public key is missing."
        log INFO "Rebuilding public key from private key."

        if [[ "$DRY_RUN" == false ]]; then

            ssh-keygen -y \
                -f "$SSH_KEY_PATH" \
                > "$SSH_PUBLIC_KEY_PATH"

        fi

        log PASS "Public key rebuilt."
        return 0
    fi


    # --------------------------------------------------------------------------
    # Generate dedicated Ed25519 key.
    #
    # -t ed25519
    #     Modern, compact SSH key type.
    #
    # -C
    #     Adds a comment to identify the key.
    #
    # -f
    #     Stores the key at the dedicated path.
    #
    # -N ""
    #     Empty passphrase.
    #
    # --------------------------------------------------------------------------

    log INFO "Generating dedicated GitHub SSH key."
    log INFO "Key file: $SSH_KEY_PATH"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] ssh-keygen -t ed25519 -C \"$GITHUB_SSH_KEY_COMMENT\" -f \"$SSH_KEY_PATH\" -N \"\""

        return 0
    fi

    ssh-keygen \
        -t ed25519 \
        -C "$GITHUB_SSH_KEY_COMMENT" \
        -f "$SSH_KEY_PATH" \
        -N ""

    log PASS "GitHub EC2 SSH key generated."
}


# ==============================================================================
# SECTION 20 — SSH PERMISSIONS
# ==============================================================================

fix_ssh_permissions() {

    section "10" "SSH PERMISSIONS"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] chmod 700 ~/.ssh"
        log INFO "[DRY-RUN] chmod 600 private key"
        log INFO "[DRY-RUN] chmod 644 public key"

        return 0
    fi

    chmod 700 "$HOME/.ssh"

    if [[ -f "$SSH_KEY_PATH" ]]; then
        chmod 600 "$SSH_KEY_PATH"
    fi

    if [[ -f "$SSH_PUBLIC_KEY_PATH" ]]; then
        chmod 644 "$SSH_PUBLIC_KEY_PATH"
    fi

    log PASS "SSH permissions configured."

    echo
    echo "Private key:"
    ls -l "$SSH_KEY_PATH" 2>/dev/null || true

    echo
    echo "Public key:"
    ls -l "$SSH_PUBLIC_KEY_PATH" 2>/dev/null || true
}


# ==============================================================================
# SECTION 21 — SSH CONFIGURATION
# ==============================================================================

configure_ssh_config() {

    section "11" "SSH CONFIGURATION"

    local begin_marker="# BEGIN CHARLIE CAFE GITHUB CONFIG"
    local end_marker="# END CHARLIE CAFE GITHUB CONFIG"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Configure $SSH_CONFIG_FILE"
        return 0
    fi

    touch "$SSH_CONFIG_FILE"

    chmod 600 "$SSH_CONFIG_FILE"

    # Remove our previously managed configuration block.
    #
    # This makes the operation idempotent.
    #
    # Running the script multiple times will not create duplicate blocks.

    if grep -qF "$begin_marker" "$SSH_CONFIG_FILE"; then

        sed -i "/$begin_marker/,/$end_marker/d" "$SSH_CONFIG_FILE"

    fi


    cat >> "$SSH_CONFIG_FILE" <<EOF

$begin_marker
Host $GITHUB_HOST
    HostName $GITHUB_HOST
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
    AddKeysToAgent yes
    StrictHostKeyChecking accept-new
$end_marker

EOF

    chmod 600 "$SSH_CONFIG_FILE"

    log PASS "SSH configuration updated."
}


# ==============================================================================
# SECTION 22 — GITHUB KNOWN HOSTS
# ==============================================================================

configure_known_hosts() {

    section "12" "GITHUB KNOWN HOSTS"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Verify GitHub host key."
        return 0
    fi

    touch "$SSH_KNOWN_HOSTS_FILE"

    chmod 600 "$SSH_KNOWN_HOSTS_FILE"

    # ssh-keygen -F works correctly with hashed known_hosts entries.
    #
    # This is better than using:
    #
    #   grep "^github.com"
    #
    # because ssh-keyscan -H creates hashed hostnames.

    if ssh-keygen -F "$GITHUB_HOST" -f "$SSH_KNOWN_HOSTS_FILE" >/dev/null 2>&1; then

        log PASS "GitHub host key already exists."

    else

        log INFO "Adding GitHub host key."

        ssh-keyscan -H "$GITHUB_HOST" >> "$SSH_KNOWN_HOSTS_FILE" 2>/dev/null

        log PASS "GitHub host key added."
    fi
}


# ==============================================================================
# SECTION 23 — DISPLAY SSH KEY
# ==============================================================================

display_github_key() {

    section "13" "GITHUB SSH KEY REGISTRATION"

    echo
    echo "======================================================================"
    echo "GitHub SSH Key Registration"
    echo "======================================================================"
    echo
    echo "GitHub SSH Key Title:"
    echo
    echo "    $GITHUB_SSH_KEY_TITLE"
    echo
    echo "Key Type:"
    echo
    echo "    Authentication Key"
    echo
    echo "Public SSH Key:"
    echo
    echo "------------------------------------------------------------------"

    if [[ "$DRY_RUN" == false ]]; then

        cat "$SSH_PUBLIC_KEY_PATH"

    else

        echo "[DRY-RUN] Public key would be displayed here."

    fi

    echo "------------------------------------------------------------------"
    echo
    echo "GitHub:"
    echo
    echo "    Settings"
    echo "       → SSH and GPG keys"
    echo "          → New SSH key"
    echo
    echo "Enter:"
    echo
    echo "    Title:"
    echo "        $GITHUB_SSH_KEY_TITLE"
    echo
    echo "    Key type:"
    echo "        Authentication Key"
    echo
    echo "    Key:"
    echo "        Copy the COMPLETE public key shown above."
    echo
    echo "IMPORTANT:"
    echo
    echo "    NEVER copy or upload:"
    echo "        $SSH_KEY_PATH"
    echo
    echo "    Only copy:"
    echo "        $SSH_PUBLIC_KEY_PATH"
    echo
    echo "======================================================================"
    echo
}


# ==============================================================================
# SECTION 24 — TEST GITHUB NETWORK
# ==============================================================================

test_github_network() {

    section "14" "GITHUB NETWORK TEST"

    if command_exists curl; then

        if curl -Is --connect-timeout 10 "https://$GITHUB_HOST" >/dev/null 2>&1; then

            log PASS "GitHub HTTPS connectivity is working."

        else

            log WARN "GitHub HTTPS connectivity test failed."

        fi

    else

        log WARN "curl is not installed; skipping HTTPS connectivity test."

    fi
}


# ==============================================================================
# SECTION 25 — TEST GITHUB SSH
# ==============================================================================

test_github_ssh() {

    section "15" "GITHUB SSH AUTHENTICATION"

    local ssh_output
    local ssh_status

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] ssh -T git@$GITHUB_HOST"
        return 0
    fi

    # GitHub normally returns exit code 1 after successful authentication
    # because GitHub does not provide shell access.
    #
    # Therefore we inspect the output instead of relying only on exit code.

    set +e

    ssh_output="$(
        ssh \
            -T \
            -i "$SSH_KEY_PATH" \
            -o IdentitiesOnly=yes \
            -o StrictHostKeyChecking=accept-new \
            "git@$GITHUB_HOST" \
            2>&1
    )"

    ssh_status=$?

    set -e

    echo "$ssh_output" >> "$LOG_FILE"

    echo
    echo "$ssh_output"
    echo

    if echo "$ssh_output" | grep -Eqi \
        "successfully authenticated|Hi .*!"; then

        log PASS "GitHub SSH authentication successful."

        return 0
    fi

    log WARN "GitHub SSH authentication failed."

    return 1
}


# ==============================================================================
# SECTION 26 — INTERACTIVE GITHUB REGISTRATION
# ==============================================================================

register_github_key_interactively() {

    # First try authentication.
    #
    # If the key was already registered in GitHub, we do not bother the user.
    #
    if test_github_ssh; then

        return 0

    fi


    # --------------------------------------------------------------------------
    # Authentication failed.
    #
    # This usually means the public key has not yet been registered in GitHub.
    # --------------------------------------------------------------------------

    display_github_key


    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Would wait for GitHub key registration."
        return 0

    fi


    # --------------------------------------------------------------------------
    # Require explicit confirmation.
    #
    # We intentionally do NOT use:
    #
    #     Press ENTER
    #
    # because it is too easy to continue accidentally.
    #
    # The user must type YES.
    # --------------------------------------------------------------------------

    while true; do

        echo
        read -r -p \
            "Type YES after adding BOTH the title and public key to GitHub: " \
            confirmation

        if [[ "$confirmation" == "YES" ]]; then

            break

        fi

        echo
        echo "[INFO] Please type exactly: YES"
        echo

    done


    # --------------------------------------------------------------------------
    # Give GitHub a moment and test authentication again.
    # --------------------------------------------------------------------------

    echo
    log INFO "Testing GitHub SSH authentication again..."

    if test_github_ssh; then

        log PASS "GitHub key registration confirmed by successful SSH authentication."

        return 0

    fi


    # --------------------------------------------------------------------------
    # Registration was confirmed by the user, but authentication still failed.
    # Show useful diagnostics.
    # --------------------------------------------------------------------------

    echo
    echo "======================================================================"
    echo "GitHub SSH Diagnostic Information"
    echo "======================================================================"
    echo

    log ERROR "GitHub SSH authentication is still failing."

    echo
    echo "Possible causes:"
    echo
    echo "1. Wrong public key was pasted into GitHub."
    echo "2. Private/public key files do not match."
    echo "3. Wrong GitHub account was used."
    echo "4. SSH configuration is incorrect."
    echo "5. Network/firewall restrictions."
    echo "6. GitHub organization SSO authorization may be required."
    echo

    echo "SSH public key fingerprint:"
    ssh-keygen -lf "$SSH_PUBLIC_KEY_PATH" 2>/dev/null || true

    echo
    echo "SSH configuration:"
    grep -A10 -B2 \
        "# BEGIN CHARLIE CAFE GITHUB CONFIG" \
        "$SSH_CONFIG_FILE" 2>/dev/null || true

    echo

    return 1
}


# ==============================================================================
# SECTION 27 — VERIFY REPOSITORY ACCESS
# ==============================================================================

verify_repository_access() {

    section "16" "GITHUB REPOSITORY ACCESS"

    local repository_url

    repository_url="git@$GITHUB_HOST:$GITHUB_USERNAME/$GITHUB_REPOSITORY.git"

    log INFO "Repository:"
    log INFO "$repository_url"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] git ls-remote $repository_url"
        return 0
    fi


    # --------------------------------------------------------------------------
    # git ls-remote verifies:
    #
    # 1. DNS/network works
    # 2. SSH authentication works
    # 3. GitHub account has repository access
    # 4. Repository exists
    #
    # This is better than waiting for git clone to discover a problem.
    # --------------------------------------------------------------------------

    if git ls-remote "$repository_url" HEAD >/dev/null 2>&1; then

        log PASS "GitHub repository access confirmed."

    else

        log ERROR "Unable to access GitHub repository."
        echo
        echo "Repository URL:"
        echo "    $repository_url"
        echo

        return 1
    fi
}


# ==============================================================================
# SECTION 28 — CLONE OR UPDATE REPOSITORY
# ==============================================================================

clone_or_update_repository() {

    section "17" "CLONE / UPDATE REPOSITORY"

    local repository_url

    repository_url="git@$GITHUB_HOST:$GITHUB_USERNAME/$GITHUB_REPOSITORY.git"


    # --------------------------------------------------------------------------
    # CASE 1:
    #
    # Repository directory does not exist.
    #
    # Action:
    #
    #     git clone
    # --------------------------------------------------------------------------

    if [[ ! -e "$REPOSITORY_DIR" ]]; then

        log INFO "Repository directory does not exist."
        log INFO "Cloning repository..."

        if [[ "$DRY_RUN" == true ]]; then

            log INFO "[DRY-RUN] git clone --branch \"$GITHUB_BRANCH\" \"$repository_url\" \"$REPOSITORY_DIR\""

            return 0
        fi

        git clone \
            --branch "$GITHUB_BRANCH" \
            "$repository_url" \
            "$REPOSITORY_DIR"

        log PASS "Repository cloned successfully."

        return 0
    fi


    # --------------------------------------------------------------------------
    # CASE 2:
    #
    # Directory exists and is a Git repository.
    #
    # Action:
    #
    #     git fetch
    #     git pull --ff-only
    #
    # --------------------------------------------------------------------------

    if [[ -d "$REPOSITORY_DIR/.git" ]]; then

        log INFO "Repository already exists."
        log INFO "Updating repository..."

        if [[ "$DRY_RUN" == true ]]; then

            log INFO "[DRY-RUN] git -C \"$REPOSITORY_DIR\" fetch origin"
            log INFO "[DRY-RUN] git -C \"$REPOSITORY_DIR\" pull --ff-only origin \"$GITHUB_BRANCH\""

            return 0
        fi

        git -C "$REPOSITORY_DIR" fetch origin

        # Make sure the requested branch exists locally.
        if git -C "$REPOSITORY_DIR" show-ref \
            --verify \
            --quiet \
            "refs/heads/$GITHUB_BRANCH"; then

            git -C "$REPOSITORY_DIR" checkout "$GITHUB_BRANCH"

        else

            git -C "$REPOSITORY_DIR" checkout \
                -B "$GITHUB_BRANCH" \
                "origin/$GITHUB_BRANCH"

        fi

        git -C "$REPOSITORY_DIR" pull \
            --ff-only \
            origin \
            "$GITHUB_BRANCH"

        log PASS "Repository updated successfully."

        return 0
    fi


    # --------------------------------------------------------------------------
    # CASE 3:
    #
    # A directory exists but is NOT a Git repository.
    #
    # NEVER delete it automatically.
    #
    # This protects user files.
    # --------------------------------------------------------------------------

    log ERROR "Repository path exists but is not a Git repository."

    echo
    echo "Path:"
    echo "    $REPOSITORY_DIR"
    echo
    echo "The script will NOT delete this directory automatically."
    echo

    return 1
}


# ==============================================================================
# SECTION 29 — VERIFY GIT REMOTE
# ==============================================================================

verify_git_remote() {

    section "18" "GIT REMOTE VERIFICATION"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Verify Git remote."
        return 0
    fi

    local expected_url
    local actual_url

    expected_url="git@$GITHUB_HOST:$GITHUB_USERNAME/$GITHUB_REPOSITORY.git"

    actual_url="$(
        git -C "$REPOSITORY_DIR" \
            remote get-url origin
    )"

    echo
    echo "Expected:"
    echo "    $expected_url"
    echo
    echo "Actual:"
    echo "    $actual_url"
    echo

    if [[ "$actual_url" == "$expected_url" ]]; then

        log PASS "Git remote is correct."

    else

        log ERROR "Git remote does not match expected repository."
        return 1

    fi
}


# ==============================================================================
# SECTION 30 — VERIFY BRANCH
# ==============================================================================

verify_git_branch() {

    section "19" "GIT BRANCH VERIFICATION"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Verify branch $GITHUB_BRANCH."
        return 0
    fi

    local current_branch

    current_branch="$(
        git -C "$REPOSITORY_DIR" \
            branch \
            --show-current
    )"

    if [[ "$current_branch" == "$GITHUB_BRANCH" ]]; then

        log PASS "Correct branch is active: $current_branch"

    else

        log ERROR "Expected branch: $GITHUB_BRANCH"
        log ERROR "Current branch : $current_branch"

        return 1
    fi
}


# ==============================================================================
# SECTION 31 — VERIFY WORKING TREE
# ==============================================================================

verify_git_status() {

    section "20" "GIT WORKING TREE"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Check Git working tree."
        return 0
    fi

    local status_output

    status_output="$(
        git -C "$REPOSITORY_DIR" \
            status \
            --porcelain
    )"

    if [[ -z "$status_output" ]]; then

        log PASS "Git working tree is clean."

    else

        log WARN "Git working tree contains local changes."

        echo
        echo "$status_output"
        echo

        # This is intentionally a warning, not an error.
        #
        # A developer may intentionally have local changes.
    fi
}


# ==============================================================================
# SECTION 32 — DISPLAY REPOSITORY INFORMATION
# ==============================================================================

display_repository_information() {

    section "21" "REPOSITORY INFORMATION"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Repository information would be displayed."
        return 0
    fi

    echo
    echo "Repository:"
    git -C "$REPOSITORY_DIR" remote get-url origin

    echo
    echo "Branch:"
    git -C "$REPOSITORY_DIR" branch --show-current

    echo
    echo "Latest commit:"
    git -C "$REPOSITORY_DIR" log -1 --oneline

    echo
    echo "Git status:"
    git -C "$REPOSITORY_DIR" status --short || true
}


# ==============================================================================
# SECTION 33 — CHECK AWS CLI
# ==============================================================================

check_aws_cli() {

    section "22" "AWS CLI"

    if [[ "$SKIP_AWS" == true ]]; then

        log INFO "AWS checks skipped with --skip-aws."
        return 0
    fi

    if command_exists aws; then

        log PASS "AWS CLI is installed."

        aws --version

    else

        log WARN "AWS CLI is not installed."
    fi
}


# ==============================================================================
# SECTION 34 — CHECK AWS IDENTITY
# ==============================================================================

check_aws_identity() {

    section "23" "AWS IDENTITY"

    if [[ "$SKIP_AWS" == true ]]; then

        return 0
    fi

    if ! command_exists aws; then

        log WARN "Skipping AWS identity check because AWS CLI is unavailable."
        return 0
    fi

    if aws sts get-caller-identity >/tmp/github_ec2_aws_identity.json 2>/dev/null; then

        log PASS "AWS credentials are working."

        cat /tmp/github_ec2_aws_identity.json

        rm -f /tmp/github_ec2_aws_identity.json

    else

        log WARN "AWS credentials are not configured or unavailable."
    fi
}


# ==============================================================================
# SECTION 35 — EC2 INFORMATION
# ==============================================================================

collect_ec2_information() {

    section "24" "EC2 INFORMATION"

    if [[ "$SKIP_AWS" == true ]]; then

        return 0
    fi

    if ! command_exists curl; then

        log WARN "curl is not installed. Cannot query EC2 metadata."
        return 0
    fi


    # --------------------------------------------------------------------------
    # IMDSv2 is preferred on modern EC2 instances.
    #
    # The metadata token expires after one hour.
    # --------------------------------------------------------------------------

    local metadata_token=""

    metadata_token="$(
        curl \
            -sS \
            --max-time 3 \
            -X PUT \
            -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
            "http://169.254.169.254/latest/api/token" \
            2>/dev/null || true
    )"


    if [[ -z "$metadata_token" ]]; then

        log WARN "EC2 metadata service is unavailable."
        return 0

    fi


    local instance_id
    local instance_type
    local availability_zone
    local region
    local private_ip
    local public_ip

    instance_id="$(
        curl \
            -sS \
            --max-time 3 \
            -H "X-aws-ec2-metadata-token: $metadata_token" \
            "http://169.254.169.254/latest/meta-data/instance-id"
    )"

    instance_type="$(
        curl \
            -sS \
            --max-time 3 \
            -H "X-aws-ec2-metadata-token: $metadata_token" \
            "http://169.254.169.254/latest/meta-data/instance-type"
    )"

    availability_zone="$(
        curl \
            -sS \
            --max-time 3 \
            -H "X-aws-ec2-metadata-token: $metadata_token" \
            "http://169.254.169.254/latest/meta-data/placement/availability-zone"
    )"

    region="${availability_zone::-1}"

    private_ip="$(
        curl \
            -sS \
            --max-time 3 \
            -H "X-aws-ec2-metadata-token: $metadata_token" \
            "http://169.254.169.254/latest/meta-data/local-ipv4"
    )"

    public_ip="$(
        curl \
            -sS \
            --max-time 3 \
            -H "X-aws-ec2-metadata-token: $metadata_token" \
            "http://169.254.169.254/latest/meta-data/public-ipv4" \
            2>/dev/null || true
    )"


    echo
    echo "Instance ID       : $instance_id"
    echo "Instance Type     : $instance_type"
    echo "Availability Zone : $availability_zone"
    echo "Region            : $region"
    echo "Private IP        : $private_ip"
    echo "Public IP         : ${public_ip:-N/A}"
    echo

    log PASS "EC2 metadata collected."
}


# ==============================================================================
# SECTION 36 — DISK SPACE
# ==============================================================================

check_disk_space() {

    section "25" "DISK SPACE"

    echo

    df -h "$HOME"

    echo

    log PASS "Disk space check completed."
}


# ==============================================================================
# SECTION 37 — RECENT COMMITS
# ==============================================================================

display_recent_commits() {

    section "26" "RECENT COMMITS"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Recent commits would be displayed."
        return 0
    fi

    if [[ ! -d "$REPOSITORY_DIR/.git" ]]; then

        log WARN "Git repository is unavailable."
        return 0
    fi

    git -C "$REPOSITORY_DIR" log \
        --oneline \
        --decorate \
        -5

    log PASS "Recent commits displayed."
}


# ==============================================================================
# SECTION 38 — GENERATE TEXT REPORT
# ==============================================================================

generate_text_report() {

    section "27" "TEXT REPORT"

    local end_time
    end_time="$(date '+%Y-%m-%d %H:%M:%S')"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Would generate report: $REPORT_FILE"
        return 0
    fi


    cat > "$REPORT_FILE" <<EOF
======================================================================
Charlie Cafe — GitHub ↔ EC2 Setup Report
======================================================================

Script Version       : $SCRIPT_VERSION

Start Time           : $START_TIME
End Time             : $end_time

Current User         : $CURRENT_USER
Home Directory       : $CURRENT_HOME

GitHub Host          : $GITHUB_HOST
GitHub Username      : $GITHUB_USERNAME
GitHub Repository    : $GITHUB_REPOSITORY
GitHub Branch        : $GITHUB_BRANCH

GitHub SSH Key Title : $GITHUB_SSH_KEY_TITLE
SSH Private Key      : $SSH_KEY_PATH
SSH Public Key       : $SSH_PUBLIC_KEY_PATH

Repository Directory : $REPOSITORY_DIR

Pass Count           : $PASS_COUNT
Warning Count        : $WARN_COUNT
Failure Count        : $FAIL_COUNT

Overall Status       : $(
    if [[ "$FAIL_COUNT" -eq 0 ]]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
)

======================================================================
EOF


    chmod 600 "$REPORT_FILE"

    log PASS "Text report generated: $REPORT_FILE"
}


# ==============================================================================
# SECTION 39 — GENERATE JSON REPORT
# ==============================================================================

generate_json_report() {

    section "28" "JSON REPORT"

    if [[ "$DRY_RUN" == true ]]; then

        log INFO "[DRY-RUN] Would generate JSON report: $JSON_REPORT_FILE"
        return 0
    fi


    local overall_status="PASS"

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        overall_status="FAIL"
    fi


    # --------------------------------------------------------------------------
    # Basic JSON report.
    #
    # We intentionally avoid external JSON dependencies such as jq.
    # --------------------------------------------------------------------------

    cat > "$JSON_REPORT_FILE" <<EOF
{
  "script": {
    "name": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION"
  },
  "runtime": {
    "user": "$CURRENT_USER",
    "home": "$CURRENT_HOME"
  },
  "github": {
    "host": "$GITHUB_HOST",
    "username": "$GITHUB_USERNAME",
    "repository": "$GITHUB_REPOSITORY",
    "branch": "$GITHUB_BRANCH",
    "ssh_key_title": "$GITHUB_SSH_KEY_TITLE",
    "ssh_key": "$SSH_KEY_PATH"
  },
  "repository": {
    "directory": "$REPOSITORY_DIR"
  },
  "results": {
    "passes": $PASS_COUNT,
    "warnings": $WARN_COUNT,
    "failures": $FAIL_COUNT,
    "status": "$overall_status"
  }
}
EOF


    chmod 600 "$JSON_REPORT_FILE"

    log PASS "JSON report generated: $JSON_REPORT_FILE"
}


# ==============================================================================
# SECTION 40 — FINAL SUMMARY
# ==============================================================================

final_summary() {

    local end_time
    end_time="$(date '+%Y-%m-%d %H:%M:%S')"

    local overall_status="PASS"

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        overall_status="FAIL"
    fi


    echo
    echo
    echo "======================================================================"
    echo "                    CHARLIE CAFE SETUP SUMMARY"
    echo "======================================================================"
    echo
    echo "Script Version       : $SCRIPT_VERSION"
    echo "Current User         : $CURRENT_USER"
    echo "Home Directory       : $CURRENT_HOME"
    echo
    echo "GitHub:"
    echo "  Username           : $GITHUB_USERNAME"
    echo "  Repository         : $GITHUB_REPOSITORY"
    echo "  Branch             : $GITHUB_BRANCH"
    echo
    echo "SSH:"
    echo "  Key Title          : $GITHUB_SSH_KEY_TITLE"
    echo "  Private Key        : $SSH_KEY_PATH"
    echo "  Public Key         : $SSH_PUBLIC_KEY_PATH"
    echo
    echo "Repository:"
    echo "  Directory          : $REPOSITORY_DIR"
    echo
    echo "Results:"
    echo "  PASS               : $PASS_COUNT"
    echo "  WARN               : $WARN_COUNT"
    echo "  FAIL               : $FAIL_COUNT"
    echo
    echo "Reports:"
    echo "  Log                : $LOG_FILE"
    echo "  Text               : $REPORT_FILE"
    echo "  JSON               : $JSON_REPORT_FILE"
    echo
    echo "Start Time           : $START_TIME"
    echo "End Time             : $end_time"
    echo
    echo "Overall Status       : $overall_status"
    echo
    echo "======================================================================"


    if [[ "$overall_status" == "PASS" ]]; then

        echo
        echo -e "${GREEN}SUCCESS${NC}"
        echo
        echo "GitHub ↔ EC2 automation completed successfully."
        echo
        echo "Repository is ready at:"
        echo
        echo "    $REPOSITORY_DIR"
        echo

    else

        echo
        echo -e "${RED}FAILED${NC}"
        echo
        echo "One or more required operations failed."
        echo
        echo "Review:"
        echo
        echo "    $LOG_FILE"
        echo

    fi

    echo "======================================================================"
}


# ==============================================================================
# SECTION 41 — MAIN
# ==============================================================================

main() {

    # Parse command-line arguments before doing anything.
    parse_arguments "$@"

    # Initialize log.
    initialize_logging


    # --------------------------------------------------------------------------
    # Show script banner.
    # --------------------------------------------------------------------------

    echo
    echo "======================================================================"
    echo "☕ Charlie Cafe — GitHub ↔ EC2 Automation"
    echo "======================================================================"
    echo
    echo "Version : $SCRIPT_VERSION"
    echo "User    : $CURRENT_USER"
    echo "Home    : $CURRENT_HOME"
    echo


    # --------------------------------------------------------------------------
    # Environment.
    # --------------------------------------------------------------------------

    check_current_user

    detect_operating_system

    detect_package_manager


    # --------------------------------------------------------------------------
    # Git.
    # --------------------------------------------------------------------------

    install_git_if_required

    collect_configuration

    validate_configuration

    configure_git_identity


    # --------------------------------------------------------------------------
    # SSH.
    # --------------------------------------------------------------------------

    prepare_ssh_directory

    generate_ssh_key

    fix_ssh_permissions

    configure_ssh_config

    configure_known_hosts


    # --------------------------------------------------------------------------
    # GitHub.
    # --------------------------------------------------------------------------

    test_github_network


    # --------------------------------------------------------------------------
    # First attempt.
    #
    # If the key has already been registered with GitHub, this finishes
    # automatically without asking the user anything.
    # --------------------------------------------------------------------------

    if ! register_github_key_interactively; then

        log ERROR "GitHub SSH setup failed."

        final_summary

        exit 1

    fi


    # --------------------------------------------------------------------------
    # Repository.
    # --------------------------------------------------------------------------

    verify_repository_access

    clone_or_update_repository

    verify_git_remote

    verify_git_branch

    verify_git_status

    display_repository_information

    display_recent_commits


    # --------------------------------------------------------------------------
    # AWS / EC2.
    # --------------------------------------------------------------------------

    check_aws_cli

    check_aws_identity

    collect_ec2_information

    check_disk_space


    # --------------------------------------------------------------------------
    # Reports.
    # --------------------------------------------------------------------------

    generate_text_report

    generate_json_report


    # --------------------------------------------------------------------------
    # Final result.
    # --------------------------------------------------------------------------

    final_summary


    # Return failure if any hard failure was recorded.
    if [[ "$FAIL_COUNT" -gt 0 ]]; then

        exit 1

    fi

    exit 0
}


# ==============================================================================
# SECTION 42 — START SCRIPT
# ==============================================================================

main "$@"