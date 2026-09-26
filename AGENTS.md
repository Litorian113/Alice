# Alice — Agent-Einstieg

Lies zu Beginn einer neuen Session [HANDOFF.md](HANDOFF.md) und danach [README.md](README.md). Die Übergabe beschreibt den Stand vom 26. September 2026; prüfe für spätere Änderungen den tatsächlichen Code und `git status`.

## Arbeitsweise mit Franz

- Kommuniziere auf Deutsch, direkt und unkompliziert. Die App-Texte sind derzeit Englisch.
- Arbeite konkrete Änderungen strukturiert ab und erhalte bereits vorhandene Änderungen.
- Franz möchte selbst auf seinem iPhone testen. Keine umfangreichen Testserien, wiederholten Simulator-Builds oder UI-Test-Targets für einfache Änderungen anlegen. Prüfe gezielt nur das Nötige.
- Baue entfernte UI-Elemente nicht ohne neuen Auftrag wieder ein: kein Chatverlauf, kein Texteingabefeld, keine Risk-Badges, keine Demo-Labels, kein Session-Balken auf der Hauptseite und keine sichtbare Beschriftung unter dem Mikrofon.
- Alice ist der mobile Partner für IBM Bob. Bob bleibt der Entwickler in der IDE. Benenne fachliche Bob-Bezüge wie Bobcoins nicht pauschal um.
- Die aktuelle App nutzt lokale Fixtures. Behaupte keine echte IDE-Verbindung, Aufnahme, Befehlsausführung oder serverseitige Freigabe.
- Behalte die bestehende App-ID und Signing-Einstellungen bei, sofern keine bewusste Migration beauftragt wird.
- Halte Xcode-Dateiverweise, `project.yml` und Dokumentation bei Dateiänderungen konsistent.

Weitere Details, Dateipfade, bekannte Grenzen und der Git-Zustand stehen in [HANDOFF.md](HANDOFF.md).
