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
- **Mobile App** — Expo/React Native, receives cards, sends decisions back
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
bob-companion-app/     ← this repo — Expo/React Native mobile app (Franz)
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

## Mobile App Screens

| Screen | Description |
|---|---|
| **Pair** | Scan QR code shown by Bob |
| **Connected** | Live status — what Bob is currently doing |
| **Decision** | Decision card with options and Bob's recommendation |
| **Completed** | Task finished confirmation |

---

## Interaction Patterns (P0 → P2)

- **P0** — tap to select an option
- **P1** — swipe left/right for binary decisions
- **P2** — shake-to-accept Bob's recommendation (low-risk only)

---

## Getting Started

> Setup instructions will be added as the implementation progresses.

```bash
# Install dependencies
npm install

# Start the app
npx expo start
```

---

## Hackathon Scope

**In scope:** pairing, status notifications, decision requests, Bob recommendation, sending decisions back, Bob continuing after response, fast interaction experiments, demo-ready end-to-end flow.

**Out of scope:** full remote Bob control, production auth, accounts, multi-user sessions, persistent history, full mobile code editor.

---

## License

Hackathon prototype — IBM Bob 2.0 Hackathon, September 2026.
