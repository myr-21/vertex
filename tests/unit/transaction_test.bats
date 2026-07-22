#!/usr/bin/env bats

setup() {
    export VERTEX_HOME="${BATS_TEST_DIRNAME}/../.."
    source "${VERTEX_HOME}/lib/transaction.sh"
    
    # Use temporary state and runtime dirs
    export VERTEX_RUNTIME_DIR=$(mktemp -d)
    mkdir -p "${VERTEX_RUNTIME_DIR}"/locks
}

teardown() {
    rm -rf "$VERTEX_RUNTIME_DIR"
}

@test "transaction_begin creates transaction file" {
    run transaction_begin "tx-123"
    [ "$status" -eq 0 ]
    [ -f "${VERTEX_RUNTIME_DIR}/locks/tx-123.tx" ]
}

@test "transaction_push records rollback steps LIFO" {
    transaction_begin "tx-123"
    transaction_push "delete_network" "net1"
    transaction_push "delete_container" "con1"
    
    run cat "${VERTEX_RUNTIME_DIR}/locks/tx-123.tx"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "delete_container con1" ]
    [ "${lines[1]}" = "delete_network net1" ]
}
