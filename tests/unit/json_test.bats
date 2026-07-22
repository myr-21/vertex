#!/usr/bin/env bats

setup() {
    export VERTEX_HOME="${BATS_TEST_DIRNAME}/../.."
    source "${VERTEX_HOME}/lib/json.sh"
    tmp_json=$(mktemp)
    echo '{"name": "test-app", "version": 1}' > "$tmp_json"
}

teardown() {
    rm -f "$tmp_json"
}

@test "json_validate verifies valid JSON" {
    run json_validate "$tmp_json"
    [ "$status" -eq 0 ]
}

@test "json_get retrieves simple values" {
    run json_get "$tmp_json" ".name"
    [ "$status" -eq 0 ]
    [ "$output" = "test-app" ]
}

@test "json_set updates values" {
    run json_set "$tmp_json" ".version" "2"
    [ "$status" -eq 0 ]
    run json_get "$tmp_json" ".version"
    [ "$output" = "2" ]
}

@test "json_delete removes properties" {
    run json_delete "$tmp_json" ".name"
    [ "$status" -eq 0 ]
    run json_exists "$tmp_json" ".name"
    [ "$status" -ne 0 ]
}
