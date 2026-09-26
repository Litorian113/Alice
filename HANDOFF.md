# Alice — vollständige Übergabe an die nächste Agent-Session

Stand: 26. September 2026. Diese Datei wurde auf ausdrücklichen Wunsch von Franz erstellt, weil der Projektordner umbenannt wurde und er ein neues Codex-Fenster öffnen muss. Sie ist der Arbeitskontext für den nächsten Agenten. Die öffentliche Produktbeschreibung steht in [README.md](README.md).

## Nachtrag: vorbereitete Spracheingabe (26. September 2026)

Dieser Nachtrag ersetzt die älteren Aussagen unten zum reinen Voice-Platzhalter. `Alice/Voice/` enthält jetzt Mikrofonaufnahme, AssemblyAI-Streaming mit kurzlebigen Tokens, Transkriptprüfung und einen austauschbaren HTTP-Adapter für die Übermittlung an Bob. `VoiceInputSheet` bietet den zugehörigen Ablauf ohne Texteingabefeld oder Chat. Der API-Key wird nicht in der App gespeichert.

**Noch nicht angeschlossen:** Der Standard-Store hat keine Voice-Services und keinen echten Session-Kontext. Deshalb bleibt der Sprachdialog ehrlich nicht verfügbar; es gibt keinen Live-Aufruf oder behaupteten Versand. Backend-Endpoints, Authentifizierung, Token-Ausgabe und Bob-Zustellung müssen später verbunden werden. Die Verträge und Anschlussanleitung stehen in [docs/VOICE_INTEGRATION.md](docs/VOICE_INTEGRATION.md). Services im Store injizieren und echte Relay-IDs mit `updateVoiceContext(_:)` setzen; keine Fixture-IDs verwenden.

Xcode-Dateiverweise wurden mit XcodeGen regeneriert; App-ID und Signing-Team bleiben erhalten. Den tatsächlichen Git-Stand prüfen: Die älteren Angaben zu uncommitted Umbenennungen sind historisch.

Gezielt geprüft: Swift-Typcheck aller App-Dateien gegen das iOS-SDK, Plists und sämtliche Xcode-Quellverweise. Ein temporärer lokaler Check mit Test-Doubles prüfte den Voice-Ablauf, Finalisierungsgrenzen, Transkript-Ersetzung, Wiederholung mit derselben Input-ID und Unterbrechungen. Kein neuer Test-Target, kein Simulatorlauf und kein echter AssemblyAI-/Backend-Aufruf. Mikrofon und Live-Verbindung auf dem iPhone erst nach dem Backend-Anschluss prüfen.

## 1. Sofort wissen

- **Produkt:** Alice, der mobile Partner für IBM Bob.
- **Neuer Arbeitsordner:** `/Users/franzos/Desktop/Alice`.
- **Xcode-Projekt:** `Alice.xcodeproj`, Target/Produkt **Alice**.
- **GitHub:** https://github.com/Litorian113/Alice
- **Remote:** `origin` zeigt bereits auf `https://github.com/Litorian113/Alice.git`.
- **Vorheriger Name:** Bob Companion; alter Ordner war `/Users/franzos/Desktop/Bob-Companion-App`.
- Die Umbenennung auf GitHub und das Verschieben des äußeren Desktop-Ordners sind **bereits erledigt**. Nicht erneut durchführen.
- **App-ID:** `com.bobcompanion.app` wurde absichtlich beibehalten, um Installation und Signing weiterzuverwenden. Dies ist die beabsichtigte Ausnahme vom Alice-Namenswechsel.
- Es ist eine **native SwiftUI-iOS-App**, keine Expo-, React-Native- oder Web-App. Die Expo-Idee stammt nur aus dem ursprünglichen Konzept und wurde nicht umgesetzt.
- Der Backend-Anschluss fehlt. Die Bedienung läuft derzeit mit lokalen Fixtures.

## 2. Git-Zustand beim Übergang — wichtig

Die letzten UI-Änderungen und die anschließende Umbenennung sind **noch nicht committed oder gepusht**. Nur der Repository-Name auf GitHub und die lokale Remote-Adresse wurden extern geändert.

`git status --short` zeigt deshalb viele gelöschte Pfade unter `BobCompanion/` und `BobCompanion.xcodeproj/`, während `Alice/` und `Alice.xcodeproj/` untracked sind. Das sind verschobene Dateien mit teilweise zusätzlichen Änderungen, kein verlorener Quellcode. `README.md`, `project.yml` und `scripts/render-app-icon.swift` sind ebenfalls geändert.

Erhalte diese Arbeit. Nicht mit einem Reset, Clean oder Checkout den alten Stand wiederherstellen und die untracked Alice-Dateien nicht löschen. Wenn später ein Commit gewünscht ist, vorher den gesamten Diff einschließlich neuer Dateien prüfen und die vollständigen Umbenennungen aufnehmen. Der GitHub-README muss noch nicht dem lokalen README entsprechen.

In der neuen Session zuerst `pwd`, `git status --short` und `git remote -v` lesen. Keine automatische Veröffentlichung oder erneute Repository-Umbenennung starten.

## 3. Menschen, Ziel und Zusammenarbeit

**Franz Anhäupl** ist der Nutzer dieser Session und arbeitet vor allem an App, Produkt und Interaction Design. **Christopher Pietsch** übernimmt MCP-Server und Relay. Anlass: IBM Bob 2.0 Hackathon, September 2026.

Bob arbeitet selbstständig in der IDE am Computer. Wenn Bob eine Freigabe benötigt, soll Alice diese verständlich auf dem Handy zeigen. Franz kann kurz entscheiden und sich wieder anderem widmen. Alice führt nicht selbst die Entwicklungsaufgabe aus, sondern vermittelt zwischen Mensch und Bob.

Der Namenswechsel ist bewusst: Bob existiert bereits als IDE-Agent; die mobile Figur heißt deshalb **Alice**, als Anspielung auf Alice und Bob in der Informatik. Produktpositionierung: **The mobile partner for IBM Bob.** Aktuelle README-Zeile: **Bob builds. Alice keeps you in the loop.**

## 4. Franz' Arbeitspräferenzen

Franz schreibt locker auf Deutsch. Antworte ebenso direkt, verständlich und ohne unnötige Förmlichkeit. Sichtbare App-Texte sind bislang Englisch; nicht ohne Auftrag alles übersetzen.

Ausdrückliche Vorgaben aus der bisherigen Session:

- „Schreib nicht für alles tests und arbeite die tasks strukturiert ab!“
- Später: „teste nicht soviel das kann uch auch machen“.
- Er testet selbst auf seinem iPhone. Für einfache UI-Änderungen keine langen Testläufe, neuen UI-Test-Targets oder wiederholten Simulator-Builds anlegen.
- Eine kurzzeitig angelegte UI-Test-Suite wurde auf seinen Wunsch wieder entfernt. Es gibt bewusst kein neues Test-Target.
- Gezielt Syntax, betroffene Dateiverweise oder notwendige Checks prüfen; Umfang an Änderung und tatsächliches Risiko anpassen.
- Seine Aufträge umsetzen, statt nur einen Plan vorzulegen. Keine unnötigen Rückfragen zu reversiblen Gestaltungsdetails.
- Echte Sandbox-/Berechtigungsgrenzen weiterhin beachten; nötige Freigaben konkret erklären.

Ein früherer erster Xcode-Build dauerte ungewöhnlich lange und führte zu zu viel Testing/Statusverkehr. Eine zusätzliche Prozessabfrage wurde abgelehnt. Nicht ungefragt dieses Vorgehen wiederholen.

## 5. Aktuelle UI-Entscheidungen — maßgeblich

Der neueste Stand ersetzt das ursprüngliche Chat-Konzept. Alte Beschreibungstexte und historische Screens sind kein Auftrag, den Chat zurückzubauen.

### Navigation

- Links **Usage**.
- Rechts **Profile**.
- In der Mitte ein schwebender runder Button in einer geschwungenen Aussparung.
- Auf anderen Seiten zeigt der Button Alices Gesicht und darunter **Alice**; ein Tap führt zur Hauptseite.
- Auf der Alice-Hauptseite ist der Button ein **Mikrofon ohne sichtbaren Titel darunter**. Insbesondere „Talk to Alice“ nicht wieder als sichtbares Label einführen. Der VoiceOver-Text darf bestehen bleiben.
- Im getrennten Zustand ist die mittlere Aktion derzeit ein Plus zum Verbinden.

### Hauptseite

- Alice als lebendige Figur mit kleinen Bewegungen und Blinzeln.
- Überschrift für die aktuelle Anfrage: **Can Bob run this?**
- Eine weiße Sprechblasenform mit dem geplanten Befehl, Titel und verständlicher Erklärung.
- Der Befehl selbst steht in einem dunklen, umbrechenden Monospace-Feld und ist auswählbar.
- Ein kleines Info-Symbol öffnet die Erklärung der Befehlsbestandteile und Freigabeumfänge.
- Eine große blaue Bubble **Approve once**.
- Darunter eine hellrote **Reject**-Bubble und eine violette **Approve for task**-Bubble.
- Große Touch-Flächen, kurze Texte, weiche asymmetrische Rundungen, leichter Druckeffekt und optionale Haptik.
- Bei Accessibility-Schriftgrößen werden die alternativen Aktionen vertikal angeordnet.
- Nach einer Wahl wird die Anfrage durch eine knappe Bestätigung ersetzt. **Next request** lädt die nächste lokale Anfrage.

Explizit entfernt und nicht ungefragt wieder einführen:

- Chatverlauf, bisherige Nachrichten und Chat-Bubbles mit vergangener Unterhaltung.
- Text-Composer, Textanweisungsfeld und Umschalter zwischen Tippen und Sprache.
- Session-Leiste mit „bob-companion“, „Needs your input“, „Auth refactor“ und „demo session“ auf der Hauptseite.
- „One quick decision. Then I'll take it from here.“ bzw. entsprechende Subline.
- Sichtbare Risk-Badges.
- Alle sichtbaren Demo-/Sample-/Prototype-Labels in der App.
- Auch der App-Header steht derzeit nicht mehr auf der Hauptseite; Usage/Profile behalten den schlichten Alice-Header.

Franz weiß, dass die Daten lokal sind. Diese Tatsache wird in Entwicklerdokumentation erklärt, nicht über wiederkehrende Produkt-Badges.

### Sprache

Das Mikro öffnet `VoiceInputSheet`, mit Alice, „I'm all ears.“ und einem Mikrofonmotiv. Aufnahme, AssemblyAI-Transkription, Transkriptprüfung und Versand sind inzwischen implementiert, aber noch nicht konfiguriert. Ohne injizierte Services und echten Session-Kontext gibt es weiterhin den ehrlichen Text „Voice input isn't connected yet.“ und eine Rückkehraktion. Siehe Voice-Nachtrag oben.

Früher gab es eine editierbare Beispielphrase. Diese wurde zusammen mit dem Textfeld entfernt. Das neue Transkript ist ebenfalls nicht editierbar; alternativ kann neu aufgenommen werden. „I'm listening“ erscheint erst nach erfolgreichem Verbindungs- und Mikrofonstart. Mikrofonfreigabe wird erst beim ausdrücklichen Start angefragt.

### Usage

Native Swift-Charts-Balkengrafik mit Today/Week/Month und Input-/Output-Anteilen. Daten sind Fixtures. Bobcoins bleiben Bobcoins, da sie zu IBM Bob gehören. Es gibt einen kleinen Ausblick auf spätere Companion-Anpassung; ein Customizer soll **noch nicht gebaut** werden.

### Profile

Lokaler Anzeigename, lokale Session verbinden/trennen, Haptik, Companion-Bewegung und About-Ansicht. Noch kein IBM-Login oder echter Account. Die gespeicherten Schlüssel `displayName`, `hapticsEnabled` und `companionMotion` wurden beim Rename beibehalten, damit Einstellungen nicht verloren gehen.

## 6. Alice-Figur und Gestaltung

Datei: `Alice/Views/Components/AliceMascot.swift`.

Alice ist native SwiftUI-Canvas-/Path-Vektorgrafik. Sie wurde aus dem bisherigen Bob-Zeichenstil entwickelt, nicht aus einer externen Bilddatei generiert.

Merkmale:

- Große dunkle Augen, weißes rundes Robotergesicht und dunkle Konturen.
- Violett-blaue seitlich geschwungene Bob-Frisur als Gehäuse statt Bobs Bauhelm.
- Türkise `//`-Spange als Code-Anspielung.
- Türkises Headset mit kleinem Mikrofonarm.
- Violette Arme/Schuhe und geometrisches A-Emblem am Körper.
- `faceOnly`, `happy`, `animated` als Darstellungsparameter.
- TimelineView für kleine Bewegungen und Blinzeln; Reduce Motion und die Profileinstellung werden respektiert.

Das App-Icon wird aus derselben Figur gerendert. Es zeigt das Gesicht mit offenem Blick auf hellem Hintergrund, 1024 × 1024, ohne Alphakanal. Asset: `Alice/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

Generator: `scripts/render-app-icon.swift`; der aktuelle Aufruf steht im README. Das Script importiert die echte Mascot-/Theme-/Model-Datei und rendert per SwiftUI ImageRenderer/CoreGraphics. Bei Änderungen an der Figur bei Bedarf Icon mitziehen. Keine vorgerundeten Icon-Ecken einzeichnen; iOS übernimmt die Maske.

Designsystem: `Alice/App/AliceTheme.swift`. Helle Flächen, IBM-Blau, Violett und Türkis. Farbzugriffe heißen inzwischen `Color.aliceBackground`, `Color.aliceAccent` usw., Oberflächenmodifier `.aliceSurface()`. Schrift ist eingebettetes **IBM Plex Sans** (Regular/Medium/SemiBold), Helfer `Font.plex(...)`. Font-Lizenz unter `Alice/Resources/Fonts/OFL.txt` erhalten.

## 7. Architektur und zentrale Dateien

| Datei | Aufgabe |
| --- | --- |
| `Alice/App/AliceApp.swift` | `@main`, erzeugt `AliceSessionStore`, setzt Environment und helles Farbschema. |
| `Alice/App/AliceTheme.swift` | Farben, Typografie und gemeinsame UI-Bausteine. |
| `Alice/Model/AliceSessionStore.swift` | Tabs, aktive Anfrage, Antwort und lokaler Verbindungszustand. |
| `Alice/Model/DecisionCard.swift` | Codable-Anfrage/Antwort, Optionen, ApprovalChoice, weitere Statusmodelle. |
| `Alice/Fixtures/AliceFixtures.swift` | Aktive Command-Anfrage sowie ältere, derzeit unbenutzte Beispielkarten. |
| `Alice/Fixtures/UsageData.swift` | Zeiträume und Token-Fixtures. |
| `Alice/Views/AliceRootView.swift` | App-Shell, `AliceNavigation`, `AliceHeader`, Voice-Sheet. |
| `Alice/Views/AliceHomeView.swift` | Figur, aktuelle Anfrage, Ergebnis und getrennte Ansicht. |
| `Alice/Views/DecisionCardView.swift` | Befehls-Bubble, CommandSnippet, drei Approval-Bubbles, Bestätigungsdialog. |
| `Alice/Views/DecisionDetailView.swift` | Erklärung des Befehls und der Freigabeumfänge. |
| `Alice/Views/VoiceInputSheet.swift` | Sprachaufnahme, Transkriptprüfung und Versand ohne Texteingabefeld. |
| `Alice/Voice/` | Austauschbare Voice-Verträge, Mikrofonaufnahme, AssemblyAI, HTTP-Backend und Zustandsmodell. |
| `Alice/Views/UsageView.swift` | Charts und Bobcoins. |
| `Alice/Views/ProfileView.swift` | Einstellungen und Session-Aktionen. |
| `Alice/Views/Components/AliceMascot.swift` | Vollständige Vektorfigur und Face-Variante. |
| `Alice/Info.plist` | App-Name Alice, Fonts und Plattformkonfiguration. |
| `project.yml` | XcodeGen-Spezifikation, Target Alice, Signing und Dateipfade. |
| `Alice.xcodeproj/project.pbxproj` | Getracktes Xcode-Projekt. |

Wichtige Umbenennungen sind bereits durchgezogen:

- `BobCompanion/` → `Alice/`, `BobCompanion.xcodeproj` → `Alice.xcodeproj`.
- `BobCompanionApp.swift` → `AliceApp.swift`.
- `DesignTokens.swift` → `AliceTheme.swift`, `bc…` → `alice…` für Farben.
- `SessionStore` → `AliceSessionStore`.
- `CompanionTab` / `CompanionPhase` → `AliceTab` / `AlicePhase`.
- `RootView` / `ConnectedView` → `AliceRootView` / `AliceHomeView`.
- `InstructionSheet` → `VoiceInputSheet`.
- `Mock/MockData.swift` → `Fixtures/AliceFixtures.swift`.
- `restartDemo()` → `loadNextRequest()`, `connectDemo()` → `connectSession()`.
- `isDemoConnected` → `isConnected`, `showsInstruction` → `showsVoiceInput`.

Bob-Nennungen, die fachlich den IDE-Agenten meinen, wurden korrekt erhalten.

## 8. Aktuelle Zustandslogik

`AliceSessionStore` ist `@MainActor` und `ObservableObject`. Die Views nutzen `@EnvironmentObject`.

- Start: `selectedTab = .alice`, `isConnected = true`, `loadNextRequest()` erzeugt die lokale Anfrage.
- Wechsel von Usage/Profile zurück zu Alice: lädt eine neue Anfrage, sofern verbunden.
- `loadNextRequest()` setzt `phase = .needsDecision`, lädt `AliceFixtures.commandApproval`, löscht letzte Wahl/Antwort.
- Jede aktive Fixture-Anfrage bekommt eine neue UUID; dieselbe Vorlage wird weiter verwendet.
- `submitDecision(...)` prüft Verbindung, Anfrage-ID, Zugehörigkeit der Option und gültige `ApprovalChoice`.
- Danach werden `lastResponse` und `lastChoice` gesetzt und `currentDecision` entfernt.
- Ergebnisphasen: `.approvedOnce`, `.approvedForTask`, `.rejected`.
- `disconnect()` löscht aktive Anfrage und Antworten, schließt Sprache und setzt `.disconnected`.
- `connectSession()` stellt den **lokalen** Zustand wieder her und lädt eine Anfrage.
- Es gibt im aktuellen Flow keine verzögerten Testlauf-Tasks, keinen Chat-Store und keine echte Ausführung.

Die echte aktuelle Fixture lautet:

```text
Titel: Run the auth tests
Befehl: npm test -- --runInBand --bail auth
Erklärung: Checks that sign-in still works after Bob's changes. Stops at the first failing test.
```

Der Befehl ist ein Beispiel für ein Jest-basiertes Projekt, **kein Build-Befehl dieser Swift-App**. Nicht im Repository ausführen, um die App zu testen.

Die drei IDs sind `approve_once`, `reject`, `approve_for_task`. Der Unterschied muss bis zum Backend erhalten bleiben. Aktuell ist „Approve for task“ nur ein eigener lokaler Ergebniszustand, keine implementierte serverseitige Berechtigung.

## 9. Backend-Konzept und bekannte Vertragsgrenzen

Geplante Kette:

```text
IBM Bob IDE/Shell → lokaler Companion MCP Server → WebSocket Relay → Alice
                                                        ↘ Push → iPhone
```

Christopher arbeitet an den externen Komponenten; sie sind nicht Teil dieses Repositories. Geplante MCP-Tools: `pair_phone`, `notify`, `ask_decision`, `get_instruction`. Ursprünglich war ntfy.sh als Push-Prototyp vorgesehen. Nichts davon als bereits verbunden annehmen.

Die App soll kompakte Entscheidungsobjekte erhalten und kein vollständiges IDE-Chatprotokoll darstellen. Request-/Response-Beispiele stehen im README.

Wichtige Details für spätere Integration:

- `DecisionCard.command` ist ein optional hinzugefügtes Feld. Mit Christopher abstimmen, woher Befehl und Erklärung kommen.
- Risiko ist weiter im Modell vorhanden. Im Hauptscreen gibt es kein Badge. Für `.high` bleibt eine explizite Bestätigung für Freigaben bestehen; Reject braucht diese nicht.
- `expiresAt` wird im aktiven lokalen Beispiel nicht verwendet. Echte Ablauffristen, Timeouts und Offline-Verhalten fehlen noch.
- `DecisionOption.recommended` hat im normalen Swift-Initializer einen Default. Der synthetisierte Codable-Decoder setzt diesen Default nicht automatisch bei fehlendem JSON-Feld. Die aktuellen README-Beispiele senden das Feld explizit. Vor echten älteren Payloads den Decoder prüfen.
- ISO-8601-Datumsdecodierung muss bei Anschluss eines Transport-Decoders konfiguriert werden.
- Die älteren a/b/c-Fixtures sind historisch und werden im aktuellen Flow nicht geladen. Der heutige Store akzeptiert die ApprovalChoice-IDs. Einfach eine alte Beispielkarte einzusetzen wäre daher keine fertige alternative Demo.
- Freigabe für eine Aufgabe muss an Aufgabe und Befehl gebunden und beim Aufgabenende widerrufen werden. Das muss der Backend-Vertrag definieren und erzwingen.
- Statusanzeigen für echte Verbindung/Ausführung erst mit entsprechenden Rückmeldungen des Relays implementieren.

## 10. Entwicklung und Prüfhistorie

Beobachtete lokale Umgebung in der vorherigen Session: macOS auf Intel (`x86_64`), Xcode 26.3, iOS-26.3-Simulatorruntime. Nicht als universelle Projektanforderung behandeln. Deployment-Target ist iOS 17.0, Swift-Sprachmodus 5.0.

`project.yml` und Xcode-Projekt enthalten derzeit Franz' vorhandenes Development Team. Diese Einstellung bei Regeneration nicht versehentlich wieder auf leer setzen. Die App-ID ist weiterhin `com.bobcompanion.app`.

Öffnen:

```bash
open Alice.xcodeproj
```

Bei neuen Dateien außerhalb von Xcode entweder Projektverweise gezielt anpassen oder mit vorhandenem XcodeGen regenerieren:

```bash
xcodegen generate
```

Verifikation ehrlich unterscheiden:

- Eine frühere Version vor den späteren Alice-/Approval-Änderungen wurde erfolgreich für den Simulator gebaut.
- Die Vektorfigur und der Icon-Generator wurden beim Erstellen des Icons tatsächlich kompiliert und das exportierte Bild angesehen.
- Die aktuellen Approval-Änderungen und anschließenden Umbenennungen wurden mit Swift-Syntaxparser geprüft.
- Plists/Xcode-Projekt wurden auf Gültigkeit geprüft; alle Xcode-Dateiverweise wurden nach dem Rename gegen existierende Dateien aufgelöst.
- **Kein vollständiger Build und kein End-to-End-/Simulator-Test der neuesten umbenannten UI durchgeführt.** Keine solche Zusicherung erfinden.
- Franz hat ausdrücklich gewünscht, das weitere Durchklicken selbst zu übernehmen.

Falls ein gezielter Syntaxcheck nötig wird:

```bash
xcrun swiftc -frontend -parse \
  Alice/App/*.swift Alice/Model/*.swift Alice/Fixtures/*.swift \
  Alice/Views/*.swift Alice/Views/Components/*.swift
```

Das ist ein Syntaxcheck, kein vollständiger Typ-/Build-Check. Für reine Dokumentationsarbeit gar keinen Build starten.

Der Simulator und Netzwerkanfragen benötigten in der alten Session Sandbox-Freigaben. Schreibzugriff auf `.git` und das Umbenennen des äußeren Projektordners ebenfalls. In einer neuen Session die dort geltenden Berechtigungen verwenden; alte Freigaben nicht voraussetzen.

## 11. iPhone und TestFlight

Franz installiert mit Xcode auf seinem iPhone. Es gab die Meldung „Developer App Certificate is not trusted“. Er erhielt die Anleitung: Einstellungen → Allgemein → VPN und Geräteverwaltung → eigenes Entwicklerzertifikat vertrauen; danach erneut Run. Das war kein App-Codefehler.

TestFlight wurde nur theoretisch besprochen: Tester können die App über einen Einladungslink/QR-Code installieren, ohne Xcode. Dafür ist eine Apple-Developer-Mitgliedschaft nötig und bei externen Testern eine erste Beta-Prüfung. **Kein TestFlight-Setup, kein Upload und keine Veröffentlichung wurden durchgeführt.** Aktuelle Apple-Voraussetzungen bei einem späteren konkreten Auftrag erneut prüfen.

## 12. Was als Nächstes zu tun ist

Der ursprüngliche Übergabeauftrag war nur, den Kontext für das neue Fenster zu sichern. Inzwischen wurde die Voice-Vorbereitung ausdrücklich beauftragt und umgesetzt (siehe Nachtrag). Es gibt weiterhin **keinen Auftrag, automatisch ein Backend zu deployen, TestFlight einzurichten oder den Customizer zu bauen**.

Nach Lesen der Übergabe ist der nächste konkrete Wunsch von Franz maßgeblich. Sinnvolle spätere Themen sind:

- Weiterer UI-Feinschliff nach seinem Feedback vom iPhone.
- Befehlserklärungen und tatsächlichen Approval-Vertrag mit Christopher abstimmen.
- Echtes Pairing, Relay-Ereignisse, Antworttransport und Verbindungszustände.
- Echte Aufnahme/Transkription ohne Chat-Composer.
- Reale Usage-/Bobcoin-Daten.
- Später Alice-Customizer, Gesten oder Push, wenn ausdrücklich priorisiert.

Die vorhandene App und alle lokalen Änderungen sind die Basis. Nicht neu anfangen, nicht zu Expo wechseln, nicht den alten Chat-Prototyp wiederherstellen.
