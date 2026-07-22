#!/usr/bin/env bash

# Vertex - Resource Manager

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"

resource_action() {
    local type="$1"
    local name="$2"
    local action="$3"
    shift 3
    local options=("$@")

    # MOCK resource generator
    local id=""
    id=$(echo -n "${type}-${name}-${action}" | md5sum | cut -d' ' -f1 | head -c 12)

    case "${type}" in
        container|network|volume)
            # Standard simulated behaviors
            case "${action}" in
                create|delete|start|stop)
                    echo "{\"success\":true,\"type\":\"${type}\",\"name\":\"${name}\",\"action\":\"${action}\",\"id\":\"${id}\"}"
                    return 0
                    ;;
                *)
                    error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Invalid resource action: ${action}"
                    return $?
                    ;;
            esac
            ;;
        *)
            error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Invalid resource type: ${type}"
            return $?
            ;;
    esac
}

resource_create_container() { resource_action "container" "$1" "create" "${@:2}"; }
resource_delete_container() { resource_action "container" "$1" "delete"; }
resource_start_container() { resource_action "container" "$1" "start"; }
resource_stop_container() { resource_action "container" "$1" "stop"; }

resource_create_network() { resource_action "network" "$1" "create"; }
resource_delete_network() { resource_action "network" "$1" "delete"; }

resource_create_volume() { resource_action "volume" "$1" "create"; }
resource_delete_volume() { resource_action "volume" "$1" "delete"; }
