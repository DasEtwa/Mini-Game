import SwiftUI
import TycoonCore

enum Destination: Identifiable {
    case laptop, rack(UUID), location, cooling, settings
    var id: String { switch self { case .laptop:return "laptop";case .rack(let id):return id.uuidString;case .location:return "location";case .cooling:return "cooling";case .settings:return "settings" } }
}
struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @State private var destination: Destination?
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            Page {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:3) {
                        Text("RACK & RICH").font(.caption.monospaced().bold()).tracking(3).foregroundStyle(Theme.teal)
                        Text(store.game.room.name).font(.largeTitle.bold())
                        Text("Monat \(store.game.hour/720+1) · Tag \(store.game.hour/24%30+1) · \(store.game.hour%24):00").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { destination = .settings } label: { Image(systemName:"gearshape").frame(width:44,height:44).background(.white,in:Circle()) }.accessibilityLabel("Einstellungen")
                }
                HStack(spacing:12) {
                    Panel { Text("DEIN KONTO").font(.caption2.bold()).foregroundStyle(Theme.muted); Text(euro(store.game.cash)).font(.title2.bold()).minimumScaleFactor(0.7).lineLimit(1) }
                    Panel { Text("GEWINN / MONAT").font(.caption2.bold()).foregroundStyle(Theme.muted); Text(euro(store.game.monthlyProfit)).font(.title2.bold()).foregroundStyle(store.game.monthlyProfit >= 0 ? Theme.teal : Theme.orange).minimumScaleFactor(0.7).lineLimit(1) }
                }
                if store.loading { ProgressView("Server starten …").frame(maxWidth:.infinity).padding() }
                if let problem = store.saveProblem {
                    Panel {
                        Label("Spielstand braucht Aufmerksamkeit",systemImage:"externaldrive.badge.exclamationmark").bold()
                        Text(problem).font(.subheadline)
                        Text("Deine Dateien bleiben erhalten. Die Simulation pausiert, bis du eine Sicherung wiederherstellst oder in den Einstellungen neu beginnst.").font(.caption)
                        ActionButton(title:"Sicherung wiederherstellen",icon:"arrow.counterclockwise") { store.recoverBackup() }
                    }
                }
                RoomScene(game:store.game,laptop:{ openLaptop() },rack:{ destination = .rack($0) },door:{ destination = .location },cooling:{ destination = .cooling })
                HStack {
                    Label("\(store.game.customers.count) Kunden",systemImage:"person.2.fill")
                    Spacer()
                    Label("\(Int(store.game.reputation)) Rep",systemImage:"star.fill")
                    Spacer()
                    Button { store.paused.toggle() } label: { Image(systemName:store.paused ? "play.fill" : "pause.fill").frame(width:44,height:44) }.accessibilityLabel(store.paused ? "Simulation fortsetzen" : "Simulation pausieren")
                }.font(.caption.bold()).foregroundStyle(Theme.teal)
                if !store.game.tutorialDismissed { tutorial }
                if store.game.milestoneCompleted {
                    Panel { Label("GARAGE UNLOCKED",systemImage:"trophy.fill").font(.headline).foregroundStyle(Theme.orange); Text("Ein Tag erfolgreiches Hosting in der Garage. Milestone 1 geschafft! Baue dein kleines Serverreich weiter aus.") }
                }
                Panel {
                    HStack { Text("Betriebsstatus").font(.headline); Spacer(); Text("LIVE").font(.caption2.monospaced().bold()).foregroundStyle(Theme.teal) }
                    Meter(title:"CPU",used:store.game.usage.cpu,capacity:store.game.capacity.cpu,unit:"CU")
                    Meter(title:"RAM",used:store.game.usage.ram,capacity:store.game.capacity.ram,unit:"GB")
                    Meter(title:"Upload",used:store.game.usage.network,capacity:store.game.plan.up,unit:"Mbit/s")
                    Meter(title:"Strom",used:store.game.watts,capacity:store.game.room.power,unit:"W")
                    Meter(title:"Wärme",used:store.game.watts,capacity:store.game.cooling,unit:"W")
                }
                ActionButton(title:"Laptop öffnen · \(store.game.requests.count) Anfragen",icon:"laptopcomputer") { openLaptop() }
                if let event = store.game.events.first {
                    HStack(alignment:.top) { Image(systemName:"bubble.left").foregroundStyle(Theme.orange); Text(event.text).font(.subheadline) }.padding(10)
                }
                Text("Klein anfangen. Groß hosten.").font(.caption).foregroundStyle(Theme.muted).frame(maxWidth:.infinity).padding(.bottom,10)
            }.toolbar(.hidden,for:.navigationBar)
        }
        .sheet(item:$destination) { target in
            NavigationStack {
                Group {
                    switch target {
                    case .laptop: LaptopView()
                    case .rack(let id): RackView(rackID:id)
                    case .location: LocationView()
                    case .cooling: CoolingView()
                    case .settings: SettingsView()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { destination = nil } label: {
                    Label("Zurück ins Zimmer", systemImage: "house.fill")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 48)
                }.accessibilityIdentifier("close-sheet").buttonStyle(.borderedProminent)
                    .padding(.horizontal, 18).padding(.vertical, 8).background(Theme.cream)
            }
            .tint(Theme.teal).presentationDragIndicator(.visible)
        }
        .alert("Rack & Rich",isPresented:Binding(get:{ store.message != nil },set:{ if !$0 { store.message = nil } })) { Button("Alles klar") { store.message = nil } } message: { Text(store.message ?? "") }
        .onReceive(timer) { _ in store.tick() }
    }
    func openLaptop() { store.act { $0.tutorialLaptopOpened = true }; destination = .laptop }
    var tutorial: some View {
        Panel {
            HStack { Label("DEIN ERSTER HOME LAB",systemImage:"sparkles").font(.caption.bold()).foregroundStyle(Theme.orange); Spacer(); Button("Ausblenden") { store.act { $0.tutorialDismissed = true } }.font(.caption).frame(minHeight:44) }
            Text(!store.game.tutorialLaptopOpened ? "Papa hat dir seinen alten Server überlassen. Tippe auf den Laptop und schau nach deinem ersten Kunden." : store.game.customers.isEmpty ? "Öffne im Laptop die Kundenanfragen. BlockBuilder21 wartet auf seinen ersten Server." : "Dein Server verdient Geld! Zahlungen kommen am Monatsende. Tippe auf dein Rack, um CPU oder RAM auszubauen.").font(.subheadline)
            Text("1 Tag = 18 Sekunden · 1 Monat = 9 Minuten. Die Eltern erstatten die ersten 3 Monate je 400 €.").font(.caption).foregroundStyle(Theme.muted)
        }
    }
}
struct LaptopView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Label("home@rack-and-rich ~",systemImage:"terminal").font(.caption.monospaced()).foregroundStyle(Theme.teal)
                Text("Alles unter Kontrolle.").font(.title.bold())
                Text("Dein kleines Hosting-Unternehmen. Ein Laptop reicht fürs Erste.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            Panel {
                menu("Dashboard",subtitle:"Ressourcen & Betriebsstatus",icon:"square.grid.2x2",destination:DashboardView())
                menu("Kunden",subtitle:"\(store.game.requests.count) neue Anfragen · \(store.game.customers.count) aktiv",icon:"person.2",destination:CustomersView())
                menu("Hardware-Shop",subtitle:"Racks, Server & Komponenten",icon:"cpu",destination:ShopView())
                menu("Internet",subtitle:"\(store.game.plan.name) · \(Int(store.game.plan.up)) Mbit Upload",icon:"network",destination:InternetView())
                menu("Finanzen",subtitle:"\(euro(store.game.monthlyProfit)) prognostizierter Monatsgewinn",icon:"chart.bar",destination:FinanceView())
                menu("Statistiken",subtitle:"Die letzten 90 Spieltage",icon:"waveform.path",destination:StatisticsView())
            }
        }.navigationTitle("Laptop").navigationBarTitleDisplayMode(.inline)
    }
    func menu<V:View>(_ title:String,subtitle:String,icon:String,destination:V) -> some View {
        NavigationLink(destination:destination) {
            HStack(spacing:14) {
                Image(systemName:icon).font(.title3).frame(width:42,height:44).background(Theme.teal.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                VStack(alignment:.leading,spacing:3) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(Theme.muted) }
                Spacer(); Image(systemName:"chevron.right").font(.caption)
            }.padding(.vertical,5).foregroundStyle(Theme.ink)
        }.accessibilityIdentifier(title)
    }
}
struct DashboardView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                StatLine(label:"Geld",value:euro(store.game.cash))
                StatLine(label:"Umsatz / Monat",value:euro(store.game.monthlyRevenue))
                StatLine(label:"Ausgaben / Monat",value:euro(store.game.monthlyCosts))
                StatLine(label:"Gewinn / Monat",value:euro(store.game.monthlyProfit))
                StatLine(label:"Kunden",value:"\(store.game.customers.count)")
                StatLine(label:"Reputation",value:"\(Int(store.game.reputation)) / 100")
            }
            Panel {
                Text("Live-Ressourcen").font(.headline)
                Meter(title:"CPU-Leistung",used:store.game.usage.cpu,capacity:store.game.capacity.cpu,unit:"CU")
                Meter(title:"RAM",used:store.game.usage.ram,capacity:store.game.capacity.ram,unit:"GB")
                Meter(title:"Storage",used:store.game.usage.storage,capacity:store.game.capacity.storage,unit:"GB")
                Meter(title:"Upload",used:store.game.usage.network,capacity:store.game.plan.up,unit:"Mbit/s")
                Meter(title:"Strom",used:store.game.watts,capacity:store.game.room.power,unit:"W")
                Meter(title:"Wärme",used:store.game.watts,capacity:store.game.cooling,unit:"W")
                Text("CU = Kerne × Leistungsindex. CPU darf bis 2×, RAM bis 1,25× gebucht werden. Reale Last pro Host entscheidet über die Qualität. Rot bedeutet Drosselung, Beschwerden und geringere Zahlungen.").font(.caption).foregroundStyle(Theme.muted)
            }
            Panel {
                Text("Betriebsjournal").font(.headline)
                if store.game.events.isEmpty { Text("Noch ganz ruhig. Der erste Kunde wartet.").font(.subheadline) }
                ForEach(store.game.events.prefix(12)) { event in Text("Tag \(event.hour/24+1) · \(event.text)").font(.caption).padding(.vertical,3) }
            }
        }.navigationTitle("Dashboard")
    }
}
