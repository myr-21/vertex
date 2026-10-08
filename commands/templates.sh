#!/usr/bin/env bash

# Vertex - Templates Command

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/template.sh"

if ! template_check_dependencies; then
    exit ${EXIT_FAILURE}
fi

echo "Available Templates"
echo ""

templates=$(template_list)
if [[ -z "$templates" ]]; then
    echo "No templates found."
else
    echo "$templates"
fi

exit 0
