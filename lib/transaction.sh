#!/usr/bin/env bash

# Vertex - Transaction Manager

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/resource.sh"
source "${VERTEX_HOME}/lib/state.sh"

export VERTEX_TX_FILE=""

transaction_begin() {
    local tx_id="$1"
    export VERTEX_TX_ID="${tx_id}"
    export VERTEX_TX_FILE="${VERTEX_RUNTIME_DIR}/locks/${tx_id}.tx"
    echo -n "" > "${VERTEX_TX_FILE}"
}

transaction_push() {
    local rollback_action="$1"
    local rollback_arg="$2"
    if [[ -f "${VERTEX_TX_FILE}" ]]; then
        # Prepend to make rollback LIFO order reading easier later
        # We can write: action arg
        local tmp_file
        tmp_file=$(mktemp)
        echo "${rollback_action} ${rollback_arg}" > "$tmp_file"
        cat "${VERTEX_TX_FILE}" >> "$tmp_file"
        mv "$tmp_file" "${VERTEX_TX_FILE}"
    fi
}

transaction_commit() {
    if [[ -f "${VERTEX_TX_FILE}" ]]; then
        rm -f "${VERTEX_TX_FILE}"
    fi
}

transaction_rollback() {
    if [[ ! -f "${VERTEX_TX_FILE}" ]]; then
        return 0
    fi

    # Trigger rollback event
    if command -v after_rollback &>/dev/null; then
        after_rollback "rollback_started"
    fi

    # Read steps line by line (they are already in LIFO order because we prepended them)
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" ]]; then continue; fi
        local action
        local arg
        action=$(echo "$line" | cut -d' ' -f1)
        arg=$(echo "$line" | cut -d' ' -f2-)
        
        case "$action" in
            delete_container)
                resource_delete_container "$arg" >/dev/null || true
                ;;
            delete_network)
                resource_delete_network "$arg" >/dev/null || true
                ;;
            delete_volume)
                resource_delete_volume "$arg" >/dev/null || true
                ;;
            restore_state)
                state_delete_app "$arg" >/dev/null || true
                ;;
        esac
    done < "${VERTEX_TX_FILE}"

    rm -f "${VERTEX_TX_FILE}"
    return 0
}

transaction_end() {
    export VERTEX_TX_ID=""
    export VERTEX_TX_FILE=""
}
