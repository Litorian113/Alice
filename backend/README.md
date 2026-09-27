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

## Same-chat voice follow-ups

`ask_decision` can wait for either a tapped option or a spoken follow-up using
`accept_voice: true` (the default even when omitted; false explicitly opts out). Put Bob's English response in `reply` (up to 4000 characters), include
2–4 relevant actions with a stop option, and use `timeout_s: 300`. Voice from the
current iOS app resumes the same MCP call/IDE conversation; Bob sends the next
answer and fresh actions the same way. Command approvals are never resolved by
speech. No fixed README workflow, second agent or browser chat is involved.

After Stop here or declining further work, `get_instruction(wait_s: 540)` keeps
Bob quietly available for new spoken requests from the home screen. It preserves
the latest result and resets task approvals. Voice resumes the same IDE call;
ordinary idle timeout renews it. IDE cancellation/disconnect ends it. The active
wait must stay open: QR pairing cannot wake a finished IDE chat. See the reusable
[phone conversation walkthrough](../docs/VOICE_DIALOG.md) and
[wire contract](../docs/PROTOCOL.md#same-chat-phone-conversations).

## Quick start (everything local)

For the complete real-iPhone / IBM Bob chat walkthrough, see [IPHONE_TEST.md](../docs/IPHONE_TEST.md). Alice now supports live pairing, both card types, acknowledgement-based answers, ntfy setup and voice.

```sh
cd backend
npm install
npm test                      # 37 tests, ~20 s
npm run dev                   # local relay + fake Bob, pairing links use this machine's LAN IP (for iPhone dev)
npm run dev -- --no-bob --configure-bob  # local relay for real Bob; writes ignored local URL override
npm run pair:show              # render a large local QR page at ../.bob/pairing.html
npm run chat                   # local ACP chat; native tool permissions → Alice
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

The alternative [ACP desktop chat](../docs/ACP_CHAT.md) uses Bob Shell's native
permission protocol and its own pairing. It does not require the Companion mode.

### MCP server (`env` in `.bob/mcp.json`)

| Var | Default | |
| --- | --- | --- |
| `RELAY_URL` | `ws://localhost:8787` | Set to `wss://bob-relay.zeigma.com` in `../.bob/mcp.json` and by `demo/setup.sh` |
| `COMPANION_SESSION_FILE` | unset (memory only) | e.g. `.bob/companion-session.json`. Keeps the pairing across Bob runs. **Needed for Bob Shell**, where every `bob run` spawns a fresh server. File is `0600` and gitignored |
| `COMPANION_LOCAL_CONFIG` | unset | Optional local JSON with `relayUrl`; root config points to ignored `.bob/local-relay.json`, generated by `dev --configure-bob` |
| `COMPANION_SESSION_ID` / `COMPANION_SECRET` | unset | Fixed credentials (win over the file) |
| `COMPANION_QR` | `app` | Root config now uses `app`; Alice handles `bobcompanion://`. `web` remains available for browser testing |
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
| `ASSEMBLYAI_API_KEY` | unset | Server-only key for authenticated `voice_session_request`; local relay/dev runner load root `.env` |
| `ASSEMBLYAI_REGION` | `eu` | `eu`, `us` or `global`, used consistently for token and streaming endpoints |
| `ASSEMBLYAI_SPEECH_MODEL` | `universal-3-6-pro` | Model returned with temporary tokens, not hardwired in Alice |

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
| Relative server path | Set `"cwd": "."` explicitly: Bob IDE resolves it against the workspace root. Without it, the IDE may launch from `/` and fail to find `./backend/companion-mcp/index.js`. This also keeps the session file and local relay override relative to the repo |
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
