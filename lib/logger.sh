#!/usr/bin/env bash

# Colors
COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_CYAN="\033[1;36m"
COLOR_GRAY="\033[1;30m"

# Formatting symbols
SYMBOL_SUCCESS="✔"
SYMBOL_FAILURE="✘"
SYMBOL_WARNING="⚠"
SYMBOL_INFO="ℹ"

log_info() {
    local msg="$1"
    echo -e "${COLOR_BLUE}${SYMBOL_INFO} ${msg}${COLOR_RESET}"
}

log_success() {
    local msg="$1"
    echo -e "${COLOR_GREEN}${SYMBOL_SUCCESS} ${msg}${COLOR_RESET}"
}

log_warning() {
    local msg="$1"
    echo -e "${COLOR_YELLOW}${SYMBOL_WARNING} ${msg}${COLOR_RESET}"
}

log_error() {
    local msg="$1"
    echo -e "${COLOR_RED}${SYMBOL_FAILURE} ${msg}${COLOR_RESET}" >&2
}

log_debug() {
    local msg="$1"
    if [[ "${VERTEX_DEBUG}" == "true" ]]; then
        echo -e "${COLOR_GRAY}[DEBUG] ${msg}${COLOR_RESET}"
    fi
}

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
