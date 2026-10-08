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

    # Dynamic step count
    local step_count
    step_count=$(jq '.steps | length' "$plan_file")
    local step_idx
    local step_success=true

    for ((step_idx=0; step_idx<step_count; step_idx++)); do
        local step_id
        step_id=$((step_idx + 1))
        local step_action
        step_action=$(json_get "$plan_file" ".steps[${step_idx}].action")
        local step_rollback
        step_rollback=$(json_get "$plan_file" ".steps[${step_idx}].rollback")

        local step_target
        step_target=$(json_get "$plan_file" ".steps[${step_idx}].target")
        if [[ "$step_target" == "null" ]]; then
            step_target="$app_name"
        fi

        # Mark step as running
        json_set "$plan_file" ".steps[${step_idx}].status" "\"running\""

        # Execute step action
        local success=false
        case "$step_action" in
            create_network)
                if resource_create_network "$step_target" >/dev/null; then
                    transaction_push "$step_rollback" "$step_target"
                    success=true
                fi
                ;;
            create_volume)
                if resource_create_volume "$step_target" >/dev/null; then
                    transaction_push "$step_rollback" "$step_target"
                    success=true
                fi
                ;;
            create_container)
                local current_desired_file
                current_desired_file=$(state_get_desired "$step_target")
                
                # Fetch image and port just in time
                local current_image
                current_image=$(json_get "$current_desired_file" ".image")
                local current_port
                current_port=$(json_get "$current_desired_file" ".ports[0].host")
                if [[ "$current_port" == "null" ]]; then
                    current_port=$(json_get "$current_desired_file" ".ports[0]")
                fi
                local current_template
                current_template=$(json_get "$current_desired_file" ".template")
                if [[ "$current_template" == "null" ]]; then
                    current_template="custom"
                fi

                if resource_create_container "$step_target" "$current_image" "$current_port" "$current_desired_file" >/dev/null; then
                    transaction_push "$step_rollback" "$step_target"
                    success=true
                fi
                ;;
            delete_container)
                if resource_delete_container "$step_target" >/dev/null; then
                    success=true
                fi
                ;;
            delete_volume)
                if resource_delete_volume "$step_target" >/dev/null; then
                    success=true
                fi
                ;;
            delete_network)
                if resource_delete_network "$step_target" >/dev/null; then
                    success=true
                fi
                ;;
            update_state)
                if [[ "$action" == "deploy" || "$action" == "deploy_manifest" ]]; then
                    local current_desired_file
                    current_desired_file=$(state_get_desired "$step_target")
                    local current_image
                    current_image=$(json_get "$current_desired_file" ".image")
                    local current_port
                    current_port=$(json_get "$current_desired_file" ".ports[0].host")
                    if [[ "$current_port" == "null" ]]; then
                        current_port=$(json_get "$current_desired_file" ".ports[0]")
                    fi
                    local current_template
                    current_template=$(json_get "$current_desired_file" ".template")
                    if [[ "$current_template" == "null" ]]; then
                        current_template="custom"
                    fi

                    # Dynamic state inspection
                    # Extract raw app name (removing stack prefix if present) to docker inspect
                    local raw_target="${step_target}"
                    if [[ "$raw_target" == *"/"* ]]; then
                        raw_target="${raw_target#*/}"
                    fi

                    local con_id="unknown"
                    local con_status="unknown"
                    local con_health="unknown"
                    if docker inspect "$raw_target" &>/dev/null; then
                        con_id=$(docker inspect "$raw_target" --format '{{.Id}}' 2>/dev/null | tr -d '\r')
                        con_status=$(docker inspect "$raw_target" --format '{{.State.Status}}' 2>/dev/null | tr -d '\r')
                        con_health=$(docker inspect "$raw_target" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' 2>/dev/null | tr -d '\r')
                    fi
                    local timestamp
                    timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

                    local schema
                    schema=$(cat <<EOF
{
  "schema_version": ${VERTEX_STATE_SCHEMA_VERSION},
  "id": "${con_id}",
  "name": "${step_target}",
  "template": "${current_template}",
  "image": "${current_image}",
  "version": "latest",
  "status": "${con_status}",
  "health": "${con_health}",
  "ports": ["${current_port}"],
  "volumes": ["${raw_target}"],
  "networks": ["${raw_target}"],
  "dependencies": [],
  "created_at": "${timestamp}",
  "updated_at": "${timestamp}",
  "last_deployment": "${timestamp}",
  "last_backup": ""
}
EOF
)
                    state_create_app "$step_target" "$schema"
                    transaction_push "$step_rollback" "$step_target"
                    success=true
                fi
                if [[ "$action" == "destroy" || "$action" == "destroy_manifest" ]]; then
                    state_delete_app "$step_target"
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
        
        if [[ "$action" == "deploy" || "$action" == "deploy_manifest" ]]; then
            # Add to registry JSON array if not exists
            if [[ "$action" == "deploy_manifest" ]]; then
                # For manifest, add all targets
                for ((i=0; i<step_count; i++)); do
                    local t
                    t=$(json_get "$plan_file" ".steps[${i}].target")
                    if [[ "$t" != "null" ]]; then
                        registry=$(echo "$registry" | jq ". + [\"${t}\"] | unique")
                    fi
                done
            else
                registry=$(echo "$registry" | jq ". + [\"${app_name}\"] | unique")
            fi
        elif [[ "$action" == "destroy" || "$action" == "destroy_manifest" ]]; then
            # Remove from registry
            if [[ "$action" == "destroy_manifest" ]]; then
                for ((i=0; i<step_count; i++)); do
                    local t
                    t=$(json_get "$plan_file" ".steps[${i}].target")
                    if [[ "$t" != "null" ]]; then
                        registry=$(echo "$registry" | jq "map(select(. != \"${t}\"))")
                    fi
                done
            else
                registry=$(echo "$registry" | jq "map(select(. != \"${app_name}\"))")
            fi
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
