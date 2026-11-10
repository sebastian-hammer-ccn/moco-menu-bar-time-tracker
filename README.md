# MocoBar

MocoBar ist eine macOS-Menüleisten-App für alle, die ihre Arbeitszeit in [Moco](https://www.mocoapp.com) erfassen. Du kannst eine Stoppuhr starten, Zeiten nachtragen und deine Buchungen direkt über die Menüleiste im Blick behalten.

## Was die App kann

- **Arbeitszeit erfassen:** Moco-Stoppuhr starten und stoppen oder eine Dauer nachträglich buchen. Für eine manuelle Buchung ist eine Notiz erforderlich.
- **Tagesfortschritt sehen:** Moco-Buchungen und laufende Zeit, Tagesziel, voraussichtliche Zielzeit und Überstunden auf einen Blick. Tagesziele und Mittagspause lassen sich einstellen.
- **Buchungen verwalten:** Vergangene Tage ansehen, Buchungsdauer und Notiz ändern oder Buchungen löschen.
- **Wochen und Monate auswerten:** Arbeitszeit und Soll-Ist-Abweichung für einzelne Tage und den gesamten Zeitraum anzeigen.
- **GFOS mit Moco vergleichen:** Einen GFOS-Monatsexport im `.xlsx`-Format einlesen und tägliche sowie monatliche Arbeitszeiten abgleichen. Abwesenheiten (Typ `ABW`) können optional mitgerechnet werden.
- **Schnellstart verwenden:** Häufige Projekt-, Aufgaben- und Notizkombinationen als Favoriten speichern.
- **App anpassen:** Zwischen drei Designs wählen, Menüleistensymbol und angezeigte Zeit einstellen sowie den automatischen Start beim Anmelden konfigurieren.
- **Tagesziel feiern:** Auf Wunsch erinnern eine macOS-Mitteilung und eine kurze Konfetti-Animation daran, wenn das Tagesziel erreicht ist.

## Einblicke

| Menüleisten-Popover | Einstellungen |
| --- | --- |
| ![MocoBar-Popover mit Tagesübersicht und Zeiterfassung](docs/popover.png) | ![MocoBar-Einstellungen](docs/settings.png) |

| Gebuchte Zeiten | GFOS-Zeitabgleich |
| --- | --- |
| ![Ansicht vergangener Buchungen](docs/history.png) | ![Abgleich zwischen GFOS und Moco](docs/reconcile.png) |

## Voraussetzungen

- macOS 13 oder neuer
- Xcode oder die Swift Command Line Tools mit Swift 5.9 oder neuer
- Ein Moco-Konto und ein persönlicher API-Key

## Installieren

MocoBar wird aus dem Quellcode gebaut. Öffne Terminal und führe diese Befehle aus:

```bash
git clone https://github.com/sebastian-hammer-ccn/moco-menu-bar-time-tracker.git
cd moco-menu-bar-time-tracker
./build-app.sh
open MocoBar.app
```

Das Skript erstellt `MocoBar.app` im Projektordner. Es baut die Release-Version, fügt das App-Symbol hinzu und signiert das Bundle lokal mit einer Ad-hoc-Signatur. Für die dauerhafte Nutzung kannst du die App in den Ordner **Programme** verschieben. Beim ersten Start kann macOS eine Sicherheitsbestätigung verlangen: Öffne die App dann per Rechtsklick über **Öffnen** oder bestätige sie unter **Systemeinstellungen → Datenschutz & Sicherheit**. Die App ist nicht mit einem Apple-Developer-Zertifikat signiert und nicht notarisiert.

Der automatische Start beim Anmelden wird beim ersten Start aktiviert und lässt sich in den Einstellungen ausschalten.

## Mit Moco verbinden

1. Klicke auf das MocoBar-Symbol in der Menüleiste und öffne die Einstellungen über das Zahnrad.
2. Trage bei **Moco-Domain** den Kontonamen vor `.mocoapp.com` ein. Bei `https://firma.mocoapp.com` ist das `firma`.
3. Erstelle oder kopiere deinen persönlichen API-Key in Moco unter **Profil → Integrationen** und füge ihn in MocoBar ein.
4. Klicke auf **Speichern & neu laden**.

Danach lädt die App deine verfügbaren Projekte und Aufgaben. Wähle beides aus, um die Stoppuhr zu starten oder eine Buchung anzulegen. Einstellungen wie Tagesziel, Design und Menüleistensymbol kannst du ebenfalls dort anpassen.

## Im Alltag

| Aufgabe | So geht's |
| --- | --- |
| Stoppuhr starten oder beenden | Projekt und Aufgabe auswählen, dann **Start** oder **Stopp** klicken |
| Zeit nachtragen | Dauer und Notiz eingeben, dann **Dauer buchen** klicken |
| Dauer eingeben | Zum Beispiel `2h`, `1,5h`, `1:30`, `45m` oder `45` (Minuten) |
| Buchungen eines anderen Tages ansehen | Kalendersymbol öffnen und Datum wählen |
| Wochen- oder Monatsübersicht öffnen | Diagrammsymbol öffnen und Zeitraum wechseln |
| GFOS-Zeiten abgleichen | Häkchensymbol öffnen und den `.xlsx`-Monatsexport auswählen |
| Schnellstart nutzen | Eine gespeicherte Favoriten-Schaltfläche anklicken |
| Daten aktualisieren | Aktualisierungssymbol im Popover anklicken |

## Datenschutz und Zugangsdaten

Der API-Key wird im macOS-Schlüsselbund gespeichert. Ein noch in älteren Versionen vorhandener Schlüssel in den UserDefaults wird beim Start in den Schlüsselbund übernommen. Die übrigen Einstellungen werden lokal in den UserDefaults gespeichert. MocoBar kommuniziert für Buchungen und Zeiterfassung über HTTPS mit der Moco-API. Der ausgewählte GFOS-Export wird lokal eingelesen und mit den Moco-Zeiten verglichen.

## Entwicklung

MocoBar ist ein Swift-Package ohne externe Paketabhängigkeiten. Die wichtigsten Bereiche:

| Datei | Zuständigkeit |
| --- | --- |
| `App.swift` | Menüleisten-Popover, Einstellungen und Fenster |
| `Store.swift` | App-Zustand, Einstellungen und Aktionen |
| `MocoClient.swift` | Moco-API-Modelle und HTTP-Anfragen |
| `HistoryView.swift` | Vergangene Buchungen ansehen und bearbeiten |
| `ReportsView.swift`, `TimeReport.swift` | Wochen- und Monatsauswertungen |
| `Reconcile.swift`, `ReconcileView.swift` | GFOS-Import und Zeitabgleich |
| `KeychainStore.swift` | Sichere Speicherung des API-Keys |
| `Theme.swift`, `Celebration.swift` | Designs und Tagesziel-Mitteilung |

Mit einer installierten Swift-Toolchain kannst du das Paket bauen und die Tests ausführen:

```bash
swift build
swift test
```

Die Tests liegen unter `Tests/MocoBarTests/`. Für ein startbares macOS-App-Bundle einschließlich Symbol und lokaler Signatur:

```bash
./build-app.sh
```
