# Repeatable Web export and secure hosting

## What this workflow provides

- A committed `export_presets.cfg` Web preset.
- A local export script for Linux/macOS (`scripts/export_web.sh`) and Windows (`scripts/export_web.bat`).
- A GitHub Actions workflow that exports with Godot 4.7 and publishes the generated static site to GitHub Pages.
- A sample Caddy reverse-proxy configuration for a separate secure WebSocket endpoint.

## One-time setup

1. Put this project in a GitHub repository. Commit the project folder and `.github/workflows/deploy-pages.yml` at the repository root (the workflow assumes this project remains in `secret_council_godot/`).
2. In GitHub, open **Settings → Pages** and select **GitHub Actions** as the build/deployment source.
3. Confirm the repository's default branch is `main`, or edit the workflow branch filter.
4. Run **Actions → Export and deploy Godot Web build → Run workflow**, or push a change under `secret_council_godot/`.
5. Open the Pages URL shown in the deployment job. Players use that HTTPS site to load the client.

## Local export

Install Godot 4.7 and its matching Web export templates first.

Linux/macOS:
```sh
cd secret_council_godot
./scripts/export_web.sh
```

Windows Command Prompt:
```bat
cd secret_council_godot
scripts\export_web.bat
```

Optional environment variables:
- `GODOT_BIN`: path/name of the Godot executable (defaults to `godot`).
- `WEB_OUT_DIR`: output directory (defaults to `build/web`).

The scripts fail if Godot is missing or expected export output is absent. Godot patch releases can change generated artifact names; if the script's file checks fail, inspect `build/web` and adjust the checks to match the output from your installed 4.7 template. The GitHub Actions workflow also verifies that the export generated an index and several files.

## Two separate public endpoints

**Static website (HTTPS):** GitHub Pages serves the exported browser client. It does not run your game server.

**Live game server (WSS):** The laptop must separately run the native Godot project with WebSocket selected. Players need a public secure WebSocket URL, e.g. `wss://play.example.com`. Route that hostname to the laptop's WebSocket listener with a secure tunnel or reverse proxy. `deploy/Caddyfile.example` illustrates the reverse-proxy shape; it is not a substitute for DNS, firewall, tunnel, and origin setup.

Do not put the game server on a public interface without considering abuse. This prototype currently has no login, room password, rate limiting, or hardened authentication. TLS encrypts traffic in transit but does **not** authenticate players or make the game logic secure against malicious clients. Share game links privately, keep the laptop patched, and stop the listener/tunnel after the session. For public use, add server-side room codes, authenticated join tokens, connection limits, action rate limits, and reconnect-safe seat ownership.

## Validation checklist

- [ ] `godot --headless --editor --path . --quit` completes.
- [ ] `./scripts/export_web.sh` completes with installed Godot 4.7 export templates.
- [ ] The entire `build/web` folder is published and opens at the Pages HTTPS URL.
- [ ] A phone loads the page and connects to the separately configured `wss://` endpoint.
- [ ] Verify mobile Safari and Chrome, portrait layout, refresh/reconnect, voting, private roles, and network loss.
- [ ] Verify GitHub Actions run and Pages deployment succeed.

## What has been tested in this delivered source

Static checks and archive creation can be performed without the Godot engine. A real Web export, CI action, Pages deployment, TLS certificate, tunnel, and mobile-browser session must be tested in the user's environment; this workspace does not have the Godot executable or the user's DNS/repository credentials.
