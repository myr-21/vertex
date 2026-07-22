#!/usr/bin/env bash

# Vertex - Resource Manager (Docker Engine Integration)

source "${VERTEX_HOME}/lib/constants.sh"
source "${VERTEX_HOME}/lib/error.sh"

# Helper to verify Docker daemon is reachable
resource_verify_daemon() {
    if ! command -v docker &>/dev/null; then
        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Docker CLI is not installed on this system"
        return $?
    fi
    if ! docker info &>/dev/null; then
        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Docker daemon is not running or unreachable"
        return $?
    fi
    return 0
}

# Unified resource manager signature: resource_action <TYPE> <NAME> <ACTION> [OPTIONS...]
resource_action() {
    local type="$1"
    local name="$2"
    local action="$3"
    shift 3
    local options=("$@")

    # Verify daemon connectivity before modifying any resources
    resource_verify_daemon || return $?

    case "${type}" in
        network)
            case "${action}" in
                create)
                    if docker network inspect "$name" &>/dev/null; then
                        # Network already exists, return success (idempotent)
                        local net_id
                        net_id=$(docker network inspect "$name" --format '{{.Id}}')
                        echo "{\"success\":true,\"type\":\"network\",\"name\":\"${name}\",\"action\":\"create\",\"id\":\"${net_id}\"}"
                        return 0
                    fi
                    local net_id
                    net_id=$(docker network create "$name" 2>/dev/null) || {
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to create docker network: ${name}"
                        return $?
                    }
                    echo "{\"success\":true,\"type\":\"network\",\"name\":\"${name}\",\"action\":\"create\",\"id\":\"${net_id}\"}"
                    return 0
                    ;;
                delete)
                    if ! docker network inspect "$name" &>/dev/null; then
                        echo "{\"success\":true,\"type\":\"network\",\"name\":\"${name}\",\"action\":\"delete\",\"id\":\"\"}"
                        return 0
                    fi
                    docker network rm "$name" &>/dev/null || {
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to remove docker network: ${name}"
                        return $?
                    }
                    echo "{\"success\":true,\"type\":\"network\",\"name\":\"${name}\",\"action\":\"delete\",\"id\":\"\"}"
                    return 0
                    ;;
            esac
            ;;
        volume)
            case "${action}" in
                create)
                    if docker volume inspect "$name" &>/dev/null; then
                        echo "{\"success\":true,\"type\":\"volume\",\"name\":\"${name}\",\"action\":\"create\",\"id\":\"${name}\"}"
                        return 0
                    fi
                    docker volume create "$name" &>/dev/null || {
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to create docker volume: ${name}"
                        return $?
                    }
                    echo "{\"success\":true,\"type\":\"volume\",\"name\":\"${name}\",\"action\":\"create\",\"id\":\"${name}\"}"
                    return 0
                    ;;
                delete)
                    if ! docker volume inspect "$name" &>/dev/null; then
                        echo "{\"success\":true,\"type\":\"volume\",\"name\":\"${name}\",\"action\":\"delete\",\"id\":\"\"}"
                        return 0
                    fi
                    docker volume rm "$name" &>/dev/null || {
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to remove docker volume: ${name}"
                        return $?
                    }
                    echo "{\"success\":true,\"type\":\"volume\",\"name\":\"${name}\",\"action\":\"delete\",\"id\":\"\"}"
                    return 0
                    ;;
            esac
            ;;
        container)
            case "${action}" in
                create)
                    local image="${options[0]}"
                    local port="${options[1]}"
                    
                    # 1. Image validation & pull if missing
                    if ! docker image inspect "$image" &>/dev/null; then
                        docker pull "$image" &>/dev/null || {
                            error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to pull docker image: ${image}"
                            return $?
                        }
                    fi

                    # 2. Check port conflict (is port in use by another container?)
                    if docker ps --format '{{.Ports}}' | grep -q ":${port}->"; then
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Port ${port} is already in use by another container"
                        return $?
                    fi

                    # 3. Check container name conflict
                    if docker ps -a --format '{{.Names}}' | grep -Eq "^${name}$"; then
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Container name ${name} is already in use"
                        return $?
                    fi

                    # 4. Determine exposed port of image dynamically
                    local exposed_port
                    exposed_port=$(docker image inspect "$image" --format '{{range $p, $conf := .Config.ExposedPorts}}{{$p}}{{end}}' 2>/dev/null | cut -d'/' -f1 | head -n 1)
                    if [[ -z "$exposed_port" ]]; then
                        exposed_port="80"
                    fi

                    # 5. Start container
                    # Map default volume to /data, bridge network app-name
                    local container_id
                    container_id=$(docker run -d \
                        --name "$name" \
                        --network "$name" \
                        -v "${name}:/data" \
                        -p "${port}:${exposed_port}" \
                        "$image" 2>/dev/null) || {
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to run docker container: ${name}"
                        return $?
                    }

                    echo "{\"success\":true,\"type\":\"container\",\"name\":\"${name}\",\"action\":\"create\",\"id\":\"${container_id}\"}"
                    return 0
                    ;;
                delete)
                    if ! docker ps -a --format '{{.Names}}' | grep -Eq "^${name}$"; then
                        echo "{\"success\":true,\"type\":\"container\",\"name\":\"${name}\",\"action\":\"delete\",\"id\":\"\"}"
                        return 0
                    fi
                    docker rm -f "$name" &>/dev/null || {
                        error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to remove docker container: ${name}"
                        return $?
                    }
                    echo "{\"success\":true,\"type\":\"container\",\"name\":\"${name}\",\"action\":\"delete\",\"id\":\"\"}"
                    return 0
                    ;;
                stop)
                    if docker ps --format '{{.Names}}' | grep -Eq "^${name}$"; then
                        docker stop "$name" &>/dev/null || {
                            error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to stop docker container: ${name}"
                            return $?
                        }
                    fi
                    echo "{\"success\":true,\"type\":\"container\",\"name\":\"${name}\",\"action\":\"stop\",\"id\":\"\"}"
                    return 0
                    ;;
                start)
                    if docker ps -a --format '{{.Names}}' | grep -Eq "^${name}$" && ! docker ps --format '{{.Names}}' | grep -Eq "^${name}$"; then
                        docker start "$name" &>/dev/null || {
                            error_msg "${EXIT_RESOURCE_FAILURE}" "Resource" "Failed to start docker container: ${name}"
                            return $?
                        }
                    fi
                    echo "{\"success\":true,\"type\":\"container\",\"name\":\"${name}\",\"action\":\"start\",\"id\":\"\"}"
                    return 0
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
