#!/usr/bin/env bash

# Vertex - JSON Library (JQ Wrapper)

# Cross-platform JQ wrapper to strip Windows carriage returns (\r)
jq() {
    command jq "$@" | tr -d '\r'
}

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"

json_validate() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    jq empty "$file" 2>/dev/null
    return $?
}

json_get() {
    local file="$1"
    local path="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    # Use -r to print raw output if it is a string
    jq -r "${path}" "$file" 2>/dev/null
    return $?
}

json_set() {
    local file="$1"
    local path="$2"
    local value="$3"

    # Initialize empty object if file does not exist
    if [[ ! -f "$file" ]]; then
        echo "{}" > "$file"
    fi

    # Check if value is valid JSON (like a string with quotes, number, array, or object)
    # If JQ fails to parse it as raw JSON, treat it as a string
    local tmp_file
    tmp_file=$(mktemp)

    if jq --argjson val "$value" "${path} = \$val" "$file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$file"
        return 0
    elif jq --arg val "$value" "${path} = \$val" "$file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$file"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

json_delete() {
    local file="$1"
    local path="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)
    if jq "del(${path})" "$file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$file"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

json_exists() {
    local file="$1"
    local path="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    # If path evaluates to null or does not exist, jq returns null
    local res
    res=$(jq "${path}" "$file" 2>/dev/null)
    if [[ "$res" == "null" || -z "$res" ]]; then
        return 1
    fi
    return 0
}
