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

An info button explains the command's individual arguments. A short confirmation replaces the request after a choice. There is no chat history or text composer.

The bottom navigation provides:

- **Usage** — token charts for today, week and month, input/output totals and Bobcoins.
- **Alice** — the current decision and the companion. The center button becomes a microphone here.
- **Profile** — session controls, a local display name, haptic feedback and companion motion settings.

## Current status

This repository contains a native SwiftUI prototype. Requests, connection state, approvals and usage figures are local fixtures. **No shell command is executed and no real task permission is granted by the app yet.** Prototype labels are intentionally absent from the product UI.

Voice input is prepared with native microphone capture, AssemblyAI streaming transcription, transcript review and a replaceable backend delivery adapter. It remains unavailable until backend services and a real paired session are injected. No API key is stored in the app and no live voice/backend connection is configured. IBM account sign-in, QR pairing, relay communication and push notifications still need to be connected.

See [Voice & backend integration](docs/VOICE_INTEGRATION.md) for the Swift interfaces, proposed token/input endpoints, JSON examples, authentication, delivery acknowledgements and the wiring steps for Christopher.

Local backend secrets go in the ignored root `.env` (`ASSEMBLYAI_API_KEY`); copy [.env.example](.env.example) on a fresh checkout. No service loads this file yet. Adding a key does not activate voice until the backend token service is connected.

Returning to Alice or choosing **Next request** loads a fresh local approval. Disconnecting keeps the session disconnected until it is explicitly reconnected.

## Run the app

Requirements: macOS, Xcode 15 or newer, and an iPhone or simulator running iOS 17 or newer. There are no package dependencies.

Open the project from the repository root:

```bash
open Alice.xcodeproj
```

Select the **Alice** scheme, choose an iPhone or simulator, and press **Run**. For a physical iPhone, select your own development team in Signing & Capabilities. If needed, trust the developer certificate on the phone.

Project and product names are **Alice**. The bundle identifier remains `com.bobcompanion.app` to retain the existing installation and signing identity; it is the only intentional legacy brand identifier.

### Project generation

The Xcode project is tracked alongside its [XcodeGen](https://github.com/yonaskolb/XcodeGen) specification:

```bash
xcodegen generate
```

Set `DEVELOPMENT_TEAM` in `project.yml` to your own team before regenerating if you use a different account. The spec preserves the current signing team.

## Project structure

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

The icon uses the same Alice face as the app. To regenerate it on macOS, run from the repository root:

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

## Planned connection to Bob

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

Christopher owns the MCP server and relay, which are separate from this iOS repository. The planned tools are `pair_phone`, `notify`, `ask_decision` and `get_instruction`.

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

Next steps are real pairing, receiving Bob's approval requests, returning decisions, connecting the prepared voice services and usage integration. Companion customization can follow later.

Alice is not a remote IDE or a full coding chat. The focus is a small, understandable decision at the moment Bob needs you.

## Credits

Alice uses bundled [IBM Plex Sans](https://github.com/IBM/plex). The font license is included in [OFL.txt](Alice/Resources/Fonts/OFL.txt).

Hackathon prototype — IBM Bob 2.0 Hackathon, September 2026.
