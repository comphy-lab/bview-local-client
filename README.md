# bview.comphy-lab.client

A self-contained, offline-capable local server for the Basilisk View client. This repository provides the same UI as `http://basilisk.ida.upmc.fr/three.js/editor/index.html` but runs entirely on your machine without requiring internet access.

## Purpose

- Run the Basilisk View client locally without internet
- Serve the client from `http://localhost:<port>/three.js/editor/index.html`
- Works with `bview2D restart --local`
- No external downloads required at runtime

## Quick Start

```bash
# Start the local server (default port 8000)
./deploy.sh

# Use with bview2D
bview2D restart --local
```

## Custom Port

```bash
# Start on a specific port
./deploy.sh 8012

# Use with bview2D on custom port
bview2D restart --local=8012
```

## Repository Structure

```
bview.comphy-lab.client/
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
