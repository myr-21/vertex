#!/usr/bin/env bash

# Vertex - Template Library

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/json.sh"

TEMPLATE_DIR="${VERTEX_HOME}/templates"

template_exists() {
    local template_name="$1"
    if [[ -f "${TEMPLATE_DIR}/${template_name}.yaml" ]]; then
        return 0
    fi
    return 1
}

template_check_dependencies() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Vertex template support requires Python 3." >&2
        echo "Install Python 3 and retry." >&2
        return 1
    fi
    
    if ! python3 -c "import yaml" >/dev/null 2>&1; then
        echo "Vertex template support requires PyYAML." >&2
        echo "Install it with:" >&2
        echo "python3 -m pip install pyyaml" >&2
        return 1
    fi
    return 0
}

template_parse() {
    local template_name="$1"
    local template_file="${TEMPLATE_DIR}/${template_name}.yaml"

    if ! template_exists "$template_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Template" "Template '${template_name}' not found."
        return $?
    fi

    if ! template_check_dependencies; then
        return ${EXIT_FAILURE}
    fi

    # Convert YAML to JSON using Python
    local json_output
    json_output=$(python3 -c '
import yaml, json, sys
try:
    data = yaml.safe_load(sys.stdin)
    if not isinstance(data, dict):
        sys.exit(1)
    json.dump(data, sys.stdout)
except Exception as e:
    sys.exit(1)
' < "$template_file" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$json_output" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Template" "Invalid YAML in template '${template_name}'"
        return $?
    fi

    # Basic Validation
    local image
    image=$(echo "$json_output" | jq -r '.image // empty')
    if [[ -z "$image" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Template" "Template: ${template_name} | Field: image | Reason: required field is missing"
        return $?
    fi

    echo "$json_output"
    return 0
}

template_list() {
    if [[ -d "$TEMPLATE_DIR" ]]; then
        for f in "$TEMPLATE_DIR"/*.yaml; do
            if [[ -f "$f" ]]; then
                basename "$f" .yaml
            fi
        done
    fi
}
