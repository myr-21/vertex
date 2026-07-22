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
