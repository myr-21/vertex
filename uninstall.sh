#!/usr/bin/env bash

# Vertex Uninstaller Script

set -eo pipefail

COLOR_RESET="\033[0m"
COLOR_RED="\033[1;31m"
COLOR_YELLOW="\033[1;33m"

echo -e "${COLOR_RED}Uninstalling Vertex...${COLOR_RESET}"

# Remove symlinks
LOCAL_BIN_DIR="${HOME}/.local/bin"
rm -f "${LOCAL_BIN_DIR}/vrtx"

echo -e "${COLOR_YELLOW}Vertex global command symlinks removed.${COLOR_RESET}"
echo -e "${COLOR_YELLOW}Note: Project directories and application states inside the clone directory have been kept intact.${COLOR_RESET}"
echo -e "${COLOR_RED}✔ Vertex uninstalled successfully.${COLOR_RESET}"
