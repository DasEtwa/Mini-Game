# Validierungsprotokoll

Stand: 14. September 2026. Release-Prüfung läuft noch.

## Bestätigt

- 28 Swift-Core-Tests auf Linux/Swift 6.2.3 erfolgreich; dieselben 28 Tests auch auf macOS und im iOS-Simulator erfolgreich.
- Nativer iOS-Simulatorbuild kompiliert ohne Swift-Compilerwarnungen. Xcode meldet lediglich die nicht benötigte AppIntents-Metadatenextraktion als übersprungen.
- Save/Load-Roundtrip, atomare Sicherung, beschädigte/neue Save-Versionen, Offline-Cap und Uhrzeit-Rücksprünge getestet.
- Hardwarekauf, Generationenwechsel, RAM-Slots, Rack-/Raum-Stromgrenzen und Customer-Host-Zuweisung getestet.
- Monatsabrechnung einschließlich zeitanteiliger Verträge, Tarifwechsel, Strom, Miete und zeitlich begrenzter Starthilfe getestet.
- Garage mit allen vier Voraussetzungen und erfolgreichem Betrieb getestet. Erfolgszähler endet bei 24 Stunden.
- Erste iPhone-16-Pro-Screenshots visuell geprüft: Kinderzimmer und Kundenansicht. Keine abgeschnittenen wesentlichen Texte in diesen Ansichten.
- Ein vom ersten UI-Test gefundener fehlender Schließen-Button in tieferen Navigationsseiten wurde durch eine dauerhafte Rückkehr-Schaltfläche behoben. Erneute Prüfung läuft.

## Balancing

Normales Tempo, automatisierte aktive Strategie, keine Geld-Cheats:

| Seed | Garage erfolgreich nach | Kunden | Vertragsumsatz/Monat | Systeme |
| --- | ---: | ---: | ---: | ---: |
| 1 | 36,3 Minuten | 58 | 15.179 € | 3 |
| 7 | 36,3 Minuten | 60 | 13.535 € | 3 |
| 42 | 36,3 Minuten | 58 | 12.275 € | 3 |
| 123 | 36,3 Minuten | 60 | 14.009 € | 3 |
| 999 | 36,3 Minuten | 64 | 13.881 € | 3 |

Die Zahlung am Monatswechsel führt bei dieser zügigen Strategie zum gleichen Freischaltmonat; die wirtschaftlichen Ergebnisse unterscheiden sich nach Seed. Das ist ein Simulationstest, keine gemessene menschliche Spielzeit. 2×/3× beschleunigen entsprechend.

## Noch zu bestätigen

- Erweiterte UI-Tests auf kompaktem und großem iPhone einschließlich Neustart und Garage.
- Release-Gerätearchiv, IPA-Prüfung und hochgeladenes Release-Asset.
- Physische Installation/Signierung über SideStore und Spielgefühl auf einem echten iPhone: hier ist kein iPhone angeschlossen. Simulator- und Core-Nachweise ersetzen diesen letzten Gerätetest nicht.
