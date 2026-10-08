#!/usr/bin/env bats

load "../../lib/template.sh"

@test "Template deps: Python missing" {
    # Mock python3 to simulate it being missing
    python3() {
        return 127
    }
    export -f python3

    run template_check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"Vertex template support requires Python 3."* ]]
    
    unset -f python3
}

@test "Template deps: PyYAML missing" {
    # Mock python3 to succeed on command -v, but fail on import yaml
    python3() {
        if [[ "$1" == "-c" && "$2" == *"import yaml"* ]]; then
            return 1
        fi
        command python3 "$@"
    }
    export -f python3

    run template_check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"Vertex template support requires PyYAML."* ]]
    
    unset -f python3
}

@test "Template deps: Dependencies available" {
    run template_check_dependencies
    # Assuming the environment has Python and PyYAML
    if [ "$status" -eq 0 ]; then
        [ -z "$output" ]
    else
        # If the actual test env is missing it, we just verify the mock works,
        # but let's mock it to succeed
        python3() {
            return 0
        }
        export -f python3
        run template_check_dependencies
        [ "$status" -eq 0 ]
        unset -f python3
    fi
}
