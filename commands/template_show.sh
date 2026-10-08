#!/usr/bin/env bash

# Vertex - Template Show Command

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/template.sh"

if ! template_check_dependencies; then
    exit ${EXIT_FAILURE}
fi

if [[ -z "$1" ]]; then
    error_msg "${EXIT_INVALID_ARGS}" "Template" "Usage: vrtx template show <template_name>"
    exit $?
fi

TEMPLATE_NAME="$1"

if ! template_exists "$TEMPLATE_NAME"; then
    error_msg "${EXIT_VALIDATION_FAILED}" "Template" "Template '${TEMPLATE_NAME}' not found."
    echo ""
    echo "Available templates:"
    template_list
    exit "${EXIT_VALIDATION_FAILED}"
fi

cat "${VERTEX_HOME}/templates/${TEMPLATE_NAME}.yaml"
exit 0
