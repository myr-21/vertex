#!/usr/bin/env bash

# Validate application name (alphanumeric, hyphens, lowercase preferred)
validate_app_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        return 1
    fi
    if [[ ${#name} -gt 63 ]]; then
        return 1
    fi
    return 0
}

# Validate docker image name format
validate_image_name() {
    local image="$1"
    # Basic check for shell injection characters or invalid image characters
    if [[ "$image" =~ [^a-zA-Z0-9_.:/-] ]]; then
        return 1
    fi
    return 0
}

# Validate ports (1 to 65535)
validate_port() {
    local port="$1"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if (( port < 1 || port > 65535 )); then
        return 1
    fi
    return 0
}

# Reject dangerous shell injection characters
sanitize_input() {
    local input="$1"
    if [[ "$input" =~ [\&\|\;\$\>\<\`\!] ]]; then
        return 1
    fi
    return 0
}
