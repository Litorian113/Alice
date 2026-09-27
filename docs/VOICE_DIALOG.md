# Voice follow-ups in the same IBM Bob IDE chat

This is a reusable conversation loop, not a scripted README demo. Bob keeps the
same IDE task and context. Alice displays the current answer and actions; it does
not create another Bob session or accumulate a chat history.

## Prepare once after updating

1. Build/run the current iOS app on the iPhone. It marks spoken instructions with
   `source: "voice"` and displays Bob's optional reply on decision cards.
2. Keep the existing relay running. No relay behavior or credentials change.
3. In Bob's MCP settings, restart **bob-companion** so `ask_decision` exposes its
   new `reply` and `accept_voice` arguments. Restart only between tasks: its input
   queue is in memory. Reuse the existing pairing.
4. Select **📱 Companion**. For an existing conversation, include the explicit loop
   instructions below so they apply even if its mode prompt was cached. If Bob
   asks permission for the MCP tool, allow it for this task.

Do not start the separate ACP browser chat for this flow. Do not run multiple
Companion chats against the same pairing at once.

## Demo starting at the PC

Choose any topic and output path. This is an example prompt to paste into Bob,
not code that determines the application's behavior:

> Create `docs/voice-demo.md` as a clear README about starting a small community
> garden. First ask me a useful question about the target audience through Alice.
> I will then continue from my phone. Keep this same IDE conversation.
> Use English for the README and every dialog message, title, option and reply.
> Every selection button and its description must be English too, even if I
> speak German. Do not reuse German labels from previous cards.
> Use `ask_decision` with `timeout_s: 300`, your actual answer in `reply`, and 2–4
> relevant actions including “Stop here”. Voice replies are enabled by default;
> you may explicitly set `accept_voice: true`. Write your answer here in chat too.
> When a voice instruction arrives, make the requested change in the same context,
> then send the new result and actions to Alice. Keep command approvals separate.
> Stop on “Stop here” or timeout; never select an action automatically.

On the phone:

1. Answer Bob's initial choice. Bob creates the requested document using his
   normal tools and permissions.
2. Read the result on Alice. The card includes a hint that voice is available.
3. Hold the microphone, speak a real change such as “Please add a specific materials
   list and a rough cost estimate for ten participants.”, release, review and Send to Bob.
4. The open choice is withdrawn and the MCP call returns the voice instruction
   to the same Bob chat. Alice waits for the actual response.
5. Bob edits the file and sends his response plus fresh actions. Ask another
   change by voice or choose a relevant action. Choose Stop here to finish.

The topic, files, response text and actions all come from the conversation. Only
the transport, waiting behavior and card rendering are implemented by Alice.

## Runtime behavior and limits

- `ask_decision` enables voice by default, even when Bob omits `accept_voice`.
  Only explicit `accept_voice: false` opts out. Older iOS cards without
  `acceptsVoice` still decode as false; update/restart MCP to create a fresh card.
- A voice-enabled `ask_decision` waits for a button **or** queued voice, with
  progress keepalives. Default mode wait: five minutes; configured cap: nine.
- Voice is an instruction, never approval. While `request_approval` is open,
  speech remains queued; approve/reject explicitly before proceeding.
- Inputs received while Bob works can be read with `get_instruction` or consumed
  by the next voice-enabled choice. They do not create a parallel agent turn.
- Input: 500 UTF-16 code units. Reply: 4000, with paragraphs preserved. Bob should
  send a complete concise answer, not a large file dump. Files remain in the repo.
- Retry IDs prevent double execution of the same queued input within the running
  MCP process. Reconnect restores open reply cards. Restart loses in-memory input.
- A timeout or cancelled tool call ends the wait without choosing an action.
  To resume a finished IDE turn, send “Resume our Alice conversation, using English for all replies and actions.” at the PC.
  There is no automatic wake-up API for completed IDE chats in this integration.
- Bob must call the tools as instructed. This is an agent-driven MCP conversation,
  not a forced mirror of every IDE message or every native permission prompt.

## Verified versus still manual

Automated checks cover the actual MCP stdio process and local WebSocket relay:
reply delivery, voice returning to the waiting call, replacement reply/actions and
a stop selection. Additional tests cover duplicates, stale taps, queued speech
during approval, timeout/cancel and reconnect snapshots. iOS is typechecked.

These tests do not prove that a real Bob model follows every instruction or that
speech recognition/haptics work on the physical iPhone. Run the above walkthrough
before recording the video. No live README modification or phone success is
fabricated by the test harness.

Wire details: [PROTOCOL.md](PROTOCOL.md#same-chat-phone-conversations).

## Diagnosed issue: voice queued while four choices remained

The real IDE tool arguments omitted both `accept_voice` and `reply`, so the former
opt-in implementation left Bob waiting for a button. Normal choice cards now
enable voice by default. The regression test uses the same old argument shape
without either field, then verifies voice resumes the MCP call. All 57 backend
tests pass, including command approval isolation. Command approvals
remain unchanged. Logs record the input source and successful dialog consumption.

All generated dialog fields should be English via Companion mode and MCP tool
instructions. The app does not silently translate the recorded transcript or
existing cards. Speak English for an entirely English demo; multilingual input
can still be understood, with Bob instructed to reply in English.
