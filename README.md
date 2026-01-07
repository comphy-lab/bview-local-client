# Basilisk View Local Client

A self-contained, offline-capable local server for the [Basilisk View](http://basilisk.fr/src/jview/README) 3D visualization interface.

## Why Use a Local Client?

When running Basilisk simulations with `bview2D`, you need a JavaScript client to visualize the 3D output. By default, `bview2D` connects to the remote client at `basilisk.ida.upmc.fr`. This local client provides an alternative that:

- **Works offline** - No internet required after cloning
- **Faster loading** - Assets served locally, no network latency
- **Always available** - Independent of remote server uptime
- **Consistent version** - Pinned to three.js r124, matching Basilisk's requirements

## Installation

```bash
git clone https://github.com/comphy-lab/bview-local-client.git
cd bview-local-client
```

## Usage

### Start the Local Server

```bash
./deploy.sh
```

This starts a local HTTP server and displays the URL:
```bash
Starting Basilisk View local client...

  URL: http://localhost:8000/three.js/editor/index.html

Press Ctrl+C to stop the server.
```

### Connect Your Simulation

In a separate terminal, run your Basilisk simulation with `--local`:

```bash
bview2D restart --local
```

The simulation will connect to your local client instead of the remote server.

### Custom Port

If port 8000 is in use, specify a different port:

```bash
./deploy.sh 8012
bview2D restart --local=8012
```

### Help

```bash
./deploy.sh --help
```

> **Note: Network Access**
> The server binds to all interfaces, so you can access it from other devices on the same network using your machine's IP address (e.g., `http://192.168.1.100:8000/three.js/editor/index.html`). This also works over Tailscale or other VPNs using the appropriate IP.

## Repository Structure

```text
bview-local-client/
  three.js/                      # Full three.js r124 tree with Basilisk editor overlay
    build/
    editor/                      # Basilisk's modified editor
    examples/
    files/
    ...
  deploy.sh                      # Start local server
  update_upstream_basilisk.sh    # Sync with upstream Basilisk
  README.md                      # This file
  basilisk/                      # (gitignored) Local Basilisk clone for updates
```

## Updating from Upstream

When Basilisk upstream updates their editor:

```bash
./update_upstream_basilisk.sh
```

This fetches fresh Basilisk and syncs the editor files to `three.js/editor/`.

## Requirements

- Python 3 (for the HTTP server)
- A running Basilisk simulation using `bview2D`

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Blank page | Missing assets | Verify `three.js/` contains the full r124 tree |
| 404 errors in console | Wrong server root | Ensure `deploy.sh` runs from repo root |
| Page won't load via `file://` | Browser security | Must serve over HTTP, use `./deploy.sh` |
| Port in use | Another process | Try `./deploy.sh 8012` with a different port |

## Technical Details

This repository combines:
1. **three.js r124**: The base 3D library version that Basilisk's client was built against
2. **Basilisk editor overlay**: Custom modifications from `basilisk/src/jview/three.js/editor/`

The editor must be served at the path `/three.js/editor/index.html` to maintain compatibility with `bview2D`.

## License

This repository contains:
- three.js (MIT License) - https://github.com/mrdoob/three.js
- Basilisk View modifications (GPL) - https://basilisk.fr
