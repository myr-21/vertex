#!/usr/bin/env bash

# Vertex - Standardized Error Library

# Prints structured error details to stderr.
# Exits with the requested code only if we are in command runner context, otherwise just returns.
# Signature: error_msg <EXIT_CODE> <MODULE> <MESSAGE>
error_msg() {
    local code="$1"
    local module="$2"
    local message="$3"
    
    # Standard log to platform logs if available
    if [[ -n "${VERTEX_LOGS_DIR}" ]]; then
        local tx_id="${VERTEX_TX_ID:-NO_TX}"
        local timestamp
        timestamp="$(date -u "+%Y-%m-%dT%H:%M:%SZ")"
        echo "[${timestamp}] [${tx_id}] [ERROR] [${module}] ${message}" >> "${VERTEX_LOGS_DIR}/platform/system.log"
    fi

    # Print error details to stderr
    echo -e "\033[1;31mError (${module}):\033[0m ${message}" >&2

    return "$code"
}
