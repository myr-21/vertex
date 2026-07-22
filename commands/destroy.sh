#!/usr/bin/env bash

# Vertex - Destroy Command Module
# Thin wrapper around Orchestrator

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/engine/orchestrator.sh"

if [[ -z "$1" ]]; then
    error_msg "${EXIT_INVALID_ARGS}" "Destroy" "Usage: vrtx destroy <app_name>"
    exit $?
fi

APP_NAME="$1"

# Invoke orchestrator
orchestrator_destroy "$APP_NAME"
exit $?
