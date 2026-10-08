#!/usr/bin/env bash

# Vertex - Deploy Command Module
# Thin wrapper around Orchestrator

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/engine/orchestrator.sh"

source "${VERTEX_HOME}/lib/template.sh"

if [[ -z "$1" ]]; then
    echo -e "${COLOR_YELLOW}Usage:${COLOR_RESET}"
    echo "  1. Manual deployment:   vrtx deploy <app_name> <image> <port>"
    echo "  2. Template deployment: vrtx deploy <app_name> --template <template>"
    echo "  3. Template shorthand:  vrtx deploy <template>"
    exit 1
fi

APP_NAME="$1"
shift

TEMPLATE=""
IMAGE=""
PORT=""

# Check arguments
if [[ "$1" == "--template" ]]; then
    if [[ -z "$2" ]]; then
        error_msg "${EXIT_INVALID_ARGS}" "Deploy" "Usage: vrtx deploy <app_name> --template <template>"
        exit 1
    fi
    TEMPLATE="$2"
elif [[ $# -eq 0 ]]; then
    # Mode 3: Shorthand
    # If app name matches a template exactly, we use it.
    if template_exists "$APP_NAME"; then
        TEMPLATE="$APP_NAME"
    else
        error_msg "${EXIT_INVALID_ARGS}" "Deploy" "Usage: vrtx deploy <app_name> [image] [port] or --template"
        exit 1
    fi
else
    # Mode 1: Manual
    IMAGE="$1"
    PORT="$2"
fi

if [[ -n "$TEMPLATE" ]]; then
    # Parse template and extract defaults
    TEMPLATE_JSON=$(template_parse "$TEMPLATE")
    if [[ $? -ne 0 ]]; then
        exit 1 # error is already printed by template_parse
    fi
    
    # Extract image and port
    IMAGE=$(echo "$TEMPLATE_JSON" | jq -r '.image // empty')
    PORT=$(echo "$TEMPLATE_JSON" | jq -r '.ports[0].host // empty')
    
    if [[ -z "$PORT" ]]; then
        PORT="80" # Fallback if no port specified
    fi
fi

if [[ -z "$IMAGE" || -z "$PORT" ]]; then
    error_msg "${EXIT_INVALID_ARGS}" "Deploy" "Invalid or missing image/port."
    exit 1
fi

# We need to pass TEMPLATE_JSON to orchestrator, or pass TEMPLATE string.
# Let's pass TEMPLATE string as well so it can be saved in state.
# We will change orchestrator signature to:
# orchestrator_deploy "$APP_NAME" "$IMAGE" "$PORT" "$TEMPLATE" "$TEMPLATE_JSON"
orchestrator_deploy "$APP_NAME" "$IMAGE" "$PORT" "${TEMPLATE:-custom}" "$TEMPLATE_JSON"
exit $?
