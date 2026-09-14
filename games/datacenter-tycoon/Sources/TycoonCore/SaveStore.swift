import Foundation

public enum SaveStore {
    public static func validate(_ state: GameState) throws {
        guard state.saveVersion == 1 else { throw GameError.rule("Spielstand-Version \(state.saveVersion) wird nicht unterstützt. Bitte App aktualisieren.") }
        let numbers = [state.cash, state.reputation, state.priceFactor, state.earnedThisMonth, state.electricityThisMonth, state.fixedCostsThisMonth, state.lifetimeRevenue, state.hardwareSpend, state.offlineRemainder]
        guard numbers.allSatisfy(\.isFinite), (0...100).contains(state.reputation), (0.8...1.3).contains(state.priceFactor),
              state.hour >= 0, state.hour < 100_000_000, (0...3).contains(state.coolingLevel), !state.racks.isEmpty,
              state.racks.count <= state.room.racks, state.servers.count <= 24, state.requests.count <= 10, state.customers.count <= 1000,
              state.earnedThisMonth >= 0, state.electricityThisMonth >= 0, state.fixedCostsThisMonth >= 0,
              state.offlineRemainder >= 0, state.offlineRemainder < Balance.secondsPerDay/24,
              Catalog.internet.contains(where: { $0.id == state.internetID && (!$0.garageOnly || state.location == .garage) }) else { throw GameError.rule("Spielstand enthält ungültige Werte.") }
        guard Set(state.racks.map(\.id)).count == state.racks.count, Set(state.servers.map(\.id)).count == state.servers.count,
              Set((state.customers+state.requests).map(\.id)).count == state.customers.count+state.requests.count else { throw GameError.rule("Spielstand enthält doppelte IDs.") }
        for rack in state.racks {
            guard let spec = Catalog.racks.first(where: { $0.id == rack.specID }), rack.servers.count <= spec.slots,
                  !spec.garageOnly || state.location == .garage else { throw GameError.rule("Ungültiges Rack.") }
            for server in rack.servers { try HardwareSystem.validate(server) }
        }
        for customer in state.customers+state.requests {
            let r = customer.booked
            guard Catalog.customers.contains(where: { $0.id == customer.typeID }),
                  [r.cpu,r.ram,r.storage,r.network,customer.monthlyPrice,customer.satisfaction,customer.uptimeExpectation].allSatisfy({ $0.isFinite && $0 >= 0 }),
                  customer.uptimeExpectation <= 1, customer.satisfaction <= 100, (-24...24).contains(customer.phase),
                  customer.serverID == nil || state.servers.contains(where: { $0.id == customer.serverID }) else { throw GameError.rule("Ungültiger Kundenvertrag.") }
        }
        guard state.customers.allSatisfy({ $0.serverID != nil }) else { throw GameError.rule("Kunde ohne Host.") }
    }
    public static func encode(_ state: GameState) throws -> Data {
        try validate(state)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
    public static func decode(_ data: Data) throws -> GameState {
        // Inspect the envelope before decoding fields so future saves are never silently reset.
        let envelope = try JSONDecoder().decode(VersionEnvelope.self, from: data)
        guard envelope.saveVersion == 1 else { throw GameError.rule("Neuere Spielstand-Version. Bitte App aktualisieren.") }
        let state = try JSONDecoder().decode(GameState.self, from: data)
        try validate(state)
        return state
    }
    private struct VersionEnvelope: Decodable { let saveVersion: Int }
    public static func save(_ state: GameState, to url: URL) throws {
        let data = try encode(state)
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let previous = try? Data(contentsOf: url), (try? decode(previous)) != nil {
            try previous.write(to: url.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
    public static func load(from url: URL) throws -> GameState { try decode(Data(contentsOf: url)) }
    public static func offline(_ state: inout GameState, now: Date) -> Int {
        let elapsed = now.timeIntervalSince(state.lastSavedAt)
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        let seconds = min(elapsed, Balance.offlineCap)+state.offlineRemainder
        let hourSeconds = Balance.secondsPerDay/24
        let hours = Int(seconds/hourSeconds)
        state.offlineRemainder = seconds-Double(hours)*hourSeconds
        Simulation.advance(hours: hours, state: &state)
        // Never move backwards. A forward clock jump cannot be rewarded again by resetting it.
        state.lastSavedAt = max(state.lastSavedAt, now)
        return hours
    }
}
