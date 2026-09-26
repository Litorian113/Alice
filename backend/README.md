# Alice backend: MCP server + relay

Steer IBM Bob from your phone (the [Alice iOS app](../ios) or the relay's web page). When Bob finishes a step it sends a short decision card
(situation, 2–4 options, one recommended). You tap one, and Bob carries on with that choice.

```
IBM Bob ──stdio──▶ companion-mcp ──outbound WS──▶ relay ◀──WS── Alice (phone)
                   (spawned by Bob)                 │
                                                    └──push──▶ ntfy / Expo ──▶ phone
```

Paths are relative to `backend/` unless they start with `../`.

| Path | What |
| --- | --- |
| `companion-mcp/` | MCP server Bob spawns. Tools: `pair_phone`, `ask_decision` (choice card), `request_approval` (approval card for one exact command), `notify`, `get_instruction` |
| `relay/` | Single-file WebSocket relay: rooms, secret check, forwarding, ntfy/Expo push, notification answer buttons. Also serves a dev phone page at `/` |
| [`../docs/PROTOCOL.md`](../docs/PROTOCOL.md) | **Contract for the app team**: pairing, messages, decision card rules, push |
| `../.bob/` | `mcp.json` (registers the server) and `custom_modes.yaml` (the **📱 Companion** mode with the steering rules) |
| `tools/fake-bob.js` | Plays Bob against a relay so the app can be built without Bob |
| `tools/dev.js` | `npm run dev`: relay + fake Bob in one process, advertising the LAN address so a real iPhone can pair (`--loop N`, `--host`, `--no-bob`) |
| `tools/check-relay.js` | Smoke-tests a deployed relay (HTTP, wss pairing, forwarding, idle hold) |
| `tools/mock-phone.js` | Terminal phone: answer cards, send instructions, auto-answer for scripted runs |
| `../demo/` | `sample-app/` (failing tests) + `setup.sh`, which creates a standalone Bob workspace from it |
| `test/` | Unit tests for the card contract + end-to-end tests (relay + MCP over stdio + fake phone + fake ntfy) |

## Quick start (everything local)

```sh
cd backend
npm install
npm test                      # 37 tests, ~20 s
npm run dev                   # local relay + fake Bob, pairing links use this machine's LAN IP (for iPhone dev)
npm run relay                 # local relay only, on 0.0.0.0:8787
npm run check:relay           # smoke-test the production relay
```

Open a Bob workspace and pick the **📱 Companion** mode. Either use the repository root (uses `../.bob/`), or for the demo run
`../demo/setup.sh ~/alice-demo` and work there. Bob treats the enclosing **git root** as its workspace, so
`demo/sample-app` inside this repo would pick up the root config; `setup.sh` makes a standalone copy with its own git repo.
- In **Bob Shell**: `bob run --mode companion "The tests are failing. Fix them." < /dev/null`
- In **Bob IDE**: the server is picked up from `.bob/mcp.json`. Ask Bob to "pair my phone"
  to get the QR code in chat.

Scan the QR with the phone, or open the web link it prints (the dev phone page), or use
the terminal phone:

```sh
node tools/mock-phone.js ~/alice-demo/.bob/companion-session.json       # interactive
node tools/mock-phone.js ~/alice-demo/.bob/companion-session.json --auto b,stop   # scripted
```

> `bob run` reads piped stdin as extra prompt input. When you script it, redirect stdin
> (`< /dev/null`) or it will wait forever.

## Configuration

### MCP server (`env` in `.bob/mcp.json`)

| Var | Default | |
| --- | --- | --- |
| `RELAY_URL` | `ws://localhost:8787` | Set to `wss://bob-relay.zeigma.com` in `../.bob/mcp.json` and by `demo/setup.sh` |
| `COMPANION_SESSION_FILE` | unset (memory only) | e.g. `.bob/companion-session.json`. Keeps the pairing across Bob runs. **Needed for Bob Shell**, where every `bob run` spawns a fresh server. File is `0600` and gitignored |
| `COMPANION_SESSION_ID` / `COMPANION_SECRET` | unset | Fixed credentials (win over the file) |
| `COMPANION_QR` | `app` | `web` (set in `mcp.json` for now) puts the dev-page link in the QR, so any phone camera can open it; switch to `app` when the native app handles `bobcompanion://` |
| `RELAY_WEB_URL` | derived from `RELAY_URL` | Base URL for the web pairing link |
| `DECISION_TIMEOUT_S` | `120` | Default wait for `ask_decision` |
| `MAX_DECISION_TIMEOUT_S` | `540` | Cap for `timeout_s`; keep below Bob's `timeout` |

Bob does **not** pass your shell environment to MCP servers. Put everything in the
`env` block of `mcp.json`.

`.bob/mcp.json` also sets `"timeout": 600000` (milliseconds, the per-server request
timeout) and `alwaysAllow` for all five tools, so Bob doesn't stop for approval while
you're away.

### Relay

| Var | Default | |
| --- | --- | --- |
| `PORT` | `8787` | Always binds `0.0.0.0` |
| `PUBLIC_URL` | unset | `https://relay.example.com`. Enables ntfy answer buttons + click-to-open |
| `NTFY_URL` / `NTFY_TOKEN` | `https://ntfy.sh` / unset | Self-hosted ntfy or auth |
| `PUSH_DETAILS` | `1` | `0` = generic push text, no card content sent to the push provider |
| `ROOM_GRACE_S` | `30` | How long a room outlives its Bob connection (lets Bob restart without re-pairing) |
| `DEV_PHONE` | `1` | `0` = don't serve the dev phone page |

### Deploying the relay

Production relay: **`wss://bob-relay.zeigma.com`** on Coolify (Dockerfile build pack, base directory `/backend/relay`).
See **[docs/DEPLOY.md](../docs/DEPLOY.md)** for the Coolify + Cloudflare settings. Verify a deployment with:

```sh
node tools/check-relay.js https://bob-relay.zeigma.com --hold 130
```

`../.bob/mcp.json` and `demo/setup.sh` already point at it. For a fully local setup, run `npm run relay` and
`RELAY_URL=ws://localhost:8787 ../demo/setup.sh ~/alice-demo`.

## Security model (hackathon grade)

- Pairing = session ID + 32-byte random secret, carried in the QR. The relay compares
  secrets in constant time and only forwards within a room.
- Nothing listens on the laptop; the MCP server dials out.
- Secrets live in memory, or in the opt-in 0600 session file. Rooms die 30 s after Bob
  disconnects. No accounts.
- The web pairing link puts credentials in the URL fragment, so they never reach HTTP logs.
- ntfy answer buttons use single-use random tokens, never the room secret.
- With default settings, card text goes to ntfy.sh (public topics). Use a long random
  topic, a self-hosted ntfy, or `PUSH_DETAILS=0`.

## Handoff open questions: findings

Verified with Bob Shell 2.0.5 (`bob run`, headless) against this repo on 2026-09-26.

| Question | Finding |
| --- | --- |
| Tool timeout field | `timeout` in `mcp.json`, **milliseconds**, default 600000 per Bob Shell docs. A 75 s blocking `ask_decision` completed fine. Bob sends no progress tokens, so the fixed timeout is what counts. Not yet tested in Bob IDE |
| Auto-approve | `alwaysAllow: [tool names]` works: Bob Shell called all our tools without prompting. Not yet checked in Bob IDE |
| Good, short options? | Yes, with the Companion mode. Real cards: *"Tests fixed. What next?"* → `Add more tests` / `Commit the fix ★` / `Stop here`. Bob followed the tapped option and asked again after hitting an obstacle. Without the "offer follow-ups when done" rule, Bob just finished and never asked |
| Relative server path | `"args": ["./backend/companion-mcp/index.js"]` resolves against the workspace root |
| Env passthrough | Shell env vars are **not** forwarded to the MCP server; use the `env` block |
| Workspace root | Bob Shell uses the enclosing **git root** as the workspace (for `.bob/`, relative paths). A subfolder of a repo can't have its own `.bob/` config |
| Hackathon rules / relaying data to a third party | Still open. Mitigation: `PUSH_DETAILS=0` keeps card text off ntfy |

## Demo script

1. Relay: the deployed `wss://bob-relay.zeigma.com` (check with `npm run check:relay`). Create/reset the workspace: `../demo/setup.sh ~/alice-demo` (keeps the pairing; `src/slugify.js` has two bugs).
2. Pair the phone once (`COMPANION_SESSION_FILE` keeps it paired across runs).
3. `cd ~/alice-demo && bob run --mode companion "The tests are failing. Fix them." < /dev/null`
4. Phone: "Investigating failing tests…" → Bob fixes → "All 3 tests passing" → card
   *"Tests fixed. What next?"*. Tap an option, and Bob continues live with it.

Backup: `npm run demo:bob` drives the phone without Bob.
