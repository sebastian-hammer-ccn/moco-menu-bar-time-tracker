# MocoBar

Kleine macOS-Menüleisten-App, um Zeiten in [Moco](https://www.mocoapp.com) zu erfassen: Stoppuhr starten und stoppen, Dauern direkt buchen und den Tag auf einen Blick sehen.

## Funktionen

- **Start / Stopp:** startet bzw. stoppt die Moco-Stoppuhr für das gewählte Projekt und die gewählte Aufgabe.
- **Dauer buchen:** legt direkt eine Buchung für heute an. Eingaben wie `2h`, `1,5h`, `1:30`, `45m` oder `45` (Minuten) werden verstanden. Optional mit Notiz.
- **Tagesübersicht:** gebuchte Stunden heute (laufende Stoppuhr eingerechnet), Fortschritt zum Tagesziel und alle Buchungen des Tages.
- **Designs:** Bunt, Hell oder Dunkel, einstellbar in den Einstellungen.
- **Tagesziel:** in den Einstellungen frei wählbar (Standard 8 h).

## Voraussetzungen

- macOS 13 oder neuer
- Swift-Toolchain: entweder Xcode oder die Command Line Tools (`xcode-select --install`)
- Ein Moco-Account mit persönlichem API-Key

## Installation

```bash
git clone <repo-url> MocoBar
cd MocoBar
./build-app.sh
open MocoBar.app
```

Das Skript baut die App und erzeugt `MocoBar.app` im Projektordner. Zum dauerhaften Nutzen:

1. `MocoBar.app` in den Ordner **Programme** ziehen.
2. Optional für Autostart: **Systemeinstellungen → Allgemein → Anmeldeobjekte** und die App hinzufügen.

Beim ersten Start kann macOS die App blockieren, weil sie nur lokal (ad hoc) signiert ist. Dann Rechtsklick auf die App → **Öffnen**, oder unter **Systemeinstellungen → Datenschutz & Sicherheit** „Trotzdem öffnen“ wählen.

## Einrichtung

1. In der Menüleiste auf das Uhr-Symbol klicken, dann auf das Zahnrad.
2. **Moco-Domain** eintragen: nur der Teil vor `.mocoapp.com` (bei `https://firma.mocoapp.com` also `firma`).
3. **API-Key** eintragen. Du findest ihn in Moco unter **Profil → Integrationen**.
4. Optional Tagesziel und Design einstellen.
5. Auf **Speichern & neu laden** klicken.

Danach erscheinen Projekt und Aufgabe zur Auswahl. Die letzte Auswahl wird gemerkt.

## Nutzung

| Aktion | Wie |
| --- | --- |
| Stoppuhr starten | Projekt und Aufgabe wählen, **Start** |
| Stoppuhr beenden | **Stopp** |
| Zeit nachtragen | Dauer eintippen (z. B. `2h`), optional Notiz, **Dauer buchen** |
| Daten neu laden | Aktualisieren-Symbol im Kopfbereich |

## Technik

- Swift Package mit SwiftUI (`MenuBarExtra`), keine externen Abhängigkeiten.
- Moco-API v1 (`https://<domain>.mocoapp.com/api/v1`), Authentifizierung per API-Key:
  - `GET /activities` für die Buchungen des Tages
  - `GET /projects/assigned` für Projekte und Aufgaben
  - `POST /activities` zum Anlegen von Buchungen
  - `PATCH /activities/{id}/start_timer` und `/stop_timer` für die Stoppuhr
- Struktur: `Sources/MocoBar/`
  - `App.swift`: Menüleiste, Oberfläche, Einstellungsfenster
  - `Store.swift`: Zustand und Logik
  - `MocoClient.swift`: API-Aufrufe
  - `Theme.swift`: Designs

## Hinweise

- Domain, API-Key und Einstellungen liegen in den macOS-UserDefaults (`local.mocobar`), der Key also nicht in der Keychain.
- Die App nutzt Mocos Stoppuhr und Buchungen. Das Anwesenheits-Modul (Kommen/Gehen) von Moco wird nicht verwendet, da es nicht in jedem Account verfügbar ist.
