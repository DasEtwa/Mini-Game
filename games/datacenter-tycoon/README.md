# Rack & Rich — Datacenter Tycoon

Ein gemütliches, vollständig lokales iOS-Tycoon: Papas alter Server, ein Kinderzimmer und 5.000 € werden zum eigenen Hosting-Unternehmen. Baue physische Server, wähle passende Kunden und ziehe in die Garage.

**Version:** 0.1.0 · **Ziel:** Milestone 1 · **iOS:** 17 oder neuer · **Technik:** SwiftUI, Swift Charts, Foundation, AVFoundation. Keine Laufzeit-Abhängigkeiten von Drittanbietern.

## Spielen

1. Tippe auf den Laptop → Kunden → nimm BlockBuilder21 an.
2. Öffne das Rack → Server → Komponenten. FX 8400 und zusätzlicher RAM helfen beim Start.
3. Prüfe CPU, RAM, Upload und Wärme. Buchung und tatsächliche Nutzung sind unterschiedlich; Kunden haben verschiedene Zeitzonen.
4. Betreute Websites, Shops und Teams zahlen deutlich mehr als kleine private VPS. Reputation schaltet sie frei. Wähle profitable Anfragen und halte Kapazität frei.
5. Baue Storage, Systeme, Kühlung und Internet aus. Das A5-Plattform-Kit tauscht Mainboard, CPU und RAM gemeinsam.
6. Spare 18.000 €, erreiche 12 Kunden, 2.500 € Vertragsumsatz/Monat und 60 Reputation. Öffne die Tür und richte die Garage ein.
7. Ein Spieltag erfolgreiches Kundenhosting in der Garage beendet Milestone 1. Danach kannst du vier Racks ausbauen.

**Tempo:** 18 echte Sekunden = 1 Spieltag, 9 Minuten = 1 Monat bei 1×. Die Einstellungen bieten Pause und 2×/3×. Kunden zahlen zeitanteilig zum Monatsende; schlechte Leistung reduziert Zahlungen. Die ersten drei Monate gibt es je 400 € Mieterstattung. Bei Geldnot hilft die Familie einmalig mit 2.000 €; danach kannst du ein neues Spiel beginnen. Prognosen enthalten keine Einmalkäufe oder Starthilfe.

## Features

- Zwei selbst gezeichnete, interaktive Räume mit Laptop, Bett/Werkbank, Tür, Kabeln und sichtbaren Racks.
- 3 Rack-Größen, 5 Komponentenkategorien, kompatible Plattform-Kits, echte Host-Zuweisung.
- 8 Kundentypen, 3 Regionen, 4 Lastzustände, veränderbare Angebotspreise, Zufriedenheit und Kündigungen.
- CPU, RAM, Storage, Upload, Raum-/Rack-Strom und Wärme; Oversubscription mit begrenzter Buchung.
- 4 Internettarife, 3 Kühlungsstufen, seltene Reparaturen, Reputation, Kontobuch und Verlaufsgrafiken.
- Tutorial, optionaler selbst synthetisierter Kaufsound, lokaler Save mit Backup und Offline-Simulation.
- Kein Account, Tracking, Werbung, In-App-Kauf oder Netzwerkzugriff im Spiel.

## Building

Auf einem Mac mit Xcode 16 oder neuer und installiertem iOS-Simulator:

```sh
cd games/datacenter-tycoon
brew install xcodegen
xcodegen generate
open RackAndRich.xcodeproj
```

Schema `RackAndRich`, iPhone-Simulator wählen und starten. Die generierte Projektdatei wird nicht eingecheckt; `project.yml` ist die Quelle. Für einen direkt per Xcode signierten Gerätebuild `CODE_SIGNING_ALLOWED=YES` setzen und das eigene Team wählen. Für SideStore sind keine Zertifikate im Repository nötig.

Core-Tests laufen auf macOS und Linux:

```sh
swift test --parallel
swift run -c release BalanceLab
```

Ohne lokale Swift-Installation unter Linux:

```sh
docker run --rm -v "$PWD:/work" -w /work swift:6.2.3-noble swift test --parallel
```

iOS-Build, Tests und IPA:

```sh
xcodebuild -project RackAndRich.xcodeproj -scheme RackAndRich \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
bash Scripts/package-ipa.sh
```

Den Simulatornamen gegebenenfalls an `xcrun simctl list devices available` anpassen.

## GitHub Actions & Releases

[Workflow](https://github.com/DasEtwa/Mini-Game/actions/workflows/datacenter-tycoon.yml) läuft auf `macos-15`: Swift-Unit-Tests, fünf Balancing-Szenarien, XcodeGen, iOS-Unit-/UI-Tests, Release-Archiv für echte Geräte, IPA-Strukturprüfung und Artefakt-Upload. Tests, Logs und Screenshots liegen im separaten Test-Artefakt. Swift-Warnungen werden als Fehler behandelt.

Unter Actions → erfolgreicher Lauf → **RackAndRich-unsigned-ipa** liegt die IPA (bei Artifact-Download zunächst das äußere ZIP entpacken).

Ein Tag `v0.1.0` startet dieselben Prüfungen. Nur nach erfolgreichem Build veröffentlicht der Release-Job die IPA und SHA-256-Prüfsumme in einem [GitHub Release](https://github.com/DasEtwa/Mini-Game/releases). Keine Apple-Secrets oder privaten Zertifikate. `GITHUB_TOKEN` erhält nur im Release-Job Schreibrechte.

## Installation mit SideStore

1. [SideStore nach offizieller Anleitung einrichten](https://docs.sidestore.io/docs/installation/install), einschließlich der dort genannten aktuellen Tunnel-/Pairing-Voraussetzungen.
2. `RackAndRich.ipa` aus dem Release auf das iPhone in Dateien herunterladen.
3. In SideStore unter „My Apps“ über `+` die IPA auswählen und mit dem in SideStore eingerichteten Apple-Account signieren/installieren.
4. Die von SideStore angezeigte Gültigkeit beachten und die App rechtzeitig erneuern. Der Spielstand bleibt bei einer Installation über dieselbe App erhalten; nicht vorher die App löschen.

Die IPA ist ein ZIP mit `Payload/RackAndRich.app`, ARM64-Gerätecode und eingebettetem Core-Framework. Sie ist absichtlich **nicht mit einem privaten Entwicklerzertifikat signiert**. Sie wird erst durch SideStores Signierung installierbar. Ein normaler Safari-Download allein installiert sie nicht. [Offizielle SideStore-FAQ](https://docs.sidestore.io/docs/faq).

## Savegame & Datenschutz

`Library/Application Support/RackAndRich/save-v1.json` im App-Sandbox-Verzeichnis; letzte gültige Fassung unter `save-v1.json.backup`. Automatisch alle 10 Sekunden, nach Käufen/Vertragsaktionen und beim Verlassen speichern. JSON-Schema `saveVersion = 1`, ID-/Kompatibilitätsvalidierung, atomare Dateiersetzung. Neuere Versionsnummern werden abgelehnt und niemals automatisch überschrieben. Bei beschädigtem Save kann die Sicherung explizit wiederhergestellt werden; die beschädigte Datei wird archiviert. Neustart archiviert den bisherigen Stand.

Offline-Fortschritt: maximal 2 reale Stunden bei 1×, einschließlich Kosten, Nachfrage, Kündigungen und Reparaturereignissen. Rückwärts laufende Uhr erzeugt keine Belohnung; ein vorgerückter Zeitpunkt wird nicht zurückgesetzt. Ohne vertrauenswürdigen Server lässt sich absichtliche Zeitmanipulation nicht vollständig verhindern. Pause gilt während die App geöffnet ist, Offline-Zeit läuft weiter.

Die App erzwingt eine helle, kontrastreiche Spielpalette auch bei systemweitem Dark Mode. Verwaltung scrollt, wichtige Aktionen haben große Touch-Flächen, Raumelemente besitzen VoiceOver-Labels. iPad wird unterstützt, iPhone-Hochformat ist primär.

## Architektur

- `Sources/TycoonCore/Catalog.swift`: zentraler typisierter Datenkatalog und Balancing.
- `Models.swift`: versionierter Wertzustand, Hardware und Kunden; kein UI-Code.
- `Hardware.swift`: atomare Käufe, Hardwarekompatibilität, Kapazitätsregeln, Standortwechsel.
- `Simulation.swift`: Last, Qualität, Nachfrage, Reputation, Ereignisse und zeitanteilige Abrechnung.
- `SaveStore.swift`: Validierung, Encoding, atomare Persistenz, Offline-Fortschritt.
- `App/`: SwiftUI-Szenen, Management und Lifecycle-Adapter. Simulation unabhängig von UI testbar.
- `Tests/`, `UITests/`, `Sources/BalanceLab/`: Logik, Bedienung und reproduzierbare Progression.

GPU-Slot und Burst-Budget sind vorbereitet; Bursting ist deaktiviert. Weitere Standorte sind bewusst noch keine spielbaren Katalogeinträge. Details: [Balancing](Docs/BALANCING.md), [Validierung](Docs/VALIDATION.md).

## Assets & Lizenz

Die vorhandene Repository-Lizenz **GPL-3.0** bleibt bestehen; siehe [LICENSE](../../LICENSE). Raumgrafik und Rack-/Hardware-Darstellung sind eigens geschriebene SwiftUI-Shapes/Canvas. Das App-Icon ist eine eigene geometrische Zeichnung. Sound wird aus einer Sinuswelle synthetisiert. Keine externen Bild-/Tondateien, keine echten Markenlogos. Systembedienelemente verwenden Apple SF Symbols über die nativen APIs. Fake-Marken: AMT, KingRAM, HyperLamb, SeaCrate, SamSing, WD Plaid, WattEver.

## Roadmap

- Kinderzimmer ✅ implementiert
- Garage ✅ implementiert
- Büro ⏳
- Serverraum ⏳
- Datacenter ⏳
- AI Center ⏳

Der konkrete Build-/Teststatus ist in [VALIDATION.md](Docs/VALIDATION.md) festgehalten. Physische Installation über SideStore benötigt ein iPhone und dessen lokale Signierung.
