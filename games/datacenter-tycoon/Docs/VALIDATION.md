# Validierungsprotokoll — v0.1.0

Stand: 14. September 2026. Die Release-Pipeline prüft den finalen Tag erneut vor der Veröffentlichung.

## Prüfumfang

- 29 Swift-Core-Tests: Economy, monatliche/zeitanteilige Abrechnung, Strom, Tarifwechsel, Hardwarekapazität und -kompatibilität, RAM-/Storage-Slots, Rack-/Raumlimits, Kunde/Host, Tageszeit/Regionen, Reputation, Ausfälle, Garage, Save/Backup und Offline-Fortschritt.
- Linux: Swift 6.2.3; macOS-/iOS-CI: Xcode 16.4, Apple Swift 6.1.2.
- UI: iPhone SE (3. Generation) und iPhone 16 Pro Max, iOS 18.5. Je zwei UI-Testfälle: erster Kunde → Rack → App beenden/neu laden → Garagenziel; Garage mit vier Racks → Rack öffnen → Dashboard.
- Gerätearchiv: Release, ARM64, iOS 17.0+, Bundle `de.dasetwa.rackandrich`, Version `0.1.0`, Build `1`.
- IPA-Prüfung: ZIP-Integrität, `Payload/RackAndRich.app`, Mach-O-Binary, iPhoneOS-Plattform, Bundle-/Versionswerte und eingebettetes Core-Framework. SHA-256 wird als separates Asset veröffentlicht.
- Visuelle QA: Kinderzimmer, Garage mit vier Racks, Kundenansicht und Rackverwaltung auf kleinen/großen iPhones. Verwaltung scrollt auf kleinen Displays; die Rückkehr-Schaltfläche bleibt erreichbar. Room-Grafik nach Feedback überarbeitet: klare Abstände, detailliertere Möbel, Rack-Beschriftungen ohne überlagerte Kühlungsschaltfläche.
- Kein Netzwerk-, Tracking-, Werbe- oder Kauf-SDK im App-Quellcode. Physische GPU-Vermietung und Bursting bleiben deaktiviert/vorbereitet.

## Ergebnisse und behobene Befunde

- Alle Core-Tests lokal bestanden; fünf Balance-Szenarien erfolgreich. Der zusätzliche 29. Test prüft, dass ausgeschaltete Hosts andere Kunden nicht durch fiktiven Upload belasten und reservierte Daten erhalten bleiben.
- [Vollständiger Build mit überarbeiteter Grafik](https://github.com/DasEtwa/Mini-Game/actions/runs/34832943039): Core- und UI-Tests, Gerätearchiv, IPA-Prüfung und Artefakt-Upload erfolgreich.
- [Abschlussprüfung mit Ausfall-Korrektur](https://github.com/DasEtwa/Mini-Game/actions/runs/34833672267): 29 Core-Tests, beide iPhone-UI-Läufe, Gerätearchiv, IPA-Prüfung und Artefakt-Upload erfolgreich. Der Release-Job veröffentlicht zusätzlich nur nach erfolgreicher Prüfung des Tags.
- Swift-Compilerwarnungen werden als Fehler behandelt. Xcodes Hinweis zur übersprungenen AppIntents-Metadatenextraktion ist erwartet: Die App bietet keine AppIntents an. GitHub meldet bei den v4-Actions die automatische Node-24-Umstellung; die Actions funktionieren.
- Behoben: zu komplexe numerische Testexpression, fehlende Schließen-Aktion in tiefer Navigation, falscher XcodeGen-Versionsdefault, endlos wachsender Erfolgszähler, möglicher veralteter Lifecycle-Ladevorgang und Uploadverbrauch ausgeschalteter Hosts.
- Die Screenshots im README stammen aus echten Simulatorläufen, nicht aus Mockups. Der Garage-Test verwendet eine ausschließlich im Debug-Build verfügbare Fixture; BalanceLab erreicht die Garage dagegen ausschließlich über normale Gameplay-APIs.

## Balancing

Normales Tempo, automatisierte aktive Strategie, keine Geld-Cheats:

| Seed | Garage erfolgreich nach | Kunden | Vertragsumsatz/Monat | Systeme |
| --- | ---: | ---: | ---: | ---: |
| 1 | 36,3 Minuten | 58 | 15.179 € | 3 |
| 7 | 36,3 Minuten | 60 | 13.535 € | 3 |
| 42 | 36,3 Minuten | 58 | 12.275 € | 3 |
| 123 | 36,3 Minuten | 60 | 14.009 € | 3 |
| 999 | 36,3 Minuten | 64 | 13.881 € | 3 |

Die Zahlung am Monatswechsel führt bei dieser zügigen Strategie zum gleichen Freischaltmonat; die wirtschaftlichen Ergebnisse unterscheiden sich nach Seed. Die Prüfung fordert für jeden Seed eine erfolgreiche Garage innerhalb von 30–90 Minuten bei 1×. Das ist ein Simulationstest, keine gemessene menschliche Spielzeit oder Garantie für jede Strategie. 2×/3× beschleunigen entsprechend.

## Grenze der Prüfung

Hier ist kein physisches iPhone angeschlossen. SideStore-Signierung und Installation auf einem echten Gerät, Geräteleistung und subjektives Spielgefühl wurden deshalb nicht praktisch bestätigt. Die IPA ist ein erfolgreicher unsignierter Gerätebuild; SideStore muss sie mit dem Account auf dem iPhone signieren. Simulator-/Core-Tests ersetzen diesen letzten Gerätetest nicht. Derzeit nur deutsche Oberfläche und feste helle Spielpalette; keine vollständige VoiceOver-/Dynamic-Type-Zertifizierung.
