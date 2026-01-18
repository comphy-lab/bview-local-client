#!/bin/bash
# Apply local CSS customizations after upstream sync
# This script copies files from local-patches/ to their target locations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/local-patches"

print_green() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

print_cyan() {
    printf "\033[0;36m%s\033[0m\n" "$1"
}

if [[ -d "$PATCHES_DIR" ]]; then
    print_cyan "Applying local patches from $PATCHES_DIR..."
    rsync -av "$PATCHES_DIR/" "$SCRIPT_DIR/three.js/editor/"
    print_green "Local patches applied successfully."
else
    print_cyan "No local-patches directory found. Skipping."
fi
