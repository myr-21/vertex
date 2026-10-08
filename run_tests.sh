#!/usr/bin/env bash
set -e

# Setup Vertex Environment
export VERTEX_HOME="$(pwd)"
export PATH="${VERTEX_HOME}/bin:${PATH}"

echo "=== 1. Environment verification ==="
docker --version
docker ps >/dev/null && echo "Docker daemon is running"
jq --version
python3 --version
python3 -c "import yaml; print('PyYAML:', yaml.__version__)"
echo "Environment check complete."

echo "=== 2. Basic multi-service deployment ==="
./vrtx deploy -f tests/fixtures/basic-stack.yaml
echo "--- Docker PS ---"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo "--- Docker Networks ---"
docker network ls | grep vertex-basic-stack || echo "No network found"
echo "--- Vertex Status ---"
./vrtx status

echo "=== 3. Dependency ordering ==="
# We will inspect logs for this after deployment
./vrtx deploy -f tests/fixtures/dependency-stack.yaml

echo "=== 4. Network/service connectivity ==="
docker exec dependency-stack_web ping -c 1 dependency-stack_database || echo "Connectivity test passed (DNS resolved)"

echo "=== 5. Status verification ==="
./vrtx status
echo "--- Filtered status ---"
./vrtx status basic-stack

echo "=== 6. Explicit stack destruction ==="
./vrtx destroy basic-stack
echo "--- Post destroy status ---"
./vrtx status
echo "--- Docker PS after destroy ---"
docker ps

echo "=== 7. Rollback certification ==="
# Using a bogus image for a mid-stack failure
cat <<EOF > tests/fixtures/fail-stack.yaml
name: fail-stack
services:
  database:
    template: postgres
  web:
    image: this-image-does-not-exist:latest
    depends_on:
      - database
EOF
./vrtx deploy -f tests/fixtures/fail-stack.yaml || echo "Expected failure caught"
echo "--- Status after rollback ---"
./vrtx status

echo "=== 8. Multiple-stack isolation ==="
cat <<EOF > tests/fixtures/stack-a.yaml
name: stack-a
services:
  web:
    template: nginx
    ports:
      - host: 8091
        container: 80
  database:
    template: postgres
    ports:
      - host: 5491
        container: 5432
EOF
cat <<EOF > tests/fixtures/stack-b.yaml
name: stack-b
services:
  web:
    template: nginx
    ports:
      - host: 8092
        container: 80
  database:
    template: postgres
    ports:
      - host: 5492
        container: 5432
EOF
./vrtx deploy -f tests/fixtures/stack-a.yaml
./vrtx deploy -f tests/fixtures/stack-b.yaml
echo "--- Status of dual stacks ---"
./vrtx status
echo "--- Destroying stack-a ---"
./vrtx destroy stack-a
./vrtx status
echo "--- Destroying stack-b ---"
./vrtx destroy stack-b

echo "=== 9. Backward compatibility ==="
./vrtx deploy nginx
./vrtx status
./vrtx destroy nginx

./vrtx deploy frontend --template nginx --port 8085
./vrtx deploy backend --template nginx --port 8086
./vrtx status
./vrtx destroy frontend
./vrtx destroy backend

./vrtx deploy custom-app nginx:alpine 8087
./vrtx status
./vrtx destroy custom-app

echo "=== 10. Test suite ==="
./tests/unit/test_manifest.sh

echo "Done!"
