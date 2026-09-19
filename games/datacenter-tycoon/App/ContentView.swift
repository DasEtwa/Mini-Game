import SwiftUI
import TycoonCore

enum Destination: Identifiable {
    case laptop, rack(UUID), location, cooling, settings, shop
    var id: String { switch self { case .laptop:return "laptop";case .rack(let id):return id.uuidString;case .location:return "location";case .cooling:return "cooling";case .settings:return "settings";case .shop:return "shop" } }
}
struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @State private var destination: Destination?
    @State private var tutorialVisible = true
    @State private var showSaveProblem = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 0) {
            hud
            RoomScene(game: store.game, laptop: { openLaptop() }, rack: { destination = .rack($0) }, door: { destination = .location }, cooling: { destination = .cooling }, freeRack: { destination = .shop })
                .equatable()
                .overlay(alignment: .top) {
                    if tutorialVisible && !store.game.tutorialDismissed { tutorial.padding(.horizontal, 10).padding(.top, 45) }
                }
            HStack {
                Label("\(store.game.customers.count) Kunden", systemImage: "person.2.fill")
                Spacer()
                Button { openLaptop() } label: { Label("\(store.game.requests.count) Anfragen", systemImage: "envelope.badge") }.accessibilityIdentifier("requests-shortcut")
                Spacer()
                Button { store.paused.toggle() } label: { Image(systemName: store.paused ? "play.fill" : "pause.fill").frame(width: 44, height: 44) }
                    .accessibilityLabel(store.paused ? "Simulation fortsetzen" : "Simulation pausieren")
            }.font(.caption.bold()).padding(.horizontal, 14)
        }.background(Theme.cream).foregroundStyle(Theme.ink).tint(Theme.teal)
        .overlay {
            if store.loading { ProgressView("Server starten …").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
        }
        .sheet(item: $destination) { target in
            VStack(spacing: 0) {
                // Outside the navigation stack: close stays visible even on pushed detail pages.
                HStack {
                    Label("home@rack-and-rich", systemImage: "terminal").font(.caption.monospaced()).foregroundStyle(Theme.teal)
                    Spacer()
                    Button { destination = nil } label: { Image(systemName: "xmark").font(.headline).frame(width: 44, height: 44) }
                        .accessibilityLabel("Management schließen").accessibilityIdentifier("dismiss-management")
                }.padding(.horizontal, 16).background(Theme.cream)
                NavigationStack {
                    switch target {
                    case .laptop: LaptopView()
                    case .rack(let id): RackView(rackID: id)
                    case .location: LocationView()
                    case .cooling: CoolingView()
                    case .settings: SettingsView()
                    case .shop: ShopView()
                    }
                }
            }.tint(Theme.teal).presentationDragIndicator(.visible).presentationDetents([.large])
        }
        .alert(showSaveProblem ? "Spielstand braucht Aufmerksamkeit" : "Rack & Rich", isPresented: Binding(
            get: { store.message != nil || showSaveProblem },
            set: { if !$0 { store.message = nil; showSaveProblem = false } }
        )) {
            if showSaveProblem {
                Button("Sicherung wiederherstellen") { store.recoverBackup() }
                Button("Einstellungen") { destination = .settings }
            } else { Button("Alles klar") { store.message = nil } }
        } message: { Text(showSaveProblem ? (store.saveProblem ?? "") : (store.message ?? "")) }
        .onChange(of: store.saveProblem) { _, problem in showSaveProblem = problem != nil }
        .onReceive(timer) { _ in store.tick() }
        .task(id: "\(store.game.tutorialDismissed)-\(store.tutorialRevision)") {
            tutorialVisible = true
            try? await Task.sleep(for: .seconds(18))
            guard !Task.isCancelled else { return }
            withAnimation { tutorialVisible = false }
        }
    }
    private var hud: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(euro(store.game.cash)).font(.title2.bold()).monospacedDigit().accessibilityIdentifier("cash-hud")
                    Text("\(store.game.monthlyProfit >= 0 ? "+" : "")\(euro(store.game.monthlyProfit))/Monat")
                        .font(.caption.bold()).foregroundStyle(store.game.monthlyProfit >= 0 ? Theme.teal : Theme.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.game.room.name).font(.subheadline.bold())
                    Text("\(GameState.dateLabel(hour: store.game.hour)) · \(Int(store.game.reputation)) Rep").font(.caption2)
                    Text("\(store.game.operations.coins) RackCoins").font(.caption2.bold()).foregroundStyle(Theme.orange)
                }
                Button { destination = .settings } label: { Image(systemName: store.saveProblem == nil ? "gearshape" : "exclamationmark.triangle").frame(width: 44, height: 44) }.accessibilityLabel("Einstellungen")
            }
            HStack(spacing: 10) {
                gauge("CPU", use: store.game.usage.cpu, max: store.game.capacity.cpu)
                gauge("RAM", use: store.game.usage.ram, max: store.game.capacity.ram)
                gauge("Upload", use: store.game.usage.network, max: store.game.plan.up)
                gauge("Strom", use: store.game.watts, max: store.game.powerLimit)
                gauge("Wärme", use: store.game.watts, max: store.game.cooling)
            }
        }.padding(.horizontal, 14).padding(.top, 4).padding(.bottom, 10)
    }
    private func gauge(_ name: String, use: Double, max capacity: Double) -> some View {
        let ratio = ResourceSystem.ratio(use, capacity)
        return VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.system(size: 10, weight: .medium))
            Text("\(Int(ratio*100)) %").font(.system(size: 11, weight: .bold, design: .monospaced))
            ProgressView(value: min(1, ratio)).tint(ratio > 1 ? .red : ratio > 0.8 ? Theme.orange : Theme.teal)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
    func openLaptop() { destination = .laptop; store.act { $0.tutorialLaptopOpened = true } }
    private var tutorial: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill").foregroundStyle(Theme.orange)
            Text(!store.game.tutorialLaptopOpened ? "Papas Server wartet. Tippe auf den Laptop für deinen ersten Kunden." : store.game.customers.isEmpty ? "Im Laptop unter Kunden wartet deine erste Anfrage." : "Du hostest! Im Rack kannst du deinen Server ausbauen.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            Button { store.act { $0.tutorialDismissed = true } } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Tutorial ausblenden")
        }.padding(.leading, 12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
struct LaptopView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            HStack {
                VStack(alignment: .leading) {
                    Text("HOST OS").font(.title2.monospaced().bold())
                    Text("\(store.game.requests.count) Anfragen · \(store.game.customers.count) Kunden").font(.caption)
                }
                Spacer()
                Image(systemName: "terminal.fill").font(.largeTitle).foregroundStyle(Theme.teal)
            }.padding(.bottom, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                app("Dashboard", icon: "square.grid.2x2", destination: DashboardView())
                app("Kunden", icon: "person.2", destination: CustomersView())
                app("Hardware-Shop", icon: "cpu", destination: ShopView())
                app("Internet", icon: "network", destination: InternetView())
                app("Strom", icon: "bolt.fill", destination: PowerView())
                app("Finanzen", icon: "chart.bar", destination: FinanceView())
                app("Statistiken", icon: "waveform.path", destination: StatisticsView())
                app("Lager", icon: "shippingbox", destination: InventoryView())
                app("Aufträge", icon: "checklist", destination: JobsView())
                app("Talente", icon: "sparkles", destination: TalentsView())
                app("Mitarbeiter", icon: "person.badge.key", destination: StaffView())
            }
        }.navigationTitle("Laptop").navigationBarTitleDisplayMode(.inline)
    }
    private func app<V: View>(_ title: String, icon: String, destination: V) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundStyle(Theme.teal)
                Text(title).font(.subheadline.bold()).foregroundStyle(Theme.ink)
            }.frame(maxWidth: .infinity, minHeight: 82).background(.white, in: RoundedRectangle(cornerRadius: 16))
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
                Meter(title:"Strom",used:store.game.watts,capacity:store.game.powerLimit,unit:"W")
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
