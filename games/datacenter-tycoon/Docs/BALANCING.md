# Balancing, Milestone 1

Standardtempo: 18 Sekunden/Tag, 9 Minuten/Monat. Garage: 18.000 € Zahlung, 12 Kunden, 2.500 € MRR, 60 Reputation. Alle Werte zentral in Catalog/Balance.

Der private 7-€-VPS ist Tutorial und Platzfüller, nicht die Haupteinnahmequelle. 8 Kundentypen reichen von 7 bis 720 €/Monat. Größere Einnahmen sind als betreutes Hosting positioniert und werden über Reputation freigeschaltet. Drei Monate 400 € Zuschuss verhindern, dass die anfängliche Miete das Geschäft sofort vernichtet. Kein unendlicher Zuschuss. Einmalige 2.000-€-Familienhilfe unter 500 € als Recovery; ein neues Spiel bleibt möglich.

Die Strategie in BalanceLab handelt einmal je Spieltag: reparieren, Wärme prüfen, Upload bei 8/18 Kunden ausbauen, CPU/RAM/Storage erweitern, A5-Kits oder weitere Systeme bei hoher Buchung kaufen, Anfragen nach Preis priorisieren. Keine Geld-Cheats, keine versteckten Freischaltungen, normale Shop-/Kunden-APIs. Fünf Seeds prüfen Erreichbarkeit. Diese Strategie ist zügig; menschliches Lesen und langsamere Entscheidungen dauern länger. 2×/3× sind freiwillige Beschleunigung.

CPU-Kapazität = Kerne × Performanceindex. CPU darf 2× und RAM 1,25× gebucht werden; Storage wird hart reserviert. Reale CPU-/RAM-/Upload-Last schwankt nach lokaler Aktivitätsstunde und Kundenphase. Qualität wird pro physischem Host berechnet, zusätzlich begrenzt durch Raum-Upload und Rack-/Raumwärme. Bei Überlastung sinken stündlicher Umsatz, Zufriedenheit und Reputation. Kunden unter 25 % Zufriedenheit kündigen beim Tageswechsel.

Strom wird konservativ als konfigurierte Leistungsaufnahme aller laufenden Systeme angesetzt. 0,30 €/kWh, 720 Stunden/Monat. Strom- und Fixkosten werden stündlich akkumuliert: Ein Tarif- oder Raumwechsel kurz vor Abrechnung kann keine Monatskosten umgehen. Monatseinnahmen sind ebenfalls zeitanteilig und nicht rückwirkend für frisch akzeptierte Kunden.

Reparaturwahrscheinlichkeit: 0,4 % pro Server-Spieltag nach dem ersten Monat; Fixpreis 120 €. Offline gelten dieselben Regeln, maximal 2 Stunden bei 1×.

Automatisch gemessene Ergebnisse stehen in VALIDATION.md und im CI-Artefakt balance-results.txt.
