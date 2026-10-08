#!/usr/bin/env bash
set -e
echo "Checking Environment..."
docker --version
docker ps >/dev/null && echo "Docker daemon is running."
jq --version
python3 --version
python3 -c 'import yaml; print("PyYAML:", yaml.__version__)'
echo "Environment check complete."
