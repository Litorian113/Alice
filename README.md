# Alice

**The mobile partner for IBM Bob.** Bob works in your IDE or terminal. Alice brings the
decisions that need you to your phone, so you can step away from the desk and keep things
moving with a tap.

IBM Bob 2.0 Hackathon · September 2026 · **Franz Anhäupl** (iOS app & interaction design) ·
**Christopher Pietsch** (MCP server & relay)

```
IBM Bob (IDE / Shell) ──stdio──▶ companion MCP server ──wss──▶ relay ◀──wss── Alice (iPhone)
                                  backend/companion-mcp        backend/relay     ios/
                                                                  └──push──▶ ntfy / Expo
```

## Repository layout

| Path | What | Start here |
| --- | --- | --- |
| [`ios/`](ios) | Alice, the native SwiftUI app | [ios/README.md](ios/README.md), backend hookup: [ios/HANDOFF_BACKEND.md](ios/HANDOFF_BACKEND.md) |
| [`backend/`](backend) | Companion MCP server (Bob spawns it) and the WebSocket relay | [backend/README.md](backend/README.md) |
| [`docs/`](docs) | Shared contract and ops: [PROTOCOL.md](docs/PROTOCOL.md) (app ↔ relay messages, decision card rules), [DEPLOY.md](docs/DEPLOY.md) (relay on Coolify) | |
| [`.bob/`](.bob) | Bob config for this repo: registers the MCP server, adds the **📱 Companion** mode | |
| [`demo/`](demo) | Demo app with failing tests + `setup.sh`, which copies it into a standalone Bob workspace | [backend/README.md#demo-script](backend/README.md#demo-script) |

## Quick start

**For native Bob approvals on the phone, use the new [local ACP chat](docs/ACP_CHAT.md):**
`cd backend && npm run chat`. It opens a separate Bob Shell session with a PC chat
and forwards its native tool permission requests to Alice. Pair with the QR in
that chat; the existing IDE session has separate credentials.

**Start with [the iPhone + Bob test guide](docs/IPHONE_TEST.md).** Alice now scans Bob's QR, receives live questions and command approvals, and returns decisions after acknowledgement. Notifications use the free ntfy app; no paid Apple account is needed for this test. A new Alice/IBM-inspired start screen is included.

```sh
# iOS app (macOS + Xcode 15)
open ios/Alice.xcodeproj

# Backend (Node 22+)
cd backend && npm install && npm test

# Bob against the production relay (wss://bob-relay.zeigma.com)
cp .env.example .env   # add BOB_KEY
demo/setup.sh ~/alice-demo   # standalone copy: Bob uses the enclosing git root as its workspace
cd ~/alice-demo && BOB_API_KEY=… bob run --mode companion "The tests are failing. Fix them." < /dev/null
```

The configured production relay is `https://bob-relay.zeigma.com`; verify availability before use (it returned HTTP 503 during integration). For local testing use `npm run dev -- --no-bob --configure-bob` in `backend/`. The relay also serves a web phone page for comparison.

The existing IBM Bob IDE chat's own approval dialogs are not forwarded. Use the
ACP chat above for native permission forwarding. The original investigation is in
[Native IDE approvals](docs/NATIVE_APPROVALS.md).
