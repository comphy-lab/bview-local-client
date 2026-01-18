#!/bin/bash
# Update Basilisk View client from upstream Basilisk
# This script fetches the version-locked Basilisk editor and syncs it to three.js/editor/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Version-locked Basilisk reference
BASILISK_REF="v2026-01-13"

print_green() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

print_cyan() {
    printf "\033[0;36m%s\033[0m\n" "$1"
}

print_red() {
    printf "\033[0;31m%s\033[0m\n" "$1"
}

# Step 1: Fresh basilisk install using version-locked reference
print_cyan "Step 1: Fetching Basilisk ($BASILISK_REF) from comphy-lab/basilisk-C..."
curl -sL https://raw.githubusercontent.com/comphy-lab/basilisk-C/main/reset_install_basilisk-ref-locked.sh | bash -s -- --ref="$BASILISK_REF" --hard

# Verify basilisk directory exists after install
if [[ ! -d "$SCRIPT_DIR/basilisk/src/jview/three.js/editor" ]]; then
    print_red "Error: Basilisk editor directory not found after install"
    exit 1
fi

# Step 2: Sync Basilisk editor overlay
print_cyan "Step 2: Syncing Basilisk editor to three.js/editor/..."
rsync -a "$SCRIPT_DIR/basilisk/src/jview/three.js/editor/" "$SCRIPT_DIR/three.js/editor/"

print_green "Sync complete!"
echo ""

# Step 3: Re-apply local patches (CSS customizations, etc.)
if [[ -f "$SCRIPT_DIR/apply_local_patches.sh" ]]; then
    print_cyan "Step 3: Re-applying local patches..."
    "$SCRIPT_DIR/apply_local_patches.sh"
else
    print_cyan "Step 3: No local patches script found. Skipping."
fi
echo ""

# Step 4: Show what changed
print_cyan "Step 4: Changes in three.js/editor/:"
git status three.js/editor/ 2>/dev/null || echo "(Not a git repository)"
echo ""
print_cyan "To commit these changes:"
echo "  git add three.js/editor"
echo "  git commit -m 'Sync with upstream Basilisk editor ($BASILISK_REF)'"
