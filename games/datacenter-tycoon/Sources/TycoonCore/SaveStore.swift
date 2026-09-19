import Foundation

public enum SaveStore {
    public static func validate(_ state: GameState) throws {
        guard state.saveVersion == 3 else { throw GameError.rule("Spielstand-Version \(state.saveVersion) wird nicht unterstützt. Bitte App aktualisieren.") }
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
            for server in rack.servers {
                try HardwareSystem.validate(server)
                if let failure = server.failure {
                    guard server.fault != nil, failure.startedHour >= 0, failure.startedHour <= state.hour,
                          failure.slot >= 0, ([server.cpu, server.psu] + server.ram + server.storage).contains(failure.partID) else { throw GameError.rule("Ungültiger Hardwaredefekt.") }
                }
            }
        }
        guard Catalog.powerPlans.contains(where: { $0.id == state.powerID && (!$0.garageOnly || state.location == .garage) }) else { throw GameError.rule("Ungültiger Stromvertrag.") }
        for customer in state.customers+state.requests {
            if let factor = customer.quotedPriceFactor {
                guard factor.isFinite, (0.8...1.3).contains(factor) else { throw GameError.rule("Ungültiger Angebotspreis.") }
            }
            if let billing = customer.billing {
                guard billing.accrued.isFinite, billing.accrued >= 0, billing.nextPaymentHour > state.hour,
                      billing.nextPaymentHour <= state.hour + 720 else { throw GameError.rule("Ungültiger Zahlungstermin.") }
            }
            if let term = customer.contract {
                guard [1,2,3,6,12].contains(term.months), term.startedHour >= 0, term.endHour > term.startedHour,
                      term.priceFactor.isFinite, (0.8...1.3).contains(term.priceFactor), term.serviceHours >= 0,
                      term.qualitySum.isFinite, term.qualitySum >= 0, term.qualitySum <= Double(term.serviceHours),
                      term.poorHours >= 0, term.poorHours <= term.serviceHours else { throw GameError.rule("Ungültige Vertragslaufzeit.") }
            }
            let r = customer.booked
            guard Catalog.customers.contains(where: { $0.id == customer.typeID }),
                  [r.cpu,r.ram,r.storage,r.network,customer.monthlyPrice,customer.satisfaction,customer.uptimeExpectation].allSatisfy({ $0.isFinite && $0 >= 0 }),
                  customer.uptimeExpectation <= 1, customer.satisfaction <= 100, (-24...24).contains(customer.phase),
                  customer.serverID == nil || state.servers.contains(where: { $0.id == customer.serverID }) else { throw GameError.rule("Ungültiger Kundenvertrag.") }
        }
        try HardwareSystem.validateRoom(state)
        guard state.customers.allSatisfy({ $0.serverID != nil && $0.contract != nil && $0.billing != nil }) else { throw GameError.rule("Kunde ohne Host oder Abrechnung.") }
        try validateOperations(state)
    }
    public static func encode(_ state: GameState) throws -> Data {
        try validate(state)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
    public static func decode(_ data: Data) throws -> GameState {
        // Inspect the envelope before decoding fields so future saves are never silently reset.
        let envelope = try JSONDecoder().decode(VersionEnvelope.self, from: data)
        guard (1...3).contains(envelope.saveVersion) else { throw GameError.rule("Neuere Spielstand-Version. Bitte App aktualisieren.") }
        let legacy = envelope.saveVersion == 1 ? try migrate(data) : data
        let state = try JSONDecoder().decode(GameState.self, from: envelope.saveVersion < 3 ? migrateOperations(legacy) : legacy)
        try validate(state)
        return state
    }
    private static func migrate(_ data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw GameError.rule("Spielstand unlesbar.") }
        json["saveVersion"] = 2
        json["operations"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(OperationsState()))
        json["powerID"] = (json["location"] as? String) == "garage" ? "business" : "home-max"
        var state = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        // Reject malformed legacy references before using catalog-derived properties.
        for rack in state.racks {
            guard Catalog.racks.contains(where: { $0.id == rack.specID }) else { throw GameError.rule("Unbekanntes Rack im alten Spielstand.") }
            for server in rack.servers { try HardwareSystem.validate(server) }
        }
        // Preserve every host, customer, UUID and component from the old permissive rack rules.
        if state.location == .bedroom, state.racks.contains(where: { $0.specID != "home" }) {
            let servers = state.servers
            if servers.count <= 4 {
                let refund = state.racks.reduce(0.0) { $0 + max(0, Catalog.rack($1.specID).price - 350) }
                state.racks = stride(from: 0, to: max(1, servers.count), by: 2).map { start in
                    Rack(servers: Array(servers.dropFirst(start).prefix(2)))
                }
                state.record(refund, "Migration: Differenz der Home-Racks erstattet")
            } else {
                state.location = .garage
                state.powerID = "business"
                state.log("Bestandsschutz: Deine großen Racks ziehen kostenlos in die Garage. Alle Server und Kunden bleiben erhalten.")
            }
        }
        for i in state.customers.indices {
            state.customers[i].contract = CustomerContract(months: 3, hour: state.hour, priceFactor: state.priceFactor)
        }
        state.log("Update: Bestehende Kunden erhalten drei Monate Laufzeit. Ein passender Stromvertrag ist für deinen Bestand freigeschaltet.")
        return try JSONEncoder().encode(state)
    }
    private static func migrateOperations(_ data: Data) throws -> Data {
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw GameError.rule("Spielstand unlesbar.") }
        json["saveVersion"] = 3
        json["operations"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(OperationsState()))
        var state = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        state.operations.legacyReceivable = state.earnedThisMonth
        for i in state.customers.indices {
            let start = state.customers[i].contract?.startedHour ?? state.hour
            let elapsed = max(0, state.hour - start)
            var billing = CustomerBilling(hour: state.hour)
            billing.nextPaymentHour = state.hour + 720 - elapsed % 720
            state.customers[i].billing = billing
            state.customers[i].quotedPriceFactor = state.customers[i].contract?.priceFactor ?? 1
        }
        // Historic offers have no stored quote factor; infer it within their ±10% price variation.
        for i in state.requests.indices {
            guard let type = Catalog.customers.first(where: { $0.id == state.requests[i].typeID }) else { throw GameError.rule("Unbekannte Kundenanfrage.") }
            state.requests[i].quotedPriceFactor = min(1.3, max(0.8, state.requests[i].monthlyPrice / type.price))
        }
        state.log("Update: individuelle Zahlungstage. Bereits verdiente Altbeträge kommen noch zum Monatsende.")
        return try JSONEncoder().encode(state)
    }
    private static func validateOperations(_ state: GameState) throws {
        let ops = state.operations
        guard ops.coins >= 0, ops.coins <= 1_000_000_000, ops.nextTipHour >= 0,
              ops.legacyReceivable.isFinite, ops.legacyReceivable >= 0, ops.receipts.count <= 24, ops.jobs.count <= 3,
              ops.stock.allSatisfy({ key, count in Catalog.parts.contains { $0.id == key } && (0...999).contains(count) }),
              ops.talents.allSatisfy({ key, level in Talent(rawValue: key) != nil && (0...5).contains(level) }),
              Set(ops.jobs.map(\.id)).count == ops.jobs.count,
              Set(ops.jobs.map(\.customerID)).count == ops.jobs.count else { throw GameError.rule("Ungültiges Lager oder RackCoin-Fortschritt.") }
        if let employee = ops.employee {
            guard state.location == .garage, employee.nextSalaryHour > state.hour, employee.nextSalaryHour <= state.hour + 720,
                  employee.nextActionHour > state.hour, employee.nextActionHour <= state.hour + 8 else { throw GameError.rule("Ungültiger Mitarbeitervertrag.") }
        }
        for receipt in ops.receipts {
            guard receipt.amount.isFinite, receipt.amount > 0, receipt.hour >= 0, receipt.hour <= state.hour,
                  state.racks.contains(where: { $0.id == receipt.rackID }) else { throw GameError.rule("Ungültige Zahlung.") }
        }
        for job in ops.jobs {
            guard let customer = state.customers.first(where: { $0.id == job.customerID }), job.offeredHour >= 0,
                  job.offeredHour <= state.hour, (0...CustomerJob.duration).contains(job.goodHours) else { throw GameError.rule("Ungültiger Kundenauftrag.") }
            if let start = job.startedHour {
                guard start >= job.offeredHour, start <= state.hour, state.hour < start + CustomerJob.duration,
                      job.goodHours <= state.hour - start, customer.booked.cpu >= CustomerJob.extraCPU else { throw GameError.rule("Ungültiger aktiver Auftrag.") }
            } else if job.goodHours != 0 { throw GameError.rule("Ungültiger Auftragsfortschritt.") }
        }
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
