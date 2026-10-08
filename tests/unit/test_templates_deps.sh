#!/usr/bin/env bash

# Mock constants for tests
export VERTEX_HOME="$(pwd)"
mkdir -p "${VERTEX_HOME}/lib"
touch "${VERTEX_HOME}/lib/constants.sh"
touch "${VERTEX_HOME}/lib/error.sh"
touch "${VERTEX_HOME}/lib/json.sh"

source "${VERTEX_HOME}/lib/template.sh"

run_test() {
    local name="$1"
    local command="$2"
    local expected_status="$3"
    local expected_output="$4"

    echo "Running test: $name"
    local output
    output=$(eval "$command" 2>&1)
    local status=$?

    if [ "$status" -ne "$expected_status" ]; then
        echo "FAILED: expected status $expected_status, got $status"
        echo "Output was: $output"
        return 1
    fi

    if [[ "$output" != *"$expected_output"* ]]; then
        echo "FAILED: expected output containing '$expected_output'"
        echo "Output was: $output"
        return 1
    fi

    echo "PASSED"
    return 0
}

# Test 1: Python missing
(
    # Create a wrapper that hides python3
    mkdir -p /tmp/mock_bin
    cat << 'EOF' > /tmp/mock_bin/python3
#!/bin/sh
exit 127
EOF
    chmod +x /tmp/mock_bin/python3
    export PATH="/tmp/mock_bin:$PATH"
    
    # We must ensure `command -v python3` fails as well. We can mock command.
    command() {
        if [[ "$1" == "-v" && "$2" == "python3" ]]; then
            return 1
        fi
        builtin command "$@"
    }
    export -f command

    run_test "Python missing" "template_check_dependencies" 1 "Vertex template support requires Python 3"
) || exit 1

# Test 2: PyYAML missing
(
    command() {
        if [[ "$1" == "-v" && "$2" == "python3" ]]; then
            echo "/usr/bin/python3"
            return 0
        fi
        builtin command "$@"
    }
    export -f command

    python3() {
        if [[ "$1" == "-c" && "$2" == *"import yaml"* ]]; then
            return 1
        fi
        # fallback to system python3 if needed, but we shouldn't need it
        return 0
    }
    export -f python3

    run_test "PyYAML missing" "template_check_dependencies" 1 "Vertex template support requires PyYAML"
) || exit 1

echo "All dependency tests passed."
exit 0
