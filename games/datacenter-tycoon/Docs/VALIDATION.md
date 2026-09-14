# Validierung — v0.1.1

Stand: 14. September 2026. Der Tag v0.1.0 bleibt unverändert. Dessen Release-Lauf scheiterte; ein neuer, vollständig geprüfter v0.1.1-Tag soll eigene Assets veröffentlichen.

## Logik und Balancing

- 43 Core-Tests unter Linux mit Swift 6.2.3 bestanden. Bestehende Tests bleiben erhalten, Erwartungen an Startgeld/Strom wurden der neuen Balance angepasst.
- Zusätzliche Abdeckung: strikte Rackklassen, atomare Kauf-/Upgrade-Ablehnung, Spitzenleistung und Vertragswechsel, Lastverbrauch und anteilige Strom-Grundgebühren, Laufzeiten, Verlängerung/Kündigung, Qualitätswirkung, Save-Roundtrip, v1-Migration einschließlich übergroßer Bestandsracks, ungültige Altdaten, Audio-Burst-Begrenzung, langsame Nachfrage und begrenzte Recovery-Arbeit.
- 175 Balance-Läufe: 5 Startbudgets × 7 Strategien × 5 Seeds, alle erreichen die Garage. Rohwerte: [BalanceResults.csv](BalanceResults.csv).
- Im Produktionslauf mit 1.900 €: 35/35 erfolgreich, kein wirtschaftlicher Stillstand im Testhorizont. Schlechtester kurzfristiger Kontostand −134 € nach absichtlichen Fehlkäufen, anschließend Erholung über normale Spielaktionen. Das ist kein Beweis für jede denkbare Strategie.

Zeiten in realen Minuten bei 1×, einschließlich eines erfolgreichen Betriebstags in der Garage:

| Strategie | Schnellster Lauf | Mittel | Langsamster Lauf | Garage |
| --- | ---: | ---: | ---: | ---: |
| Aggressiv | 63,3 | 66,9 | 72,3 | 5/5 |
| Konservativ | 81,3 | 99,3 | 135,3 | 5/5 |
| Fehlkäufe | 81,9 | 92,5 | 99,9 | 5/5 |
| Zu frühe Upgrades | 72,3 | 75,9 | 81,3 | 5/5 |
| Wenig Annahmen | 108,3 | 135,3 | 153,3 | 5/5 |
| Viele Annahmen | 72,3 | 83,1 | 90,3 | 5/5 |
| Zusätzliches Kündigungspech | 72,3 | 72,3 | 72,3 | 5/5 |

Der aggressive Median liegt bei 63,3 Minuten, der konservative bei 90,3 Minuten. Die Zielbereiche werden im Mittel getroffen; einzelne konservative Seeds benötigen länger als 120 Minuten. Die Monatsabrechnung führt zu Zeitstufen von etwa 9 Minuten. Kündigungspech ist keine garantierte Zeitverlängerung: frei werdende Kapazität und ein anderer späterer Kundenmix können Verluste ausgleichen.

Bei aggressivem Spiel erfolgen erste Upgrades nach 3,3–6,9 Minuten; erste Zahlungen nach 9 Minuten. Die erste positive Monatsprognose liegt später. Der extrem zurückhaltende Bot prüft nur alle 4,5 Minuten eine Anfrage und verzögert auch Upgrades bewusst.

## iOS-Prüfung

Die macOS-Pipeline baut mit vollständiger Concurrency-Prüfung und behandelt Swift-Warnungen als Fehler. Die zwei ersten Prüfungen fanden und beseitigten einen zu komplexen Sound-Ausdruck und eine fehlende nichtisolierte Equatable-Implementierung der SwiftUI-Raumansicht.

Aktuell laufen die erneuten Simulator-/UI-/Archivprüfungen. Ein erfolgreicher IPA-/Release-Status wird erst nach ihrem Abschluss eingetragen.

Die UI-Tests prüfen auf einem kleinen und großen iPhone:

1. Hauptscreen ohne ScrollView; Laptop, Rack, Tür und freier Stellplatz direkt erreichbar.
2. Kunde annehmen, Rack/Server öffnen, CPU kaufen, oben schließen, App beenden und Spielstand erneut laden.
3. Laptop/Strom, Standortseite und erreichbare Kauf-/Upgrade-Aktionen ohne unteren Zurück-Button.
4. Vier Garage-Racks, Studio-Rack-Upgrade, Dashboard und Garagenfreischaltung über die Tür.

Die Garage-Fixtures sind ausschließlich im Debug-Build verfügbar. BalanceLab verwendet dagegen keine Freischalt-Cheats. Das Gerätearchiv ist ARM64, iOS 17+, Bundle `de.dasetwa.rackandrich`, Version 0.1.1, Build 2. Die IPA-Prüfung kontrolliert ZIP/Payload, Mach-O, Plattform, Bundle-Version und Core-Framework.

## Laufzeit und Grenzen

- Normale Taps aktualisieren den Spielzustand synchron; Dateiprüfung, Backup und Schreiben laufen seriell im Hintergrund. Lifecycle-Laden wartet außerhalb des UI-Threads auf vorherige Schreibvorgänge. Ein iOS-Hintergrundtask schützt das abschließende Speichern beim Verlassen.
- Audio hält genau einen Player auf einer eigenen seriellen Queue, startet ihn neu und begrenzt identische Trigger auf höchstens einen pro 60 ms. Gameplay-Aktionen durchlaufen diese Sperre nicht.
- Die Raumansicht vergleicht nur Standort, Racks und Kühlung; Uhrzeit/Kontostand lösen keine Neuzeichnung ihrer Möbel aus. Die kleine stündliche Simulation bleibt auf dem Main Actor, große Offline-Schritte laufen außerhalb davon.
- Der Nutzer hat v0.1.0 auf einem echten iPhone gespielt. Hier ist kein physisches iPhone angeschlossen; subjektive Touch-Latenz, Audiolautstärke und SideStore-Update von v0.1.1 müssen auf dem Gerät nachgeprüft werden. Simulatorerfolg ist keine physische Audio-/Latenzmessung.
- Deutsche Oberfläche und feste helle Farbpalette. iPhone/iPad im Hochformat, keine vollständige Dynamic-Type-/VoiceOver-Zertifizierung.
