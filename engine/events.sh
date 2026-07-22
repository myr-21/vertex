#!/usr/bin/env bash

# Vertex - Event Hooks

log_event() {
    local hook_name="$1"
    local detail="$2"
    local timestamp
    timestamp="$(date -u "+%Y-%m-%dT%H:%M:%SZ")"
    local tx_id="${VERTEX_TX_ID:-NO_TX}"
    echo "[${timestamp}] [${tx_id}] [INFO] [EVENTS] Hook [${hook_name}] triggered: ${detail}" >> "${VERTEX_LOGS_DIR}/platform/events.log"
}

before_plan() { log_event "before_plan" "$1"; }
after_plan() { log_event "after_plan" "$1"; }
before_execute() { log_event "before_execute" "$1"; }
after_execute() { log_event "after_execute" "$1"; }
before_rollback() { log_event "before_rollback" "$1"; }
after_rollback() { log_event "after_rollback" "$1"; }
