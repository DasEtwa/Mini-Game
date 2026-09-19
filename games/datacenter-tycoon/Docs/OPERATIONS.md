# Operations update — v0.2.0

## Individuelle Kundenzahlungen

Der Spielkalender beginnt am 1.1.1111 und verwendet weiterhin zwölf Monate mit je 30 Tagen. Ein am 17.1. angenommener Kunde zahlt erstmals am 17.2., ein am 19.1. angenommener am 19.2. Die genaue Annahmestunde bleibt erhalten. Qualität und Service-Profi-Talente beeinflussen stündlich den verdienten Betrag. Verlängerungen verschieben den Zahlungstag nicht. Bei Kündigung oder Vertragsende wird der offene Rest einmalig ausgezahlt.

Miete, Strom und Internet bleiben am globalen Monatsende fällig. Monatsumsatz und Gewinn bleiben Prognosen. Kunden zeigen nächsten Zahlungstermin und bisher verdientes Geld; Finanzen zeigt die nächsten fünf Termine. Zahlungen erscheinen am betroffenen Rack als animierte Euro-Beträge, bei reduzierter Bewegung ohne Aufsteigen. Offline-Zahlungen werden verbucht, ohne beim nächsten Start alte Animationen abzuspielen.

## Lager und Reparaturen

Alle Katalogteile können in Mengen von 1–99 auf Vorrat gekauft werden (maximal 999 je Modell). Der Komponenten-Shop bietet direkten Kauf sowie Einbau aus Lager. Bestehende Kompatibilitäts- und Stromprüfungen gelten auch für Lagerteile. Ausgebaute Teile werden weiterhin recycelt.

Ausfälle betreffen CPU, ein RAM-Modul, ein Laufwerk oder das Netzteil. Ein identisches Lagerteil repariert den Defekt, ohne andere Module oder Kundendaten zu entfernen. Manueller Austausch ist sofort möglich. Die abschaltbare Automatik repariert nach 40 Spielstunden = 30 echten Sekunden bei 1×. Fehlende Teile und unzureichende Stromreserve blockieren den Austausch, ohne Teile zu verbrauchen. Der bisherige Reparaturdienst für 120 € bleibt als Alternative verfügbar. Bei Defekten aus alten Spielständen ohne Teileinformation ist der Dienst erforderlich.

## RackCoins, Aufträge und Talente

RackCoins sind eine lokale Spielwährung ohne Echtgeldbezug. Zuverlässige Kunden geben am Zahlungstag mit 6 % Wahrscheinlichkeit einen Coin. Eine Reparatur innerhalb von 16 Spielstunden kann mit 35 % Wahrscheinlichkeit einen Coin bringen, wenn der Host Kunden hat. Trinkgelder sind auf maximal eines pro Spieltag begrenzt. Wochenaufträge sind davon unabhängig.

Täglich besteht eine Chance von 12 % auf einen Auftrag, maximal drei gleichzeitig und einer je Kunde. Angebote gelten drei Tage. Der Kunde benötigt +2 CU für sieben Tage; die zusätzliche Buchung muss auf seinen Host passen und der Vertrag lange genug laufen. Mindestens 160 von 168 Stunden müssen das Uptime-Ziel erreichen. Erfolg gibt einen Coin, anschließend wird die CPU-Reservierung freigegeben. Abreise des Kunden entfernt seinen Auftrag ohne Belohnung.

Fünf voneinander unabhängige Talentzweige, jeweils fünf aufeinander aufbauende Stufen. Stufe n kostet n Coins:

| Zweig | Effekt je Stufe |
| --- | --- |
| Bekanntheit | +10 % Anfragechance, insgesamt auf 100 % begrenzt |
| Service-Profi | +2 % laufende Hosting-Einnahmen |
| Green Hosting | −3 % tatsächlicher Serververbrauch und Wärme; physische Spitzenreserve bleibt gleich |
| Werkstatt | −10 % automatische Reparaturdauer |
| Kundenliebling | +1 Prozentpunkt Treue-Coin-Chance am Zahlungstag |

## Mitarbeiter

Ein Platz ab der Garage; Tätigkeit jederzeit zwischen Technik und Kundenbetreuung wechselbar. 450 € pro 30 Spieltage, erster Monat im Voraus bei Einstellung, Folgegehälter am individuellen Einstellungstag. Bei fehlendem Geld am Gehaltstag kündigt der Mitarbeiter. Bereits bezahlte Monate werden bei Entlassung nicht erstattet.

Technik verkürzt den automatischen Lageraustausch von 40 auf acht Spielstunden. Kundenbetreuung prüft alle acht Stunden und nimmt maximal einen Kunden an: profitabelste passende Anfrage zuerst, maximal 85 % gebuchter Upload, zusätzlich Qualitätsprüfung aller Kunden über 24 Stunden. Lager und Mitarbeiter arbeiten auch in der Offline-Simulation.

## Migration und Regressionen

Schema 3; unveränderter Dateiname save-v1.json. Schema 1 durchläuft zunächst die bestehende Rack-Migration. Bestehende Kunden erhalten Zahlungstermine relativ zum letzten gespeicherten Vertragsbeginn. Bereits vor dem Update verdientes Geld bleibt separat erhalten und wird einmalig zum bisherigen Monatsende gezahlt. Historische Anfragen enthalten keinen Preisfaktor; dieser wird aus ihrem Angebotspreis angenähert. Neue Anfragen speichern ihn exakt.

Weitere Fixes: Mindestnachfrage auch bei null Reputation; Angebotspreisfaktor unabhängig vom späteren Preisregler; Tutorial über eine explizite Wiederholungskennung erneut aufrufbar. Explizite Backup-Wiederherstellung verarbeitet nun ebenfalls Offline-Zeit.

Die Startwerte sind in Operations.swift und Simulation.swift zentral definiert und eine erste spielbare Balance. Bestehende BalanceLab-Szenarien prüfen weiterhin die Grundprogression ohne den Einsatz von Talenten oder Mitarbeitern.
