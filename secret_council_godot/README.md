# Secret Council Online — Godot 4.7

A multiplayer hidden-role policy game prototype. The host is authoritative for game state and validates actions before applying them. **WebSocket transport is included for browser/mobile clients; ENet remains available for desktop-only play.** See [`WEB_MOBILE_GUIDE.md`](WEB_MOBILE_GUIDE.md) for the laptop-host + mobile-browser workflow.

## Quick desktop test
1. Extract the ZIP and open `project.godot` in Godot 4.7.
2. Run the project in multiple instances.
3. Leave **WebSocket (website + mobile)** selected. Host on one instance; join from another using `ws://127.0.0.1:24590`.
4. Connect 5–10 players, then the host clicks **Start game**.
5. ENet is still available for desktop-only LAN/internet testing. ENet clients cannot connect from a web browser.

## Browser/mobile play
1. Export the project using Godot's **Web** export preset and host the exported web files on an HTTPS static site.
2. On the laptop, run the project as a native desktop app and choose **WebSocket (website + mobile)**, then click **Host room**.
3. Expose the laptop's WebSocket port through a secure WSS tunnel/reverse proxy. Follow [`WEB_MOBILE_GUIDE.md`](WEB_MOBILE_GUIDE.md).
4. Players open the exported website on their phones and enter the public `wss://...` tunnel URL in the server URL field.

The website is a Godot Web export of this project, not a separately implemented HTML/JavaScript client. The export must be built in the Godot editor with matching export templates; this ZIP does not include compiled `.wasm`/`.pck` export artifacts.

## Implemented online game loop
- Server-owned roles, policy deck, discard pile, policy tracks, election tracker, presidency, chancellorship, player status, and win state.
- Presidential nominations and simultaneous Ja/Nein voting. Individual votes are hidden from public snapshots until all living seats have voted.
- President privately draws three policies and discards one; Chancellor privately chooses one of the remaining two to enact.
- Veto requests after five Fascist policies, with the President accepting or rejecting the request.
- Liberal victory at five Liberal policies; Fascist victory at six Fascist policies; Hitler elected Chancellor after three Fascist policies wins for Fascists; executing Hitler wins for Liberals.
- Fascist powers based on player count: investigation, special election, and execution.
- Investigation result and role/team information are sent only to the relevant client. Public snapshots do not include roles or legislative hands.
- Server validates sender, phase, living status, role in turn, target eligibility, vote values, and policy-hand indexes before accepting actions.
- Disconnected seats are retained and a disconnected voter's missing vote defaults to Nein so a vote cannot stall forever.

## Mobile UI improvements in this version
- Responsive single-column layout for viewport widths at or below 760 px, with a two-column layout on wider screens.
- Scrollable lobby/game content to keep controls reachable on short portrait displays.
- Larger mobile/web buttons, wrapped labels, reduced portrait margins, and prominent green Ja / red Nein vote buttons.
- Policy choices and veto decisions use distinct colors for quicker scanning.

## Important limitations
- **Active-game reconnection is not complete.** Disconnected seats are retained, but a new connection cannot yet reclaim a seat with a reconnection token or restore the full state.
- **Security:** this prototype has no account authentication or anti-cheat protection. The host can see every role. Use a private trusted group and do not expose the server publicly without a suitable access-control layer.
- **Transport security:** WebSocket itself is not encrypted. For browsers on an HTTPS website, connect using `wss://` through a secure tunnel/reverse proxy. Do not use plain `ws://` from an HTTPS page; browsers block mixed content.
- **Mobile layout:** lobby and game screens now switch to a single-column layout at narrow viewport widths, add vertical scrolling for portrait screens, reduce margins and headings, and use larger touch targets. Ja/Nein voting buttons are large, color-coded, and side-by-side. Verify on target phones because no real-device rendering test was available here.
- **Not engine-tested here:** files were updated and packaged, but the Godot 4.7 editor/runtime and a real browser-to-host multiplayer session were not available for execution in this environment. Check the Godot debugger and test with multiple devices before relying on it.
- Standard rules are approximated; playtesting is needed for edge cases and full rules parity.

## Files
- `OnlineLobby.tscn` / `OnlineLobby.gd`: host/join lobby, WebSocket or ENet transport, private role assignment.
- `OnlineGame.tscn` / `OnlineGame.gd`: authoritative networked game loop and UI.
- `GameSession.gd`: autoload for session and local private state.
- `Main.tscn` / `Main.gd`: previous standalone local prototype. Change `run/main_scene` to `res://Main.tscn` to run it.

Default port: `24590` (TCP for WebSocket, UDP for ENet). Firewall/tunnel configuration may be required.

## Repeatable web export and secure hosting (v5)

- Web export preset: `export_presets.cfg`
- Local export scripts: `scripts/export_web.sh` and `scripts/export_web.bat`
- GitHub Pages CI workflow: `.github/workflows/deploy-pages.yml`
- Reverse proxy template: `deploy/Caddyfile.example`
- Full instructions and security caveats: `WEB_DEPLOY_WORKFLOW.md`

The static web build and the live multiplayer WebSocket server are separate services. GitHub Pages hosts the client; the laptop (or a separately deployed server) hosts the live game endpoint, exposed as WSS through a correctly configured tunnel/reverse proxy. The CI workflow assumes this project folder is named `secret_council_godot` at the repository root. The web export and live endpoint have not been end-to-end tested from this workspace.
