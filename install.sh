#!/usr/bin/env bash

# Vertex Installer Script

set -eo pipefail

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_BLUE="\033[1;34m"
COLOR_YELLOW="\033[1;33m"

echo -e "${COLOR_BLUE}Installing Vertex - Local Container Orchestration & Platform Engineering Toolkit...${COLOR_RESET}"

# Verify required system dependencies
dependencies=("docker" "jq" "curl" "tar" "flock")
missing=()

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        missing+=("$dep")
    fi
done

# Special check for docker compose vs docker-compose
if ! docker compose version &>/dev/null && ! command -v docker-compose &>/dev/null; then
    missing+=("docker-compose")
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${COLOR_YELLOW}Warning: Missing dependencies: ${missing[*]}${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Please install them to ensure full Vertex functionality.${COLOR_RESET}"
fi

# Determine source home directory
VERTEX_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create local directories
mkdir -p "${VERTEX_SRC_DIR}"/bin
mkdir -p "${VERTEX_SRC_DIR}"/commands
mkdir -p "${VERTEX_SRC_DIR}"/engine
mkdir -p "${VERTEX_SRC_DIR}"/lib
mkdir -p "${VERTEX_SRC_DIR}"/state/{desired,current,history}
mkdir -p "${VERTEX_SRC_DIR}"/runtime/{locks,pid,cache,generated,compose,proxy}
mkdir -p "${VERTEX_SRC_DIR}"/logs/{platform,applications,transactions}
mkdir -p "${VERTEX_SRC_DIR}"/backups
mkdir -p "${VERTEX_SRC_DIR}"/templates
mkdir -p "${VERTEX_SRC_DIR}"/compose
mkdir -p "${VERTEX_SRC_DIR}"/tests
mkdir -p "${VERTEX_SRC_DIR}"/docs/{architecture,adr}

# Set execute permissions
chmod +x "${VERTEX_SRC_DIR}/vrtx"

# Link CLI executable
LOCAL_BIN_DIR="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN_DIR}"
ln -sf "${VERTEX_SRC_DIR}/vrtx" "${LOCAL_BIN_DIR}/vrtx"

echo -e "${COLOR_GREEN}✔ Vertex successfully installed!${COLOR_RESET}"
echo -e "${COLOR_GREEN}Add ${LOCAL_BIN_DIR} to your PATH to run 'vrtx' globally, or execute directly via:${COLOR_RESET}"
echo -e "${COLOR_BLUE}  ${VERTEX_SRC_DIR}/vrtx version${COLOR_RESET}"
