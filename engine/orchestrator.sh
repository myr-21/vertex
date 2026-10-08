#!/usr/bin/env bash

# Vertex - Orchestrator

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"
source "${VERTEX_HOME}/lib/logger.sh"
source "${VERTEX_HOME}/engine/planner.sh"
source "${VERTEX_HOME}/engine/executor.sh"
source "${VERTEX_HOME}/engine/events.sh"

orchestrator_deploy() {
    local app_name="$1"
    local image="$2"
    local port="$3"
    local template_name="${4:-custom}"
    local template_json="$5"

    before_plan "deploy ${app_name}"

    # Step 1: Generate Plan
    local tx_id
    tx_id=$(planner_plan_deploy "$app_name" "$image" "$port" "$template_name" "$template_json" 2>/dev/null)
    local plan_status=$?
    if [[ "$plan_status" -ne 0 ]]; then
        # If planner printed error, propagate it
        planner_plan_deploy "$app_name" "$image" "$port" "$template_name" "$template_json" >&2
        return "$plan_status"
    fi

    after_plan "tx_id=${tx_id}"

    # Step 2: Execute Plan
    log_info "Deploying application: ${app_name} (Tx: ${tx_id})"
    
    executor_execute "$tx_id"
    local exec_status=$?

    if [[ "$exec_status" -eq 0 ]]; then
        log_success "Deployment of ${app_name} completed successfully!"
        return 0
    else
        log_error "Deployment failed. Rollback executed."
        return "$exec_status"
    fi
}

orchestrator_destroy() {
    local app_name="$1"

    before_plan "destroy ${app_name}"

    # Step 1: Generate Plan
    local tx_id
    tx_id=$(planner_plan_destroy "$app_name" 2>/dev/null)
    local plan_status=$?
    if [[ "$plan_status" -ne 0 ]]; then
        planner_plan_destroy "$app_name" >&2
        return "$plan_status"
    fi

    after_plan "tx_id=${tx_id}"

    # Step 2: Execute Plan
    log_info "Destroying application: ${app_name} (Tx: ${tx_id})"
    
    executor_execute "$tx_id"
    local exec_status=$?

    if [[ "$exec_status" -eq 0 ]]; then
        log_success "Application ${app_name} destroyed successfully."
        return 0
    else
        log_error "Destruction failed. Rollback executed."
        return "$exec_status"
    fi
}

orchestrator_deploy_manifest() {
    local manifest_json="$1"
    local stack_name
    stack_name=$(echo "$manifest_json" | jq -r '.name')

    before_plan "deploy_manifest ${stack_name}"

    local tx_id
    tx_id=$(planner_plan_manifest "$manifest_json" 2>/dev/null)
    local plan_status=$?
    if [[ "$plan_status" -ne 0 ]]; then
        planner_plan_manifest "$manifest_json" >&2
        return "$plan_status"
    fi

    after_plan "tx_id=${tx_id}"

    log_info "Deploying stack: ${stack_name} (Tx: ${tx_id})"
    
    executor_execute "$tx_id"
    local exec_status=$?

    if [[ "$exec_status" -eq 0 ]]; then
        log_success "Deployment of stack ${stack_name} completed successfully!"
        return 0
    else
        log_error "Stack deployment failed. Rollback executed."
        return "$exec_status"
    fi
}

orchestrator_destroy_manifest() {
    local stack_name="$1"

    before_plan "destroy_manifest ${stack_name}"

    local tx_id
    tx_id=$(planner_plan_destroy_manifest "$stack_name" 2>/dev/null)
    local plan_status=$?
    if [[ "$plan_status" -ne 0 ]]; then
        planner_plan_destroy_manifest "$stack_name" >&2
        return "$plan_status"
    fi

    after_plan "tx_id=${tx_id}"

    log_info "Destroying stack: ${stack_name} (Tx: ${tx_id})"
    
    executor_execute "$tx_id"
    local exec_status=$?

    if [[ "$exec_status" -eq 0 ]]; then
        log_success "Stack ${stack_name} destroyed successfully."
        return 0
    else
        log_error "Stack destruction failed. Rollback executed."
        return "$exec_status"
    fi
}
