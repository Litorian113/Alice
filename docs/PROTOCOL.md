# Alice ↔ Bob: relay protocol and decision card contract

This is the interface between the backend ([`backend/`](../backend): MCP server + relay) and the mobile app ([`ios/`](../ios): Alice).
App control messages use one authenticated relay WebSocket. Audio goes directly to AssemblyAI using a temporary token issued by that relay. The app never connects directly to Bob.

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

Alice additionally sends `pushClick: "bobcompanion://open"` when ntfy notifications are enabled. This exact allowlisted value opens Alice and suppresses notification answer buttons, so all choices are made in the app. Other clients keep the original web/action-button behavior. `push_unregister` with `topic` removes a topic from the authenticated room. Normal socket disconnect keeps it registered.

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

`paired` now also includes `voiceAvailable: true|false`, depending on server key configuration. On iOS, use the `error` payload to distinguish wrong secrets from unknown sessions; custom close codes are not consistently surfaced by URLSession.

## 3. Messages

All messages are JSON objects with a `type`. After `hello`, the relay forwards messages
unchanged within the room: Bob → every connected phone, phone → Bob.

### Bob → phone

| Type | Fields | App behaviour |
| --- | --- | --- |
| `notify` | `id`, `message` (≤ 200 chars), `level`: `info` \| `success` \| `error` | Show in the activity feed / as a toast |
| `decision_request` | the card, `kind` `choice` or `approval`, see §4 | Show the card, buzz |
| `voice_status` | `voiceReadyUntil`: ISO 8601 UTC timestamp or `null` | Quiet home-screen voice listener is active until that time. Preserve the last result; no card or push. Clear readiness on disconnect or expiry. |
| `sync` | `decisions`: array of all currently open cards | Authoritative snapshot after phone/Bob reconnect; remove stale cards and deduplicate subsequent individual replays |
| `ack` | `id` | Your `decision_response` or `instruction` with this `id` was accepted. **Dismiss that card** (also on other phones in the same room) |
| `decision_expired` | `id`, `reason`: `timeout` \| `cancelled` \| `unknown` \| `voice_input` | Remove the card. `voice_input`: spoken input resumed a voice-enabled choice, never an approval. Timeout ends voice dialogs without selecting a fallback; ordinary choices retain their conservative policy |
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
| `decision_response` | `id`, `optionId` (one of the card's option ids), `text` (optional/`null`, ≤ 500 chars) | `text` alone (no `optionId`) is allowed when the card has `allowFreeText: true`. Bob then follows the text instead of an option |
| `instruction` | `id` (any unique string), `text` (≤ 500 chars), optional `source: "voice"` | Accepted into the queue with `ack`. Voice may immediately resume an open voice-enabled choice; otherwise Bob picks it up with `get_instruction` or the next voice-enabled choice. |

### Delivery rules the app can rely on

- **Open cards are re-sent** whenever a phone (re)connects. Deduplicate by `id`.
- A card is closed by exactly one of `ack` or `decision_expired`. Don't remove a card
  before one of them arrives, because the answer might not have reached Bob.
- New IDs include a random process prefix (`d_<run>_<sequence>`); counters restarting no longer collide with old cards after a Bob restart. Treat IDs as opaque strings.
- Repeated instructions with the same ID/text are acknowledged without queuing twice, including after consumption. Reusing an ID with different text is rejected. Receipts live for the current MCP process (up to 2,000 inputs); the queue accepts up to 100 waiting instructions. No persistence across process restarts is promised.
- Duplicate option answers receive the original acknowledgement while cached; changing an already accepted option is rejected. Expiration is also checked when the response arrives, not just by a timer.
- Unknown message types should be ignored (forward compatibility).

## 4. Decision card contract

There is **one card type** (`decision_request`) with a `kind`:

| `kind` | Sent by (MCP tool) | Purpose | Option ids |
| --- | --- | --- | --- |
| `choice` | `ask_decision` | "What next?": 2–4 next steps, one may be recommended | `a`, `b`, `c`, `d` |
| `approval` | `request_approval` | "May Bob run this exact command?" | `approve_once`, `approve_for_task`, `reject` (always these three, in this order) |

**Every base key is always present**, whatever the kind (`null`, `""`, `false` or `[]` when
unused), so a strict decoder (Swift `Codable` with non-optional fields) never hits a
missing key. New optional keys may be added later; ignore keys you don't know.

### Choice card

```json
{
  "type": "decision_request",
  "id": "d_42",
  "kind": "choice",
  "title": "Refactor done, 3 tests failing",
  "context": "Auth module refactored. 3 of 48 tests fail on outdated mocks.",
  "command": null,
  "explanations": [],
  "risk": "low",
  "options": [
    { "id": "a", "label": "Fix tests", "detail": "Update mocks, then rerun", "recommended": true },
    { "id": "b", "label": "Revert refactor", "detail": "Back to last green commit", "recommended": false },
    { "id": "c", "label": "Pause", "detail": "Wait until I'm back", "recommended": false }
  ],
  "allowFreeText": true,
  "expiresAt": "2026-09-26T14:05:00Z"
}
```

### Approval card

```json
{
  "type": "decision_request",
  "id": "d_43",
  "kind": "approval",
  "title": "Run the auth tests",
  "context": "Checks that sign-in still works after Bob's changes. Stops at the first failing test.",
  "command": "npm test -- --runInBand --bail auth",
  "explanations": [
    { "part": "npm test", "meaning": "Starts the project's test runner." },
    { "part": "--runInBand", "meaning": "Runs the tests one at a time." },
    { "part": "--bail", "meaning": "Stops when the first test fails." },
    { "part": "auth", "meaning": "Selects the authentication tests." }
  ],
  "risk": "low",
  "options": [
    { "id": "approve_once", "label": "Approve once", "detail": "Just this time", "recommended": false },
    { "id": "approve_for_task", "label": "Approve for task", "detail": "Allow this command for this task", "recommended": false },
    { "id": "reject", "label": "Reject", "detail": "Don't run it", "recommended": false }
  ],
  "allowFreeText": false,
  "expiresAt": "2026-09-26T14:05:00Z"
}
```

What the answers mean on Bob's side (enforced by the MCP server):

| Answer | Bob is told |
| --- | --- |
| `approve_once` | Run it exactly as shown, once. The next time Bob wants to run it, a new card comes |
| `approve_for_task` | Run it. The MCP server remembers the command (whitespace-insensitive), so later requests for it **during the same task** are approved without a card. The task ends when Bob sends `notify` with `success`/`error`, or when Bob exits |
| `reject` | Don't run it; find another way. A `text` note is passed on ("use yarn instead") |
| no answer by `expiresAt` | Not approved. Bob must not run it |

The MCP server can only tell Bob what was decided. Bob Shell runs commands with its own
tools, so the Companion mode's rules are what make Bob ask first and follow the answer.

### Field rules

| Field | Guarantee |
| --- | --- |
| `id` | string, unique per Bob session |
| `kind` | `choice` \| `approval`. Treat an unknown kind like `choice`: render the options generically |
| `title` | 1–60 chars, single line |
| `context` | 0–140 chars, at most 2 sentences, single line. May be `""` |
| `command` | `null`, or the exact command, **never trimmed** (≤ 500 chars, may contain newlines). Always a string for `approval`; optional for `choice` (e.g. a migration choice showing its command). Show it in full, monospace |
| `explanations` | 0–6 `{ part, meaning }` (part ≤ 40, meaning ≤ 100 chars) for an "info" sheet. May be `[]` |
| `risk` | `low` \| `medium` \| `high`. For `high`, the app should confirm anything except `reject` / a safe option before sending |
| `options` | choice: 2–4, ids `a`–`d` in display order. approval: exactly the 3 ids above |
| `options[].label` | 1–25 chars, unique within the card |
| `options[].detail` | 0–60 chars. `""` when there's no detail |
| `options[].recommended` | boolean, `true` on at most one option. Approval cards recommend nothing |
| `allowFreeText` | boolean: may the user answer with **text instead of** an option? A note that comes with an option is always accepted |
| `reply` | Optional choice-card extension: Bob's answer, ≤ 4000 UTF-16 code units, paragraphs preserved. Oversized replies rejected, not truncated. Show above actions; do not accumulate chat history. |
| `acceptsVoice` | Optional boolean; new MCP choice cards set true by default, explicit `accept_voice: false` opts out. Older/missing fields decode as false. Only `choice` cards can wait for a voice instruction as an alternative to a button. |
| `expiresAt` | ISO 8601 UTC **without fractional seconds** (`2026-09-26T14:05:00Z`, works with Swift `.iso8601`). The app should also accept `null` (no expiry) |

Over-long text (title, context, labels, details, explanations) is cut at a word boundary
and ends with `…`. Commands are never cut: a too-long command is refused before a card is sent.

**Answer** (same for both kinds):

```json
{ "type": "decision_response", "id": "d_43", "optionId": "approve_for_task", "text": null }
```

`text` may be omitted, `null`, or a note (≤ 500 chars).

## 5. Push notifications

For every `notify` and `decision_request` the relay pushes to each `pushTopic` of the room,
whether or not the app is connected. If the app is in the foreground it will get both,
so dedupe or suppress in-app as you prefer.

**ntfy for native Alice** (`pushClick: "bobcompanion://open"`): all choices and approvals
use title "Alice · Bob needs you" and body "Take action". This is independent of
the workflow, ACP source or `PUSH_DETAILS`; question titles, commands and
recommendations stay inside Alice. Status titles are "Alice · Task complete", "Alice · Bob needs a hand"
or "Alice · Update from Bob" according to level. Normal alerts have no emoji
tags; high-risk requests retain the warning tag and urgent priority.

**ntfy for web pairing** (`pushTopic` = topic name): title = card title (or "Bob" / "Bob: done" /
"Bob: failed"), message = `$ command` (if any) + context + "Recommended: …". Priority is 4,
or 5 for high risk. If the relay has `PUBLIC_URL` set, cards get up to 3 **action buttons**
(recommended first, marked ★; approval cards: Approve once / Approve for task / Reject).
**High-risk cards get no buttons**, so the answer has to go through the app's confirmation. Each is a one-time `POST {PUBLIC_URL}/a/<token>/<optionId>`, so the
user can answer straight from the lock screen. The resulting `decision_response`
arrives at Bob with `"via": "push"`. Tapping the notification body opens `PUBLIC_URL/`.

**Expo** (`pushTopic` = `ExponentPushToken[…]`): `title`, `body`, `priority: high`,
`sound: default`, and `data: { type, id }` for cards / `data: { type }` for notify. On tap,
open the app and connect; the card is re-sent on connect.

With `PUSH_DETAILS=0` on the relay, push texts are generic ("Bob needs a decision") and
no card content leaves the relay.

Replayed cards are not pushed repeatedly to the same topic. Native Alice topics use `bobcompanion://open` and no action buttons. ntfy must be installed/subscribed separately; this is not native APNs for Alice.

## Same-chat phone conversations

`ask_decision` accepts optional `reply` and `accept_voice` MCP arguments. They become
`reply` and `acceptsVoice` on the existing choice card. Voice is enabled by default
even when the model omits `accept_voice`; explicit false opts out. No extra MCP tool, second Bob
session or relay connection is created. The mode supplies a 300-second wait
(maximum 540 seconds in this workspace), below the IDE's 600-second MCP timeout.

While that tool call is open, `instruction` with `source: "voice"` is queued and
acknowledged as usual, then the oldest queued voice input resolves one eligible
choice with an instruction result in the **same IDE chat**. The server withdraws
that card with `decision_expired(reason: "voice_input")`. There is no decision ack,
selected option or permission grant for that card. Duplicate input UUID/text
retries are acknowledged without replaying a conversation turn. Inputs without
`source: "voice"` keep the existing polling behavior. The original source is kept
on retries; resending a legacy input ID does not upgrade it into voice.

Speech received during work or a command approval stays queued until Bob calls
`get_instruction` or a voice-enabled choice. It never resolves `request_approval`.
If a tap wins the race, a later voice input remains queued for the next step;
if voice wins, stale taps receive `decision_expired`. Opening a voice wait while
another request is pending is rejected by the MCP tool. Do not use this shared
pairing concurrently from multiple IDE tasks.

Companion mode requires English titles, replies, context, option labels/details
and notifications. User transcripts remain verbatim; no hidden translation is
applied. Bob writes his actual English response in the IDE and passes it in the next
`ask_decision.reply`, together with context-appropriate actions and a stop option.
Alice shows this answer and its actions as one current card. The next card replaces
it after resolution; no fabricated response or transcript history is generated.
Bob's decision to call the tool remains agent-driven, governed by Companion mode.
A stop choice/spoken task stop ends the current work with a final `notify`, then
Bob calls `get_instruction(wait_s: 540)` for quiet standby. Card timeout selects
**no fallback action** and enters standby rather than reopening choices. Explicit
stop-listening/disconnect and IDE cancellation end the listener.

This does not wake a completed IDE task. Starting/resuming from the IDE and keeping
the wait active are required. Ordinary Stop here leaves the IDE task in a pending
MCP call so later voice can start new work. Queue and dialog state remain in memory; restarting
MCP loses queued input. Reconnecting a phone to the same running MCP resends the
whole open card, including reply text and voice capability.

### Quiet standby after a task

`get_instruction` with no arguments defaults to a 540-second voice wait. This
prevents callers that omit the optional argument from checking once and falsely
claiming standby. Only explicit `wait_s: 0` performs an immediate queue pop
(use this between ongoing work steps). A positive integer `wait_s`
(1–540 seconds, also capped by `MAX_DECISION_TIMEOUT_S`) waits for a `source: "voice"` instruction without
a card. This requires a connected relay and an already paired phone session; the
phone may be temporarily backgrounded. Only one wait may own the queue, and it
cannot coexist with a pending decision. Normal queue polling refuses to steal
input while standby owns it. Approval requests during standby cannot be approved.

Starting standby clears command approvals from the finished task. It sends
`voice_status` with a deadline, but no `notify`, no new card and no push, so Alice
keeps the last work result under “You're in the loop”. Phone reconnect receives
the current listener status after the decision snapshot. On voice consumption,
timeout, cancellation, server stop or relay disconnect it sends a null deadline
(where the transport is available) and cleans up the wait. iOS also clears stale
readiness on local disconnect/expiry.

A voice input (including one queued just before standby) resumes the same MCP
call exactly once. Bob evaluates it as fresh work, with fresh required approvals.
A simple answer can use an English `notify` (existing 200-character limit), then
return to standby; tasks needing choices continue through `ask_decision`.
No arbitrary natural-language command is run by the server itself.

On an ordinary standby timeout, Bob is instructed to renew `get_instruction`
without posting another result or performing work. These renewals require an
active IDE agent turn and may cause a model turn at most once per wait interval;
they are not a background wake-up API. The MCP timeout remains finite and below
the IDE's 600-second timeout, with progress every 15 seconds when supported.
IDE cancellation, explicit end-session/stop-listening, or loss of the relay ends
standby without automatic renewal. The user can resume from the IDE later.

## 6. Voice tokens and instructions

After an authenticated phone hello:

```json
{ "type": "voice_session_request", "id": "<unique-request-UUID>" }
```

The relay, when configured with `ASSEMBLYAI_API_KEY`, calls the regional AssemblyAI `/v3/token` endpoint and responds **only to the requesting socket**:

```json
{
  "type": "voice_session", "id": "<same-request-UUID>",
  "token": "<temporary-single-use-token>", "expiresAt": "2026-09-26T20:00:55Z",
  "websocketURL": "wss://streaming.eu.assemblyai.com/v3/ws",
  "speechModel": "universal-3-6-pro"
}
```

The token redemption window is 60 seconds (55 reported conservatively); provider session cap is 180 seconds. Alice records at most 120 seconds. The relay limits issuance to one concurrent request and one request per five seconds per room, times out upstream after 12 seconds, and sends an `error` with the matching ID on failure. No provider secrets or errors are forwarded/logged. Region/model are environment settings. The relay only permits `decision_response` and `instruction` through from phones; token/revocation requests are handled locally.

Once transcription finishes and the user confirms, Alice sends the existing `instruction` message with its UUID, text and `source: "voice"`. A matching `ack` becomes `VoiceInputReceipt(status: "accepted")`. Instructions over 500 UTF-16 code units are rejected, never silently truncated. No task ID exists in this protocol yet. Tokens and transcript messages are not approval grants.

## Testing without Bob

Quickest: `cd backend && npm install && npm run dev` (relay + fake Bob, pairing links point at this
machine's LAN IP so an iPhone on the same Wi-Fi can connect). Or step by step:

```sh
cd backend
npm install
npm run relay                                  # relay on 0.0.0.0:8787
RELAY_URL=ws://<relay-host>:8787 npm run demo:bob       # fake Bob: prints QR + links
#   keys: d = choice card, a = approval card, h / x = high-risk choice / approval,
#         n/s/e = notify info/success/error
#   or unattended: npm run demo:bob -- --loop 20
node tools/mock-phone.js '<link>'              # terminal phone, if you need one
```

`fake-bob` uses the same card normalizer and session code as the real MCP server, so its
messages match production exactly. One sample card is deliberately too long, to show trimming.
# ACP desktop adapter extension

The separate PC chat described in [ACP_CHAT.md](ACP_CHAT.md) owns a dedicated relay
session and forwards actual ACP `session/request_permission` requests. It uses
the existing approval card envelope with an optional `source: "acp"` field.
For these cards, `command` is the complete operation input plus supplied text/diff
content, limited to 24,000 characters / 30 KB of JSON-encoded text. MCP-generated
command cards retain their existing 500-character limit. The Swift decoder
already accepts the longer string and ignores the optional source field.

ACP cards offer only `approve_once` and `reject`; the adapter maps them to the
original ACP `allow_once` / `reject_once` option IDs. Tool-wide `allow_always`
is not equivalent to command-specific `approve_for_task` and is not offered.
The adapter sends `ack` only after writing the selected JSON-RPC response to Bob;
this confirms decision delivery, not successful tool execution. Invalidated
requests emit `decision_expired` (`cancelled`, `timeout`, or `delivery_failed`).
ACP push notifications omit complete operation input/diffs and direct the user
to Alice. Pairing and push subscriptions otherwise use the existing protocol.
