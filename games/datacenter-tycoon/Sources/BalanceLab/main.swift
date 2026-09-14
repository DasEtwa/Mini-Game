import Foundation
import TycoonCore

enum Strategy: String, CaseIterable {
    case aggressive, conservative, poorPurchases, prematureUpgrades, lowAcceptance, highAcceptance, unluckyChurn
    var interval: Int { switch self { case .conservative: return 3; case .lowAcceptance: return 15; case .poorPurchases: return 4; default: return 1 } }
    var reserve: Double { self == .conservative ? 1000 : self == .aggressive ? 100 : 350 }
}
struct Result {
    let minutes: Double
    let state: GameState
    let minimumCash: Double
    let firstProfit: Double?
    let firstUpgrade: Double?
}
func play(seed: UInt64, cash: Double, strategy: Strategy) -> Result {
    var g = GameState(seed: seed); g.cash = cash
    var lowest = cash
    var profit: Double?
    var upgrade: Double?
    for day in 0..<900 {
        if day % strategy.interval == 0 {
            if g.cash < 200 && !g.rescueUsed { try? ShopSystem.rescue(&g) }
            if g.cash < 200 { try? ShopSystem.sideJob(&g) }
            for server in g.servers where server.fault != nil { try? ShopSystem.repair(server.id, in: &g) }
            // Deliberately waste scarce initial capital on capacity with no immediate customer benefit.
            if day == 0 && strategy == .poorPurchases {
                try? ShopSystem.replace(serverID: g.servers[0].id, partID: "psu-pro", in: &g)
                try? ShopSystem.buyRack("home", in: &g)
                try? ShopSystem.internet("gigabit", in: &g)
            }
            if day == 0 && strategy == .prematureUpgrades {
                try? ShopSystem.buyServer(in: g.racks[0].id, state: &g)
                try? ShopSystem.replace(serverID: g.servers[0].id, partID: "cpu-home", in: &g)
            }
            if g.cash > 300 + strategy.reserve && g.watts/g.cooling > 0.8 { try? ShopSystem.cooling(in: &g) }
            let bookedNet = g.customers.reduce(0) { $0+$1.booked.network }
            if bookedNet > g.plan.up*1.1, g.cash > 450 + strategy.reserve {
                if g.internetID == "basic" { try? ShopSystem.internet("plus", in: &g) }
                else if g.internetID == "plus" { try? ShopSystem.internet("gigabit", in: &g) }
            }
            for server in g.servers {
                let booked = HardwareSystem.booked(on: server.id, in: g)
                if server.cpu == "cpu-old", booked.cpu >= 5, g.cash > 450 + strategy.reserve { try? ShopSystem.replace(serverID: server.id, partID: "cpu-home", in: &g) }
                if server.capacity.ram < 32, booked.ram > server.capacity.ram*0.7, g.cash > 160 + strategy.reserve {
                    try? ShopSystem.replace(serverID: server.id, partID: "ram-home", append: server.ram.count < 2, in: &g)
                }
                if server.capacity.storage < 1000, booked.storage > server.capacity.storage*0.6, g.cash > 220 + strategy.reserve { try? ShopSystem.replace(serverID: server.id, partID: "storage-ssd", in: &g) }
            }
            let bookedRAM = g.customers.reduce(0) { $0+$1.booked.ram }
            if bookedRAM > g.capacity.ram*0.75 {
                if let server = g.servers.first(where: { $0.board == "board-old" }), g.cash > 2110 + strategy.reserve {
                    try? ShopSystem.modernize(server.id, in: &g)
                } else if g.cash > 700 + strategy.reserve, g.servers.count < 4 {
                    if g.reservedWatts + 145 > g.powerLimit {
                        if g.powerID == "family" { try? ShopSystem.power("home", in: &g) }
                        else if g.powerID == "home" { try? ShopSystem.power("home-max", in: &g) }
                    } else if let rack = g.racks.first(where: { $0.servers.count < Catalog.rack($0.specID).slots }) {
                        try? ShopSystem.buyServer(in: rack.id, state: &g)
                    } else { try? ShopSystem.buyRack("home", in: &g) }
                }
            }
            let offers = g.requests.sorted(by: { $0.monthlyPrice > $1.monthlyPrice })
            for request in (strategy == .lowAcceptance ? Array(offers.prefix(1)) : offers) {
                if strategy != .highAcceptance && g.customers.count >= 6 && request.monthlyPrice < 30 { CustomerSystem.decline(request.id, in: &g); continue }
                if strategy == .conservative && g.usage.network > g.plan.up*0.65 { continue }
                if strategy == .aggressive, request.monthlyPrice >= 160,
                   !g.servers.contains(where: { HardwareSystem.canHost(request, on: $0, in: g) }),
                   let cheap = g.customers.filter({ $0.monthlyPrice < 30 }).min(by: { $0.monthlyPrice < $1.monthlyPrice }) {
                    CustomerSystem.cancel(cheap.id, in: &g)
                }
                try? CustomerSystem.accept(request.id, in: &g)
            }
            // A fixed additional 15% of expiring contracts leave in this stress scenario.
            if strategy == .unluckyChurn {
                for customer in g.customers where (customer.contract?.endHour ?? Int.max) <= g.hour + 24 {
                    if g.random() < 0.15 { CustomerSystem.cancel(customer.id, in: &g) }
                }
            }
            if g.garageEligible { try? ShopSystem.moveToGarage(&g) }
        }
        Simulation.advance(hours: 24, state: &g)
        lowest = min(lowest, g.cash)
        let minutes = Double(g.hour)/24*Balance.secondsPerDay/60
        if profit == nil && g.monthlyProfit >= 0 { profit = minutes }
        if upgrade == nil && g.hardwareSpend > 0 { upgrade = minutes }
        if g.milestoneCompleted { break }
    }
    return Result(minutes: Double(g.hour)/24*Balance.secondsPerDay/60, state: g, minimumCash: lowest, firstProfit: profit, firstUpgrade: upgrade)
}
let trials = CommandLine.arguments.contains("--cash-trials") ? [1000.0, 1300, 1600, 1900, 2200] : [Balance.startCash]
var failures = 0
for cash in trials {
    for strategy in Strategy.allCases {
        for seed: UInt64 in [1, 7, 42, 123, 999] {
            let r = play(seed: seed, cash: cash, strategy: strategy)
            print("cash=\(Int(cash)) strategy=\(strategy.rawValue) seed=\(seed) minutes=\(r.minutes) garage=\(r.state.milestoneCompleted) minCash=\(Int(r.minimumCash)) profitAt=\(r.firstProfit ?? -1) upgradeAt=\(r.firstUpgrade ?? -1) clients=\(r.state.customers.count) MRR=\(Int(r.state.monthlyRevenue)) rep=\(Int(r.state.reputation)) servers=\(r.state.servers.count)")
            if !r.state.milestoneCompleted || r.minimumCash < -500 { failures += 1 }
        }
    }
}
if failures > 0 { print("FAILED scenarios: \(failures)"); exit(1) }
