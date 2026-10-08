#!/usr/bin/env bash

# Vertex - Planner

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/validation.sh"
source "${VERTEX_HOME}/lib/state.sh"
source "${VERTEX_HOME}/lib/time.sh"

planner_generate_tx_id() {
    local date_str
    date_str=$(date "+%Y%m%d-%H%M%S")
    local rand_str
    rand_str=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)
    echo "tx-${date_str}-${rand_str}"
}

planner_plan_deploy() {
    local app_name="$1"
    local image="$2"
    local port="$3"
    local template_name="${4:-custom}"
    local template_json="$5"

    # Input validations
    if ! validate_app_name "$app_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Invalid application name: ${app_name}"
        return $?
    fi

    if ! validate_image_name "$image"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Invalid docker image: ${image}"
        return $?
    fi

    if ! validate_port "$port"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Invalid port format: ${port}"
        return $?
    fi

    # Conflict check - is app already deployed?
    if state_app_exists "$app_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Application ${app_name} is already deployed"
        return $?
    fi

    # Write desired configuration
    local desired_file
    desired_file=$(state_get_desired "$app_name")
    mkdir -p "$(dirname "$desired_file")"
    if [[ -n "$template_json" ]]; then
        # Update the host port in the template JSON if it exists
        echo "$template_json" | jq ". + {schema_version: ${VERTEX_STATE_SCHEMA_VERSION}, name: \"${app_name}\", template: \"${template_name}\"} | if .ports[0] != null and (.ports[0] | type == \"object\") then .ports[0].host = ${port} else . end" > "$desired_file"
    else
        cat <<EOF > "$desired_file"
{
  "schema_version": ${VERTEX_STATE_SCHEMA_VERSION},
  "name": "${app_name}",
  "template": "custom",
  "image": "${image}",
  "ports": ["${port}"]
}
EOF
    fi

    local tx_id
    tx_id=$(planner_generate_tx_id)
    local generated_at
    generated_at=$(time_iso8601)
    local plan_file="${VERTEX_RUNTIME_DIR}/plans/${tx_id}.json"

    # Ensure plan directory exists
    mkdir -p "${VERTEX_RUNTIME_DIR}/plans"

    # Construct plan JSON
    cat <<EOF > "$plan_file"
{
  "version": ${VERTEX_PLAN_VERSION},
  "transaction_id": "${tx_id}",
  "action": "deploy",
  "application": "${app_name}",
  "generated_at": "${generated_at}",
  "status": "planned",
  "steps": [
    {
      "id": 1,
      "action": "create_network",
      "rollback": "delete_network",
      "status": "pending"
    },
    {
      "id": 2,
      "action": "create_volume",
      "rollback": "delete_volume",
      "status": "pending"
    },
    {
      "id": 3,
      "action": "create_container",
      "rollback": "delete_container",
      "status": "pending"
    },
    {
      "id": 4,
      "action": "update_state",
      "rollback": "restore_state",
      "status": "pending"
    }
  ]
}
EOF

    # Validate output plan
    if ! json_validate "$plan_file"; then
        error_msg "${EXIT_FAILURE}" "Planner" "Failed to generate valid plan JSON"
        return $?
    fi

    # Write plan logging
    echo "[$(time_iso8601)] [${tx_id}] [INFO] [PLANNER] Generated deploy plan for ${app_name}" >> "${VERTEX_LOGS_DIR}/platform/system.log"

    echo "$tx_id"
    return 0
}

planner_plan_destroy() {
    local app_name="$1"

    if ! validate_app_name "$app_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Invalid application name: ${app_name}"
        return $?
    fi

    if ! state_app_exists "$app_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Application ${app_name} does not exist"
        return $?
    fi

    local tx_id
    tx_id=$(planner_generate_tx_id)
    local generated_at
    generated_at=$(time_iso8601)
    local plan_file="${VERTEX_RUNTIME_DIR}/plans/${tx_id}.json"

    mkdir -p "${VERTEX_RUNTIME_DIR}/plans"

    # Construct plan JSON for destroy
    cat <<EOF > "$plan_file"
{
  "version": ${VERTEX_PLAN_VERSION},
  "transaction_id": "${tx_id}",
  "action": "destroy",
  "application": "${app_name}",
  "generated_at": "${generated_at}",
  "status": "planned",
  "steps": [
    {
      "id": 1,
      "action": "delete_container",
      "rollback": "create_container",
      "status": "pending"
    },
    {
      "id": 2,
      "action": "delete_volume",
      "rollback": "create_volume",
      "status": "pending"
    },
    {
      "id": 3,
      "action": "delete_network",
      "rollback": "create_network",
      "status": "pending"
    },
    {
      "id": 4,
      "action": "update_state",
      "rollback": "restore_state",
      "status": "pending"
    }
  ]
}
EOF

    if ! json_validate "$plan_file"; then
        error_msg "${EXIT_FAILURE}" "Planner" "Failed to generate valid destroy plan JSON"
        return $?
    fi

    echo "[$(time_iso8601)] [${tx_id}] [INFO] [PLANNER] Generated destroy plan for ${app_name}" >> "${VERTEX_LOGS_DIR}/platform/system.log"

    echo "$tx_id"
    return 0
}

planner_plan_manifest() {
    local manifest_json="$1"

    local stack_name
    stack_name=$(echo "$manifest_json" | jq -r '.name')

    if ! validate_app_name "$stack_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Invalid stack name: ${stack_name}"
        return $?
    fi

    # Topologically sort services and detect circular dependencies using Python
    local sorted_services
    sorted_services=$(python3 -c '
import sys, json

def topo_sort(manifest):
    services = manifest.get("services", {})
    in_degree = {s: 0 for s in services}
    adj = {s: [] for s in services}
    
    for s, conf in services.items():
        deps = conf.get("depends_on", [])
        if deps is None:
            deps = []
        if not isinstance(deps, list):
            deps = [deps]
        for d in deps:
            if d not in services:
                print(f"Error: service {s} depends on nonexistent service {d}", file=sys.stderr)
                sys.exit(1)
            adj[d].append(s)
            in_degree[s] += 1
            
    queue = [s for s in services if in_degree[s] == 0]
    sorted_list = []
    
    while queue:
        u = queue.pop(0)
        sorted_list.append(u)
        for v in adj[u]:
            in_degree[v] -= 1
            if in_degree[v] == 0:
                queue.append(v)
                
    if len(sorted_list) != len(services):
        print("Dependency validation failed:\nCircular dependency detected.", file=sys.stderr)
        sys.exit(1)
        
    print(" ".join(sorted_list))

try:
    manifest = json.loads(sys.argv[1])
    topo_sort(manifest)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
' "$manifest_json" 2>&1)

    if [[ $? -ne 0 ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "$sorted_services"
        return $?
    fi

    # Write desired configuration for each service
    for svc in $sorted_services; do
        local svc_id="${stack_name}/${svc}"
        
        # Conflict check
        if state_app_exists "$svc_id"; then
            error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Service ${svc_id} is already deployed"
            return $?
        fi

        local desired_file
        desired_file=$(state_get_desired "$svc_id")
        mkdir -p "$(dirname "$desired_file")"

        local svc_config
        svc_config=$(echo "$manifest_json" | jq -c ".services[\"${svc}\"]")
        
        echo "$svc_config" | jq ". + {schema_version: ${VERTEX_STATE_SCHEMA_VERSION}, name: \"${svc_id}\", networks: [\"vertex-${stack_name}\"]}" > "$desired_file"
    done

    local tx_id
    tx_id=$(planner_generate_tx_id)
    local generated_at
    generated_at=$(time_iso8601)
    local plan_file="${VERTEX_RUNTIME_DIR}/plans/${tx_id}.json"

    mkdir -p "${VERTEX_RUNTIME_DIR}/plans"

    # Start building JSON plan
    local plan_json="{\"version\": ${VERTEX_PLAN_VERSION}, \"transaction_id\": \"${tx_id}\", \"action\": \"deploy_manifest\", \"application\": \"${stack_name}\", \"generated_at\": \"${generated_at}\", \"status\": \"planned\", \"steps\": []}"
    
    local step_idx=1
    
    # 1. Create stack network
    local net_name="vertex-${stack_name}"
    plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${net_name}\", \"action\": \"create_network\", \"rollback\": \"delete_network\", \"status\": \"pending\"}]")
    step_idx=$((step_idx + 1))

    # 2. Iterate services in sorted order
    for svc in $sorted_services; do
        local svc_id="${stack_name}/${svc}"
        
        plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${svc_id}\", \"action\": \"create_volume\", \"rollback\": \"delete_volume\", \"status\": \"pending\"}]")
        step_idx=$((step_idx + 1))

        plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${svc_id}\", \"action\": \"create_container\", \"rollback\": \"delete_container\", \"status\": \"pending\"}]")
        step_idx=$((step_idx + 1))

        plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${svc_id}\", \"action\": \"update_state\", \"rollback\": \"restore_state\", \"status\": \"pending\"}]")
        step_idx=$((step_idx + 1))
    done

    echo "$plan_json" > "$plan_file"

    if ! json_validate "$plan_file"; then
        error_msg "${EXIT_FAILURE}" "Planner" "Failed to generate valid manifest plan JSON"
        return $?
    fi

    echo "[$(time_iso8601)] [${tx_id}] [INFO] [PLANNER] Generated deploy manifest plan for stack ${stack_name}" >> "${VERTEX_LOGS_DIR}/platform/system.log"

    echo "$tx_id"
    return 0
}

planner_plan_destroy_manifest() {
    local stack_name="$1"

    if ! validate_app_name "$stack_name"; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Invalid stack name: ${stack_name}"
        return $?
    fi

    # Find all services for this stack
    # In state/desired/stack_name/*.json
    local stack_dir="${VERTEX_STATE_DIR}/desired/${stack_name}"
    if [[ ! -d "$stack_dir" ]]; then
        error_msg "${EXIT_VALIDATION_FAILED}" "Planner" "Stack ${stack_name} does not exist"
        return $?
    fi

    # Read desired configurations to rebuild dependency graph
    local manifest_json="{\"services\": {}}"
    for f in "$stack_dir"/*.json; do
        if [[ -f "$f" ]]; then
            local svc
            svc=$(basename "$f" .json)
            local svc_json
            svc_json=$(cat "$f")
            manifest_json=$(echo "$manifest_json" | jq --argjson s "$svc_json" --arg name "$svc" '.services[$name] = $s')
        fi
    done

    # Sort services in REVERSE topological order
    local sorted_services
    sorted_services=$(python3 -c '
import sys, json

def topo_sort(manifest):
    services = manifest.get("services", {})
    in_degree = {s: 0 for s in services}
    adj = {s: [] for s in services}
    
    for s, conf in services.items():
        deps = conf.get("depends_on", [])
        if deps is None:
            deps = []
        if not isinstance(deps, list):
            deps = [deps]
        for d in deps:
            if d in services:
                adj[d].append(s)
                in_degree[s] += 1
            
    queue = [s for s in services if in_degree[s] == 0]
    sorted_list = []
    
    while queue:
        u = queue.pop(0)
        sorted_list.append(u)
        for v in adj[u]:
            in_degree[v] -= 1
            if in_degree[v] == 0:
                queue.append(v)
                
    # Reverse for destruction
    sorted_list.reverse()
    print(" ".join(sorted_list))

try:
    manifest = json.loads(sys.argv[1])
    topo_sort(manifest)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
' "$manifest_json" 2>&1)

    local tx_id
    tx_id=$(planner_generate_tx_id)
    local generated_at
    generated_at=$(time_iso8601)
    local plan_file="${VERTEX_RUNTIME_DIR}/plans/${tx_id}.json"

    mkdir -p "${VERTEX_RUNTIME_DIR}/plans"

    local plan_json="{\"version\": ${VERTEX_PLAN_VERSION}, \"transaction_id\": \"${tx_id}\", \"action\": \"destroy_manifest\", \"application\": \"${stack_name}\", \"generated_at\": \"${generated_at}\", \"status\": \"planned\", \"steps\": []}"
    local step_idx=1

    for svc in $sorted_services; do
        local svc_id="${stack_name}/${svc}"
        
        plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${svc_id}\", \"action\": \"delete_container\", \"rollback\": \"create_container\", \"status\": \"pending\"}]")
        step_idx=$((step_idx + 1))

        plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${svc_id}\", \"action\": \"delete_volume\", \"rollback\": \"create_volume\", \"status\": \"pending\"}]")
        step_idx=$((step_idx + 1))

        plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${svc_id}\", \"action\": \"update_state\", \"rollback\": \"restore_state\", \"status\": \"pending\"}]")
        step_idx=$((step_idx + 1))
    done

    local net_name="vertex-${stack_name}"
    plan_json=$(echo "$plan_json" | jq ".steps += [{\"id\": ${step_idx}, \"target\": \"${net_name}\", \"action\": \"delete_network\", \"rollback\": \"create_network\", \"status\": \"pending\"}]")
    
    echo "$plan_json" > "$plan_file"

    if ! json_validate "$plan_file"; then
        error_msg "${EXIT_FAILURE}" "Planner" "Failed to generate valid destroy manifest plan JSON"
        return $?
    fi

    echo "[$(time_iso8601)] [${tx_id}] [INFO] [PLANNER] Generated destroy manifest plan for stack ${stack_name}" >> "${VERTEX_LOGS_DIR}/platform/system.log"

    echo "$tx_id"
    return 0
}
