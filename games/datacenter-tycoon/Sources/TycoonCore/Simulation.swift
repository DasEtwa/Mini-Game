import Foundation

public enum CustomerSystem {
    public static func accept(_ id: UUID, serverID: UUID? = nil, in state: inout GameState) throws {
        guard let index = state.requests.firstIndex(where: { $0.id == id }) else { throw GameError.rule("Anfrage abgelaufen.") }
        var request = state.requests[index]
        let hosts = state.servers.filter { (serverID == nil || $0.id == serverID) && HardwareSystem.canHost(request, on: $0, in: state) }
        guard let host = hosts.min(by: { HardwareSystem.booked(on: $0.id, in: state).ram/$0.capacity.ram < HardwareSystem.booked(on: $1.id, in: state).ram/$1.capacity.ram }) else { throw GameError.rule("Kein passender Online-Host. CPU/RAM-Buchung oder Speicher voll: Hardware ausbauen.") }
        request.serverID = host.id
        request.contract = CustomerContract(months: ContractSystem.term(for: request.typeID), hour: state.hour, priceFactor: request.quotedPriceFactor ?? 1)
        request.billing = CustomerBilling(hour: state.hour)
        state.customers.append(request)
        state.requests.remove(at: index)
        state.acceptedTotal += 1
        state.log("\(request.name) ist online. Willkommen auf deiner Blechkiste!")
    }
    public static func decline(_ id: UUID, in state: inout GameState) { state.requests.removeAll { $0.id == id } }
    public static func cancel(_ id: UUID, in state: inout GameState) {
        guard state.customers.contains(where: { $0.id == id }) else { return }
        EconomySystem.settle(id, in: &state)
        state.customers.removeAll { $0.id == id }
        state.operations.jobs.removeAll { $0.customerID == id }
        state.reputation = max(0, state.reputation-1)
        state.log("Vertrag beendet. Deine Reputation sinkt um 1.")
    }
    public static func generate(in state: inout GameState) {
        guard state.requests.count < (state.location == .bedroom ? 3 : 6) else { return }
        let eligible = Catalog.customers.filter { $0.minReputation <= state.reputation }
        let index = min(eligible.count-1, Int(state.random()*Double(eligible.count)))
        let type = eligible[index]
        let variation = 0.9 + state.random()*0.2
        let regionIndex = min(2, Int(state.random()*3))
        let suffix = Int(state.random()*900)+100
        let phase = Int(state.random()*5)-2
        state.requests.append(Customer(name: "\(type.name)\(suffix)", typeID: type.id, booked: type.resources,
                                       monthlyPrice: (type.price*variation*state.priceFactor).rounded(), region: Region.allCases[regionIndex], phase: phase,
                                       uptimeExpectation: type.uptime, expiresHour: state.hour+240))
        state.requests[state.requests.count-1].quotedPriceFactor = state.priceFactor
    }
}
public enum ResourceSystem {
    public static func ratio(_ use: Double, _ capacity: Double) -> Double { capacity > 0 ? use/capacity : (use > 0 ? 2 : 0) }
    public static func hostQualities(in state: GameState) -> [UUID: Double] {
        var load: [UUID: Resources] = [:]
        var network = 0.0
        let online = Set(state.servers.filter(\.online).map(\.id))
        for customer in state.customers {
            guard let host = customer.serverID, online.contains(host) else { continue }
            let use = customer.usage(hour: state.hour)
            network += use.network
            if let id = customer.serverID { load[id, default: Resources()] = load[id, default: Resources()] + use }
        }
        let roomHeat = max(1, state.watts/state.cooling)
        let networkPressure = ratio(network, state.plan.up)
        var qualities: [UUID: Double] = [:]
        for rack in state.racks {
            let throttle = 1/max(roomHeat, rack.servers.reduce(0) { $0 + state.serverWatts($1) }/Catalog.rack(rack.specID).cooling)
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
        for i in state.customers.indices {
            let customer = state.customers[i]
            let quality = customer.serverID.flatMap { resolved[$0] } ?? 0
            let earned = customer.monthlyPrice/(30*24)*quality*state.revenueMultiplier
            if state.customers[i].billing == nil { state.customers[i].billing = CustomerBilling(hour: customer.contract?.startedHour ?? state.hour) }
            state.customers[i].billing?.accrued += earned
            state.earnedThisMonth += earned
        }
        state.electricityThisMonth += state.watts/1000*state.powerPlan.kWh + state.powerPlan.monthly/720
        state.fixedCostsThisMonth += (state.room.rent+state.plan.monthly)/(30*24)
    }
    public static func closeMonth(_ state: inout GameState) {
        let revenue = state.earnedThisMonth
        if state.operations.legacyReceivable > 0 {
            state.record(state.operations.legacyReceivable, "Hosting vor dem Update")
            state.lifetimeRevenue += state.operations.legacyReceivable
            state.operations.legacyReceivable = 0
        }
        state.record(-state.electricityThisMonth, "Stromrechnung")
        state.record(-state.fixedCostsThisMonth, "Miete & Internet")
        if state.hour <= 3*30*24 { state.record(400, "Gründerhilfe: Eltern erstatten 400 € (3 Monate)") }
        state.log("Monat abgerechnet: \(Int(revenue)) € Hosting-Umsatz. Papa: ‚Und die Stromrechnung?‘")
        state.earnedThisMonth = 0; state.electricityThisMonth = 0; state.fixedCostsThisMonth = 0
    }
    public static func settle(_ customerID: UUID, in state: inout GameState) {
        guard let i = state.customers.firstIndex(where: { $0.id == customerID }), let billing = state.customers[i].billing else { return }
        let customer = state.customers[i]
        state.customers[i].billing?.accrued = 0
        guard billing.accrued > 0 else { return }
        state.record(billing.accrued, "Hosting: \(customer.name)")
        state.lifetimeRevenue += billing.accrued
        if let rack = state.racks.first(where: { rack in rack.servers.contains { $0.id == customer.serverID } }) {
            state.operations.receipts.append(.init(rackID: rack.id, amount: billing.accrued, hour: state.hour))
            state.operations.receipts = Array(state.operations.receipts.suffix(24))
        }
    }
    public static func payDue(_ state: inout GameState) {
        for i in state.customers.indices {
            guard let billing = state.customers[i].billing, state.hour >= billing.nextPaymentHour else { continue }
            let customer = state.customers[i]
            settle(customer.id, in: &state)
            state.customers[i].billing?.nextPaymentHour += 720
            if customer.satisfaction >= 95, ResourceSystem.quality(for: customer, in: state) >= customer.uptimeExpectation {
                let chance = 0.06 + Double(state.operations.level(.loyalty)) * 0.01
                TalentSystem.tip(in: &state, chance: chance, reason: "\(customer.name) bedankt sich für zuverlässiges Hosting.")
            }
        }
    }
}
public enum Simulation {
    public static func advance(hours: Int, state: inout GameState) {
        guard hours > 0 else { return }
        for _ in 0..<hours {
            state.hour += 1
            InventorySystem.tick(&state)
            let qualities = ResourceSystem.hostQualities(in: state)
            EconomySystem.accrueHour(&state, qualities: qualities)
            var good = 0.0
            for i in state.customers.indices {
                let quality = state.customers[i].serverID.flatMap { qualities[$0] } ?? 0
                good += quality
                let change = quality >= state.customers[i].uptimeExpectation ? 0.06 : -(1-quality)*0.6
                if state.customers[i].contract != nil {
                    state.customers[i].contract?.serviceHours += 1
                    state.customers[i].contract?.qualitySum += quality
                    if quality < state.customers[i].uptimeExpectation { state.customers[i].contract?.poorHours += 1 }
                }
                state.customers[i].satisfaction = min(100, max(0, state.customers[i].satisfaction+change))
            }
            if !state.customers.isEmpty {
                let quality = good/Double(state.customers.count)
                state.reputation = min(100, max(0, state.reputation + (quality > 0.96 ? 0.012 : -(1-quality)*0.12)))
            }
            JobSystem.tick(&state, qualities: qualities)
            EconomySystem.payDue(&state)
            ContractSystem.resolve(in: &state)
            state.requests.removeAll { $0.expiresHour <= state.hour }
            StaffSystem.tick(&state)
            if state.hour % (state.reputation >= 65 ? 36 : 72) == 0 {
                let demand = requestChance(in: state)
                if state.random() < demand { CustomerSystem.generate(in: &state) }
            }
            if state.hour % 24 == 0 {
                let departed = state.customers.filter { $0.satisfaction < 25 }
                for customer in departed {
                    EconomySystem.settle(customer.id, in: &state)
                    state.operations.jobs.removeAll { $0.customerID == customer.id }
                    state.log("\(customer.name) kündigt: ‚Server laggt bro.‘")
                }
                state.customers.removeAll { $0.satisfaction < 25 }
                if state.usage.cpu > state.capacity.cpu || state.usage.network > state.plan.up || state.watts > state.cooling {
                    state.log("Support: Engpass entdeckt. Prüfe Host-Last, Upload und Kühlung.")
                }
                // ~one repair per 250 server-days; no failures during first month.
                for r in state.racks.indices {
                    for s in state.racks[r].servers.indices {
                        if state.hour > 720, state.racks[r].servers[s].online, state.random() < 0.004 {
                            let server = state.racks[r].servers[s]
                            let parts = [server.cpu, server.psu] + server.ram + server.storage
                            let part = parts[min(parts.count-1, Int(state.random()*Double(parts.count)))]
                            InventorySystem.fail(server.id, partID: part, in: &state)
                        }
                    }
                }
                let c = state.capacity, u = state.usage
                state.history.append(.init(hour: state.hour, cpu: ResourceSystem.ratio(u.cpu,c.cpu), ram: ResourceSystem.ratio(u.ram,c.ram), network: ResourceSystem.ratio(u.network,state.plan.up), revenue: state.monthlyRevenue, customers: state.customers.count))
                state.history = Array(state.history.suffix(90))
                if state.random() < 0.12 { JobSystem.generate(in: &state) }
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
    public static func requestChance(in state: GameState) -> Double {
        let base = max(0.08, 0.30 + (state.reputation-40)/90 + (state.location == .garage ? 0.3 : 0))
        return min(1, base / pow(state.priceFactor, 2) * (1 + Double(state.operations.level(.marketing))*0.10))
    }
}

public enum ContractSystem {
    public static func term(for type: String) -> Int {
        switch type { case "tiny", "game": return 1; case "web", "dev": return 2; case "shop", "agency": return 3; default: return 6 }
    }
    public static func renewalChance(_ customer: Customer, reputation: Double) -> Double {
        let contract = customer.contract
        let quality = contract?.quality ?? 1
        let poorShare = Double(contract?.poorHours ?? 0) / Double(max(1, contract?.serviceHours ?? 0))
        return min(0.98, max(0.05, 0.35 + customer.satisfaction/100*0.35 + quality*0.20 + reputation/100*0.08 - max(0, (contract?.priceFactor ?? 1)-1)*0.5 - poorShare*0.25))
    }
    public static func resolve(in state: inout GameState) {
        for index in state.customers.indices.reversed() {
            let customer = state.customers[index]
            guard let contract = customer.contract, state.hour >= contract.endHour else { continue }
            if state.random() < renewalChance(customer, reputation: state.reputation) {
                var renewal = CustomerContract(months: contract.months, hour: state.hour, priceFactor: contract.priceFactor)
                renewal.renewals = contract.renewals + 1
                state.customers[index].contract = renewal
                state.log("\(customer.name) verlängert um \(contract.months) Monate. Danke für gutes Hosting!")
            } else {
                EconomySystem.settle(customer.id, in: &state)
                state.operations.jobs.removeAll { $0.customerID == customer.id }
                state.customers.remove(at: index)
                state.log("\(customer.name): Vertrag ausgelaufen, keine Verlängerung (Zufriedenheit \(Int(customer.satisfaction)) %). Kapazität ist wieder frei.")
            }
        }
    }
}
