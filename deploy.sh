#!/bin/bash
# Basilisk View local client server
# Serves the three.js editor at http://localhost:<port>/three.js/editor/index.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-8000}"

# Check if port is in use
check_port() {
    local port="$1"
    if lsof -i :"$port" >/dev/null 2>&1; then
        return 1  # Port is in use
    fi
    return 0  # Port is free
}

# Find next available port
find_free_port() {
    local port="$1"
    local max_attempts=10
    for ((i=0; i<max_attempts; i++)); do
        if check_port "$port"; then
            echo "$port"
            return 0
        fi
        ((port++))
    done
    return 1
}

# Verify three.js directory exists
if [[ ! -d "$SCRIPT_DIR/three.js/editor" ]]; then
    echo "Error: three.js/editor directory not found."
    echo "Please ensure the repository is properly set up."
    exit 1
fi

# Check port availability
if ! check_port "$PORT"; then
    echo "Port $PORT is already in use."
    FREE_PORT=$(find_free_port "$((PORT + 1))" 2>/dev/null || echo "")
    if [[ -n "$FREE_PORT" ]]; then
        echo "Suggested alternative: ./deploy.sh $FREE_PORT"
    fi
    exit 1
fi

# Print URL
echo ""
echo "Starting Basilisk View local client..."
echo ""
echo "  URL: http://localhost:${PORT}/three.js/editor/index.html"
echo ""
echo "Press Ctrl+C to stop the server."
echo ""

# Start Python HTTP server from repo root
cd "$SCRIPT_DIR"
python3 -m http.server "$PORT"
