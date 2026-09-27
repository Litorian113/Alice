# Voice integration

Voice is wired through the authenticated relay connection. Setup and the real-device walkthrough are in [IPHONE_TEST.md](../../docs/IPHONE_TEST.md); the wire contract is [PROTOCOL.md](../../docs/PROTOCOL.md#6-voice-tokens-and-instructions).

## Configuration

Set `ASSEMBLYAI_API_KEY` in the ignored repository-root `.env`. Local `backend/relay/server.js` and `backend/tools/dev.js` load it; deployment uses the host environment. Optional values:

```dotenv
ASSEMBLYAI_REGION=eu
ASSEMBLYAI_SPEECH_MODEL=universal-3-6-pro
```

Restart the relay after changes. `paired.voiceAvailable` tells Alice whether tokens are enabled. The phone holds only temporary tokens; never copy the permanent key into Swift, Info.plist or the app bundle. No real AssemblyAI request is made until the user starts speaking.

## Runtime flow

```text
Alice → voice_session_request over authenticated relay WebSocket
  ← voice_session with temporary token, expiry, provider URL and model
  → AssemblyAI streaming WebSocket + microphone → live transcript
  → Release (or Stop) → finalized transcript → user reviews → Send to Bob
  → instruction with stable input UUID → MCP queue → ack
  → open voice-enabled ask_decision returns the instruction in the SAME Bob chat
  → Bob writes his response and calls ask_decision(reply, accept_voice=true, options)
  → next answer/actions replace the current card; Stop here ends the dialog
  (Without an open voice wait: get_instruction between steps / next voice dialog)
```

Token messages are handled by the relay and returned only to the requesting phone, never forwarded to Bob or other phones. Text uses `instruction`/`ack`. This is feedback/input, not a command approval and not a separate voice agent. There is no TTS or spoken reply.

## Replaceable Swift interfaces

All interfaces are `@MainActor`; implementations live in `Alice/Voice/`.

| Interface | Runtime implementation | Responsibility |
| --- | --- | --- |
| `VoiceRecording` | `MicrophoneRecorder` | Permission, AVAudioEngine capture, PCM conversion, stop/flush |
| `SpeechTranscribing` | `AssemblyAITranscriber` | Temporary-token WebSocket, audio, turn updates and termination |
| `VoiceSessionProviding` | `RelayVoiceBridge` | Request streaming credentials through the paired relay |
| `VoiceInputSending` | `RelayVoiceBridge` | Send reviewed text and await matching acknowledgement |
| `VoiceServices` | Factories assembled by `AliceSessionStore` | Keeps provider/transport choices out of the view |
| `VoiceInputModel` | Inline voice state machine | Record, finalize, review, send, cancel, retry |

`HTTPVoiceBackend` remains an unused alternative for a future HTTP transport. Its constructor takes explicit HTTPS session/input endpoints and an auth closure. The old proposed `/v1/voice/sessions` and `/v1/inputs` routes were **not** implemented; wiring now uses WebSocket messages. Switching transport means supplying different `VoiceServices` in `makeVoiceInput()`, not changing the voice UI.

Session ID comes from Keychain pairing; decision ID is the active card. The relay has no task ID. Its `instruction` contains `type`, `id`, `text` and `source: "voice"`, so per-task/decision routing is not asserted.

## Delivery guarantees and limits

- A matching `ack` means the running MCP process accepted the input into its memory queue, not that Bob already consumed/executed it.
- Retry preserves the exact UUID and text. The MCP process deduplicates matching retries, including after consumption, and rejects conflicting reuse.
- Receipts/queue are not persisted across MCP restarts. Queue limit: 100 waiting inputs; receipt limit: 2,000 per process. Durable delivery remains future work.
- Maximum input is 500 UTF-16 code units (backend JavaScript string limit). Overlong speech must be recorded again more briefly; neither side silently truncates it.
- Closing inline voice or switching tabs discards the draft. A failed send retains it for retry while voice remains open. Tab switching and closing are disabled during delivery.
- Network/relay errors and a 20-second acknowledgement timeout never produce a success message.

## Audio and lifecycle

- Hold the navigation microphone for 0.25 seconds to start; release to finalize and review. Tapping opens inline Start/Stop controls as an accessible alternative. Capture begins only after microphone permission and AssemblyAI `Begin`. Releasing during setup cancels it, so delayed permission/token results cannot start a microphone later.
- The store owns the inline voice model. Incoming decisions remain queued until it closes; matching input acknowledgement shows confirmation for 1.5 seconds, then returns to status/decisions. New MCP choice cards enable voice by default (explicit false opts out). A voice-enabled `ask_decision` resumes immediately with the input; otherwise Bob needs `get_instruction` or a new voice-enabled choice. Bob returns his answer through `ask_decision.reply` and its actions. This remains the same active IDE chat, but does not wake a completed task or mirror the full transcript.
- Hardware audio is converted to 16 kHz mono signed 16-bit little-endian PCM; binary frames are 100 ms. Stop flushes the converter and silence-pads the final short frame.
- Ordered sends and a bounded two-second audio buffer prevent unlimited backlog; overflow reports an error.
- Turn updates replace earlier versions by `turn_order`, including formatted finals. They do not append duplicates.
- Stop sends `Terminate` after draining audio. Send unlocks only after final turns and `Termination`; incomplete transcripts cannot be submitted.
- Recording cap: 120 seconds. Connection timeout: 15 seconds. Overall finalization timeout: 15 seconds; termination timeout: 10 seconds.
- Tokens redeem within 60 seconds; relay reports 55 conservatively and caps provider sessions at 180 seconds. Issuance is limited per room and never automatically retried.
- Closing/backgrounding, audio interruption and input device removal stop capture and attempt termination, with a socket-close fallback. No background recording or auto-reconnect.
- Audio is never written to disk. The microphone permission prompt does not cancel initial setup.
- No chat history or transcript editor is added. User can record again before sending.

## Verification

The Swift app was typechecked against the iOS SDK. Backend tests stub the provider to verify authenticated token issuance, caller-only delivery, rate limiting and instruction deduplication. Live audio, microphone behavior and actual phone delivery require the iPhone walkthrough; they were not claimed as tested automatically.

Official references: [model selection](https://www.assemblyai.com/docs/streaming/select-the-speech-model), [WebSocket API](https://www.assemblyai.com/docs/streaming/api-spec/streaming-websocket), [temporary tokens](https://www.assemblyai.com/docs/streaming/authenticate-with-a-temporary-token), [token endpoint](https://www.assemblyai.com/docs/streaming/api-spec/generate-streaming-token).

Phone dialog copy is English. Generated Bob replies/actions are instructed to be
English even for non-English input; the speech transcript is preserved verbatim.
If the active card cannot accept voice (approval, explicit opt-out, or an older
MCP card), review explains that sending queues the instruction rather than
immediately continuing Bob.
