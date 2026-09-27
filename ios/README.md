# Alice

**The mobile partner for IBM Bob.**

Bob works in your IDE. Alice brings the decisions that need you to your phone, so you can step away from the desk and keep things moving with a tap.

> **Bob builds. Alice keeps you in the loop.**

IBM Bob 2.0 Hackathon · September 2026

**Franz Anhäupl** — iOS app & interaction design

**Christopher Pietsch** — MCP server & relay

## Meet Alice

Alice and Bob are partners. Bob writes code, runs tools and handles the development task. Alice shows what Bob wants to do, explains the command in plain language and brings your decision back to him.

The name is a nod to the familiar Alice-and-Bob pair in computer science. Alice shares Bob's friendly robot style, with a violet shell, a turquoise `//` hair clip, a headset and an A badge.

## The experience

Alice opens on a single decision, with the exact command and an explanation of what it does. Three action bubbles keep the choice clear:

| Action | Intended permission |
| --- | --- |
| **Approve once** | Allow this command to run once; ask again next time. |
| **Approve for task** | Allow this command again during the current task. |
| **Reject** | Do not allow the command; Bob needs another approach. |

An info button explains the command's individual arguments. After Bob acknowledges a choice, Alice peeks over a feedback card with a different expression for each result, including X eyes for rejection. Feedback returns to the waiting screen (or the next queued request) automatically after five seconds. After two seconds, tapping anywhere in the main content dismisses it early. There is no extra heading or back button, chat history or text composer.

The bottom navigation provides:

- **Usage** — a three-day token graph with input/output curves, an hourly Today view and Bobcoins.
- **Alice** — the current decision and the companion. The center button becomes a microphone here; neither the face nor microphone has a visible label.
- **Profile** — session controls, a local display name, dark mode, haptic feedback and companion motion settings. Dark mode is saved on the phone; light mode is the default.

## Current status

Alice connects to the monorepo's MCP/relay backend. It starts unpaired, scans Bob's QR, stores credentials in Keychain and receives live choice/approval cards. Responses wait for Bob's acknowledgement; reconnect and expiry are handled. **The app does not execute commands itself.** Bob receives the decision and follows Companion mode's tool rules. Usage remains local: the Bobcoin snapshot (40 limit, 14 used, 26 remaining) comes from Franz's screenshot; the token graph for 25–27 September 2026 uses invented prototype data. Tokens are not calculated from Bobcoins, and there is no live Bobalytics connection.

Hold the microphone on the Alice page to speak: the button grows with haptic feedback, Alice listens and a live transcript appears inline. Release to review, then tap “Send to Bob”. A tap also opens accessible Start/Stop controls. After acknowledgement, Alice returns to updates and decision cards. Voice uses native microphone capture, AssemblyAI streaming and transcript review. The authenticated relay issues temporary tokens and forwards reviewed text to Bob. A voice-enabled choice can wait for that speech in the same active IDE conversation. Bob sends his next answer as reply text with fresh actions; the current card replaces the previous one. Command approvals still require an explicit choice. See [the voice dialog walkthrough](../docs/VOICE_DIALOG.md). Without a server-side API key it stays unavailable. Notifications use the free ntfy iOS app, configured under Profile. Native Alice APNs and IBM account sign-in are not implemented.

See [the iPhone/Bob test guide](../docs/IPHONE_TEST.md), [the shared protocol](../docs/PROTOCOL.md) and [Voice integration](docs/VOICE_INTEGRATION.md). The launch screen and splash always stay light. A centered Alice waves and winks above her name, with “The mobile partner for IBM Bob” at the bottom. Normal launches show the splash for 2.6 seconds before fading out; incoming pairing/notification links skip it. Reduce Motion and the companion-motion preference disable the greeting animation. There is no grid, glow, ring or extra slogan.

Local secrets go in the ignored repository-root `.env` (`ASSEMBLYAI_API_KEY`); copy [.env.example](../.env.example) on a fresh checkout. The local relay/dev runner loads it. Restart the relay after setting the key, then reconnect Alice.

Profile displays a simulated IBMid card with a local display name and the masked address `franz.anhaeupl@…`; it does not authenticate an IBM account. Tapping the card opens local account settings.

Returning to Alice never fabricates a request. Pending cards come from Bob. “Disconnect this session” clears its Keychain pairing; backgrounding preserves it and reconnects on return.

## Run the app

Requirements: macOS, Xcode 15 or newer, and an iPhone or simulator running iOS 17 or newer. There are no package dependencies.

The app lives in `ios/` of the monorepo. Open the project from the repository root:

```bash
open ios/Alice.xcodeproj
```

Select the **Alice** scheme, choose an iPhone or simulator, and press **Run**. For a physical iPhone, select your own development team in Signing & Capabilities. If needed, trust the developer certificate on the phone.

Project and product names are **Alice**. The bundle identifier remains `com.bobcompanion.app` to retain the existing installation and signing identity; it is the only intentional legacy brand identifier.

### Project generation

The Xcode project is tracked alongside its [XcodeGen](https://github.com/yonaskolb/XcodeGen) specification:

```bash
cd ios && xcodegen generate
```

Set `DEVELOPMENT_TEAM` in `project.yml` to your own team before regenerating if you use a different account. The spec preserves the current signing team.

## Project structure

Paths are relative to `ios/`.

```text
Alice/
├── App/
│   ├── AliceApp.swift              # Entry point
│   └── AliceTheme.swift            # Colors, typography and shared surfaces
├── Model/
│   ├── AliceSessionStore.swift     # Navigation, approvals and session state
│   └── DecisionCard.swift          # Request/response models and approval choices
├── Fixtures/
│   ├── AliceFixtures.swift         # Local decision requests
│   └── UsageData.swift             # Token usage fixtures and periods
├── Views/
│   ├── AliceRootView.swift         # App shell and Alice navigation
│   ├── AliceHomeView.swift         # Companion and current request
│   ├── DecisionCardView.swift      # Command and approval bubbles
│   ├── DecisionDetailView.swift    # Command explanation
│   ├── VoiceInputSheet.swift       # Record, review and send voice input
│   ├── UsageView.swift
│   ├── ProfileView.swift
│   └── Components/AliceMascot.swift
├── Voice/                         # Recording, AssemblyAI, backend contracts and adapters
└── Resources/
    ├── Assets.xcassets/            # App icon
    └── Fonts/                     # IBM Plex Sans and its license
Alice.xcodeproj/
project.yml
scripts/render-app-icon.swift
```

Alice's state uses `AliceSessionStore`, `AliceTab` and `AlicePhase`. The mascot is native vector artwork; animation respects Reduce Motion and the profile preference. Existing local profile and preference keys are retained during the rename.

### App icon

The icon uses the same Alice face as the app. To regenerate it on macOS, run from `ios/`:

```bash
xcrun swiftc -parse-as-library \
  -target "$(uname -m)-apple-macosx14.0" \
  Alice/Views/Components/AliceMascot.swift \
  Alice/App/AliceTheme.swift \
  Alice/Model/DecisionCard.swift \
  scripts/render-app-icon.swift \
  -o /tmp/alice-render-app-icon
/tmp/alice-render-app-icon
```

The script writes an opaque 1024 × 1024 PNG into `AppIcon.appiconset`.

## Connection to Bob

```text
IBM Bob IDE / Shell
        │ MCP over stdio
        ▼
Companion MCP server
        │ WebSocket
        ▼
      Relay ──────────► Push service
        │ WebSocket           │
        ▼                     ▼
             Alice on iPhone
```

Christopher owns the MCP server and relay, which live in [`backend/`](../backend) of this monorepo. The wire format and decision card rules are in [docs/PROTOCOL.md](../docs/PROTOCOL.md). The tools are `pair_phone`, `notify`, `ask_decision`, `request_approval` and `get_instruction`.

Alice will receive compact requests rather than a full IDE conversation. The relay and Bob integration must enforce command scope, task scope and expiry; the phone's selection alone does not grant a real permission.

### Approval request

The optional `command` field extends the decision-card model. Example payload:

```json
{
  "type": "decision_request",
  "id": "approval_42",
  "title": "Run the auth tests",
  "context": "Checks that sign-in still works after Bob's changes. Stops at the first failing test.",
  "command": "npm test -- --runInBand --bail auth",
  "risk": "low",
  "options": [
    { "id": "approve_once", "label": "Approve once", "detail": "Just this time", "recommended": false },
    { "id": "reject", "label": "Reject", "detail": "Don't run it", "recommended": false },
    { "id": "approve_for_task", "label": "Approve for task", "detail": "Allow this command for this task", "recommended": false }
  ],
  "allowFreeText": false,
  "expiresAt": null
}
```

The current example assumes a Jest-based project. Alice preserves the selected option ID in its response:

```json
{
  "type": "decision_response",
  "id": "approval_42",
  "optionId": "approve_once",
  "text": null
}
```

Risk remains part of the model, although the main UI has no risk badge. High-risk approvals retain an explicit confirmation step.

## Scope

Next steps are the real-device walkthrough, production relay deployment, native APNs if desired, and real usage data. Companion customization can follow later.

Alice is not a remote IDE or a full coding chat. The focus is a small, understandable decision at the moment Bob needs you.

## Credits

Alice uses bundled [IBM Plex Sans](https://github.com/IBM/plex). The font license is included in [OFL.txt](Alice/Resources/Fonts/OFL.txt).

Hackathon prototype — IBM Bob 2.0 Hackathon, September 2026.
