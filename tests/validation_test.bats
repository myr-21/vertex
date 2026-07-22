#!/usr/bin/env bats

setup() {
    source "${BATS_TEST_DIRNAME}/../lib/validation.sh"
}

@test "validate_app_name accepts valid names" {
    run validate_app_name "nginx"
    [ "$status" -eq 0 ]
    run validate_app_name "node-api"
    [ "$status" -eq 0 ]
    run validate_app_name "python-3-app"
    [ "$status" -eq 0 ]
}

@test "validate_app_name rejects invalid names" {
    run validate_app_name "Nginx"
    [ "$status" -ne 0 ]
    run validate_app_name "node_api"
    [ "$status" -ne 0 ]
    run validate_app_name "invalid@app"
    [ "$status" -ne 0 ]
}

@test "validate_port accepts correct range" {
    run validate_port 80
    [ "$status" -eq 0 ]
    run validate_port 3000
    [ "$status" -eq 0 ]
}

@test "validate_port rejects incorrect range" {
    run validate_port 0
    [ "$status" -ne 0 ]
    run validate_port 70000
    [ "$status" -ne 0 ]
    run validate_port "port"
    [ "$status" -ne 0 ]
}

@test "sanitize_input rejects injection characters" {
    run sanitize_input "safe-input"
    [ "$status" -eq 0 ]
    run sanitize_input "input; rm -rf /"
    [ "$status" -ne 0 ]
    run sanitize_input "input & other"
    [ "$status" -ne 0 ]
}
