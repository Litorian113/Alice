# Voice input and backend integration

Status: iOS implementation prepared; no backend is configured or deployed. No API key is included. `AliceApp` still creates the default, fixture-backed `AliceSessionStore()` and the microphone sheet therefore shows “Voice input isn't connected yet.” Enabling voice requires both injected services and a real paired session context.

This is speech-to-text for feedback/instructions to Bob, not a separate conversational agent. Voice input does not approve a command. The existing explicit approval actions remain separate.

## Local API key

The repository root contains an ignored `.env` for local secrets. On a fresh checkout, copy `.env.example` to `.env`, then set `ASSEMBLYAI_API_KEY` there. Only the empty `.env.example` belongs in Git; `.env` and environment-specific variants are ignored.

This file is reserved for the future backend token service. No process in this repository loads it yet, and adding the key alone does not activate voice input. The backend integration must explicitly load the environment variable. Never bundle `.env` in the iOS target or copy the permanent key into Swift, Info.plist or Xcode build settings.

## Flow

```text
Start speaking → microphone permission → backend issues temporary token
    → AssemblyAI WebSocket opens → microphone audio → live transcript
    → Stop → final transcript → review → Send to Bob
    → backend accepts input → relay/MCP delivers to Bob (backend responsibility)
```

Audio goes directly from the phone to AssemblyAI. Only reviewed text goes to the Alice backend. The app does not save audio files or persist transcripts. Closing the sheet discards the draft. Nothing is automatically submitted when recording ends.

## Replaceable Swift interfaces

All interfaces are `@MainActor`; implementations live in `Alice/Voice/`.

| Interface | Current implementation | Responsibility |
| --- | --- | --- |
| `VoiceRecording` | `MicrophoneRecorder` | Permission, AVAudioEngine capture, mono PCM conversion, stop/flush. |
| `SpeechTranscribing` | `AssemblyAITranscriber` | Temporary-token WebSocket, ordered audio sends, turn updates, graceful termination. |
| `VoiceSessionProviding` | `HTTPVoiceBackend` | Ask our authenticated backend for a streaming session. |
| `VoiceInputSending` | `HTTPVoiceBackend` | Deliver reviewed input and validate acceptance receipt. Can be replaced by a relay WebSocket adapter. |
| `VoiceServices` | Injected dependencies/factories | Keeps provider and transport choices out of views. |
| `VoiceInputModel` | Sheet state machine | Record, finalize, review, send, cancel, retry. |

No hostname for the Alice backend, session ID, task ID, model choice or API secret is embedded in the UI. AssemblyAI's supported WebSocket hosts are validated within its provider adapter.

## Proposed backend contract

These endpoints are a proposal for Christopher, **not existing server APIs**. `HTTPVoiceBackend` accepts complete URLs, so route names can change without changing views. Dates are ISO 8601 UTC (token expiry accepts timestamps with or without fractional seconds). Every request must authenticate the paired user/device; the backend must verify session/task ownership and reject stale context.

### 1. Create a voice session

Suggested route: `POST /v1/voice/sessions`.

```json
{
  "context": {
    "sessionId": "session_42",
    "taskId": "task_7",
    "decisionId": "approval_42"
  }
}
```

`sessionId` is required. `taskId` and `decisionId` are optional and omitted by Swift's encoder when absent. Use IDs received from pairing/relay events, never the UUIDs from local approval fixtures. Context is captured when the sheet opens; a relay context change must close the old sheet via `updateVoiceContext(_:)`.

Example response (expiry must be in the future):

```json
{
  "token": "SHORT_LIVED_SINGLE_USE_TOKEN",
  "expiresAt": "2026-09-26T19:30:00Z",
  "websocketURL": "wss://streaming.eu.assemblyai.com/v3/ws",
  "speechModel": "universal-3-6-pro"
}
```

The backend stores `ASSEMBLYAI_API_KEY` in its secret configuration. It calls AssemblyAI's regional `GET /v3/token` with `expires_in_seconds=60` and `max_session_duration_seconds=180`, using the raw key in the `Authorization` header (no Bearer prefix). Return only the temporary token and configuration. Mint a fresh token for every recording; never log the token or the authenticated WebSocket URL. Disable response caching (`Cache-Control: no-store`).

EU is the proposed region for this project; Christopher should confirm it and use matching token/WebSocket regions. The phone also supports AssemblyAI's global and US hosts. The model is selected by the backend. Live documentation currently lists `universal-3-6-pro` as recommended and `universal-3-5-pro` from the pasted guide as supported. Both support German/English; no language restriction is sent by the app.

### 2. Deliver reviewed input

Suggested route: `POST /v1/inputs`. Header: `Idempotency-Key: <input UUID>`.

```json
{
  "id": "749E506E-04B7-4B95-9E7A-9D5ED9B3535A",
  "type": "user_input",
  "source": "voice",
  "context": {
    "sessionId": "session_42",
    "taskId": "task_7",
    "decisionId": "approval_42"
  },
  "text": "Please also check sign-in on smaller screens.",
  "createdAt": "2026-09-26T19:30:00Z"
}
```

Success response: HTTP 2xx with this body:

```json
{
  "inputId": "749E506E-04B7-4B95-9E7A-9D5ED9B3535A",
  "status": "accepted"
}
```

`accepted` means the backend has accepted responsibility for delivery, not that Bob executed anything. The app only shows success for a matching input ID and status. A bare 204, mismatched ID or other status is not a valid receipt. Backend delivery to Bob, queue retention and `get_instruction` mapping still need implementation.

Deduplicate by authenticated session + input ID, and return the same receipt for retries. If the same ID is reused with different text/context, reject it. A network timeout may occur after acceptance: the app retains the exact payload/UUID and lets the user retry. Do not interpret a spoken “approve” as an approval response; command/task permissions must use the separate approval contract and server checks.

Non-2xx responses, decoding failures and unconfirmed delivery show an error. The adapter uses a 20-second request timeout and does not automatically retry. Agree on structured backend error codes later for expired pairing, stale task, rate limits and unavailable Bob sessions.

## Wiring after pairing is available

Configure once in `AliceApp` (or a new composition root), using real endpoints and the relay's auth provider. This is an illustrative factory; the URLs and auth closure come from the backend integration:

```swift
@MainActor
func makeStore(
    sessionEndpoint: URL,
    inputEndpoint: URL,
    authorize: @escaping HTTPVoiceBackend.Authorize
) -> AliceSessionStore {
    let backend = HTTPVoiceBackend(
        sessionEndpoint: sessionEndpoint,
        inputEndpoint: inputEndpoint,
        authorize: authorize
    )
    return AliceSessionStore(
        voiceServices: VoiceServices(sessions: backend, inputs: backend)
    )
}
```

The auth closure adds **Alice backend credentials**, not the AssemblyAI key. It can obtain refreshed credentials from the future pairing/account layer. Both endpoints must use HTTPS.

After a verified pairing/relay event, call:

```swift
store.updateVoiceContext(VoiceContext(
    sessionId: pairedSessionID,
    taskId: activeTaskID,
    decisionId: activeDecisionID
))
```

When the task/session changes, update context; for disconnection call `store.disconnect()`, which clears voice context and closes the sheet. Local `connectSession()` does not establish a real voice context. The existing `isConnected` fixture flag is insufficient to enable voice by itself.

## Audio and lifecycle

- Capture starts only after explicit Start, microphone permission and AssemblyAI `Begin`.
- AVAudioConverter handles the hardware rate; output is 16 kHz mono signed 16-bit little-endian PCM, in 100 ms binary frames. Final audio is flushed and the last short frame is silence-padded.
- A bounded audio buffer fails visibly if the network cannot keep up. Audio sends are sequential.
- Repeated `Turn` events replace by `turn_order`, so partial/final/formatted updates do not duplicate text.
- Stop drains audio and sends `Terminate`; review/send unlock only after final turns and `Termination`. A missing final or timeout cannot silently send a truncated transcript.
- Recording stops after 120 seconds. Connection setup times out after 15 seconds; finalization has a 15-second overall deadline and a 10-second termination deadline. Backend tokens should cap the provider session at 180 seconds.
- Closing, backgrounding, interruptions, loss of the current input device and errors stop capture and attempt termination. A fallback closes the socket after two seconds. The connection also requests a 15-second provider inactivity timeout.
- No background recording or auto-reconnect. Start again explicitly with a fresh token. The system microphone permission prompt does not cancel initial setup.
- Permission denied offers Open Settings. No Apple Speech permission is needed because AssemblyAI handles transcription.
- No speech output/TTS, automatic approvals, transcript editing, chat history, durable outbox or offline transcription is included.

## Other interfaces still to connect

| Area | Current seam / next contract |
| --- | --- |
| Pairing/session | Replace fixture connection with verified relay session IDs and device authentication. Call `updateVoiceContext` on context changes. |
| Approval requests | `DecisionCard` and README's `decision_request`; configure ISO dates, expiration and missing-field compatibility before decoding live traffic. |
| Approval responses | `DecisionResponse`; `approve_once`, `reject`, `approve_for_task` remain distinct. Add real transport and acknowledgement. |
| Voice input | `VoiceInputSending` / `user_input` above; backend maps accepted input to Bob's `get_instruction` flow. |
| Usage | Replace `UsageData` fixtures with server totals, periods and Bobcoins. No usage endpoint specified yet. |
| Push/reconnect | Device registration, queue replay and stale request handling remain backend integration work. |

## Targeted verification

No paid AssemblyAI call is made during preparation. Once connected, verify on iPhone: German/English dictation, final words after Stop, permission denial, close/background during recording, network loss, and retry after an unconfirmed send. Confirm that the backend receives each input only once and that closing the sheet ends the provider session. The default unconfigured app must never request microphone access or claim input was sent.

Official references checked during implementation:

- [Documentation index](https://www.assemblyai.com/docs/llms.txt)
- [Streaming model selection](https://www.assemblyai.com/docs/streaming/select-the-speech-model)
- [WebSocket protocol](https://www.assemblyai.com/docs/streaming/api-spec/streaming-websocket)
- [Temporary tokens](https://www.assemblyai.com/docs/streaming/authenticate-with-a-temporary-token)
- [Token endpoint and duration limits](https://www.assemblyai.com/docs/streaming/api-spec/generate-streaming-token)
