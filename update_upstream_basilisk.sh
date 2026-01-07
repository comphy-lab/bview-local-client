#!/bin/bash
# Update Basilisk View client from upstream Basilisk
# This script fetches the latest Basilisk editor and syncs it to three.js/editor/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Default mode
MODE="1"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --mode=*)
            MODE="${arg#*=}"
            ;;
        --help|-h)
            echo "Usage: ./update_upstream_basilisk.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode=N    Installation mode (1-3, default=1)"
            echo "              1) darcs clone + GitHub patches"
            echo "              2) wget tarball + GitHub patches"
            echo "              3) git clone from comphy-lab fork"
            echo "  --help      Show this help message"
            exit 0
            ;;
    esac
done

print_green() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

print_cyan() {
    printf "\033[0;36m%s\033[0m\n" "$1"
}

print_red() {
    printf "\033[0;31m%s\033[0m\n" "$1"
}

# Step 1: Fresh basilisk install
print_cyan "Step 1: Fetching fresh Basilisk from upstream (mode=$MODE)..."
if [[ -f "$SCRIPT_DIR/reset_install_requirements.sh" ]]; then
    ./reset_install_requirements.sh --hard --mode="$MODE"
else
    print_red "Error: reset_install_requirements.sh not found"
    print_cyan "Manual alternative: darcs clone https://basilisk.fr/basilisk basilisk"
    exit 1
fi

# Verify basilisk directory exists after install
if [[ ! -d "$SCRIPT_DIR/basilisk/src/jview/three.js/editor" ]]; then
    print_red "Error: Basilisk editor directory not found after install"
    exit 1
fi

# Step 2: Re-apply overlay
print_cyan "Step 2: Syncing Basilisk editor to three.js/editor/..."
rsync -a "$SCRIPT_DIR/basilisk/src/jview/three.js/editor/" "$SCRIPT_DIR/three.js/editor/"

print_green "Sync complete!"
echo ""

# Step 3: Show what changed
print_cyan "Step 3: Changes in three.js/editor/:"
git status three.js/editor/ 2>/dev/null || echo "(Not a git repository)"
echo ""
print_cyan "To commit these changes:"
echo "  git add three.js/editor"
echo "  git commit -m 'Sync with upstream Basilisk editor'"
