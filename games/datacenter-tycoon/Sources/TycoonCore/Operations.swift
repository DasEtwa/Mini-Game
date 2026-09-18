import Foundation

public struct CustomerBilling: Codable, Equatable, Sendable {
    public var nextPaymentHour: Int
    public var accrued = 0.0
    public init(hour: Int) { nextPaymentHour = hour + 720 }
}
public struct CashReceipt: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var rackID: UUID
    public var amount: Double
    public var hour: Int
}
public struct HardwareFailure: Codable, Equatable, Sendable {
    public var partID: String
    public var slot: Int
    public var startedHour: Int
}
public enum Talent: String, Codable, CaseIterable, Sendable {
    case marketing, revenue, efficiency, repairs, loyalty
    public var name: String {
        switch self {
        case .marketing: return "Bekanntheit"
        case .revenue: return "Service-Profi"
        case .efficiency: return "Green Hosting"
        case .repairs: return "Werkstatt"
        case .loyalty: return "Kundenliebling"
        }
    }
    public var effect: String {
        switch self {
        case .marketing: return "+10 % Anfragechance je Stufe"
        case .revenue: return "+2 % Hosting-Einnahmen je Stufe"
        case .efficiency: return "−3 % Serververbrauch und Wärme je Stufe"
        case .repairs: return "−10 % automatische Reparaturzeit je Stufe"
        case .loyalty: return "+1 Prozentpunkt Chance auf Treue-Coins je Stufe"
        }
    }
}
public enum StaffRole: String, Codable, CaseIterable, Sendable {
    case maintenance, sales
    public var name: String { self == .maintenance ? "Technik" : "Kundenbetreuung" }
}
public struct Employee: Codable, Equatable, Sendable {
    public var role: StaffRole
    public var nextSalaryHour: Int
    public var nextActionHour: Int
}
public struct CustomerJob: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var customerID: UUID
    public var offeredHour: Int
    public var startedHour: Int? = nil
    public var goodHours = 0
    public static let duration = 168
    public static let extraCPU = 2.0
    public var endHour: Int? { startedHour.map { $0 + Self.duration } }
}
public struct OperationsState: Codable, Equatable, Sendable {
    public var stock: [String: Int] = [:]
    public var automaticRepairs = true
    public var coins = 0
    public var talents: [String: Int] = [:]
    public var employee: Employee? = nil
    public var jobs: [CustomerJob] = []
    public var receipts: [CashReceipt] = []
    // Earnings from v1/v2 remain payable at their original month end.
    public var legacyReceivable = 0.0
    public var nextTipHour = 0
    public init() {}
    public func level(_ talent: Talent) -> Int { talents[talent.rawValue, default: 0] }
}
public extension GameState {
    var revenueMultiplier: Double { 1 + Double(operations.level(.revenue)) * 0.02 }
    var efficiencyMultiplier: Double { 1 - Double(operations.level(.efficiency)) * 0.03 }
    var pendingRevenue: Double { customers.reduce(operations.legacyReceivable) { $0 + ($1.billing?.accrued ?? 0) } }
    var autoRepairHours: Int {
        let base = operations.employee?.role == .maintenance ? 8.0 : 40.0
        return Int(ceil(base * (1 - Double(operations.level(.repairs)) * 0.10)))
    }
    static func dateLabel(hour: Int) -> String {
        let day = max(0, hour) / 24
        return "\(day % 30 + 1).\((day / 30) % 12 + 1).\(1111 + day / 360)"
    }
}
public enum TalentSystem {
    public static func upgrade(_ talent: Talent, in state: inout GameState) throws {
        let level = state.operations.level(talent)
        guard level < 5 else { throw GameError.rule("Talent bereits auf Stufe 5.") }
        let price = level + 1
        guard state.operations.coins >= price else { throw GameError.rule("Benötigt: \(price) RackCoins.") }
        state.operations.coins -= price
        state.operations.talents[talent.rawValue] = level + 1
    }
    public static func tip(in state: inout GameState, chance: Double, reason: String) {
        guard state.hour >= state.operations.nextTipHour, state.random() < chance else { return }
        state.operations.coins += 1
        state.operations.nextTipHour = state.hour + 24
        state.log("+1 RackCoin · \(reason)")
    }
}
public enum InventorySystem {
    public static func buy(_ partID: String, quantity: Int, in state: inout GameState) throws {
        guard let part = Catalog.parts.first(where: { $0.id == partID }), (1...99).contains(quantity),
              state.operations.stock[partID, default: 0] + quantity <= 999 else { throw GameError.rule("Lagerkauf: 1–99 Teile, maximal 999 pro Typ.") }
        let price = part.price * Double(quantity)
        guard state.cash >= price else { throw GameError.rule("Nicht genug Geld für diesen Lagerkauf.") }
        state.record(-price, "Lager: \(quantity) × \(part.name)")
        state.hardwareSpend += price
        state.operations.stock[partID, default: 0] += quantity
    }
    public static func consume(_ partID: String, in state: inout GameState) throws {
        guard state.operations.stock[partID, default: 0] > 0 else { throw GameError.rule("Passendes Ersatzteil fehlt im Lager.") }
        state.operations.stock[partID, default: 0] -= 1
    }
    public static func fail(_ serverID: UUID, partID: String, slot: Int = 0, in state: inout GameState) {
        guard let r = state.racks.firstIndex(where: { $0.servers.contains { $0.id == serverID } }),
              let s = state.racks[r].servers.firstIndex(where: { $0.id == serverID }), state.racks[r].servers[s].online else { return }
        let server = state.racks[r].servers[s]
        let parts = [server.cpu, server.psu] + server.ram + server.storage
        guard parts.contains(partID) else { return }
        state.racks[r].servers[s].failure = .init(partID: partID, slot: slot, startedHour: state.hour)
        state.racks[r].servers[s].fault = "\(Catalog.part(partID).name) defekt"
        state.log("\(server.name): \(Catalog.part(partID).name) defekt. Ersatz aus dem Lager oder Reparaturdienst.")
    }
    public static func repair(_ serverID: UUID, in state: inout GameState) throws {
        guard let r = state.racks.firstIndex(where: { $0.servers.contains { $0.id == serverID } }),
              let s = state.racks[r].servers.firstIndex(where: { $0.id == serverID }),
              let failure = state.racks[r].servers[s].failure, state.racks[r].servers[s].fault != nil else { throw GameError.rule("Kein austauschbares defektes Teil.") }
        var next = state
        try consume(failure.partID, in: &next)
        next.racks[r].servers[s].fault = nil
        next.racks[r].servers[s].failure = nil
        try HardwareSystem.validateRoom(next)
        rewardRepair(serverID, failure: failure, state: &next)
        next.log("\(next.racks[r].servers[s].name): Ersatzteil eingebaut.")
        state = next
    }
    public static func rewardRepair(_ id: UUID, failure: HardwareFailure?, state: inout GameState) {
        guard let failure, state.hour - failure.startedHour <= 16,
              state.customers.contains(where: { $0.serverID == id }) else { return }
        TalentSystem.tip(in: &state, chance: 0.35, reason: "Danke für die schnelle Reparatur!")
    }
    public static func tick(_ state: inout GameState) {
        guard state.operations.automaticRepairs else { return }
        for server in state.servers where server.isOn {
            if let failure = server.failure, state.hour - failure.startedHour >= state.autoRepairHours {
                try? repair(server.id, in: &state)
            }
        }
    }
}
public enum StaffSystem {
    public static let salary = 450.0
    public static func hire(_ role: StaffRole, in state: inout GameState) throws {
        guard state.location == .garage, state.operations.employee == nil else { throw GameError.rule("Ein Mitarbeiterplatz ab der Garage.") }
        guard state.cash >= salary else { throw GameError.rule("Für den ersten Gehaltsmonat werden 450 € benötigt.") }
        state.record(-salary, "Mitarbeiter: erster Gehaltsmonat")
        state.operations.employee = .init(role: role, nextSalaryHour: state.hour + 720, nextActionHour: state.hour + 8)
    }
    public static func dismiss(in state: inout GameState) { state.operations.employee = nil }
    public static func tick(_ state: inout GameState) {
        guard var employee = state.operations.employee else { return }
        if state.hour >= employee.nextSalaryHour {
            guard state.cash >= salary else {
                state.operations.employee = nil
                state.log("Dein Mitarbeiter kündigt: Das Gehalt von 450 € konnte nicht bezahlt werden.")
                return
            }
            state.record(-salary, "Mitarbeitergehalt")
            employee.nextSalaryHour += 720
        }
        if state.hour >= employee.nextActionHour {
            employee.nextActionHour = state.hour + 8
            if employee.role == .sales {
                // Leave upload headroom and reject work that would overload the shared connection at peak.
                let bookedNetwork = state.customers.reduce(0) { $0 + $1.booked.network }
                for request in state.requests.sorted(by: { $0.monthlyPrice > $1.monthlyPrice }) {
                    guard bookedNetwork + request.booked.network <= state.plan.up * 0.85 else { continue }
                    var preview = state
                    if (try? CustomerSystem.accept(request.id, in: &preview)) != nil {
                        let healthy = (0..<24).allSatisfy { offset in
                            var sample = preview; sample.hour += offset
                            return sample.customers.allSatisfy { ResourceSystem.quality(for: $0, in: sample) >= $0.uptimeExpectation }
                        }
                        if healthy { state = preview; break }
                    }
                }
            }
        }
        state.operations.employee = employee
    }
}
public enum JobSystem {
    public static func generate(in state: inout GameState) {
        guard state.operations.jobs.count < 3 else { return }
        let eligible = state.customers.filter { customer in
            !state.operations.jobs.contains { $0.customerID == customer.id } && (customer.contract?.endHour ?? 0) > state.hour + CustomerJob.duration
        }
        guard !eligible.isEmpty else { return }
        let index = min(eligible.count - 1, Int(state.random() * Double(eligible.count)))
        state.operations.jobs.append(.init(customerID: eligible[index].id, offeredHour: state.hour))
    }
    public static func accept(_ id: UUID, in state: inout GameState) throws {
        guard let j = state.operations.jobs.firstIndex(where: { $0.id == id }), state.operations.jobs[j].startedHour == nil,
              state.hour < state.operations.jobs[j].offeredHour + 72,
              let c = state.customers.firstIndex(where: { $0.id == state.operations.jobs[j].customerID }),
              let server = state.servers.first(where: { $0.id == state.customers[c].serverID }),
              (state.customers[c].contract?.endHour ?? 0) >= state.hour + CustomerJob.duration else { throw GameError.rule("Auftrag nicht mehr verfügbar oder Vertragslaufzeit zu kurz.") }
        var extra = state.customers[c]; extra.booked = .init(cpu: CustomerJob.extraCPU)
        guard HardwareSystem.canHost(extra, on: server, in: state) else { throw GameError.rule("Für den Auftrag fehlen 2 CU auf dem Host.") }
        state.customers[c].booked.cpu += CustomerJob.extraCPU
        state.operations.jobs[j].startedHour = state.hour
    }
    public static func decline(_ id: UUID, in state: inout GameState) {
        state.operations.jobs.removeAll { $0.id == id && $0.startedHour == nil }
    }
    public static func tick(_ state: inout GameState, qualities: [UUID: Double]) {
        for j in state.operations.jobs.indices.reversed() {
            let job = state.operations.jobs[j]
            guard let c = state.customers.firstIndex(where: { $0.id == job.customerID }) else { state.operations.jobs.remove(at: j); continue }
            guard let end = job.endHour else {
                if state.hour >= job.offeredHour + 72 { state.operations.jobs.remove(at: j) }
                continue
            }
            let quality = state.customers[c].serverID.flatMap { qualities[$0] } ?? 0
            if quality >= state.customers[c].uptimeExpectation { state.operations.jobs[j].goodHours += 1 }
            if state.hour >= end {
                state.customers[c].booked.cpu -= CustomerJob.extraCPU
                if state.operations.jobs[j].goodHours >= Int(ceil(Double(CustomerJob.duration) * 0.95)) {
                    state.operations.coins += 1
                    state.log("+1 RackCoin · Wochenauftrag von \(state.customers[c].name) erfüllt!")
                } else { state.log("Wochenauftrag nicht erfüllt: zu viele Stunden unter dem Uptime-Ziel.") }
                state.operations.jobs.remove(at: j)
            }
        }
    }
}
