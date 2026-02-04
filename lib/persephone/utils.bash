#!/usr/bin/env bash
#
# utils.bash - Utility functions for persephone
#

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Log an info message
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

# Log a warning message
log_warn() {
    >&2 echo -e "${YELLOW}[WARN]${NC} $*"
}

# Log an error message
log_error() {
    >&2 echo -e "${RED}[ERROR]${NC} $*"
}

# Log a verbose message (only when $VERBOSE is true)
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        log_info "$@"
    fi
}

# Print error message and exit
die() {
    log_error "$@"
    exit 1
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if a file exists and is readable
file_readable() {
    [[ -f "$1" && -r "$1" ]]
}

# Prompt for password with asterisk masking
prompt_password() {
    local prompt="${1:-Password: }"
    local password=""
    local char

    >&2 printf "%s" "$prompt"

    while IFS= read -r -s -n1 char; do
        # Enter pressed - done
        if [[ -z "$char" ]]; then
            break
        fi
        # Backspace pressed
        if [[ "$char" == $'\x7f' || "$char" == $'\x08' ]]; then
            if [[ -n "$password" ]]; then
                password="${password%?}"
                >&2 printf '\b \b'
            fi
        else
            password+="$char"
            >&2 printf '*'
        fi
    done
    >&2 printf '\n'

    printf '%s' "$password"
}

# Prompt for password with confirmation (for encryption)
prompt_password_confirm() {
    local password confirm
    while true; do
        password="$(prompt_password "Enter password: ")"
        confirm="$(prompt_password "Confirm password: ")"
        if [[ "$password" == "$confirm" ]]; then
            printf '%s' "$password"
            return 0
        fi
        log_error "Passwords do not match. Please try again."
    done
}

# Check password length and warn if too short, prompt for confirmation
warn_short_password() {
    local password="$1"
    local min_length="${2:-8}"
    local response
    if [[ ${#password} -lt $min_length ]]; then
        log_warn "Password is less than $min_length characters"
        >&2 printf "Continue with weak password? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            die "Aborted due to weak password"
        fi
    fi
}
