# Running the client as a service

`deploy.sh` starts a throwaway foreground server and is right for occasional
local use. This document covers the other case: a machine that should serve the
client continuously, so a URL can be bookmarked and shared with your own
devices.

## The one thing to understand first

Basilisk View uses two independent channels, and most deployment confusion comes
from conflating them.

| | Serves | Lifetime | Where it lives |
|---|---|---|---|
| **HTTP** | the client — static JavaScript, HTML, CSS | fetched once, then idle | this repository |
| **WebSocket** | the data — live geometry from a solver | the length of a session | inside `bview*` or a `-DDISPLAY` run |

The HTTP side knows nothing about your simulation. The WebSocket side never
touches the file server. Replacing the public client with this one changes only
the first; the second is, and always was, wherever your solver runs.

## Deploying the client

`deploy-server.sh` publishes an immutable export rather than serving the working
checkout, so the served tree cannot change under a branch switch, a rebase, or
the directory being removed and recreated.

```bash
git clone https://github.com/comphy-lab/bview-local-client.git
cd bview-local-client
./deploy-server.sh                # deploy HEAD to ~/.local/share/bview-client
./deploy-server.sh --fetch        # fetch origin, deploy origin/main
./deploy-server.sh --ref=v1.2.0   # deploy a tag
./deploy-server.sh --dry-run
```

The export is produced with `git archive`, so it contains only tracked files and
no `.git` directory. Set `BVIEW_DEPLOY_DIR` to deploy elsewhere.

Then install the unit:

```bash
mkdir -p ~/.config/systemd/user
sed "s|@DEPLOY_DIR@|$HOME/.local/share/bview-client|" \
    deploy/bview-client.service > ~/.config/systemd/user/bview-client.service
systemctl --user daemon-reload
systemctl --user enable --now bview-client.service
sudo loginctl enable-linger "$USER"     # so it starts at boot without a login
```

`deploy-server.sh` restarts the unit and verifies the new tree is actually being
served — by fetching `.deployed-ref` and checking it matches the deployed commit
— before discarding the previous tree. A failed deployment leaves the old tree
in place with a rollback command printed.

## Exposing it

The unit binds `127.0.0.1` only. That is deliberate and should stay that way:
the server has no authentication, and neither does the WebSocket protocol on the
other side.

**Same machine.** Nothing further to do. Open
`http://localhost:8000/three.js/editor/index.html` and append the `?ws://...`
suffix your solver prints.

**Your own devices, over a private overlay network.** A WireGuard-style overlay
with per-device identity is the least effort for the most safety. Publish the
static client over HTTPS, and the solver port as a *TLS-terminated TCP forward*.

> **The static client and the solver port need different treatment.** An HTTP
> reverse proxy works for the client, because that is a real HTTP server. It
> does **not** work for the solver: Basilisk's `wsServer` is a raw socket
> handler that speaks only enough HTTP to complete a WebSocket handshake, so an
> HTTP-aware proxy rejects it before the upgrade and returns **502**. Forward
> raw TCP with TLS terminated in front of it instead.
>
> If you see a 502 on the WebSocket but the client itself loads, this is why.

**Over the public internet.** Don't, without an authenticating proxy in front of
both. See the security note below.

## Pointing solvers at your client

Stock `bview2D`/`bview3D` have the upstream client URL compiled in. Two options:

1. Ignore the printed host and paste the `?ws://...` suffix onto your own client
   URL by hand.
2. Build Basilisk with the `--comphy-bview` flag from
   [comphy-lab/basilisk-C](https://github.com/comphy-lab/basilisk-C), which adds
   `bview-comphy2D` and `bview-comphy3D`. These bind loopback by default and
   read both halves of the URL from the environment:

   ```bash
   export BVIEW_CLIENT_URL='https://example.internal/three.js/editor/index.html'
   export BVIEW_WS_TEMPLATE='wss://example.internal:{port}'
   bview-comphy2D dump
   ```

   `{port}` expands to the port the server actually bound, which it chooses by
   scanning `DISPLAY_RANGE` — it is not told which to use. That form is only
   correct when the proxy preserves the port; write the external port literally
   otherwise. `BVIEW_BIND_HOST` overrides the bind address if you genuinely need
   to listen more widely.

## Security note

The WebSocket protocol carries no authentication. `display_onmessage()` passes
client text to `process_line()`, which interprets drawing commands inside the
running process — including `save()`, which reaches `open_image()` and builds a
`popen()` command string from the filename. **Anyone who can reach a bview port
can therefore run commands as the user running the solver.**

Upstream's documentation assumes an SSH tunnel, which implies a loopback
listener, but stock builds bind every interface and do not enforce it.

Practical consequences:

- Keep the client server on loopback and reach it through a proxy or overlay
  network, never by binding it to a public interface.
- Prefer `bview-comphy*` builds, which bind loopback by default.
- With a stock build, firewall the `DISPLAY_RANGE` ports (typically 7100–7200)
  or tunnel to them over SSH.

## Updating

```bash
./update_upstream_basilisk.sh   # resync the editor from a pinned Basilisk ref
./deploy-server.sh --fetch      # publish it
```

`update_upstream_basilisk.sh` reapplies `local-patches/` after the resync, so
local styling survives an upstream update.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Blank page | Server root is not the repository root. The editor reaches up into `../build/` and `../../examples/jsm/`. |
| Client loads, WebSocket 502 | An HTTP proxy is in front of the solver port. Use TLS-terminated raw TCP. |
| Client loads, nothing renders | No solver on the `?ws://` endpoint, or the wrong port — bview picks its own from `DISPLAY_RANGE`. |
| Printed URL has an unreachable host | `display_url()` uses `gethostbyname()`, which often returns something unroutable. Replace the host; keep the port. |
| Long stall after each sidebar change | Older clients serialised every vertex attribute on autosave. Update, or untick autosave. |
