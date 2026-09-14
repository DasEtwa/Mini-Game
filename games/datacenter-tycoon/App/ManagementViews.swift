import SwiftUI
import Charts
import TycoonCore

struct CustomersView: View {
    @EnvironmentObject var store: GameStore
    @State private var showActive = false
    @State private var cancelID: UUID?
    var body: some View {
        Page {
            Panel {
                DisclosureGroup("Hosting-Angebot & Preise") {
                StatLine(label:"Small VPS · 1 CU / 1 GB / 15 GB",value:"\(euro(7*store.game.priceFactor))/Mo")
                HStack { Text("Preisniveau"); Spacer(); Text("\(Int(store.game.priceFactor*100)) %").bold() }
                Slider(value:Binding(get:{store.game.priceFactor},set:{ value in store.act { $0.priceFactor = value } }),in:0.8...1.3,step:0.05).accessibilityLabel("Preisniveau für neue Anfragen")
                Text("Gilt für neue Anfragen. Höhere Preise verringern die Nachfrage. Betreute Websites, Shops und Teams zahlen mehr für Service; sie brauchen eine gute Reputation.").font(.caption).foregroundStyle(Theme.muted)
            }
                }
            Picker("Kundenansicht",selection:$showActive) { Text("Anfragen (\(store.game.requests.count))").tag(false); Text("Aktiv (\(store.game.customers.count))").tag(true) }.pickerStyle(.segmented)
            if (showActive ? store.game.customers : store.game.requests).isEmpty {
                ContentUnavailableView(showActive ? "Noch keine Kunden" : "Alles abgearbeitet",systemImage:"person.crop.circle.badge.clock",description:Text("Neue Anfragen kommen bei guter Nachfrage frühestens alle 54 Sekunden bei normalem Tempo."))
            }
            ForEach(showActive ? store.game.customers : store.game.requests) { customer in
                Panel {
                    HStack(alignment:.top) {
                        VStack(alignment:.leading,spacing:4) { Text(customer.name).font(.headline); Text("\(customer.region.rawValue) · \(Catalog.customers.first { $0.id == customer.typeID }?.name ?? "Hosting")").font(.caption).foregroundStyle(Theme.muted) }
                        Spacer(); Text("\(euro(customer.monthlyPrice))\n/ Monat").font(.subheadline.bold()).multilineTextAlignment(.trailing).foregroundStyle(Theme.teal)
                    }
                    Text("\(number(customer.booked.cpu)) CU · \(number(customer.booked.ram)) GB RAM · \(number(customer.booked.storage)) GB\n\(number(customer.booked.network)) Mbit/s · Uptime-Ziel \(Int(customer.uptimeExpectation*100)) %").font(.caption)
                    if showActive {
                        let usage = customer.usage(hour:store.game.hour)
                        Text("Jetzt: \(customer.activity(hour:store.game.hour).rawValue) · \(number(usage.cpu)) CU · \(number(usage.ram)) GB RAM").font(.caption).foregroundStyle(Theme.teal)
                        if let contract = customer.contract {
                            StatLine(label: "Laufzeit", value: "\(contract.months) Monate · noch \(contract.daysRemaining(hour: store.game.hour)) Tage")
                            StatLine(label: "Status", value: "Aktiv · \(contract.renewals)× verlängert")
                            let chance = ContractSystem.renewalChance(customer, reputation: store.game.reputation)
                            Text("Verlängerung: \(chance >= 0.8 ? "wahrscheinlich" : chance >= 0.5 ? "unsicher" : "gefährdet") (\(Int(chance*100)) %). Qualität, Preis und Zufriedenheit zählen.").font(.caption).foregroundStyle(Theme.muted)
                        }
                        StatLine(label:"Zufriedenheit",value:"\(Int(customer.satisfaction)) %")
                        Text("Host: \(store.game.servers.first { $0.id == customer.serverID }?.name ?? "Offline")").font(.caption)
                        Button("Vertrag kündigen",role:.destructive) { cancelID = customer.id }.frame(minHeight:44)
                    } else {
                        Text("Vertrag: \(ContractSystem.term(for: customer.typeID)) Monate, danach mögliche Verlängerung.").font(.caption.bold())
                        Text("Anfrage gültig: noch \(max(0,customer.expiresHour-store.game.hour)) Spielstunden. Host wird passend zugewiesen.").font(.caption).foregroundStyle(Theme.muted)
                        HStack {
                            Button("Ablehnen") { store.act { CustomerSystem.decline(customer.id,in:&$0) } }.buttonStyle(.bordered).controlSize(.large)
                            ActionButton(title:"Annehmen",icon:"checkmark") { store.act { try CustomerSystem.accept(customer.id,in:&$0) } }.accessibilityIdentifier("accept-\(customer.name)")
                        }
                    }
                }
            }
        }.navigationTitle("Kunden").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Vertrag kündigen? Reputation −1. Bereits verdientes Geld bleibt erhalten.",isPresented:Binding(get:{cancelID != nil},set:{if !$0 {cancelID=nil}}),titleVisibility:.visible) {
                Button("Vertrag kündigen",role:.destructive) { if let id = cancelID { store.act { CustomerSystem.cancel(id,in:&$0) } }; cancelID=nil }
            }
    }
}
struct InternetView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel { Text("Upload ist dein Nadelöhr.").font(.title2.bold()); Meter(title:"Aktueller Upload",used:store.game.usage.network,capacity:store.game.plan.up,unit:"Mbit/s"); Text("Verträge gelten sofort. Monatliche Gebühren werden zeitanteilig berechnet, die Anschlussgebühr wird sofort abgezogen.").font(.caption) }
            ForEach(Catalog.internet) { plan in
                Panel {
                    Text(plan.name).font(.headline)
                    StatLine(label:"Download / Upload",value:"\(Int(plan.down)) / \(Int(plan.up)) Mbit/s")
                    StatLine(label:"Monatlich",value:euro(plan.monthly))
                    StatLine(label:"Einmaliger Anschluss",value:euro(plan.setup))
                    if plan.id == store.game.internetID { Label("Aktiv",systemImage:"checkmark.seal.fill").foregroundStyle(Theme.teal) }
                    else if plan.garageOnly && store.game.location != .garage { Label("Benötigt Garage",systemImage:"lock").font(.caption) }
                    else { ActionButton(title:"Tarif wechseln",icon:"network") { store.act { try ShopSystem.internet(plan.id,in:&$0) } } }
                }
            }
        }.navigationTitle("Internet")
    }
}
struct FinanceView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text("Monatliche Prognose").font(.headline)
                StatLine(label:"Hosting",value:euro(store.game.monthlyRevenue))
                StatLine(label:"Miete / Kostenbeitrag",value:euro(store.game.room.rent))
                StatLine(label:"Internet",value:euro(store.game.plan.monthly))
                StatLine(label:"Strom",value:euro(store.game.monthlyPowerCost))
                Divider(); StatLine(label:"Gewinn",value:euro(store.game.monthlyProfit))
                Text("Strom: \(Int(store.game.watts)) W ÷ 1.000 × 720 h × \(energyRate(store.game.powerPlan.kWh)) €/kWh + \(euro(store.game.powerPlan.monthly)) Grundgebühr. Prognose ohne Ausfälle, Starthilfe und Einmalkäufe.").font(.caption).foregroundStyle(Theme.muted)
            }
            Panel {
                Text("Laufender Monat").font(.headline)
                StatLine(label:"Verdient, noch nicht ausgezahlt",value:euro(store.game.earnedThisMonth))
                StatLine(label:"Strom bisher",value:euro(store.game.electricityThisMonth))
                StatLine(label:"Miete & Internet bisher",value:euro(store.game.fixedCostsThisMonth))
                StatLine(label:"Hardware & Anschluss gesamt",value:euro(store.game.hardwareSpend))
                Text("Abrechnung in \(720-store.game.hour%720) Spielstunden. Die ersten 3 Monate erstatten deine Eltern je 400 €. Zahlungen sind zeitanteilig und bei schlechter Leistung reduziert.").font(.caption)
                if store.game.cash < 500 { ActionButton(title:"Nachbarschafts-IT · +600 € / Spielmonat",icon:"wrench") { store.act { try ShopSystem.sideJob(&$0) } } }
                if !store.game.rescueUsed && store.game.cash < 500 { ActionButton(title:"Einmalige Familienhilfe · +2.000 €",icon:"heart") { store.act { try ShopSystem.rescue(&$0) } } }
            }
            Panel {
                Text("Kontobuch").font(.headline)
                if store.game.ledger.isEmpty { Text("Noch keine Buchungen.").font(.caption) }
                ForEach(store.game.ledger.prefix(50)) { entry in
                    VStack(alignment:.leading,spacing:4) { StatLine(label:entry.label,value:euro(entry.amount)); Text("Tag \(entry.hour/24+1)").font(.caption2).foregroundStyle(Theme.muted) }.padding(.vertical,4)
                }
            }
        }.navigationTitle("Finanzen")
    }
}
struct StatisticsView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            if store.game.history.isEmpty { ContentUnavailableView("Der erste Spieltag läuft",systemImage:"chart.xyaxis.line",description:Text("Nach jedem Spieltag wird ein Messpunkt gespeichert.")) }
            Panel {
                Text("Ressourcen · % Auslastung").font(.headline)
                Chart(store.game.history) { s in
                    LineMark(x:.value("Tag",s.hour/24),y:.value("Auslastung",s.cpu*100)).foregroundStyle(by:.value("Ressource","CPU"))
                    LineMark(x:.value("Tag",s.hour/24),y:.value("Auslastung",s.ram*100)).foregroundStyle(by:.value("Ressource","RAM"))
                    LineMark(x:.value("Tag",s.hour/24),y:.value("Auslastung",s.network*100)).foregroundStyle(by:.value("Ressource","Upload"))
                }.chartForegroundStyleScale(["CPU":Theme.teal,"RAM":Theme.orange,"Upload":Color.blue]).frame(height:210)
            }
            Panel {
                Text("Vertraglicher Monatsumsatz · €").font(.headline)
                Chart(store.game.history) { s in AreaMark(x:.value("Tag",s.hour/24),y:.value("Umsatz",s.revenue)).foregroundStyle(Theme.teal.opacity(0.2)); LineMark(x:.value("Tag",s.hour/24),y:.value("Umsatz",s.revenue)).foregroundStyle(Theme.teal) }.frame(height:170)
            }
            Panel {
                Text("Aktive Kunden").font(.headline)
                Chart(store.game.history) { s in BarMark(x:.value("Tag",s.hour/24),y:.value("Kunden",s.customers)).foregroundStyle(Theme.orange) }.frame(height:150)
            }
        }.navigationTitle("Statistiken")
    }
}
struct LocationView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text(store.game.location == .garage ? "Willkommen in der Garage." : "Dein nächster großer Schritt.").font(.title.bold())
                Text("Mehr Platz. Mehr Leistung. Weniger Schlafen neben blinkenden LEDs.").foregroundStyle(Theme.muted)
                StatLine(label:"Rack-Plätze",value:"2 → 4")
                StatLine(label:"Strom",value:"bis 1.200 → 3.200 W")
                StatLine(label:"Basiskühlung",value:"350 → 1.800 W")
                StatLine(label:"Miete",value:"400 → 700 €/Monat")
                Text("Alle Racks, Server, Kunden und Kühlungsstufen ziehen mit. Business Fiber und 6-Slot-Racks werden verfügbar.").font(.caption)
            }
            if store.game.location == .bedroom {
                Panel {
                    Text("Garagenschlüssel verdienen").font(.headline)
                    requirement("\(euro(store.game.cash)) / 18.000 €",met:store.game.cash >= Balance.garagePrice)
                    requirement("\(store.game.customers.count) / 12 aktive Kunden",met:store.game.customers.count >= Balance.garageCustomers)
                    requirement("\(euro(store.game.monthlyRevenue)) / 2.500 € Monatsumsatz",met:store.game.monthlyRevenue >= Balance.garageRevenue)
                    requirement("\(Int(store.game.reputation)) / 60 Reputation",met:store.game.reputation >= Balance.garageReputation)
                    ActionButton(title:"Garage einrichten · 18.000 €",icon:"door.left.hand.open") { store.act { try ShopSystem.moveToGarage(&$0) } }.disabled(!store.game.garageEligible).accessibilityIdentifier("unlock-garage")
                }
            } else {
                Panel { Label(store.game.milestoneCompleted ? "Milestone 1 geschafft" : "Hoste einen vollen Tag in der Garage",systemImage:store.game.milestoneCompleted ? "trophy.fill" : "clock").font(.headline); Meter(title:"Erfolgreiche Betriebsstunden",used:Double(store.game.garageOperatingHours),capacity:24,unit:"h") }
            }
            Panel { Text("Irgendwann: AI Compute Center.").font(.headline); Text("Büro → Serverraum → Datacenter → AI Center\nDie nächste Reise folgt in einem späteren Update.").font(.subheadline).foregroundStyle(Theme.muted) }
        }.navigationTitle("Standorte")
    }
    func requirement(_ text:String,met:Bool) -> some View { Label(text,systemImage:met ? "checkmark.circle.fill" : "circle").font(.subheadline).foregroundStyle(met ? Theme.teal : Theme.muted).padding(.vertical,3) }
}
struct CoolingView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text("Bitte nicht die Bettdecke lüften.").font(.title2.bold())
                Meter(title:"Raumwärme",used:store.game.watts,capacity:store.game.cooling,unit:"W")
                Text("Bei Überhitzung drosseln CPUs. Jedes Rack hat zusätzlich ein eigenes Wärmelimit. Raumkühlung ersetzt kein größeres Rack.").font(.subheadline)
                StatLine(label:"Kühlungsstufe",value:"\(store.game.coolingLevel) / 3")
                Text(store.game.location == .bedroom ? "Ventilator → mobile Klimaanlage → Abluft. Jede Stufe bringt 200 W Kühlkapazität und benötigt 35 W Strom." : "Jede Stufe bringt 600 W Kühlkapazität und benötigt 35 W Strom.").font(.caption)
                if store.game.coolingLevel < 3 { ActionButton(title:"Kühlung ausbauen · \(euro(Double(store.game.coolingLevel+1)*250))",icon:"fanblades") { store.act { try ShopSystem.cooling(in:&$0) } } }
            }
        }.navigationTitle("Kühlung")
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: GameStore
    @State private var confirmReset = false
    var body: some View {
        Page {
            Panel {
                Toggle("Kaufsound",isOn:Binding(get:{store.game.soundEnabled},set:{ v in store.act { $0.soundEnabled=v } }))
                Toggle("Simulation pausieren",isOn:$store.paused)
                Picker("Tempo",selection:$store.speed) { Text("1×").tag(1); Text("2×").tag(2); Text("3×").tag(3) }.pickerStyle(.segmented)
                Text("Normales Tempo: 18 Sekunden pro Spieltag, 9 Minuten pro Monat. Offline läuft normales Tempo, maximal 2 echte Stunden. Pause gilt nur bei geöffneter App.").font(.caption)
                ActionButton(title:"Jetzt speichern",icon:"externaldrive") { store.save(reportSuccess: true) }
                Button("Tutorial wieder zeigen") { store.act { $0.tutorialDismissed=false } }.frame(minHeight:44)
            }
            Panel {
                Text("Deine Daten bleiben hier.").font(.headline)
                Text("Kein Konto. Keine Werbung. Kein Tracking. Keine Cloud. Spielstände liegen lokal in Application Support/RackAndRich. Eine atomare Sicherung schützt den letzten gültigen Stand.").font(.subheadline)
                Text("Rack & Rich · Version 0.1.1\nGrafik, Hardware-Universum und Sound wurden für dieses Spiel erstellt.").font(.caption).foregroundStyle(Theme.muted)
                Button("Neues Spiel starten",role:.destructive) { confirmReset=true }.frame(minHeight:44)
            }
        }.navigationTitle("Einstellungen").confirmationDialog("Neues Spiel starten? Der bisherige Stand wird archiviert und durch einen neuen ersetzt.",isPresented:$confirmReset,titleVisibility:.visible) { Button("Neues Spiel",role:.destructive) { store.reset() } }
    }
}

struct PowerView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text(store.game.powerPlan.name).font(.headline)
                Meter(title: "Verbrauch jetzt", used: store.game.watts, capacity: store.game.powerLimit, unit: "W")
                Meter(title: "Reservierte Spitzenleistung", used: store.game.reservedWatts, capacity: store.game.powerLimit, unit: "W")
                Text("Beim Einschalten reservierst du die Spitzenleistung. Bezahlt wird nur der lastabhängige Verbrauch. Leere Racks brauchen keinen Strom.").font(.caption)
            }
            ForEach(Catalog.powerPlans) { plan in
                Panel {
                    Text(plan.name).font(.headline)
                    StatLine(label: "Anschlussleistung", value: "\(Int(plan.watts)) W")
                    StatLine(label: "Arbeitspreis", value: "\(energyRate(plan.kWh)) €/kWh")
                    StatLine(label: "Grundgebühr / Monat", value: euro(plan.monthly))
                    StatLine(label: "Einrichtung", value: euro(plan.setup))
                    if plan.id == store.game.powerID { Label("Aktiv", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.teal) }
                    else if plan.garageOnly && store.game.location != .garage { Label("Benötigt: Garage", systemImage: "lock") }
                    else { ActionButton(title: "Stromvertrag wechseln", icon: "bolt") { store.act { try ShopSystem.power(plan.id, in: &$0) } } }
                }
            }
        }.navigationTitle("Strom").navigationBarTitleDisplayMode(.inline)
    }
}
