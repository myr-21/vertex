#!/usr/bin/env bash

# Vertex - Deploy Command Module
# Thin wrapper around Orchestrator

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/engine/orchestrator.sh"

if [[ -z "$1" ]]; then
    error_msg "${EXIT_INVALID_ARGS}" "Deploy" "Usage: vrtx deploy <app_name> [image] [port]"
    exit $?
fi

APP_NAME="$1"
IMAGE="${2:-nginx:latest}"
PORT="${3:-80}"

# Invoke orchestrator
orchestrator_deploy "$APP_NAME" "$IMAGE" "$PORT"
exit $?
