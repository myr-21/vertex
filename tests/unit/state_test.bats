#!/usr/bin/env bats

setup() {
    export VERTEX_HOME="${BATS_TEST_DIRNAME}/../.."
    source "${VERTEX_HOME}/lib/state.sh"
    
    # Use temporary state dirs
    export VERTEX_STATE_DIR=$(mktemp -d)
    mkdir -p "${VERTEX_STATE_DIR}"/{current,desired,history}
    export VERTEX_REGISTRY_FILE="${VERTEX_STATE_DIR}/registry.json"
}

teardown() {
    rm -rf "$VERTEX_STATE_DIR"
}

@test "state_create_app registers desired and current configurations" {
    local schema='{"name":"app","image":"nginx"}'
    run state_create_app "app" "$schema"
    [ "$status" -eq 0 ]
    [ -f "${VERTEX_STATE_DIR}/desired/app.json" ]
    [ -f "${VERTEX_STATE_DIR}/current/app.json" ]
}

@test "state_app_exists verifies presence of app" {
    run state_app_exists "app"
    [ "$status" -ne 0 ]

    local schema='{"name":"app","image":"nginx"}'
    state_create_app "app" "$schema"
    run state_app_exists "app"
    [ "$status" -eq 0 ]
}
