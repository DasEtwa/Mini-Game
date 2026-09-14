import SwiftUI
import TycoonCore

struct RackView: View {
    @EnvironmentObject var store: GameStore
    let rackID: UUID
    var rack: Rack? { store.game.racks.first { $0.id == rackID } }
    var body: some View {
        Page {
            if let rack = rack {
                let spec = Catalog.rack(rack.specID)
                Panel {
                    HStack(spacing:24) {
                        RackDrawing(rack:rack).frame(width:85,height:140)
                        VStack(alignment:.leading,spacing:8) { Text(spec.name).font(.title2.bold()); Text("\(rack.servers.count) / \(spec.slots) Systeme"); Text("\(spec.slots-rack.servers.count) freie Slots").font(.caption).foregroundStyle(Theme.teal) }
                    }
                    Meter(title:"Rack-Strom reserviert",used:rack.watts,capacity:spec.watts,unit:"W")
                    Meter(title:"Rack-Wärme",used:rack.servers.reduce(0) { $0+store.game.serverWatts($1) },capacity:spec.cooling,unit:"W")
                    StatLine(label:"Netzwerkbedarf",value:"\(number(store.game.customers.filter { c in rack.servers.contains { $0.id == c.serverID } }.reduce(0) { $0+$1.usage(hour:store.game.hour).network })) Mbit/s")
                }
                ForEach(rack.servers) { server in
                    NavigationLink { ServerView(serverID:server.id) } label: {
                        Panel {
                            HStack { Image(systemName:"server.rack").font(.title); VStack(alignment:.leading,spacing:5) { Text(server.name).font(.headline); Text("\(Catalog.part(server.cpu).name) · \(Int(server.capacity.ram)) GB RAM").font(.caption) }; Spacer(); Image(systemName:"chevron.right") }
                            Label(server.fault ?? (server.online ? "Online · \(Int(store.game.serverWatts(server))) W" : "Ausgeschaltet"),systemImage:server.online ? "circle.fill" : "exclamationmark.circle").font(.caption).foregroundStyle(server.online ? Theme.teal : Theme.orange)
                        }.foregroundStyle(Theme.ink)
                    }.accessibilityIdentifier("server-\(server.id)")
                }
                if rack.servers.count < spec.slots {
                    Panel {
                        Text("Noch Platz für eine Blechkiste.").font(.headline)
                        Text("Gebrauchtserver: FX 8400, 16 GB RAM, 250 GB HDD. Reserviert 142 W, im Leerlauf etwa 50 W.").font(.caption)
                        ActionButton(title:"Server einbauen · 700 €",icon:"plus") { store.act { try ShopSystem.buyServer(in:rackID,state:&$0) } }.accessibilityIdentifier("buy-server")
                    }
                }
                ForEach(Catalog.racks.filter { $0.slots > spec.slots }) { upgrade in
                    if upgrade.garageOnly && store.game.location != .garage { Label("\(upgrade.name) · \(upgrade.slots) Systeme · Benötigt: Garage", systemImage: "lock").font(.caption).padding(8) } else {
                    ActionButton(title:"Auf \(upgrade.name) erweitern · \(euro(upgrade.price))",icon:"arrow.up") { store.act { try ShopSystem.upgradeRack(rackID,to:upgrade.id,in:&$0) } }.accessibilityIdentifier("upgrade-rack-\(upgrade.id)")
                    }
                }
            }
        }.navigationTitle("Rackverwaltung").navigationBarTitleDisplayMode(.inline)
    }
}
struct ServerView: View {
    @EnvironmentObject var store: GameStore
    let serverID: UUID
    var server: Server? { store.game.servers.first { $0.id == serverID } }
    var body: some View {
        Page {
            if let server = server {
                let booked = HardwareSystem.booked(on:server.id,in:store.game)
                let use = server.online ? store.game.customers.filter { $0.serverID == server.id }.reduce(Resources()) { $0+$1.usage(hour:store.game.hour) } : Resources(storage:booked.storage)
                Panel {
                    Text(server.name).font(.title2.bold())
                    if let fault = server.fault { Label(fault,systemImage:"exclamationmark.triangle.fill").foregroundStyle(Theme.orange); ActionButton(title:"Reparieren · 120 €",icon:"wrench") { store.act { try ShopSystem.repair(serverID,in:&$0) } } }
                    Button { store.act { try ShopSystem.toggle(serverID,in:&$0) } } label: { Label(server.isOn ? "Server ausschalten" : "Server einschalten",systemImage:"power").frame(minHeight:44) }.buttonStyle(.bordered)
                    Text("Ausschalten unterbricht Kundenverträge auf diesem Host. Keine automatische Umverteilung.").font(.caption).foregroundStyle(Theme.muted)
                    Meter(title:"CPU live",used:use.cpu,capacity:server.online ? server.capacity.cpu : 0,unit:"CU")
                    Meter(title:"RAM live",used:use.ram,capacity:server.online ? server.capacity.ram : 0,unit:"GB")
                    Meter(title:"CPU gebucht",used:booked.cpu,capacity:server.capacity.cpu*Balance.cpuBookingFactor,unit:"CU")
                    Meter(title:"RAM gebucht",used:booked.ram,capacity:server.capacity.ram*Balance.ramBookingFactor,unit:"GB")
                    Meter(title:"Speicher belegt",used:booked.storage,capacity:server.capacity.storage,unit:"GB")
                    StatLine(label:"Verbrauch / reserviert",value:"\(Int(store.game.serverWatts(server))) / \(Int(server.watts)) W")
                    StatLine(label:"Netzwerkkarte",value:"1.000 Mbit/s")
                }
                Panel {
                    Text("Deine Hardware").font(.headline)
                    component("Mainboard",value:Catalog.part(server.board).name,icon:"rectangle.connected.to.line.below")
                    component("CPU",value:"\(Catalog.part(server.cpu).name) · \(Int(Catalog.part(server.cpu).cores)) Kerne × \(number(Catalog.part(server.cpu).performance))",icon:"cpu")
                    component("RAM",value:server.ram.map { Catalog.part($0).name }.joined(separator:" + "),icon:"memorychip")
                    component("Storage",value:server.storage.map { Catalog.part($0).name }.joined(separator:" + "),icon:"internaldrive")
                    component("Netzteil",value:Catalog.part(server.psu).name,icon:"bolt")
                    let board = Catalog.part(server.board)
                    Text("Sockel \(board.socket) · \(board.generation) · \(server.ram.count)/\(board.ramSlots) RAM-Slots · max. \(Int(board.maxRAM)) GB · \(server.storage.count)/\(board.storageSlots) Laufwerke").font(.caption).foregroundStyle(Theme.muted)
                }
                if server.board == "board-old" {
                    Panel {
                        Text("Eine neue Generation.").font(.headline)
                        Text("Plattform-Kit: Sockelbrett 5 + Rhyzen 12 + 2 × 32 GB DDD5. Mainboard, CPU und RAM werden zusammen getauscht, damit alle Teile kompatibel bleiben.").font(.subheadline)
                        ActionButton(title:"Plattform modernisieren · 2.110 €",icon:"sparkles") { store.act { try ShopSystem.modernize(serverID,in:&$0) } }
                    }
                }
                NavigationLink { PartsShopView(serverID:serverID) } label: { Label("Komponenten kaufen & einbauen",systemImage:"cart").font(.headline).frame(maxWidth:.infinity,minHeight:54).background(Theme.teal,in:RoundedRectangle(cornerRadius:16)).foregroundStyle(.white) }.accessibilityIdentifier("open-components")
            }
        }.navigationTitle("Server").navigationBarTitleDisplayMode(.inline)
    }
    func component(_ name:String,value:String,icon:String) -> some View { HStack(alignment:.top,spacing:12) { Image(systemName:icon).frame(width:22); VStack(alignment:.leading,spacing:3) { Text(name).font(.caption).foregroundStyle(Theme.muted); Text(value).font(.subheadline.bold()) } }.padding(.vertical,5) }
}
struct PartsShopView: View {
    @EnvironmentObject var store: GameStore
    let serverID: UUID
    @State private var kind: PartKind = .cpu
    func title(_ kind:PartKind) -> String { switch kind {case .board:return "Board";case .cpu:return "CPU";case .ram:return "RAM";case .storage:return "Storage";case .psu:return "Netzteil"} }
    var body: some View {
        Page {
            Text("Kauf und Einbau erfolgen direkt in diesen Server. Ersetzen tauscht alle Module dieser Kategorie; Erweiterung belegt einen weiteren Slot. Alte Teile werden recycelt, ohne Verkaufserlös.").font(.caption).foregroundStyle(Theme.muted)
            Picker("Kategorie",selection:$kind) { ForEach(PartKind.allCases,id:\.self) { Text(title($0)).tag($0) } }.pickerStyle(.segmented)
            ForEach(Catalog.parts.filter { $0.kind == kind }) { part in
                Panel {
                    HStack { Text(part.name).font(.headline); Spacer(); Text(euro(part.price)).bold().foregroundStyle(Theme.teal) }
                    Text(details(part)).font(.caption)
                    if let reason = incompatibility(part,append:false) {
                        Label(reason,systemImage:"info.circle").font(.caption).foregroundStyle(Theme.orange)
                    } else {
                        ActionButton(title:"Kaufen & ersetzen",icon:"arrow.triangle.2.circlepath") { store.act { try ShopSystem.replace(serverID:serverID,partID:part.id,in:&$0) } }.accessibilityIdentifier("buy-\(part.id)")
                    }
                    if part.kind == .ram || part.kind == .storage, incompatibility(part,append:true) == nil {
                        Button("Zusätzlich einbauen · \(euro(part.price))") { store.act { try ShopSystem.replace(serverID:serverID,partID:part.id,append:true,in:&$0) } }.frame(maxWidth:.infinity,minHeight:44).buttonStyle(.bordered)
                    }
                }
            }
        }.navigationTitle("Komponenten").navigationBarTitleDisplayMode(.inline)
    }
    func incompatibility(_ part:Part,append:Bool) -> String? {
        var preview = store.game
        preview.cash = max(preview.cash,part.price)
        do { try ShopSystem.replace(serverID:serverID,partID:part.id,append:append,in:&preview); return nil }
        catch { return error.localizedDescription }
    }
    func details(_ part:Part) -> String {
        switch part.kind {
        case .cpu:return "\(Int(part.cores)) Kerne · Leistung ×\(number(part.performance)) · \(Int(part.watts)) W · Sockel \(part.socket)"
        case .board:return "Sockel \(part.socket) · \(part.generation) · \(part.ramSlots) RAM-Slots · max. \(Int(part.maxRAM)) GB · \(part.storageSlots) Laufwerke. Generation wechseln: Plattform-Kit im Server verwenden."
        case .ram:return "\(Int(part.capacity)) GB · \(part.generation) · 1 Slot · \(Int(part.watts)) W"
        case .storage:return "\(Int(part.capacity)) GB · 1 Laufwerk · \(Int(part.watts)) W\(part.generation.isEmpty ? "" : " · benötigt Sockelbrett 5")"
        case .psu:return "Bis \(Int(part.capacity)) W"
        }
    }
}
struct ShopView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        Page {
            Panel {
                Text("Hardware hat ein Zuhause.").font(.title2.bold())
                Text("Komponenten werden in einen konkreten Server eingebaut. Öffne ein Rack und wähle den Server. Neue Systeme kaufst du im freien Rack-Slot.").font(.subheadline)
                ForEach(Array(store.game.racks.enumerated()),id:\.element.id) { index,rack in
                    NavigationLink("Rack \(index+1) · \(rack.servers.count) Systeme") { RackView(rackID:rack.id) }.frame(minHeight:44)
                }
            }
            Text("Racks · \(store.game.racks.count)/\(store.game.room.racks) Stellplätze").font(.title2.bold())
            ForEach(Catalog.racks) { rack in
                Panel {
                    Text(rack.name).font(.headline)
                    StatLine(label:"System-Slots",value:"\(rack.slots)")
                    StatLine(label:"Strom / Kühlung",value:"\(Int(rack.watts)) / \(Int(rack.cooling)) W")
                    if rack.garageOnly && store.game.location != .garage { Label("Benötigt: Garage",systemImage:"lock").font(.caption) }
                    else { ActionButton(title:"Rack kaufen · \(euro(rack.price))",icon:"plus") { store.act { try ShopSystem.buyRack(rack.id,in:&$0) } }.disabled(store.game.racks.count >= store.game.room.racks) }
                }
            }
        }.navigationTitle("Hardware-Shop").navigationBarTitleDisplayMode(.inline)
    }
}
