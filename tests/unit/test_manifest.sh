#!/usr/bin/env bash
export VERTEX_HOME="$(pwd)"
source "${VERTEX_HOME}/lib/manifest.sh"
source "${VERTEX_HOME}/engine/planner.sh"

echo "Running tests..."

# Test 1: Basic manifest parse
echo "Test: parse basic stack"
res=$(manifest_parse "tests/fixtures/basic-stack.yaml")
if [[ $? -ne 0 ]]; then
    echo "Failed to parse basic-stack.yaml"
    exit 1
fi
stack_name=$(echo "$res" | jq -r '.name')
if [[ "$stack_name" != "basic-stack" ]]; then
    echo "Expected name basic-stack, got $stack_name"
    exit 1
fi

# Test 2: Dependency parsing
echo "Test: dependency stack generation"
res=$(manifest_parse "tests/fixtures/dependency-stack.yaml")
if [[ $? -ne 0 ]]; then
    echo "Failed to parse dependency-stack.yaml"
    exit 1
fi
deps=$(echo "$res" | jq -r '.services.web.depends_on[0]')
if [[ "$deps" != "database" ]]; then
    echo "Expected depends_on database, got $deps"
    exit 1
fi

# Test 3: Planner circular dep mock
echo "Test: circular dependency detection"
circ="{\"name\": \"circ-stack\", \"services\": {\"a\": {\"depends_on\": [\"b\"]}, \"b\": {\"depends_on\": [\"a\"]}}}"
res=$(planner_plan_manifest "$circ" 2>&1)
if [[ $? -eq 0 ]]; then
    echo "Expected planner to fail on circular dependency"
    exit 1
fi
if [[ "$res" != *"Circular dependency detected"* ]]; then
    echo "Expected circular dependency error message, got: $res"
    exit 1
fi

echo "All tests passed!"
exit 0
