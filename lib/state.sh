#!/usr/bin/env bash

# Vertex - State Engine

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/json.sh"

state_get_current() {
    local app_name="$1"
    echo "${VERTEX_STATE_DIR}/current/${app_name}.json"
}

state_get_desired() {
    local app_name="$1"
    echo "${VERTEX_STATE_DIR}/desired/${app_name}.json"
}

state_app_exists() {
    local app_name="$1"
    local file
    file=$(state_get_current "$app_name")
    if [[ -f "$file" ]]; then
        return 0
    fi
    return 1
}

state_create_app() {
    local app_name="$1"
    local json_data="$2"
    
    local desired_file
    desired_file=$(state_get_desired "$app_name")
    local current_file
    current_file=$(state_get_current "$app_name")

    mkdir -p "$(dirname "$desired_file")"
    mkdir -p "$(dirname "$current_file")"

    # Write input configuration to desired state
    echo "$json_data" > "$desired_file"
    # Set default values for schema and statuses in current state
    echo "$json_data" > "$current_file"
    json_set "$current_file" ".schema_version" "${VERTEX_STATE_SCHEMA_VERSION}"
    json_set "$current_file" ".status" "\"planned\""
    json_set "$current_file" ".health" "\"unknown\""
}

state_get_app() {
    local app_name="$1"
    local file
    file=$(state_get_current "$app_name")
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    cat "$file"
    return 0
}

state_update_app() {
    local app_name="$1"
    local path="$2"
    local value="$3"
    
    local file
    file=$(state_get_current "$app_name")
    json_set "$file" "$path" "$value"
    return $?
}

state_delete_app() {
    local app_name="$1"
    
    local desired_file
    desired_file=$(state_get_desired "$app_name")
    local current_file
    current_file=$(state_get_current "$app_name")
    local history_dir="${VERTEX_STATE_DIR}/history"

    # Backup to history directory before deleting
    if [[ -f "$current_file" ]]; then
        mkdir -p "$(dirname "${history_dir}/${app_name}")"
        cp "$current_file" "${history_dir}/${app_name}-$(date "+%Y%m%d-%H%M%S").json"
        rm -f "$current_file"
    fi
    if [[ -f "$desired_file" ]]; then
        rm -f "$desired_file"
    fi
}

state_list_apps() {
    # List filenames without .json extension
    if [[ -d "${VERTEX_STATE_DIR}/current" ]]; then
        find "${VERTEX_STATE_DIR}/current" -name "*.json" -exec basename {} .json \;
    fi
}

state_read_registry() {
    if [[ ! -f "${VERTEX_REGISTRY_FILE}" ]]; then
        echo "[]"
        return 0
    fi
    cat "${VERTEX_REGISTRY_FILE}"
}

state_write_registry() {
    local json_array="$1"
    echo "$json_array" > "${VERTEX_REGISTRY_FILE}"
}
