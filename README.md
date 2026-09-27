# Alice

**The mobile partner for IBM Bob. Keep building from anywhere.**

Bob works in your IDE or terminal. When Bob needs you, Alice brings the decision to your
phone: tap a next step, approve or reject a command, or speak a follow-up. Bob continues
in the same session while you're away from your desk.

IBM Bob 2.0 Hackathon · September 2026 · **Franz Anhäupl** (iOS app & interaction design) ·
**Christopher Pietsch** (MCP server & relay)

## App screenshots

| Splash screen | Alice | Usage | Profile | App icon |
| :---: | :---: | :---: | :---: | :---: |
| <img src="docs/bob-sessions/Splashscreen.PNG" alt="Alice splash screen" width="150"> | <img src="docs/bob-sessions/Alice-Page.PNG" alt="Alice main page" width="150"> | <img src="docs/bob-sessions/Usage-Page.PNG" alt="Usage page" width="150"> | <img src="docs/bob-sessions/Settingspage.PNG" alt="Profile and settings page" width="150"> | <img src="docs/bob-sessions/Alice-App-Icon.PNG" alt="Alice app icon screenshot" width="150"> |

## How it works

1. Switch Bob to the **📱 Companion** agent and start a task.
2. Scan Bob's QR code with Alice.
3. Your phone buzzes when Bob needs input.
4. Tap a choice, approve once / approve for the task / reject a command, or hold the mic and speak.
5. Bob receives the answer and continues.

```
IBM Bob (IDE / Shell) ──stdio──▶ Companion MCP server ──wss──▶ Relay ◀──wss── Alice (iPhone)
   + Companion agent              backend/companion-mcp       backend/relay     ios/
   (.bob/custom_modes.yaml)                                     ├──push──▶ ntfy ──▶ iPhone
                                                                └──tokens─▶ AssemblyAI (speech)
```

- **Companion agent:** a custom IBM Bob mode ([`.bob/custom_modes.yaml`](.bob/custom_modes.yaml)) that
  teaches Bob when to involve you. It announces the task, offers 2–4 next steps after each step (always
  including "Stop here"), asks for approval before state-changing commands, never takes a risky action
  without an answer, and then waits quietly for your voice.
- **MCP server:** five tools for Bob: `pair_phone`, `notify`, `ask_decision`, `request_approval`,
  `get_instruction`. It trims every card to phone size and remembers "approve for task" until the task ends.
- **Relay:** forwards messages between Bob and the phone. Nothing on the developer's machine is exposed,
  because the MCP server dials out. It also sends ntfy pushes and issues short-lived AssemblyAI tokens.
- **Alice:** native SwiftUI app. It handles QR pairing (credentials in the Keychain), choice and approval
  cards, hold-to-speak voice, and a customizable companion.

## Status

| Working today | Prototype | Next |
| --- | --- | --- |
| QR pairing and live relay connection | Usage page: Bobcoin snapshot and illustrative token data | Native Alice push (APNs) |
| Choice cards, command approvals, status updates | Account sign-in is simulated | Real account authentication and usage data |
| Voice follow-ups in the same Bob conversation (needs `ASSEMBLYAI_API_KEY` on the relay) | Experimental [ACP chat](docs/ACP_CHAT.md) that forwards Bob's native permission prompts | More resilient session lifecycle and reconnects |
| ntfy notifications with answer buttons | | |
| Production relay `https://bob-relay.zeigma.com` (live, verified 27 Sep 2026) | | |

## Try it

**With the production relay:** the root [`.bob/mcp.json`](.bob/mcp.json) already points at
`wss://bob-relay.zeigma.com`.

```sh
cd backend && npm install                 # Node 22+
open ../ios/Alice.xcodeproj               # macOS, Xcode 15+, iOS 17+
```

Open this repository in IBM Bob, select **📱 Companion** and start a task. Bob shows the pairing QR
code (tool `pair_phone`). Scan it with Alice. Step-by-step guides:

- [iPhone + Bob test guide](docs/IPHONE_TEST.md): the full live loop.
- [Voice dialog](docs/VOICE_DIALOG.md): spoken follow-ups in the same IDE conversation.
- [ACP chat](docs/ACP_CHAT.md): `cd backend && npm run chat`. This is a separate Bob Shell session whose
  native tool permission requests are forwarded to Alice. The Bob IDE chat's own approval dialogs are
  not forwarded ([background](docs/NATIVE_APPROVALS.md)).

**Locally, without the production relay** (voice works when `ASSEMBLYAI_API_KEY` is in `.env`):

```sh
cd backend
npm run dev                  # relay + simulated Bob; QR links use this Mac's LAN IP for the iPhone
npm run dev -- --no-bob      # relay only, for real Bob (see docs/IPHONE_TEST.md)
```

**Headless with Bob Shell (automated tests):**

```sh
cp .env.example .env                       # add BOB_KEY
demo/setup.sh ~/alice-demo                 # standalone demo project (Bob uses the enclosing git root as workspace)
cd ~/alice-demo && BOB_API_KEY=… bob run --mode companion "The tests are failing. Fix them, then commit the fix." < /dev/null
```

## How we used IBM Bob

IBM Bob is the platform Alice extends, one of the main tools we built it with, and the engine of every
demo. The project bootstrapped itself: once the first loop worked, we steered Bob from Alice while Bob
improved Alice. We used the Bob IDE to test, develop further and self-improve the product, and the Bob
CLI (Bob Shell) for automated end-to-end tests, alongside other coding tools. Everything uses Bob's
documented extension points (custom mode + MCP server); Bob itself is not modified.

**IBM Bob task session summaries** from each team member: [docs/bob-sessions/](docs/bob-sessions/).

## Repository layout

| Path | What |
| --- | --- |
| [`ios/`](ios) | Alice, the native SwiftUI app. [ios/README.md](ios/README.md) |
| [`backend/`](backend) | Companion MCP server, relay, ACP chat, dev and test tools. [backend/README.md](backend/README.md) |
| [`.bob/`](.bob) | Bob config: MCP server registration and the Companion agent |
| [`docs/`](docs) | Protocol, deployment, test guides, Bob session screenshots |
| [`demo/`](demo) | Demo project with failing tests + `setup.sh` for a standalone Bob workspace |

## Documentation

| Document | Content |
| --- | --- |
| [docs/PROTOCOL.md](docs/PROTOCOL.md) | App ↔ relay messages, choice and approval card contract, push |
| [docs/IPHONE_TEST.md](docs/IPHONE_TEST.md) | Live test: Bob → iPhone → Bob |
| [docs/VOICE_DIALOG.md](docs/VOICE_DIALOG.md) | Voice follow-ups in the same Bob IDE chat |
| [docs/ACP_CHAT.md](docs/ACP_CHAT.md) | Separate Bob Shell chat with native permission forwarding |
| [docs/NATIVE_APPROVALS.md](docs/NATIVE_APPROVALS.md) | Why the IDE's own approval dialogs are not mirrored |
| [docs/DEPLOY.md](docs/DEPLOY.md) | Relay on Coolify + Cloudflare |
| [docs/bob-sessions/](docs/bob-sessions/) | IBM Bob task session summary screenshots |
| [docs/voice-demo.md](docs/voice-demo.md) | Sample document Bob wrote and revised through voice during testing |
| [backend/README.md](backend/README.md) | Backend configuration, tools, findings about Bob |
| [ios/README.md](ios/README.md) | App features, build, project structure |
| [ios/docs/VOICE_INTEGRATION.md](ios/docs/VOICE_INTEGRATION.md) | Voice recording and transcription in the app |
| [ios/HANDOFF_BACKEND.md](ios/HANDOFF_BACKEND.md) | Backend → app handoff (German) |

---

Bob does the development work. Alice keeps you in the loop.
