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
# Environment:
#   BVIEW_DEPLOY_DIR   deploy target (default ~/.local/share/bview-client)
#   BVIEW_HEALTH_URL   post-restart health check; set empty to skip
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
print_yellow(){ printf "\033[0;33m%s\033[0m\n" "$1"; }

# systemd reporting the unit as active does not prove the new tree is being
# served: the process can be up while the document root points somewhere else.
# Set BVIEW_HEALTH_URL to an empty string to skip the check entirely; leaving it
# unset uses the default below.
HEALTH_URL="${BVIEW_HEALTH_URL-http://127.0.0.1:8000/three.js/editor/index.html}"

deployment_is_serving() {
    [[ -z "$HEALTH_URL" ]] && return 0

    if ! command -v curl >/dev/null 2>&1; then
        print_red "Health check requested but curl is unavailable."
        print_red "Install curl, or set BVIEW_HEALTH_URL='' to skip the check deliberately."
        return 1
    fi

    # A 200 alone does not prove the response came from $DEPLOY_DIR. The tree
    # carries .deployed-ref, so fetch it from the same origin and require it to
    # match the commit just deployed.
    local ref_url="${HEALTH_URL%/three.js/*}/.deployed-ref"
    local code served attempts=10
    while (( attempts-- > 0 )); do
        code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$HEALTH_URL" 2>/dev/null || echo 000)"
        if [[ "$code" == "200" ]]; then
            served="$(curl -s --max-time 3 "$ref_url" 2>/dev/null | tr -d '[:space:]' || true)"
            if [[ "$served" == "$COMMIT" ]]; then
                return 0
            fi
            print_red "Served tree reports commit '${served:-<none>}', expected '$COMMIT'."
            print_red "The unit is probably serving a different directory than $DEPLOY_DIR."
            return 1
        fi
        sleep 1
    done
    print_red "Health check failed: $HEALTH_URL returned $code"
    return 1
}

for arg in "$@"; do
    case "$arg" in
        --ref=*)   REF="${arg#*=}" ;;
        --fetch)   DO_FETCH=true; REF="origin/main" ;;
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            # Header comment block only; it ends at line 25.
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
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
    if [[ "$DRY_RUN" == true ]]; then
        print_cyan "Dry run: skipping fetch (would fetch origin)."
    else
        print_cyan "Fetching origin..."
        git fetch --quiet origin
    fi
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
LOCKDIR="${DEPLOY_DIR}.lock"

# $STAGING and $PREVIOUS are fixed paths, so two concurrent deployments would
# move and delete each other's trees and destroy the rollback copy. mkdir is
# atomic on every POSIX filesystem, so this needs no external tool and there is
# no path where the lock is merely advisory.
mkdir -p "$(dirname "$LOCKDIR")"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    holder="$(cat "$LOCKDIR/pid" 2>/dev/null || true)"
    if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
        print_red "Error: deployment already in progress (pid $holder, lock $LOCKDIR)."
    else
        # Deliberately not reclaimed automatically. Two invocations that both
        # judged the lock stale would each remove it and could delete the
        # other's freshly created lock, which is the exact race the lock
        # exists to prevent. A stale lock only survives SIGKILL or a reboot
        # mid-deploy, so it is rare and worth a human look.
        print_red "Error: stale lock at $LOCKDIR (holder pid ${holder:-unknown} is gone)."
        print_red "No deployment is running. Confirm that, then remove it:"
        print_red "  rm -rf '$LOCKDIR'"
    fi
    exit 1
fi
echo "$$" > "$LOCKDIR/pid"
release_lock() { rm -rf "$LOCKDIR"; }

cleanup_staging() { rm -rf "$STAGING"; release_lock; }
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
trap release_lock EXIT

# The previous tree is deliberately retained until the service is confirmed
# healthy, so a failed restart leaves something to roll back to.
if systemctl --user list-unit-files "$UNIT" >/dev/null 2>&1 && \
   systemctl --user is-enabled "$UNIT" >/dev/null 2>&1; then
    print_cyan "Restarting $UNIT..."
    # Guarded: under `set -e` a failed restart would exit here and the
    # rollback advice below would never be printed.
    restart_rc=0
    systemctl --user restart "$UNIT" || restart_rc=$?
    sleep 1
    if [[ $restart_rc -eq 0 ]] && systemctl --user is-active --quiet "$UNIT" \
       && deployment_is_serving; then
        print_green "Service is active and serving the new tree."
    else
        print_red "Warning: $UNIT did not come up healthy after restart."
        systemctl --user status "$UNIT" --no-pager 2>&1 | head -12 || true
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
