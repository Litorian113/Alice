# Bob → iPhone → Bob: live test

Alice now pairs with the relay, receives real choice/approval cards and sends decisions back. The app closes a card only after Bob acknowledges it or it expires. No approval fixtures are loaded at startup.

## 1. Start the local relay

From the repo root:

```sh
cd backend
npm ci
npm run dev -- --no-bob --configure-bob
```

Keep this terminal running. The command prints the Mac's LAN address and writes it to the ignored `.bob/local-relay.json`. The shared `.bob/mcp.json` keeps the production URL; the MCP server reads this local override when present. Mac and iPhone must use the same Wi-Fi. Disable Wi-Fi client isolation if your network blocks device-to-device connections.

`--no-bob` means the relay waits for **real IBM Bob**. The fake Bob is not started. Without this flag, `npm run dev` still provides Christopher's fixture-driven backend for development.

On 26 September, the public relay's `/healthz` returned HTTP 503 during integration. Check it again before switching to production. To switch, remove `.bob/local-relay.json`, restart the MCP server in Bob and generate a new QR page with the updated relay URL. A phone paired to the local URL needs to scan the production URL again.

## 2. Open the project in IBM Bob

Open the **repository root**, `/Users/franzos/Desktop/Alice`, in IBM Bob (not just `ios/`). Select **📱 Companion** mode. The repository's `.bob/mcp.json` registers `bob-companion`; restart this MCP server after changing local relay configuration. If Bob reports a missing Node command, ensure Node 22+ is installed and visible to Bob.

Keep `"cwd": "."` in the MCP server configuration. Bob IDE resolves this against the workspace root; without it, the server can start in `/` and fail with `Cannot find module '/backend/companion-mcp/index.js'`. This was corrected and the real IDE logged both `Session connected` and `phone paired (1 connected)` on 26 September 2026.

**Verified on 27 September 2026:** the existing IBM Bob IDE chat called `ask_decision` with the button-color question below. Franz selected **Blau** on his physical iPhone; the MCP log recorded that choice and Bob confirmed it in the same IDE chat. The IDE required **Approve once** for this MCP call despite the configured `alwaysAllow` list. This test validates explicit MCP questions; native IDE command approvals remain separate.

Stop the ACP browser chat before this IDE test. In the installed Bob Shell 2.0.5, its child process started the repository MCP server despite `--disable-mcp`. Both MCP instances used the IDE session and repeatedly displaced each other (`4000 replaced`). Stopping the browser chat and its children resolved this conflict. Use `pair:show` below to switch Alice back to the IDE pairing.

First chat prompt:

> Rufe `pair_phone` auf und zeige mir den QR-Code. Ich verbinde jetzt mein iPhone mit Alice. Ändere keine Dateien und warte auf meinen nächsten Chat-Auftrag.

For a larger, clean QR code in a browser, use another terminal:

```sh
cd backend
npm run pair:show
open ../.bob/pairing.html
```

The page uses the same `.bob/companion-session.json` as Bob. If no session exists, it creates the credentials before Bob starts. It renders the QR locally; no secret is sent to a QR service. The HTML and session file contain pairing credentials and are ignored by Git. Do not share them. `pair:show` alone does not start Bob or create a live connection.

## 3. Install Alice on your iPhone

```sh
open ios/Alice.xcodeproj
```

Select your iPhone in Xcode and Run. Keep the existing bundle ID and signing team. On first launch, Alice shows the new start screen and then **Scan Bob's QR code**. Allow camera and local network access, scan the PC's QR, check the displayed relay host and tap **Connect to Bob**.

You can also scan with the system Camera app (`bobcompanion://` QR), or paste the pairing link via the Paste button. The in-app scanner accepts both app links and the relay web links. Credentials are kept in the iPhone Keychain. Returning to the app reconnects automatically.

If Alice says **Waiting for Bob**, check the running relay terminal and that `bob-companion` is connected in Bob. A saved QR is not proof of a running MCP session. If prompted by macOS, allow Node's incoming local network connection.

## 4. Set up notifications without a paid Apple account

1. In Alice, open **Profile → Notifications**.
2. Install the free **ntfy** iOS app using the link, and allow its notifications.
3. Copy the topic shown by Alice. In ntfy, subscribe to that exact topic on **ntfy.sh**.
4. Back in Alice, enable **Send me notifications**.

The popup is delivered by **ntfy**, not a native Alice APNs notification. It includes an Alice link; if your ntfy/iOS version opens its own detail page, open Alice manually. Alice reconnects and shows Bob's still-pending card. Native Apple Push directly for Alice remains a separate paid-Developer-Program integration; no push entitlement was added, so Personal Team signing remains usable.

Native Alice topics have no lock-screen approval buttons. Decisions are made in Alice, including confirmation for high-risk actions. Disabling notifications or forgetting a session attempts to unregister the topic while connected. If the phone was offline, unsubscribe from the old topic in ntfy as well. `PUSH_DETAILS=0` on the relay uses generic notification text.

## 5. Round trip from the Bob chat

After pairing and notification setup, put Alice in the background or lock the phone. Send Bob:

> Teste jetzt nur die Verbindung zu Alice. Rufe `ask_decision` mit dem Titel „Welche Farbe soll der Button haben?“, den Optionen „Blau“, „Violett“ und „So lassen“ und `timeout_s: 540` auf. Warte auf meine Antwort vom iPhone. Ändere keine Dateien. Bestätige anschließend im Chat genau die empfangene Auswahl. Danach ist der Test beendet, ohne weitere Rückfragen.

Expected: ntfy popup → open Alice → tap an option → Alice shows receipt confirmation → Bob repeats that choice in the PC chat.

To test the command UI, ask Bob to call `request_approval` with a harmless exact command and wait for the phone response. Start with **Reject** if you only want to verify response routing.

**A normal Bob chat question is not automatically intercepted.** Companion mode directs Bob to use `ask_decision` and `request_approval`. These tools produce the phone cards. The MCP server gives Bob the decision; Bob's own tool policy still governs execution.

## 6. Voice

The local relay and dev runner load the repository-root `.env`. Set `ASSEMBLYAI_API_KEY` there and restart the relay. Optional settings are `ASSEMBLYAI_REGION=eu` and `ASSEMBLYAI_SPEECH_MODEL=universal-3-6-pro`.

Alice learns whether voice is available from the relay. Tap the microphone → **Start speaking** → allow microphone access → speak → **Stop recording** → review → **Send to Bob**. The relay gives Alice a short-lived token; the permanent key never reaches the phone. Speech is sent to AssemblyAI only after starting recording. The reviewed text is queued for Bob's `get_instruction`, not interpreted as an approval.

Try a short message (maximum 500 UTF-16 code units, matching the backend limit). Bob should call `get_instruction` between steps; for a direct check, ask him to retrieve and repeat the latest instruction. The queue is in memory and is lost when the MCP process exits. A receipt means the running MCP process accepted the input, not that Bob has acted on it.

## Verification in this change

- Swift typecheck against the iOS SDK, no simulator run.
- Backend tests cover the MCP/relay round trip, both card types, rejection, expiry, reconnect, native notification routing and voice-token handling with a stubbed provider.
- No live AssemblyAI audio request or actual ntfy/iPhone delivery was used as an automated test. The final real-device and Bob chat steps above are performed by Franz.

References: [ntfy iOS setup](https://docs.ntfy.sh/subscribe/phone/), [Apple memberships](https://developer.apple.com/support/compare-memberships/).
