import SwiftUI
import TycoonCore

struct InventoryView: View {
    @EnvironmentObject var store: GameStore
    @State private var kind: PartKind = .cpu
    @State private var quantity = 1
    var body: some View {
        Page {
            Panel {
                Text("Für den nächsten Ausfall gerüstet.").font(.title2.bold())
                Text("Teile bleiben im Lager, bis du sie einbaust oder ein defektes Teil ersetzt wird. Die Automatik verwendet dasselbe Modell; sie kauft nichts nach.").font(.subheadline)
                Toggle("Automatisch aus Lager reparieren", isOn: Binding(get: { store.game.operations.automaticRepairs }, set: { value in store.act { $0.operations.automaticRepairs = value } }))
                Text("Reparatur nach \(store.game.autoRepairHours) Spielstunden (\(number(Double(store.game.autoRepairHours) * Balance.secondsPerDay / 24)) Sekunden bei 1×). Technik-Mitarbeiter und Werkstatt-Talente beschleunigen den Austausch. Auch offline aktiv.").font(.caption).foregroundStyle(Theme.muted)
            }
            Picker("Teile", selection: $kind) {
                Text("CPU").tag(PartKind.cpu); Text("RAM").tag(PartKind.ram)
                Text("Disk").tag(PartKind.storage); Text("PSU").tag(PartKind.psu); Text("Board").tag(PartKind.board)
            }.pickerStyle(.segmented)
            Stepper("Menge: \(quantity)", value: $quantity, in: 1...99).accessibilityIdentifier("stock-quantity")
            ForEach(Catalog.parts.filter { $0.kind == kind }) { part in
                Panel {
                    Text(part.name).font(.headline)
                    StatLine(label: "Auf Lager", value: "\(store.game.operations.stock[part.id, default: 0]) Stück")
                    ActionButton(title: "\(quantity) × kaufen · \(euro(part.price * Double(quantity)))", icon: "shippingbox") {
                        store.act { try InventorySystem.buy(part.id, quantity: quantity, in: &$0) }
                    }.accessibilityIdentifier("stock-buy-\(part.id)")
                }
            }
            Text("Einbauen: Rack → Server → Komponenten. Direkte Käufe und Lager-Einbau prüfen dieselben Sockel-, Slot- und Stromlimits.").font(.caption)
        }.navigationTitle("Lager").navigationBarTitleDisplayMode(.inline)
    }
}

struct TalentsView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Label("\(store.game.operations.coins) RackCoins", systemImage: "bitcoinsign.circle.fill").font(.title2.bold()).foregroundStyle(Theme.orange)
                Text("Kunden bedanken sich gelegentlich bei Zahlung oder schneller Reparatur. Erfüllte Wochenaufträge bringen garantiert 1 Coin. Keine Käufe mit echtem Geld.").font(.subheadline)
            }
            ForEach(Talent.allCases, id: \.self) { talent in
                TalentRow(talent: talent)
            }
        }.navigationTitle("Talentbaum").navigationBarTitleDisplayMode(.inline)
    }
}
private struct TalentRow: View {
    @EnvironmentObject var store: GameStore
    let talent: Talent
    var level: Int { store.game.operations.level(talent) }
    var body: some View {
        Panel {
            HStack { Text(talent.name).font(.headline); Spacer(); Text("\(level) / 5").monospacedDigit() }
            Text(talent.effect).font(.caption)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { step in
                    Text("\(step)").font(.headline).frame(maxWidth: .infinity, minHeight: 36)
                        .background(step <= level ? Theme.teal : Theme.cream, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(step <= level ? Color.white : Theme.ink)
                }
            }.accessibilityLabel("\(level) von 5 Stufen freigeschaltet")
            if level < 5 {
                ActionButton(title: "Stufe \(level + 1) · \(level + 1) RackCoins", icon: "arrow.up") {
                    store.act { try TalentSystem.upgrade(talent, in: &$0) }
                }.disabled(store.game.operations.coins < level + 1).accessibilityIdentifier("talent-\(talent.rawValue)")
            } else { Label("Vollständig ausgebaut", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.teal) }
        }
    }
}

struct JobsView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text("Ein bisschen mehr Leistung, bitte.").font(.title2.bold())
                Text("Kunden fragen gelegentlich nach +2 CU für 7 Spieltage. Mindestens 95 % der Stunden müssen das Uptime-Ziel erfüllen. Belohnung: 1 RackCoin. Danach wird die CPU-Buchung automatisch zurückgesetzt.").font(.subheadline)
            }
            if store.game.operations.jobs.isEmpty {
                ContentUnavailableView("Gerade keine Aufträge", systemImage: "checklist", description: Text("Hoste Kunden mit mindestens einer Woche Restlaufzeit. Neue Aufträge können täglich eintreffen."))
            }
            ForEach(store.game.operations.jobs) { job in
                JobRow(job: job)
            }
        }.navigationTitle("Kundenaufträge").navigationBarTitleDisplayMode(.inline)
    }
}
private struct JobRow: View {
    @EnvironmentObject var store: GameStore
    let job: CustomerJob
    var body: some View {
        Panel {
            Text(store.game.customers.first { $0.id == job.customerID }?.name ?? "Kunde").font(.headline)
            Label("+2 CU · 7 Tage · 1 RackCoin", systemImage: "bitcoinsign.circle").foregroundStyle(Theme.orange)
            if let start = job.startedHour, let end = job.endHour {
                StatLine(label: "Läuft bis", value: GameState.dateLabel(hour: end))
                Meter(title: "Fortschritt", used: Double(store.game.hour-start), capacity: Double(CustomerJob.duration), unit: "h")
                Text("\(job.goodHours) erfolgreiche von \(store.game.hour-start) bisherigen Stunden.").font(.caption)
            } else {
                Text("Angebot: noch \(max(0, job.offeredHour + 72 - store.game.hour)) Spielstunden").font(.caption)
                ActionButton(title: "Auftrag annehmen", icon: "checkmark") { store.act { try JobSystem.accept(job.id, in: &$0) } }
                    .accessibilityIdentifier("job-accept")
                Button("Ablehnen") { store.act { JobSystem.decline(job.id, in: &$0) } }.frame(minHeight: 44)
            }
        }
    }
}

struct StaffView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text("Verstärkung fürs Hosting.").font(.title2.bold())
                Text("Ein Mitarbeiterplatz ab der Garage. 450 € für jeweils 30 Spieltage, den ersten Monat zahlst du bei Einstellung. Reicht das Geld am Gehaltstag nicht, kündigt dein Mitarbeiter.").font(.subheadline)
            }
            if store.game.location != .garage {
                Label("Ziehe zuerst in die Garage.", systemImage: "lock.fill")
            } else if let employee = store.game.operations.employee {
                Panel {
                    Label("Mitarbeiter im Dienst", systemImage: "person.crop.circle.badge.checkmark").font(.headline)
                    Picker("Aufgabe", selection: Binding(get: { store.game.operations.employee?.role ?? .maintenance }, set: { role in store.act { $0.operations.employee?.role = role } })) {
                        ForEach(StaffRole.allCases, id: \.self) { Text($0.name).tag($0) }
                    }.pickerStyle(.segmented)
                    roleDescription(employee.role)
                    StatLine(label: "Nächstes Gehalt", value: GameState.dateLabel(hour: employee.nextSalaryHour))
                    Text("Automatische Lagerreparatur muss für Technik eingeschaltet sein.").font(.caption)
                    Button("Beschäftigung beenden", role: .destructive) { store.act { StaffSystem.dismiss(in: &$0) } }.frame(minHeight: 44)
                }
            } else {
                ForEach(StaffRole.allCases, id: \.self) { role in
                    Panel {
                        Text(role.name).font(.headline)
                        roleDescription(role)
                        ActionButton(title: "Einstellen · 450 €", icon: "person.badge.plus") { store.act { try StaffSystem.hire(role, in: &$0) } }
                            .accessibilityIdentifier("hire-\(role.rawValue)")
                    }
                }
            }
        }.navigationTitle("Mitarbeiter").navigationBarTitleDisplayMode(.inline)
    }
    private func roleDescription(_ role: StaffRole) -> some View {
        Text(role == .maintenance
             ? "Technik ersetzt defekte Teile aus deinem Lager nach 8 statt 40 Spielstunden. Werkstatt-Talente beschleunigen das weiter."
             : "Kundenbetreuung prüft alle 8 Spielstunden Anfragen und nimmt höchstens einen passenden Kunden an. Upload-Reserve und ein Lastcheck über 24 Stunden schützen bestehende Kunden.")
            .font(.subheadline)
    }
}
