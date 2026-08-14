#!/bin/bash
# Deploy the Basilisk View client as a long-running local service.
#
# This is NOT deploy.sh. deploy.sh starts a throwaway foreground server from a
# working checkout, for local use. This script publishes an immutable export to
# a fixed location and restarts a systemd user unit, so the served tree cannot
# change under a branch switch, a rebase, or a workspace being re-materialised.
#
# The export is produced with `git archive`, so it contains only tracked files
# at the chosen ref and carries no .git directory.
#
# Typical usage:
#   ./deploy-server.sh                  # deploy current HEAD
#   ./deploy-server.sh --ref=v1.2.0     # deploy a tag
#   ./deploy-server.sh --fetch          # fetch origin first, deploy origin/main
#   ./deploy-server.sh --dry-run
#
# Exposure is handled separately and deliberately: the service binds 127.0.0.1
# only, and is published to the tailnet by
#   tailscale serve --bg --https=443 --set-path=/ http://127.0.0.1:8000
# There is no path by which this server is reachable from a public network.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="${BVIEW_DEPLOY_DIR:-$HOME/.local/share/bview-client}"
UNIT="bview-client.service"
REF="HEAD"
DO_FETCH=false
DRY_RUN=false

print_green() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_cyan()  { printf "\033[0;36m%s\033[0m\n" "$1"; }
print_red()   { printf "\033[0;31m%s\033[0m\n" "$1"; }

for arg in "$@"; do
    case "$arg" in
        --ref=*)   REF="${arg#*=}" ;;
        --fetch)   DO_FETCH=true; REF="origin/main" ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            # Header comment block only; it ends at line 21.
            sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            print_red "Unknown argument: $arg"
            echo "Try --help."
            exit 1
            ;;
    esac
done

cd "$SCRIPT_DIR"

if [[ ! -d .git ]]; then
    print_red "Error: $SCRIPT_DIR is not a git repository."
    print_red "This script exports from git; it cannot deploy a plain directory."
    exit 1
fi

if [[ "$DO_FETCH" == true ]]; then
    print_cyan "Fetching origin..."
    git fetch --quiet origin
fi

if ! COMMIT=$(git rev-parse --verify --quiet "${REF}^{commit}"); then
    print_red "Error: '$REF' does not resolve to a commit."
    exit 1
fi

SHORT=$(git rev-parse --short "$COMMIT")
SUBJECT=$(git log -1 --pretty=%s "$COMMIT")

print_cyan "Deploying $SHORT — $SUBJECT"
echo "  ref:    $REF"
echo "  commit: $COMMIT"
echo "  target: $DEPLOY_DIR"

if [[ -f "$DEPLOY_DIR/.deployed-ref" ]]; then
    CURRENT=$(cat "$DEPLOY_DIR/.deployed-ref")
    if [[ "$CURRENT" == "$COMMIT" ]]; then
        print_green "Already deployed at this commit. Nothing to do."
        exit 0
    fi
    echo "  current: $(git rev-parse --short "$CURRENT" 2>/dev/null || echo "$CURRENT")"
fi

if [[ "$DRY_RUN" == true ]]; then
    print_cyan "Dry run — no changes made."
    exit 0
fi

# Export to a staging directory, then swap. A partially extracted tree is never
# served: the running server keeps using the old directory until the rename.
STAGING="${DEPLOY_DIR}.new"
PREVIOUS="${DEPLOY_DIR}.old"

cleanup_staging() { rm -rf "$STAGING"; }
trap cleanup_staging EXIT

print_cyan "Exporting tracked tree (git archive)..."
rm -rf "$STAGING"
mkdir -p "$STAGING"
git archive "$COMMIT" | tar -x -C "$STAGING"

# Fail closed rather than publish a broken tree.
for required in \
    three.js/editor/index.html \
    three.js/build/three.module.js \
    three.js/editor/js/BasiliskBufferGeometry.js
do
    if [[ ! -f "$STAGING/$required" ]]; then
        print_red "Error: export is missing $required — refusing to deploy."
        exit 1
    fi
done

if [[ -e "$STAGING/.git" ]]; then
    print_red "Error: export unexpectedly contains .git — refusing to deploy."
    exit 1
fi

echo "$COMMIT" > "$STAGING/.deployed-ref"

print_cyan "Swapping into place..."
rm -rf "$PREVIOUS"
[[ -d "$DEPLOY_DIR" ]] && mv "$DEPLOY_DIR" "$PREVIOUS"
mv "$STAGING" "$DEPLOY_DIR"
trap - EXIT

# The previous tree is deliberately retained until the service is confirmed
# healthy, so a failed restart leaves something to roll back to.
if systemctl --user list-unit-files "$UNIT" >/dev/null 2>&1 && \
   systemctl --user is-enabled "$UNIT" >/dev/null 2>&1; then
    print_cyan "Restarting $UNIT..."
    systemctl --user restart "$UNIT"
    sleep 1
    if systemctl --user is-active --quiet "$UNIT"; then
        print_green "Service is active."
    else
        print_red "Warning: $UNIT is not active after restart."
        systemctl --user status "$UNIT" --no-pager | head -12
        if [[ -d "$PREVIOUS" ]]; then
            print_red "Previous tree retained at $PREVIOUS"
            print_red "Roll back with:"
            print_red "  rm -rf '$DEPLOY_DIR' && mv '$PREVIOUS' '$DEPLOY_DIR' && systemctl --user restart $UNIT"
        fi
        exit 1
    fi
else
    echo ""
    print_cyan "No enabled $UNIT found; the tree is deployed but nothing serves it."
    echo "To install the unit, see docs/server-deployment.md."
fi

rm -rf "$PREVIOUS"

echo ""
print_green "Deployed $SHORT to $DEPLOY_DIR"
echo "  Size: $(du -sh "$DEPLOY_DIR" | cut -f1)"
