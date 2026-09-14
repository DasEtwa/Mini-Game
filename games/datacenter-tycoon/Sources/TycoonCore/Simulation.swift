import Foundation

public enum CustomerSystem {
    public static func accept(_ id: UUID, serverID: UUID? = nil, in state: inout GameState) throws {
        guard let index = state.requests.firstIndex(where: { $0.id == id }) else { throw GameError.rule("Anfrage abgelaufen.") }
        var request = state.requests[index]
        let hosts = state.servers.filter { (serverID == nil || $0.id == serverID) && HardwareSystem.canHost(request, on: $0, in: state) }
        guard let host = hosts.min(by: { HardwareSystem.booked(on: $0.id, in: state).ram/$0.capacity.ram < HardwareSystem.booked(on: $1.id, in: state).ram/$1.capacity.ram }) else { throw GameError.rule("Kein passender Online-Host. CPU/RAM-Buchung oder Speicher voll: Hardware ausbauen.") }
        request.serverID = host.id
        state.customers.append(request)
        state.requests.remove(at: index)
        state.acceptedTotal += 1
        state.log("\(request.name) ist online. Willkommen auf deiner Blechkiste!")
    }
    public static func decline(_ id: UUID, in state: inout GameState) { state.requests.removeAll { $0.id == id } }
    public static func cancel(_ id: UUID, in state: inout GameState) {
        guard state.customers.contains(where: { $0.id == id }) else { return }
        state.customers.removeAll { $0.id == id }
        state.reputation = max(0, state.reputation-1)
        state.log("Vertrag beendet. Deine Reputation sinkt um 1.")
    }
    public static func generate(in state: inout GameState) {
        guard state.requests.count < 10 else { return }
        let eligible = Catalog.customers.filter { $0.minReputation <= state.reputation }
        let index = min(eligible.count-1, Int(state.random()*Double(eligible.count)))
        let type = eligible[index]
        let variation = 0.9 + state.random()*0.2
        let regionIndex = min(2, Int(state.random()*3))
        let suffix = Int(state.random()*900)+100
        let phase = Int(state.random()*5)-2
        state.requests.append(Customer(name: "\(type.name)\(suffix)", typeID: type.id, booked: type.resources,
                                       monthlyPrice: (type.price*variation*state.priceFactor).rounded(), region: Region.allCases[regionIndex], phase: phase,
                                       uptimeExpectation: type.uptime, expiresHour: state.hour+120))
    }
}
public enum ResourceSystem {
    public static func ratio(_ use: Double, _ capacity: Double) -> Double { capacity > 0 ? use/capacity : (use > 0 ? 2 : 0) }
    public static func hostQualities(in state: GameState) -> [UUID: Double] {
        var load: [UUID: Resources] = [:]
        var network = 0.0
        for customer in state.customers {
            let use = customer.usage(hour: state.hour)
            network += use.network
            if let id = customer.serverID { load[id, default: Resources()] = load[id, default: Resources()] + use }
        }
        let roomHeat = max(1, state.watts/state.cooling)
        let networkPressure = ratio(network, state.plan.up)
        var qualities: [UUID: Double] = [:]
        for rack in state.racks {
            let throttle = 1/max(roomHeat, rack.watts/Catalog.rack(rack.specID).cooling)
            for server in rack.servers {
                guard server.online else { qualities[server.id] = 0; continue }
                let use = load[server.id, default: Resources()]
                let capacity = server.capacity
                let pressure = max(1, ratio(use.cpu, capacity.cpu*throttle), ratio(use.ram, capacity.ram), networkPressure, ratio(use.network, capacity.network))
                qualities[server.id] = 1/pressure
            }
        }
        return qualities
    }
    public static func quality(for customer: Customer, in state: GameState) -> Double {
        guard let id = customer.serverID else { return 0 }
        return hostQualities(in: state)[id] ?? 0
    }
}
public enum EconomySystem {
    public static func accrueHour(_ state: inout GameState, qualities: [UUID: Double]? = nil) {
        let resolved = qualities ?? ResourceSystem.hostQualities(in: state)
        for customer in state.customers {
            let quality = customer.serverID.flatMap { resolved[$0] } ?? 0
            state.earnedThisMonth += customer.monthlyPrice/(30*24)*quality
        }
        state.electricityThisMonth += state.watts/1000*Balance.electricity
        state.fixedCostsThisMonth += (state.room.rent+state.plan.monthly)/(30*24)
    }
    public static func closeMonth(_ state: inout GameState) {
        let revenue = state.earnedThisMonth
        state.record(revenue, "Hosting-Einnahmen")
        state.lifetimeRevenue += revenue
        state.record(-state.electricityThisMonth, "Stromrechnung")
        state.record(-state.fixedCostsThisMonth, "Miete & Internet")
        if state.hour <= 3*30*24 { state.record(400, "Gründerhilfe: Eltern erstatten 400 € (3 Monate)") }
        state.log("Monat abgerechnet: \(Int(revenue)) € Hosting-Umsatz. Papa: ‚Und die Stromrechnung?‘")
        state.earnedThisMonth = 0; state.electricityThisMonth = 0; state.fixedCostsThisMonth = 0
    }
}
public enum Simulation {
    public static func advance(hours: Int, state: inout GameState) {
        guard hours > 0 else { return }
        for _ in 0..<hours {
            state.hour += 1
            let qualities = ResourceSystem.hostQualities(in: state)
            EconomySystem.accrueHour(&state, qualities: qualities)
            var good = 0.0
            for i in state.customers.indices {
                let quality = state.customers[i].serverID.flatMap { qualities[$0] } ?? 0
                good += quality
                let change = quality >= state.customers[i].uptimeExpectation ? 0.06 : -(1-quality)*0.6
                state.customers[i].satisfaction = min(100, max(0, state.customers[i].satisfaction+change))
            }
            if !state.customers.isEmpty {
                let quality = good/Double(state.customers.count)
                state.reputation = min(100, max(0, state.reputation + (quality > 0.96 ? 0.018 : -(1-quality)*0.12)))
            }
            state.requests.removeAll { $0.expiresHour <= state.hour }
            if state.hour % 12 == 0 {
                let demand = min(1, 0.6 + state.reputation/200) / pow(state.priceFactor, 2)
                if state.random() < demand { CustomerSystem.generate(in: &state) }
            }
            if state.hour % 24 == 0 {
                let departed = state.customers.filter { $0.satisfaction < 25 }
                for customer in departed { state.log("\(customer.name) kündigt: ‚Server laggt bro.‘") }
                state.customers.removeAll { $0.satisfaction < 25 }
                if state.usage.cpu > state.capacity.cpu || state.usage.network > state.plan.up || state.watts > state.cooling {
                    state.log("Support: Engpass entdeckt. Prüfe Host-Last, Upload und Kühlung.")
                }
                // ~one repair per 250 server-days; no failures during first month.
                for r in state.racks.indices {
                    for s in state.racks[r].servers.indices {
                        if state.hour > 720, state.racks[r].servers[s].online, state.random() < 0.004 {
                            let faults = ["RAM-Stick macht Mittagspause", "HDD klackert im Takt", "Netzteil im Ruhestand"]
                            let fault = faults[min(2, Int(state.random()*3))]
                            state.racks[r].servers[s].fault = fault
                            state.log("\(state.racks[r].servers[s].name): \(fault). Reparatur: 120 €.")
                        }
                    }
                }
                let c = state.capacity, u = state.usage
                state.history.append(.init(hour: state.hour, cpu: ResourceSystem.ratio(u.cpu,c.cpu), ram: ResourceSystem.ratio(u.ram,c.ram), network: ResourceSystem.ratio(u.network,state.plan.up), revenue: state.monthlyRevenue, customers: state.customers.count))
                state.history = Array(state.history.suffix(90))
            }
            if state.hour % 720 == 0 { EconomySystem.closeMonth(&state) }
            if state.location == .garage && !state.milestoneCompleted {
                let current = ResourceSystem.hostQualities(in: state)
                let hosting = state.customers.contains { customer in
                    let quality = customer.serverID.flatMap { current[$0] } ?? 0
                    return quality >= customer.uptimeExpectation
                }
                if hosting { state.garageOperatingHours += 1 }
                if state.garageOperatingHours >= 24 {
                    state.milestoneCompleted = true
                    state.log("Milestone 1 geschafft! Ein voller Tag Hosting in deiner Garage. Vier Racks passen hier rein. Nur so als Idee.")
                }
            }
        }
    }
}
