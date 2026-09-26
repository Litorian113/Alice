# Alice ↔ Bob: relay protocol and decision card contract

This is the interface between the backend ([`backend/`](../backend): MCP server + relay) and the mobile app ([`ios/`](../ios): Alice).
The app only talks to the relay, over one WebSocket. It never talks to Bob.

To build against a live backend without Bob, run a relay and `backend/tools/fake-bob.js`
(see [Testing without Bob](#testing-without-bob)).

## 1. Pairing

The MCP server shows a QR code (in the terminal on stderr, and in the Bob chat via the
`pair_phone` tool). It carries one of two link formats. The app should accept both.

| Format | Example | Used by |
| --- | --- | --- |
| App link (default) | `bobcompanion://pair?s=<sessionId>&k=<secret>&r=<relayUrl>` | Native app (register the `bobcompanion` scheme) |
| Web link | `https://relay.example.com/#s=<sessionId>&k=<secret>` | Dev phone page served by the relay. Relay URL = same host, `wss://` |

- `sessionId`: 4-64 chars `[A-Za-z0-9_-]`, usually 10 chars.
- `secret`: 43 chars base64url (32 random bytes). Treat it like a password: store it in
  secure storage and never log it.
- `relayUrl`: URL-encoded `ws://` or `wss://` URL.

## 2. Connecting

Open a WebSocket to `relayUrl`. The **first** message must be `hello`, sent within 10 s:

```json
{ "type": "hello", "role": "phone", "sessionId": "k3m9x2pq7w", "secret": "…43 chars…", "pushTopic": "bobc-1f2e3d4c5b6a79880a1b2c3d" }
```

`pushTopic` is optional. It can be either:
- an **ntfy topic** (`[A-Za-z0-9_-]{8,64}`; use a long random one because ntfy.sh topics are public), or
- an **Expo push token** (`ExponentPushToken[…]`).

The relay stores it for the room and keeps it after the app disconnects. This is what
wakes the phone when the app is closed.

Relay reply on success:

```json
{ "type": "paired", "sessionId": "k3m9x2pq7w", "role": "phone", "bobOnline": true }
```

On failure the relay sends `{ "type": "error", "error": "<reason>" }` and closes:

| Close code | Meaning | App should |
| --- | --- | --- |
| `4003` | Wrong secret / bad hello | Drop the pairing, ask the user to scan again |
| `4004` | Unknown session: Bob isn't connected (yet) | Keep pairing, retry with backoff (1 s → 10 s) |
| `4001` | Session ended: Bob exited and did not come back within 30 s | Keep pairing, retry with backoff. A fixed/persisted session may come back. Show "Bob offline" |
| other / network drop | | Retry with backoff |

The relay pings every 30 s. Standard WebSocket clients answer automatically.

## 3. Messages

All messages are JSON objects with a `type`. After `hello`, the relay forwards messages
unchanged within the room: Bob → every connected phone, phone → Bob.

### Bob → phone

| Type | Fields | App behaviour |
| --- | --- | --- |
| `notify` | `id`, `message` (≤ 200 chars), `level`: `info` \| `success` \| `error` | Show in the activity feed / as a toast |
| `decision_request` | the decision card, see §4 | Show the card, buzz |
| `ack` | `id` | Your `decision_response` or `instruction` with this `id` was accepted. **Dismiss that card** (also on other phones in the same room) |
| `decision_expired` | `id`, `reason`: `timeout` \| `cancelled` \| `unknown` | Remove the card. `timeout`: Bob continued conservatively. `cancelled`: Bob aborted the call |
| `error` | `id`, `error` | Your answer was rejected (e.g. `unknown optionId`). The card stays open |

### Relay → phone

| Type | Fields | Meaning |
| --- | --- | --- |
| `paired` | `sessionId`, `role`, `bobOnline` | Joined the room |
| `bob_status` | `online` | Bob (the MCP server) connected / disconnected |
| `error` | `error` | Hello rejected (followed by close) |

### Phone → Bob

| Type | Fields | Notes |
| --- | --- | --- |
| `decision_response` | `id`, `optionId` (`a`–`d`), `text` (optional, ≤ 500 chars) | `text` alone (no `optionId`) is allowed when the card has `allowFreeText: true`. Bob then follows the text instead of an option |
| `instruction` | `id` (any unique string), `text` (≤ 500 chars) | Free-text instruction. Bob picks it up with `get_instruction` between steps. Answered with `ack` |

### Delivery rules the app can rely on

- **Open cards are re-sent** whenever a phone (re)connects. Deduplicate by `id`.
- A card is closed by exactly one of `ack` or `decision_expired`. Don't remove a card
  before one of them arrives, because the answer might not have reached Bob.
- `id`s are unique per MCP server process (`d_1`, `n_2`, …). If Bob restarts, ids start over.
- Unknown message types should be ignored (forward compatibility).

## 4. Decision card contract

The MCP server reduces every card before it is sent. The app never has to truncate.

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
  "expiresAt": "2026-09-26T14:05:00.000Z"
}
```

| Field | Guarantee |
| --- | --- |
| `id` | string, unique per Bob session |
| `title` | 1–60 chars, single line |
| `context` | 0–140 chars, at most 2 sentences, single line. **May be empty** |
| `risk` | `low` \| `medium` \| `high` (defaults to `medium`) |
| `options` | 2–4 entries, ids `a`, `b`, `c`, `d` in display order |
| `options[].label` | 1–25 chars, unique within the card |
| `options[].detail` | 1–60 chars; **key omitted** when there's no detail |
| `options[].recommended` | `true` on at most one option; **key omitted** otherwise. There may be no recommended option |
| `allowFreeText` | boolean |
| `expiresAt` | ISO 8601 UTC. After this, Bob has moved on and a `decision_expired` follows |

Over-long text is cut at a word boundary and ends with `…`.

**Answer:**

```json
{ "type": "decision_response", "id": "d_42", "optionId": "a", "text": "optional note" }
```

## 5. Push notifications

For every `notify` and `decision_request` the relay pushes to each `pushTopic` of the room,
whether or not the app is connected. If the app is in the foreground it will get both,
so dedupe or suppress in-app as you prefer.

**ntfy** (`pushTopic` = topic name): title = card title (or "Bob" / "Bob: done" /
"Bob: failed"), message = context + "Recommended: …". Priority is 4, or 5 for high risk.
If the relay has `PUBLIC_URL` set, cards get up to 3 **action buttons** (recommended
first, marked ★). Each is a one-time `POST {PUBLIC_URL}/a/<token>/<optionId>`, so the
user can answer straight from the lock screen. The resulting `decision_response`
arrives at Bob with `"via": "push"`. Tapping the notification body opens `PUBLIC_URL/`.

**Expo** (`pushTopic` = `ExponentPushToken[…]`): `title`, `body`, `priority: high`,
`sound: default`, and `data: { type, id }` for cards / `data: { type }` for notify. On tap,
open the app and connect; the card is re-sent on connect.

With `PUSH_DETAILS=0` on the relay, push texts are generic ("Bob needs a decision") and
no card content leaves the relay.

## Testing without Bob

```sh
cd backend
npm install
npm run relay                                  # relay on 0.0.0.0:8787
RELAY_URL=ws://<relay-host>:8787 npm run demo:bob       # fake Bob: prints QR + links
#   keys: d = next sample card, h = high-risk card, n/s/e = notify info/success/error
#   or unattended: npm run demo:bob -- --loop 20
node tools/mock-phone.js '<link>'              # terminal phone, if you need one
```

`fake-bob` uses the same card normalizer and session code as the real MCP server, so its
messages match production exactly. One sample card is deliberately too long, to show trimming.
