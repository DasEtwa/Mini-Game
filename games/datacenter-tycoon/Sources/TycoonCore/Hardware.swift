import Foundation

public enum GameError: Error, LocalizedError, Equatable {
    case rule(String)
    public var errorDescription: String? { switch self { case .rule(let text): return text } }
}
public enum HardwareSystem {
    public static func validate(_ server: Server) throws {
        let ids = [server.board, server.cpu, server.psu] + server.ram + server.storage
        guard ids.allSatisfy({ id in Catalog.parts.contains { $0.id == id } }) else { throw GameError.rule("Unbekannte Hardware.") }
        let board = Catalog.part(server.board)
        guard board.kind == .board, Catalog.part(server.cpu).kind == .cpu, Catalog.part(server.psu).kind == .psu,
              server.ram.allSatisfy({ Catalog.part($0).kind == .ram }), server.storage.allSatisfy({ Catalog.part($0).kind == .storage }) else { throw GameError.rule("Falscher Komponententyp.") }
        guard board.socket == Catalog.part(server.cpu).socket else { throw GameError.rule("CPU benötigt Sockel \(Catalog.part(server.cpu).socket).") }
        guard !server.ram.isEmpty, server.ram.count <= board.ramSlots, server.capacity.ram <= board.maxRAM,
              server.ram.allSatisfy({ Catalog.part($0).generation == board.generation }) else { throw GameError.rule("RAM passt nicht: \(board.ramSlots) Slots, max. \(Int(board.maxRAM)) GB \(board.generation).") }
        guard !server.storage.isEmpty, server.storage.count <= board.storageSlots,
              server.storage.allSatisfy({ Catalog.part($0).generation.isEmpty || Catalog.part($0).generation == board.generation }) else { throw GameError.rule("Storage passt nicht zum Mainboard.") }
        guard server.watts <= Catalog.part(server.psu).capacity else { throw GameError.rule("Netzteil ist zu schwach.") }
    }
    public static func validateRoom(_ state: GameState) throws {
        guard state.racks.count <= state.room.racks else { throw GameError.rule("Kein Platz für ein weiteres Rack.") }
        guard state.reservedWatts <= state.powerLimit else { throw GameError.rule("Stromvertrag ausgelastet. Im Laptop unter Strom aufrüsten oder ein System ausschalten.") }
        for rack in state.racks {
            let spec = Catalog.rack(rack.specID)
            guard !spec.garageOnly || state.location == .garage else { throw GameError.rule("Dieses Rack benötigt die Garage.") }
            guard rack.servers.count <= spec.slots, rack.watts <= spec.watts else { throw GameError.rule("Rack-Slots oder Rack-Stromlimit erreicht.") }
        }
    }
    public static func booked(on server: UUID, in state: GameState) -> Resources {
        state.customers.filter { $0.serverID == server }.reduce(Resources()) { $0+$1.booked }
    }
    public static func canHost(_ request: Customer, on server: Server, in state: GameState) -> Bool {
        let total = booked(on: server.id, in: state) + request.booked
        return server.online && total.cpu <= server.capacity.cpu*Balance.cpuBookingFactor && total.ram <= server.capacity.ram*Balance.ramBookingFactor && total.storage <= server.capacity.storage && total.network <= server.capacity.network
    }
}
public enum ShopSystem {
    private static func charge(_ price: Double, label: String, state: inout GameState) throws {
        guard state.cash >= price else { throw GameError.rule("Dafür fehlen \(Int(ceil(price-state.cash))) €.") }
        state.record(-price, label)
        state.hardwareSpend += price
    }
    public static func buyRack(_ id: String, in state: inout GameState) throws {
        guard let spec = Catalog.racks.first(where: { $0.id == id }) else { throw GameError.rule("Rack unbekannt.") }
        guard !spec.garageOnly || state.location == .garage else { throw GameError.rule("Erst in der Garage erhältlich.") }
        var next = state
        next.racks.append(Rack(specID: id))
        try HardwareSystem.validateRoom(next)
        try charge(spec.price, label: spec.name, state: &next)
        state = next
    }
    public static func upgradeRack(_ rackID: UUID, to id: String, in state: inout GameState) throws {
        guard let index = state.racks.firstIndex(where: { $0.id == rackID }), let spec = Catalog.racks.first(where: { $0.id == id }), spec.slots > Catalog.rack(state.racks[index].specID).slots else { throw GameError.rule("Wähle ein größeres Rack.") }
        guard !spec.garageOnly || state.location == .garage else { throw GameError.rule("Nur in der Garage verfügbar.") }
        var next = state
        next.racks[index].specID = id
        try HardwareSystem.validateRoom(next)
        try charge(spec.price, label: "Rack-Ausbau: \(spec.name)", state: &next)
        state = next
    }
    public static func buyServer(in rackID: UUID, state: inout GameState) throws {
        guard let i = state.racks.firstIndex(where: { $0.id == rackID }) else { throw GameError.rule("Rack fehlt.") }
        var next = state
        var server = Server(); server.name = "Blechkiste \(state.servers.count+1)"; server.cpu = "cpu-home"; server.ram = ["ram-home"]
        next.racks[i].servers.append(server)
        try HardwareSystem.validateRoom(next)
        try charge(Balance.serverPrice, label: "Gebrauchtserver", state: &next)
        state = next
    }
    public static func replace(serverID: UUID, partID: String, append: Bool = false, fromStock: Bool = false, in state: inout GameState) throws {
        guard let part = Catalog.parts.first(where: { $0.id == partID }) else { throw GameError.rule("Hardware unbekannt.") }
        var next = state
        guard let r = next.racks.firstIndex(where: { $0.servers.contains { $0.id == serverID } }),
              let s = next.racks[r].servers.firstIndex(where: { $0.id == serverID }) else { throw GameError.rule("Server fehlt.") }
        var server = next.racks[r].servers[s]
        guard server.fault == nil else { throw GameError.rule("Vor dem Umbau den Defekt reparieren.") }
        switch part.kind {
        case .board: server.board = part.id
        case .cpu: server.cpu = part.id
        case .ram: server.ram = append ? server.ram + [part.id] : [part.id]
        case .storage: server.storage = append ? server.storage + [part.id] : [part.id]
        case .psu: server.psu = part.id
        }
        guard server != next.racks[r].servers[s] else { throw GameError.rule("Diese Komponente ist bereits eingebaut.") }
        try HardwareSystem.validate(server)
        guard HardwareSystem.booked(on: server.id, in: state).storage <= server.capacity.storage else { throw GameError.rule("Belegte Kundendaten passen nicht auf diesen Speicher.") }
        next.racks[r].servers[s] = server
        try HardwareSystem.validateRoom(next)
        if fromStock { try InventorySystem.consume(part.id, in: &next) }
        else { try charge(part.price, label: part.name, state: &next) }
        state = next
    }
    // Board, CPU and RAM must change atomically across incompatible generations.
    public static func modernize(_ id: UUID, in state: inout GameState) throws {
        var next = state
        guard let r = next.racks.firstIndex(where: { $0.servers.contains { $0.id == id } }), let s = next.racks[r].servers.firstIndex(where: { $0.id == id }) else { throw GameError.rule("Server fehlt.") }
        guard next.racks[r].servers[s].board != "board-pro" else { throw GameError.rule("Plattform ist bereits modern.") }
        guard next.racks[r].servers[s].fault == nil else { throw GameError.rule("Vor dem Umbau den Defekt reparieren.") }
        next.racks[r].servers[s].board = "board-pro"
        next.racks[r].servers[s].cpu = "cpu-pro"
        next.racks[r].servers[s].ram = ["ram-32", "ram-32"]
        try HardwareSystem.validate(next.racks[r].servers[s])
        try HardwareSystem.validateRoom(next)
        try charge(2110, label: "A5-Plattform + 12 Kerne + 64 GB", state: &next)
        state = next
    }
    public static func toggle(_ id: UUID, in state: inout GameState) throws {
        var next = state
        guard let r = next.racks.firstIndex(where: { $0.servers.contains { $0.id == id } }), let s = next.racks[r].servers.firstIndex(where: { $0.id == id }) else { throw GameError.rule("Server fehlt.") }
        next.racks[r].servers[s].isOn.toggle()
        try HardwareSystem.validateRoom(next)
        state = next
    }
    public static func repair(_ id: UUID, in state: inout GameState) throws {
        guard let r = state.racks.firstIndex(where: { $0.servers.contains { $0.id == id } }), let s = state.racks[r].servers.firstIndex(where: { $0.id == id }), state.racks[r].servers[s].fault != nil else { throw GameError.rule("Keine Reparatur nötig.") }
        var next = state
        let failure = next.racks[r].servers[s].failure
        next.racks[r].servers[s].fault = nil
        next.racks[r].servers[s].failure = nil
        try HardwareSystem.validateRoom(next)
        try charge(Balance.repairPrice, label: "Reparatur", state: &next)
        InventorySystem.rewardRepair(id, failure: failure, state: &next)
        state = next
    }
    public static func internet(_ id: String, in state: inout GameState) throws {
        guard let plan = Catalog.internet.first(where: { $0.id == id }), plan.id != state.internetID else { throw GameError.rule("Dieser Tarif ist bereits aktiv.") }
        guard !plan.garageOnly || state.location == .garage else { throw GameError.rule("Glasfaser gibt es erst in der Garage.") }
        try charge(plan.setup, label: "Internet: \(plan.name)", state: &state)
        state.internetID = id
    }
    public static func power(_ id: String, in state: inout GameState) throws {
        guard let plan = Catalog.powerPlans.first(where: { $0.id == id }), id != state.powerID else { throw GameError.rule("Stromtarif bereits aktiv oder unbekannt.") }
        guard !plan.garageOnly || state.location == .garage else { throw GameError.rule("Benötigt: Garage.") }
        var next = state
        next.powerID = id
        try HardwareSystem.validateRoom(next)
        try charge(plan.setup, label: "Stromanschluss: \(plan.name)", state: &next)
        state = next
    }
    public static func cooling(in state: inout GameState) throws {
        guard state.coolingLevel < 3 else { throw GameError.rule("Kühlung bereits vollständig ausgebaut.") }
        var next = state
        let price = Double(next.coolingLevel+1)*250
        next.coolingLevel += 1
        try HardwareSystem.validateRoom(next)
        try charge(price, label: "Kühlungs-Ausbau", state: &next)
        state = next
    }
    public static func moveToGarage(_ state: inout GameState) throws {
        guard state.garageEligible else { throw GameError.rule("Benötigt: 18.000 €, 12 Kunden, 2.500 €/Monat und 60 Reputation.") }
        state.record(-Balance.garagePrice, "Garage eingerichtet")
        state.location = .garage
        state.log("Die Garage gehört jetzt deinen Servern. Das Auto muss draußen schlafen.")
    }
    public static func sideJob(_ state: inout GameState) throws {
        guard state.cash < 500, state.hour - (state.lastRecoveryHour ?? -720) >= 720 else { throw GameError.rule("Nachbarschafts-IT: bei weniger als 500 € einmal pro Spielmonat verfügbar.") }
        state.lastRecoveryHour = state.hour
        state.record(600, "Nebenjob: PCs der Nachbarn repariert")
        state.log("600 € vom Nebenjob. Damit kannst du dein Hosting wieder auf Kurs bringen.")
    }
    public static func rescue(_ state: inout GameState) throws {
        guard state.cash < 500, !state.rescueUsed else { throw GameError.rule("Familienhilfe: einmalig bei weniger als 500 € verfügbar.") }
        state.rescueUsed = true
        state.record(2000, "Einmalige Familienhilfe")
        state.log("Papa springt einmal ein. Jetzt den monatlichen Gewinn prüfen!")
    }
}
