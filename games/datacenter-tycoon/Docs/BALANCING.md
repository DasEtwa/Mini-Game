# Balancing

## v0.2.0

Die Grundpreise bleiben bestehen. Neu sind individuelle Zahlungszyklen, Mindestnachfrage bei niedriger Reputation und die optionalen Operations-Systeme. Deren Werte stehen in [OPERATIONS.md](OPERATIONS.md). Durch individuelle Zahlungstermine ändert sich die Liquidität gegenüber v0.1.1; historische Messwerte unten gelten nicht automatisch für das Update.

## Historischer Stand v0.1.1

## Ausgangswerte und Entscheidungen

- Startkapital **1.900 €** statt 5.000 €. Alter Server und Home Rack bleiben geschenkt. Die ersten drei Monate erstatten die Eltern je 400 € Miete; danach fallen die vollen Fixkosten an.
- Zeit bleibt 18 Sekunden/Tag, 9 Minuten/Monat bei 1×. Die Garage kostet weiterhin 18.000 € und benötigt 12 Kunden, 2.500 € MRR und 60 Reputation. Die Verlangsamung entsteht durch Nachfrage, Kundenmix, Kapital und Vertragsbindung, nicht durch eine künstliche Wartezeit an der Tür.
- Kleiner VPS 7 €, Gameserver 28 €, Website **24 statt 90 €**, Entwickler **80 statt 160 €**, Shop **160 statt 250 €**, Agentur **300 statt 420 €**, Build **440 statt 600 €**, Team **540 statt 720 €**. Entwickler/Shop/Agentur/Build/Team benötigen 54/60/66/72/78 Reputation. Preise variieren ±10 % und mit dem gewählten Preisniveau.
- Reputation wächst bei guter Qualität um 0,012/Stunde statt 0,018. Eine gute Kundenbeziehung erschließt größere Verträge allmählich.
- Nachfrage frühestens alle **72 Spielstunden = 54 Sekunden** statt 9 Sekunden, ab 65 Reputation alle 36 Stunden = 27 Sekunden. Zusätzlich greift eine reputations-/preisabhängige Chance. Warteschlange: maximal 3 im Kinderzimmer, 6 in der Garage; Angebote verfallen nach 10 Spieltagen. Keine rückwirkende Nachfrageflut beim Öffnen.

## Verträge und Bindung

VPS/Gameserver: 1 Monat; Websites/Entwickler: 2; Shops/Agenturen: 3; Build/Teams: 6 Monate. Beginn ist die Annahme, nicht der Erstellzeitpunkt der Anfrage. Die UI zeigt verbleibende Tage, gebuchte Ressourcen, Zufriedenheit und Verlängerungsprognose. Bei Ablauf wird entweder verlängert oder die Kapazität freigegeben. Verlängerte Verträge behalten ihren Preis.

Verlängerungschance (auf 5–98 % begrenzt): Basis 35 %, Zufriedenheit bis +35 %, durchschnittliche Qualität bis +20 %, Reputation bis +8 %, Abzüge für erhöhte Preise und Stunden unter dem Uptime-Ziel. Qualitätsverlauf wird pro Vertragsperiode gespeichert. Unter 25 % Zufriedenheit kündigt ein Kunde beim Tageswechsel vorzeitig. Monatliche Einnahmen bleiben zeitanteilig und qualitätsabhängig, auch bei Ablauf mitten im Rechnungsmonat.

## Strom, Wärme und Raumgrenzen

| Tarif | Spitzenleistung | €/kWh | Grundgebühr/Monat | Anschluss | Standort |
| --- | ---: | ---: | ---: | ---: | --- |
| Familienstrom | 350 W | 0,34 | 0 € | 0 € | Kinderzimmer/Garage |
| Home Power Plus | 700 W | 0,30 | 18 € | 280 € | Kinderzimmer/Garage |
| Home Power Max | 1.200 W | 0,28 | 40 € | 550 € | Kinderzimmer/Garage |
| Garage Energy | 3.200 W | 0,24 | 85 € | 750 € | Garage |

Beim Einschalten/Kaufen wird die maximale konfigurierte Leistung reserviert. Der Verbrauch folgt der CPU-Last zwischen 35 % und 100 % dieses Wertes, ausgeschaltete/defekte Hosts verbrauchen nichts. Der Startserver benötigt ohne Kunden **45,85 W**, bei voller CPU **131 W**. Leere Racks haben keinen Overhead. Kühlung benötigt 35 W je Stufe. Das ist ein bewusst einfaches Steckdosenmodell ohne detaillierte Netzteileffizienz oder thermische Trägheit.

Stromrechnung: tatsächliche Watt / 1.000 × Stunden × Tarifpreis + anteilige Grundgebühr. Tarifwechsel werden stündlich berücksichtigt. Raum- und Rackwärme verwenden tatsächlichen Verbrauch. CPU/RAM-Oversubscription bleibt 2×/1,25×; Storage ist hart reserviert.

Kinderzimmer: höchstens **2 Home Racks mit je 2 Systemen**, maximal 1.200 W Infrastruktur. Studio Rack (4 Slots) und Garage Rack (6) sind auf Shop- und Logikebene gesperrt. Garage: 4 Stellplätze, 3.200 W Infrastruktur, 1.800 W Basiskühlung, größere Racks und Business Fiber. Ein stärkerer Stromvertrag wird bewusst separat gewählt.

## Erholung statt Neustartzwang

Einmalige Familienhilfe +2.000 € unter 500 € bleibt verfügbar. Zusätzlich kann man in Finanzen bei Geldnot einmal je Spielmonat einen **600-€-Nachbarschafts-IT-Auftrag** annehmen. Die Aktion ist bei 500 € oder mehr gesperrt und kann nicht gespammt werden. Sie ermöglicht Reparaturen und weitere Investitionen nach Fehlkäufen; sie ist keine automatische Dauersubvention. Kurzzeitiges negatives Guthaben stoppt Kundenhosting nicht.

## Reproduzierbare Strategien

`swift run -c release BalanceLab` prüft 7 Strategien × 5 Seeds (1, 7, 42, 123, 999). Alle Käufe, Annahmen, Kündigungen, Reparaturen und Umzüge verwenden die normalen Gameplay-APIs. Die Strategie sieht den aktuellen Zustand, keine zukünftigen Zufallszahlen.

- **Aggressiv:** täglich handeln, 100 € Reserve, Engpässe ausbauen, besonders billige Kunden bei wertvoller Nachfrage ablösen.
- **Konservativ:** alle 3 Tage handeln, 1.000 € Reserve, Uploadreserve behalten.
- **Fehlkäufe:** zunächst unnötig Netzteil, zweites Rack und Gigabit; danach alle 4 Tage handeln und wirtschaftlich reparieren.
- **Zu frühe Upgrades:** sofort zweites System und bessere CPU, obwohl die Kundennachfrage noch fehlt.
- **Wenig Annahmen:** alle 15 Tage höchstens einen Kunden akzeptieren, auch Investitionen nur dann prüfen.
- **Viele Annahmen:** auch kleine/ineffiziente Verträge weiter aufnehmen; kein Aussortieren billiger Kunden.
- **Kündigungspech:** zusätzlich 15 % der bald auslaufenden Kunden verlieren. Diese zusätzliche Störung existiert nur im Labor, nicht als versteckter Spielmodifikator.

`--cash-trials` vergleicht zusätzlich 1.000/1.300/1.600/1.900/2.200 €. Nach Einführung des begrenzten Nebenjobs erreichen alle 175 Kombinationen die Garage. Niedrige Beträge benötigen häufiger Hilfe und verzögern notwendige Upgrades; 2.200 € entschärfen den Anfang zu stark. 1.900 € liegen knapp über CPU+RAM-Upgrade plus zwei unbezuschussten Monatskosten; sofortiger Ausbau mehrerer moderner Systeme ist damit unmöglich.

Die gemessenen Zeiten stehen in [VALIDATION.md](VALIDATION.md). Zeitangaben sind simulierte aktive Zeit bei 1×, keine Garantie für menschliche Spieler. 2×/3× und Offline-Zeit verändern die reale Dauer. Eine einzelne optimale Strategie ist kein vollständiges Modell für Spielspaß.
