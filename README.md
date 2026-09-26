# Bob Companion

> **Let Bob work. Step in when it matters.**

A mobile decision layer for IBM Bob — IBM Bob 2.0 Hackathon · September 2026

**Team:** Franz Anhäupl · Christopher Pietsch

---

## What is Bob Companion?

Bob Companion is a lightweight mobile interface that lets developers step away from their computer while IBM Bob continues working autonomously. When Bob reaches a point where human judgment is genuinely needed, it sends a compact decision request to the developer's phone.

The developer receives:

- a short description of the situation
- 2–4 possible next steps
- Bob's recommended option
- an indication of risk

One tap. Bob continues.

---

## The Problem

Autonomous coding agents can work for extended periods without supervision — until suddenly they can't.

Bob Companion solves the gap between *agent running* and *agent waiting for you*:

```
Today:        Developer watches → waits → responds → watches again

With Companion:  Developer starts task → leaves → Bob asks when it matters → tap → done
```

---

## Architecture

```
IBM Bob  ──stdio──>  Companion MCP Server  ──wss──>  Relay  ──wss──>  Mobile App
                                                        │
                                                      Push ──────────────────────>  Phone
```

- **IBM Bob** runs the development task and calls Companion MCP tools
- **Companion MCP Server** — local Node.js server, exposes tools to Bob, bridges to relay
- **Relay** — lightweight remote WebSocket server, connects MCP server and phone
- **Mobile App** — native SwiftUI iOS app, currently runs against local demo data
- **Push** — ntfy.sh (prototype), so the phone wakes up even when the app is closed

---

## MCP Tools

| Tool | Description |
|---|---|
| `pair_phone` | Returns pairing state and QR pairing URL |
| `notify` | Sends a non-blocking status notification to the phone |
| `ask_decision` | Sends a decision card, blocks until the developer responds |
| `get_instruction` | Checks whether the developer sent a free-text instruction |

---

## Decision Card

```json
{
  "type": "decision_request",
  "id": "d_42",
  "title": "Refactor done, 3 tests failing",
  "context": "Auth module refactored. 3 of 48 tests fail on outdated mocks.",
  "risk": "low",
  "options": [
    { "id": "a", "label": "Fix tests", "detail": "Update mocks, then rerun", "recommended": true },
    { "id": "b", "label": "Revert refactor", "detail": "Back to last green commit" },
    { "id": "c", "label": "Pause", "detail": "Wait until I'm back" }
  ],
  "allowFreeText": true,
  "expiresAt": "2026-09-26T14:05:00Z"
}
```

---

## Repository Structure

```
bob-companion-app/     ← this repo — Swift/SwiftUI iOS app (Franz)
companion-mcp/         ← MCP server (Christopher)
companion-relay/       ← WebSocket relay (Christopher)
```

---

## Minimum Viable Demo

```
Bob works autonomously
  ↓
Bob calls ask_decision()
  ↓
Phone receives decision card
  ↓
Developer taps an option
  ↓
Bob receives the choice
  ↓
Bob continues
```

Everything else is a bonus.

---

## App Stack

| Layer | Technology |
|---|---|
| Language | Swift (Swift 5 language mode) |
| UI | SwiftUI |
| IDE | Xcode 15+ |
| Minimum iOS | 17.0 |
| Gestures | SwiftUI `.gesture()`, `UIImpactFeedbackGenerator` |
| WebSocket (later) | `URLSessionWebSocketTask` — built-in, no dependencies |
| Push (later) | ntfy.sh |

---

## Mobile App

The app opens directly on **Bob**, with a local authentication-refactor demo. A curved bottom bar keeps **Usage** on the left and **Profile** on the right. The raised center button shows Bob on the other tabs and becomes a microphone on the Bob screen.

- **Bob:** animated vector companion, decision bubbles, recommendation, context sheet, working/completed/reverted/paused states, and typed instructions.
- **Usage:** interactive stacked token chart for today/week/month, input/output totals, and an illustrative Bobcoin allowance. Companion customization is a future feature.
- **Profile:** editable local display name, demo disconnect/reconnect, persistent haptic and animation preferences, and app information.

The visual system uses light surfaces, IBM blue, and bundled [IBM Plex Sans](https://github.com/IBM/plex). The font license is included in `BobCompanion/Resources/Fonts/OFL.txt`. Bob is drawn natively in SwiftUI, with blinking and floating motion that respects Reduce Motion and the profile preference.

### Demo behavior

Every return from Usage or Profile to Bob starts a fresh demo, while a disconnected session stays disconnected until explicitly reconnected.

1. Bob has refactored the authentication module. Three tests fail because of outdated mocks.
2. **Fix tests** updates the mocks and finishes with 48/48 passing tests.
3. **Revert refactor** restores the previous version and finishes with passing tests.
4. **Pause** stays paused. **Replay demo** restarts the scenario.
5. The microphone opens a **voice preview** with an editable sample phrase. The text input sends arbitrary instructions into the local conversation.

No backend, IBM account, live billing, real microphone recording, QR pairing, or push notifications are connected. Demo data is labeled in the UI. Disconnecting or restarting cancels delayed demo work. The existing decision-card/response models remain the integration point for the relay.

### Run

From the repository root:

```bash
open BobCompanion.xcodeproj
```

Select an iPhone simulator and Run. Minimum deployment target: iOS 17. There are no package dependencies. For a physical device, select your signing team in Xcode.

If source files or build settings change outside Xcode, regenerate using [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
```

### Validation

The app builds for the iOS Simulator. Interaction and visual review can be done directly in Xcode; no additional test suite is included.

---

## Hackathon Scope

**In scope:** pairing, status notifications, decision requests, Bob recommendation, sending decisions back, Bob continuing after response, fast interaction experiments, demo-ready end-to-end flow.

**Out of scope:** full remote Bob control, production auth, accounts, multi-user sessions, persistent history, full mobile code editor.

---

## License

Hackathon prototype — IBM Bob 2.0 Hackathon, September 2026.
