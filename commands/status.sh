#!/usr/bin/env bash

# Vertex - Status Command Module
# Displays active applications status

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/state.sh"
source "${VERTEX_HOME}/lib/table.sh"
source "${VERTEX_HOME}/lib/json.sh"

apps_json=$(state_read_registry)
apps_count=$(echo "$apps_json" | jq '. | length')

if [[ "$apps_count" -eq 0 ]]; then
    echo "No applications deployed."
    exit 0
fi

# Build headers and rows
header="APP"$'\t'"STATUS"$'\t'"IMAGE"$'\t'"PORT"
rows=()

for ((i=0; i<apps_count; i++)); do
    app_name=$(echo "$apps_json" | jq -r ".[${i}]")
    app_file=$(state_get_current "$app_name")

    if [[ -f "$app_file" ]]; then
        # Cross-check Docker reality
        active_status="stopped"
        if command -v docker &>/dev/null && docker info &>/dev/null; then
            if docker ps --format '{{.Names}}' | grep -Eq "^${app_name}$"; then
                active_status="running"
            elif docker ps -a --format '{{.Names}}' | grep -Eq "^${app_name}$"; then
                active_status="exited"
            fi
        fi

        # Update state if out of sync
        current_file_status=$(json_get "$app_file" ".status")
        if [[ "$current_file_status" != "$active_status" ]]; then
            json_set "$app_file" ".status" "\"${active_status}\""
        fi

        status=$(json_get "$app_file" ".status")
        image=$(json_get "$app_file" ".image")
        
        # Get first port from array
        port=$(json_get "$app_file" ".ports[0]")
        if [[ -z "$port" || "$port" == "null" ]]; then
            port="-"
        fi
        
        rows+=("${app_name}"$'\t'"${status}"$'\t'"${image}"$'\t'"${port}")
    fi
done

print_table "$header" "${rows[@]}"
exit 0
