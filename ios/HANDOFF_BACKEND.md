# Übergabe: Backend → Alice-App (für Franz)

Stand: 26. September 2026, von Christopher. Ergänzt [HANDOFF.md](HANDOFF.md); diese Datei beschreibt nur, **was das Backend jetzt kann und was in der App noch fehlt**, damit Alice mit dem echten Bob spricht.

## Kurzfassung

- Das Repo ist jetzt ein **Monorepo**: die App liegt unverändert unter `ios/`, das Backend (MCP-Server + Relay) unter `backend/`, der gemeinsame Vertrag unter [`docs/PROTOCOL.md`](../docs/PROTOCOL.md). Am App-Code wurde **nichts** geändert, nur Pfadhinweise in README/HANDOFF.
- Backend und Relay sind fertig und mit dem **echten IBM Bob** getestet (Bob Shell 2.0.5): Bob schickt Karten, das Handy tippt, Bob macht mit der Wahl weiter.
- Es gibt jetzt **zwei Kartentypen in einer Form**: `kind: "choice"` (nächster Schritt, Optionen `a`–`d`) und `kind: "approval"` (Befehl freigeben, Optionen `approve_once` / `approve_for_task` / `reject`, genau wie in deinen Fixtures).
- Die Karten sind so gebaut, dass dein aktuelles `DecisionCard`-Codable sie **ohne Absturz decodieren** kann (alle Keys immer vorhanden, Datum ohne Millisekunden).
- Damit Alice live funktioniert, fehlen in der App: Relay-Verbindung, Pairing, Antworten für Choice-Karten und die Darstellung nach `kind`. Details und Code-Skizzen unten.
- Das Relay läuft unter `wss://bob-relay.zeigma.com`, sobald es auf Coolify deployt ist (**Stand jetzt: noch nicht live**, liefert 503). Bis dahin: lokales Relay, siehe [Testen](#testen-ohne-bob).

## So hängt alles zusammen

```text
IBM Bob ──stdio──▶ Companion-MCP-Server ──wss──▶ Relay ◀──wss── Alice (iPhone)
                   backend/companion-mcp          backend/relay
                   (Bob startet ihn selbst)          └──push──▶ ntfy ──▶ iPhone
```

Alice spricht **nur mit dem Relay**, über **eine** WebSocket-Verbindung. Keine HTTP-API, keine Accounts. Das Relay leitet Nachrichten innerhalb eines „Raums“ (Session) zwischen Bob und Handy weiter.

Als **Referenz-Client** gibt es eine fertige Web-Version im Relay: [`backend/relay/public/phone.html`](../backend/relay/public/phone.html) (ca. 300 Zeilen JavaScript, ohne Framework). Sie macht alles, was Alice tun muss (Pairing, Verbindung, Reconnect, beide Kartentypen, Antworten, Anweisungen). Im Zweifel dort nachsehen, wie es gemeint ist.

## Der Vertrag auf einer Seite

Vollständig in [`docs/PROTOCOL.md`](../docs/PROTOCOL.md). Das Wichtigste:

### Pairing

Der QR-Code (von Bob über das Tool `pair_phone` oder im Terminal) enthält einen von zwei Links. Alice sollte **beide** verstehen:

```text
bobcompanion://pair?s=<sessionId>&k=<secret>&r=<relayUrl, URL-encoded>
https://bob-relay.zeigma.com/#s=<sessionId>&k=<secret>          (Relay = gleicher Host, wss://)
```

`secret` ist ein Passwort (43 Zeichen) und gehört in die **Keychain**, nie ins Log. Derzeit steht in `.bob/mcp.json` `COMPANION_QR=web`: Der QR enthält den `https://…`-Link, damit ihn jede Handykamera öffnen kann (dann öffnet sich die Web-Version). Sobald Alice das URL-Schema `bobcompanion` registriert hat, stellen wir auf `app` um.

### Verbindung

```json
→ { "type": "hello", "role": "phone", "sessionId": "…", "secret": "…", "pushTopic": "bobc-…" }
← { "type": "paired", "sessionId": "…", "role": "phone", "bobOnline": true }
```

`hello` muss die **erste** Nachricht sein (innerhalb von 10 s). `pushTopic` ist optional (siehe [Push](#8-push)).

Bei Fehlern schickt das Relay erst `{ "type": "error", "error": "…" }` und schließt dann. **Nimm den `error`-Text, nicht den Close-Code**: `URLSessionWebSocketTask` bildet eigene Codes (4001/4003/4004) nicht zuverlässig ab.

| `error` | Bedeutung | Alice soll |
| --- | --- | --- |
| `wrong secret` | QR veraltet/falsch | Pairing löschen, neu scannen lassen |
| `unknown session` | Bob läuft (noch) nicht | Pairing behalten, mit Backoff neu verbinden (1 s → 10 s) |
| Verbindung weg / `session ended` | Bob beendet, Netz weg | Pairing behalten, neu verbinden, „Bob offline“ zeigen |

### Nachrichten

| Richtung | `type` | Inhalt / Bedeutung |
| --- | --- | --- |
| Bob → Handy | `decision_request` | eine Karte (siehe unten) |
| Bob → Handy | `notify` | `id`, `message`, `level` (`info` / `success` / `error`), Statuszeile für den Verlauf |
| Bob → Handy | `ack` | `id`: Antwort oder Anweisung mit dieser id ist bei Bob angekommen. **Karte schließen** |
| Bob → Handy | `decision_expired` | `id`, `reason` (`timeout` / `cancelled`): Karte entfernen, Bob ist ohne Antwort weiter |
| Bob → Handy | `error` | `id`, `error`: Antwort abgelehnt (z. B. unbekannte Option), Karte bleibt offen |
| Relay → Handy | `bob_status` | `online`: Bob verbunden / getrennt |
| Handy → Bob | `decision_response` | `id`, `optionId`, `text` (optional/`null`), deine `DecisionResponse` passt schon |
| Handy → Bob | `instruction` | `id`, `text`: freie Anweisung (z. B. aus Voice), Bob holt sie mit `get_instruction` ab, Antwort ist `ack` |

Regeln, auf die du dich verlassen kannst:
- Offene Karten werden bei **jedem (Re-)Connect erneut geschickt**. Nach `id` deduplizieren.
- Eine Karte endet genau mit `ack` **oder** `decision_expired`. Vorher nicht endgültig entfernen (Antwort könnte verloren sein).
- Unbekannte `type`s und unbekannte Keys ignorieren.

### Die Karte (beide Arten, gleiche Form)

```json
{
  "type": "decision_request",
  "id": "d_43",
  "kind": "approval",
  "title": "Run the auth tests",
  "context": "Checks that sign-in still works after Bob's changes. Stops at the first failing test.",
  "command": "npm test -- --runInBand --bail auth",
  "explanations": [
    { "part": "--runInBand", "meaning": "Runs the tests one at a time." },
    { "part": "--bail", "meaning": "Stops when the first test fails." }
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

Eine **Choice**-Karte sieht genauso aus, nur mit `"kind": "choice"`, meist `"command": null`, `"explanations": []` und Optionen `a`–`d`, davon höchstens eine mit `"recommended": true`. Beispiel: *„Tests fixed. What next?“* → `Add more tests` / `Commit the fix ★` / `Stop here`.

Garantien (vom Server durchgesetzt): `title` ≤ 60, `context` ≤ 140 Zeichen / max. 2 Sätze, `label` ≤ 25, `detail` ≤ 60 (sonst `""`), `explanations` max. 6. `command` wird **nie gekürzt** (≤ 500 Zeichen, kann Zeilenumbrüche enthalten), weil man genau das freigibt, was läuft. Also immer vollständig anzeigen.

Was die Approval-Antworten bei Bob bewirken:

| Antwort | Bob |
| --- | --- |
| `approve_once` | führt den Befehl genau einmal aus; nächstes Mal kommt eine neue Karte |
| `approve_for_task` | führt aus; der MCP-Server merkt sich den Befehl und fragt **in dieser Aufgabe** nicht mehr (endet, wenn Bob `notify` mit `success`/`error` schickt oder beendet wird) |
| `reject` | führt nicht aus, sucht einen anderen Weg; ein `text` („nimm yarn“) kommt bei Bob an |
| keine Antwort bis `expiresAt` | gilt als **nicht** freigegeben |

## Was in der App zu tun ist

In sinnvoller Reihenfolge. Die Skizzen sind **nicht kompiliert** (kein Xcode auf dem Linux-Rechner). Bitte als Richtung verstehen, nicht als fertigen Code.

### 1. Model: `kind` und `explanations` (`Model/DecisionCard.swift`)

```swift
enum CardKind: String, Codable {
    case choice, approval, unknown
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CardKind(rawValue: raw) ?? .unknown   // unbekannte Arten wie choice behandeln
    }
}

struct CommandExplanation: Codable, Equatable, Hashable {
    let part: String
    let meaning: String
}

// in DecisionCard:
let kind: CardKind
let explanations: [CommandExplanation]
```

Die Fixtures brauchen dann `kind` (und `explanations`, z. B. die vier Zeilen aus `DecisionDetailView`). Empfehlung: ein eigenes `init(from:)` mit `decodeIfPresent` und Defaults (`kind` → `.approval`, wenn `command != nil`, sonst `.choice`; `explanations` → `[]`), damit auch ältere Nachrichten gehen.

### 2. Datum decodieren

```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601   // Server schickt "2026-09-26T14:05:00Z", ohne Millisekunden
```

Relay-Nachrichten zuerst nach `type` unterscheiden:

```swift
struct Envelope: Decodable { let type: String }
let type = try decoder.decode(Envelope.self, from: data).type
switch type {
case "decision_request": let card = try decoder.decode(DecisionCard.self, from: data) // …
case "notify":           let n = try decoder.decode(StatusNotification.self, from: data) // …
case "ack", "decision_expired": /* Karte mit dieser id schließen */
default: break  // unbekannt → ignorieren
}
```

### 3. Antworten für beide Arten (`Model/AliceSessionStore.swift`)

`submitDecision` bricht heute ab, wenn die Option keine Approval-id hat (`guard … let choice = option.approvalChoice else { return }`). **Choice-Karten lassen sich dadurch nicht beantworten.** Vorschlag: die Antwort immer senden, die Phase danach nach Art wählen:

```swift
func submitDecision(card: DecisionCard, option: DecisionOption, note: String? = nil) {
    guard isConnected, currentDecision?.id == card.id, card.options.contains(option) else { return }
    relay.send(DecisionResponse(id: card.id, optionId: option.id, text: note))
    lastChoice = option
    switch option.approvalChoice {
    case .once:   phase = .approvedOnce
    case .task:   phase = .approvedForTask
    case .reject: phase = .rejected
    case nil:     phase = .answered        // neu: Choice-Karte beantwortet
    }
    // currentDecision erst bei ack/decision_expired endgültig entfernen
}
```

### 4. Darstellung nach `kind` (`Views/DecisionCardView.swift`)

- `approval`: so wie jetzt (Befehl, drei Bubbles, Bestätigung bei `risk == .high`).
- `choice`: 2–4 Optionen untereinander, die `recommended` hervorgehoben. Hier gibt es kein „once / reject“. Das Design entscheidest du. Die Web-Version zeigt eine einfache Variante.
- `command` kann auch bei `choice` gesetzt sein (z. B. „Migration ausführen?“). Dann einfach `CommandSnippet` mit anzeigen.
- Bei `risk == .high` alles außer `reject` / der sicheren Option bestätigen lassen (hast du schon). Das Relay schickt für High-Risk-Karten bewusst **keine** Lockscreen-Buttons, damit diese Bestätigung nicht umgangen wird.

### 5. Info-Sheet aus Daten (`Views/DecisionDetailView.swift`)

Die Erklärungen sind heute fest für den Fixture-Befehl (`if card.command == AliceFixtures.commandApproval.command`). Stattdessen `card.explanations` anzeigen (`part` = Titel, `meaning` = Text). Bob liefert sie mit jeder Approval-Karte. Wenn die Liste leer ist, den Block weglassen.

### 6. Relay-Client (neu, z. B. `Model/RelayClient.swift`)

```swift
@MainActor
final class RelayClient {
    private var task: URLSessionWebSocketTask?
    private var backoff: Duration = .seconds(1)

    func connect(_ p: Pairing) {
        task = URLSession.shared.webSocketTask(with: p.relayURL)
        task?.resume()
        send(["type": "hello", "role": "phone", "sessionId": p.sessionId,
              "secret": p.secret, "pushTopic": p.pushTopic])
        receiveLoop()
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(.string(let text)): self?.handle(Data(text.utf8)); self?.receiveLoop()
                case .success: self?.receiveLoop()
                case .failure: self?.scheduleReconnect()   // Backoff 1 s → 10 s
                }
            }
        }
    }
    // send(_:), handle(_:), scheduleReconnect() …
}
```

- Pings vom Relay (alle 30 s) beantwortet `URLSessionWebSocketTask` selbst.
- Im Hintergrund trennt iOS die Verbindung. Beim Zurückkommen neu verbinden, offene Karten kommen dann automatisch erneut.
- Der Store ersetzt `loadNextRequest()` / Fixtures durch eingehende `decision_request`s. `isConnected` sollte aus `paired` / `bob_status` kommen.

### 7. Pairing (Kamera + URL-Schema)

- QR-Scanner (z. B. `DataScannerViewController` oder `AVCaptureMetadataOutput`). In `Info.plist` fehlt dafür noch `NSCameraUsageDescription`.
- URL-Schema `bobcompanion` registrieren (`CFBundleURLTypes`, fehlt noch), damit Links aus der Kamera-App direkt Alice öffnen. Passt zur alten Bundle-ID `com.bobcompanion.app`.
- Beide Link-Formate parsen (siehe oben), `sessionId` + `secret` + Relay-URL in die Keychain.
- Die Voice-`sessionId` aus deinem `VoiceContext` ist genau diese `sessionId`, die `decisionId` ist die Karten-`id`. Eine `taskId` gibt es im Protokoll (noch) nicht.

### 8. Push

- **Jetzt:** ntfy. Alice erzeugt ein langes zufälliges Topic (z. B. `bobc-` + 24 Hex-Zeichen), schickt es als `pushTopic` im `hello`, und der Nutzer abonniert es in der **ntfy-iOS-App**. Karten kommen dann mit Buttons (Approve once / Approve for task / Reject, bei Choice die Optionen) auch bei geschlossener App.
- **APNs** (native Push direkt an Alice) ist im Relay **noch nicht** gebaut. Das Relay kann nur ntfy und Expo, und Expo passt nicht zu einer Swift-App. Wenn wir das wollen: Alice schickt ihren APNs-Device-Token als `pushTopic` und das Relay bekommt einen APNs-Sender (Arbeit für Christopher, braucht einen APNs-Key aus deinem Developer-Account).

### 9. Voice

Dein `VoiceInputSending` kann direkt über das Relay laufen, ohne `POST /v1/inputs`:

```json
→ { "type": "instruction", "id": "<Input-UUID>", "text": "Please also check sign-in on smaller screens." }
← { "type": "ack", "id": "<Input-UUID>" }       // = "accepted": beim MCP-Server angekommen, Bob holt es mit get_instruction
```

Das `ack` mit gleicher id ist die Empfangsbestätigung. **Noch nicht gebaut** (Christopher): der Token-Endpunkt für AssemblyAI (`POST /v1/voice/sessions`) und die Deduplizierung wiederholter Anweisungen mit gleicher id (ein Retry mit derselben UUID landet derzeit doppelt bei Bob).

## Testen ohne Bob

Auf dem Mac (Node 22+):

```sh
cd backend && npm install
npm run relay                                        # Relay auf 0.0.0.0:8787
RELAY_URL=ws://localhost:8787 npm run demo:bob       # „Fake-Bob“: zeigt QR + Links, schickt Karten
```

Tasten im Fake-Bob: `d` Choice-Karte, `a` Approval-Karte (u. a. genau dein `npm test -- --runInBand --bail auth` mit Erklärungen), `h` / `x` High-Risk Choice / Approval, `n` / `s` / `e` Notify info / success / error. Unbeaufsichtigt: `npm run demo:bob -- --loop 20` (abwechselnd Choice und Approval). Fake-Bob benutzt denselben Code wie der echte MCP-Server, also exakt dieselben Nachrichten.

- **Web-Version** zum Vergleich: `http://localhost:8787/#s=…&k=…` (Link steht im Fake-Bob-Output).
- **iPhone gegen lokales Relay:** `ws://<Mac-Name>.local:8787`. Unverschlüsseltes `ws://` kann an App Transport Security scheitern. Für lokale Tests `NSAllowsLocalNetworking` setzen oder, sobald live, gleich `wss://bob-relay.zeigma.com` nehmen.
- **Mit echtem Bob:** `demo/setup.sh ~/alice-demo` legt ein Demo-Projekt mit kaputten Tests an. Dann `cd ~/alice-demo && BOB_API_KEY=… bob run --mode companion "The tests are failing. Fix them, then commit the fix." < /dev/null`. Bob fragt per Approval-Karte vor dem Commit und danach per Choice-Karte, wie es weitergeht.

## Offene Punkte

| Punkt | Wer |
| --- | --- |
| Relay auf Coolify deployen (`/backend/relay`, Domain `bob-relay.zeigma.com`), dann `COMPANION_QR` ggf. auf `app` | Christopher |
| Design der Choice-Karte in Alice | Franz |
| Punkte 1–7 oben (Model, Decoding, Antworten, Darstellung, Relay-Client, Pairing) | Franz |
| APNs statt ntfy? | beide entscheiden, dann Christopher (Relay) + Franz (Token) |
| Voice: Token-Endpunkt + Dedupe von `instruction`-ids | Christopher |
| Usage-Tab: echte Zahlen. Bob Shell meldet Kosten pro Lauf (`bob run --format json`), ein Endpunkt dafür existiert noch nicht | offen |
| Hackathon-Regeln: dürfen Karteninhalte über ntfy.sh laufen? Sonst Relay mit `PUSH_DETAILS=0` (nur „Bob needs a decision“) | beide |
