#!/usr/bin/env bats

setup() {
    export VERTEX_HOME="${BATS_TEST_DIRNAME}/../.."
    source "${VERTEX_HOME}/lib/constants.sh"
    source "${VERTEX_HOME}/lib/state.sh"
}

@test "deploy workflow succeeds and registers application" {
    # Clean previous states
    rm -f "${VERTEX_STATE_DIR}/current/nginx-test.json"
    rm -f "${VERTEX_STATE_DIR}/desired/nginx-test.json"

    run bash "${VERTEX_HOME}/vrtx" deploy nginx-test
    [ "$status" -eq 0 ]
    [ -f "${VERTEX_STATE_DIR}/current/nginx-test.json" ]
}

@test "destroy workflow cleans configuration" {
    run bash "${VERTEX_HOME}/vrtx" destroy nginx-test
    [ "$status" -eq 0 ]
    [ ! -f "${VERTEX_STATE_DIR}/current/nginx-test.json" ]
}
