#!/usr/bin/env bash

# Vertex - Manifest Library

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/json.sh"
source "${VERTEX_HOME}/lib/template.sh"

manifest_parse() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Manifest file '${manifest_file}' not found."
        return $?
    fi

    if ! template_check_dependencies; then
        return ${EXIT_FAILURE}
    fi

    # Convert manifest YAML to JSON using Python
    local raw_json
    raw_json=$(python3 -c '
import yaml, json, sys
try:
    with open(sys.argv[1], "r") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        sys.exit(1)
    json.dump(data, sys.stdout)
except Exception as e:
    sys.exit(1)
' "$manifest_file" 2>/dev/null)

    if [[ $? -ne 0 ]] || [[ -z "$raw_json" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Invalid YAML in manifest '${manifest_file}'"
        return $?
    fi

    local stack_name
    stack_name=$(echo "$raw_json" | jq -r '.name // empty')
    if [[ -z "$stack_name" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Manifest must specify a 'name'"
        return $?
    fi

    local has_services
    has_services=$(echo "$raw_json" | jq -r 'has("services")')
    if [[ "$has_services" != "true" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Manifest must specify 'services'"
        return $?
    fi

    local service_keys
    service_keys=$(echo "$raw_json" | jq -r '.services | keys[]?' 2>/dev/null)
    if [[ -z "$service_keys" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Manifest must contain at least one service"
        return $?
    fi

    # Build normalized JSON
    local normalized_json="{\"name\": \"${stack_name}\", \"services\": {}}"

    for svc in $service_keys; do
        local svc_config
        svc_config=$(echo "$raw_json" | jq -c ".services[\"${svc}\"]")
        
        local tmpl_name
        tmpl_name=$(echo "$svc_config" | jq -r '.template // empty')

        local merged_config="{}"

        if [[ -n "$tmpl_name" ]]; then
            local tmpl_json
            tmpl_json=$(template_parse "$tmpl_name") || return $?
            # Start with template as base
            merged_config="$tmpl_json"
        else
            # If no template, must have image
            local image
            image=$(echo "$svc_config" | jq -r '.image // empty')
            if [[ -z "$image" ]]; then
                error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Service '${svc}' must specify 'template' or 'image'"
                return $?
            fi
            merged_config="$svc_config"
        fi

        # Override with manifest specific fields
        # fields to override: ports, environment, volumes, command, depends_on, image
        merged_config=$(echo "$merged_config" | jq --argjson svc "$svc_config" '
            . + (
                $svc | {
                    ports: (if has("ports") then .ports else null end),
                    environment: (if has("environment") then .environment else null end),
                    volumes: (if has("volumes") then .volumes else null end),
                    command: (if has("command") then .command else null end),
                    depends_on: (if has("depends_on") then .depends_on else null end),
                    image: (if has("image") then .image else null end),
                    template: (if has("template") then .template else null end)
                } | with_entries(select(.value != null))
            )
        ')

        # Add to normalized output
        normalized_json=$(echo "$normalized_json" | jq --argjson conf "$merged_config" --arg svc "$svc" '.services[$svc] = $conf')
    done

    # Dependency Validation check - are there references to nonexistent services?
    for svc in $service_keys; do
        local deps
        deps=$(echo "$normalized_json" | jq -r ".services[\"${svc}\"].depends_on[]?" 2>/dev/null)
        for dep in $deps; do
            local dep_exists
            dep_exists=$(echo "$normalized_json" | jq -r ".services[\"${dep}\"] | type == \"object\"" 2>/dev/null)
            if [[ "$dep_exists" != "true" ]]; then
                error_msg "${EXIT_VALIDATION_FAILED}" "Manifest" "Service '${svc}' depends on nonexistent service '${dep}'"
                return $?
            fi
        done
    done

    echo "$normalized_json"
    return 0
}
