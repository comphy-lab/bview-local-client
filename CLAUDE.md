# CLAUDE.md

## Project Overview

This is the **Basilisk View local client** repository. It provides a self-contained, offline-capable server for the Basilisk View 3D visualization interface.

## Key Architecture

- **three.js r124**: Base 3D library - DO NOT upgrade without matching Basilisk editor updates
- **Basilisk editor overlay**: Custom editor from `basilisk/src/jview/three.js/editor/` replaces stock three.js editor
- **Server root must be repo root**: The path `/three.js/editor/index.html` must resolve correctly

## Critical Files

- `deploy.sh` - Local server launcher (Python HTTP server)
- `three.js/` - Full three.js r124 tree with Basilisk modifications
- `three.js/editor/` - Basilisk's custom editor (the overlay)

## Development Notes

### DO NOT
- Upgrade three.js beyond r124 (breaks Basilisk compatibility)
- Modify the server root path (URL paths depend on it)
- Commit the `basilisk/` folder (it's gitignored for local reference only)

### Testing Changes
```bash
./deploy.sh
# Open http://localhost:8000/three.js/editor/index.html
# Run a bview2D simulation to verify connection
```

### Rebuilding the three.js Tree
If you need to rebuild from scratch:
```bash
# Clone three.js r124
git clone https://github.com/mrdoob/three.js.git
cd three.js && git checkout r124 && cd ..

# Overlay Basilisk editor
rsync -a --delete basilisk/src/jview/three.js/editor/ three.js/editor/
```

## Related Projects

- Basilisk: https://basilisk.fr
- three.js: https://github.com/mrdoob/three.js
