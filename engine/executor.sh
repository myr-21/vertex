#!/usr/bin/env bash

# Vertex - Executor

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/json.sh"
source "${VERTEX_HOME}/lib/state.sh"
source "${VERTEX_HOME}/lib/resource.sh"
source "${VERTEX_HOME}/lib/transaction.sh"
source "${VERTEX_HOME}/engine/events.sh"

executor_execute() {
    local tx_id="$1"
    local plan_file="${VERTEX_RUNTIME_DIR}/plans/${tx_id}.json"

    if [[ ! -f "$plan_file" ]]; then
        error_msg "${EXIT_FAILURE}" "Executor" "Plan file not found: ${plan_file}"
        return $?
    fi

    # Verify plan version
    local version
    version=$(json_get "$plan_file" ".version")
    if [[ "$version" -ne "$VERTEX_PLAN_VERSION" ]]; then
        error_msg "${EXIT_UNSUPPORTED_PLAN_VERSION}" "Executor" "Unsupported plan version: ${version}"
        return $?
    fi

    local action
    action=$(json_get "$plan_file" ".action")
    local app_name
    app_name=$(json_get "$plan_file" ".application")

    local desired_file
    desired_file=$(state_get_desired "$app_name")
    local template_name="custom"
    if [[ "$action" == "deploy" && -f "$desired_file" ]]; then
        image=$(json_get "$desired_file" ".image")
        
        # Extract port (handling array of strings vs array of objects)
        local port_val
        port_val=$(json_get "$desired_file" ".ports[0].host")
        if [[ "$port_val" == "null" ]]; then
            port=$(json_get "$desired_file" ".ports[0]")
        else
            port="$port_val"
        fi
        
        # Extract template
        template_name=$(json_get "$desired_file" ".template")
        if [[ "$template_name" == "null" ]]; then
            template_name="custom"
        fi
    fi

    # Start transaction tracking
    transaction_begin "$tx_id"
    before_execute "tx_id=${tx_id}"

    echo "[$(date -u "+%Y-%m-%dT%H:%M:%SZ")] [${tx_id}] [INFO] [EXECUTOR] Starting ${action} for ${app_name}" >> "${VERTEX_LOGS_DIR}/platform/system.log"
    json_set "$plan_file" ".status" "\"running\""

    # We have 4 steps in both deploy and destroy plans
    local step_count=4
    local step_idx
    local step_success=true

    for ((step_idx=0; step_idx<step_count; step_idx++)); do
        local step_id
        step_id=$((step_idx + 1))
        local step_action
        step_action=$(json_get "$plan_file" ".steps[${step_idx}].action")
        local step_rollback
        step_rollback=$(json_get "$plan_file" ".steps[${step_idx}].rollback")

        # Mark step as running
        json_set "$plan_file" ".steps[${step_idx}].status" "\"running\""

        # Execute step action
        local success=false
        case "$step_action" in
            create_network)
                if resource_create_network "$app_name" >/dev/null; then
                    transaction_push "$step_rollback" "$app_name"
                    success=true
                fi
                ;;
            create_volume)
                if resource_create_volume "$app_name" >/dev/null; then
                    transaction_push "$step_rollback" "$app_name"
                    success=true
                fi
                ;;
            create_container)
                if resource_create_container "$app_name" "$image" "$port" "$desired_file" >/dev/null; then
                    transaction_push "$step_rollback" "$app_name"
                    success=true
                fi
                ;;
            delete_container)
                if resource_delete_container "$app_name" >/dev/null; then
                    success=true
                fi
                ;;
            delete_volume)
                if resource_delete_volume "$app_name" >/dev/null; then
                    success=true
                fi
                ;;
            delete_network)
                if resource_delete_network "$app_name" >/dev/null; then
                    success=true
                fi
                ;;
            update_state)
                if [[ "$action" == "deploy" ]]; then
                    # Dynamic state inspection
                    local con_id
                    con_id=$(docker inspect "$app_name" --format '{{.Id}}' 2>/dev/null || echo "unknown")
                    local con_status
                    con_status=$(docker inspect "$app_name" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
                    local con_health
                    con_health=$(docker inspect "$app_name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' 2>/dev/null || echo "unknown")
                    local timestamp
                    timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

                    # Compile state JSON matching Phase 2 schema requirements
                    local schema
                    schema=$(cat <<EOF
{
  "schema_version": ${VERTEX_STATE_SCHEMA_VERSION},
  "id": "${con_id}",
  "name": "${app_name}",
  "template": "${template_name}",
  "image": "${image}",
  "version": "latest",
  "status": "${con_status}",
  "health": "${con_health}",
  "ports": ["${port}"],
  "volumes": ["${app_name}"],
  "networks": ["${app_name}"],
  "dependencies": [],
  "created_at": "${timestamp}",
  "updated_at": "${timestamp}",
  "last_deployment": "${timestamp}",
  "last_backup": ""
}
EOF
)
                    state_create_app "$app_name" "$schema"
                    transaction_push "$step_rollback" "$app_name"
                    success=true
                fi
                if [[ "$action" == "destroy" ]]; then
                    state_delete_app "$app_name"
                    success=true
                fi
                ;;
        esac

        if [[ "$success" == "true" ]]; then
            json_set "$plan_file" ".steps[${step_idx}].status" "\"completed\""
        else
            json_set "$plan_file" ".steps[${step_idx}].status" "\"failed\""
            step_success=false
            break
        fi
    done

    if [[ "$step_success" == "true" ]]; then
        # Commit transaction details
        transaction_commit
        json_set "$plan_file" ".status" "\"completed\""
        after_execute "tx_id=${tx_id}"

        # Update registry
        local registry
        registry=$(state_read_registry)
        
        if [[ "$action" == "deploy" ]]; then
            # Add to registry JSON array if not exists
            registry=$(echo "$registry" | jq ". + [\"${app_name}\"] | unique")
        elif [[ "$action" == "destroy" ]]; then
            # Remove from registry
            registry=$(echo "$registry" | jq "map(select(. != \"${app_name}\"))")
        fi
        state_write_registry "$registry"

        echo "[$(date -u "+%Y-%m-%dT%H:%M:%SZ")] [${tx_id}] [INFO] [EXECUTOR] Completed ${action} for ${app_name}" >> "${VERTEX_LOGS_DIR}/platform/system.log"
        transaction_end
        return 0
    else
        # Trigger LIFO Rollback
        echo "[$(date -u "+%Y-%m-%dT%H:%M:%SZ")] [${tx_id}] [ERROR] [EXECUTOR] Action failed. Triggering rollback." >> "${VERTEX_LOGS_DIR}/platform/system.log"
        before_rollback "tx_id=${tx_id}"
        
        # Rollback all completed steps
        transaction_rollback
        
        json_set "$plan_file" ".status" "\"failed\""
        # Update remaining steps to rolled_back or pending
        for ((i=0; i<step_count; i++)); do
            local status
            status=$(json_get "$plan_file" ".steps[${i}].status")
            if [[ "$status" == "completed" || "$status" == "running" ]]; then
                json_set "$plan_file" ".steps[${i}].status" "\"rolled_back\""
            fi
        done

        after_rollback "tx_id=${tx_id}"
        transaction_end
        return "${EXIT_TX_ROLLBACK}"
    fi
}
