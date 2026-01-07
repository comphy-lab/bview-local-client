#!/bin/bash
# Basilisk View local client server
# Serves the three.js editor at http://localhost:<port>/three.js/editor/index.html

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse arguments
PORT="8000"
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo "Usage: ./deploy.sh [PORT]"
            echo ""
            echo "Start the Basilisk View local client server."
            echo ""
            echo "Arguments:"
            echo "  PORT    Port number to serve on (default: 8000)"
            echo ""
            echo "Examples:"
            echo "  ./deploy.sh          # Serve on port 8000"
            echo "  ./deploy.sh 8012     # Serve on port 8012"
            exit 0
            ;;
        *)
            PORT="$arg"
            ;;
    esac
done

# Validate port is a number
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid port '$PORT'. Port must be a number."
    exit 1
fi

# Check if a tool is available
check_tool() {
    command -v "$1" > /dev/null 2>&1
}

# Check if port is in use (with fallbacks for minimal environments)
check_port() {
    local port="$1"

    # Try lsof first (macOS, most Linux)
    if check_tool lsof; then
        if lsof -i :"$port" >/dev/null 2>&1; then
            return 1  # Port is in use
        fi
        return 0  # Port is free
    fi

    # Fallback: ss (modern Linux)
    if check_tool ss; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
        return 0
    fi

    # Fallback: netstat (older systems)
    if check_tool netstat; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
        return 0
    fi

    # No port-checking tool available - warn and assume free
    echo "Warning: No port-checking tool found (lsof, ss, netstat)."
    echo "Cannot verify if port $port is available."
    return 0
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
