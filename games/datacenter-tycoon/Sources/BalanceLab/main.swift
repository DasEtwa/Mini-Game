import Foundation
import TycoonCore

// Deterministic, feasible active strategy: act once per game day (18 real seconds).
func play(seed: UInt64) -> (minutes: Double, state: GameState) {
    var g = GameState(seed: seed)
    for _ in 0..<600 {
        for server in g.servers where server.fault != nil { try? ShopSystem.repair(server.id, in: &g) }
        if g.cash > 300, g.watts/g.cooling > 0.8, g.coolingLevel < 3 { try? ShopSystem.cooling(in: &g) }
        if g.internetID == "basic", g.customers.count >= 8 { try? ShopSystem.internet("plus", in: &g) }
        if g.internetID == "plus", g.customers.count >= 18 { try? ShopSystem.internet("gigabit", in: &g) }
        for server in g.servers {
            if server.cpu == "cpu-old", g.cash > 1000 { try? ShopSystem.replace(serverID: server.id, partID: "cpu-home", in: &g) }
            if server.capacity.ram < 32, g.cash > 800 { try? ShopSystem.replace(serverID: server.id, partID: "ram-home", append: true, in: &g) }
            if server.capacity.storage < 1000, g.cash > 600 { try? ShopSystem.replace(serverID: server.id, partID: "storage-ssd", in: &g) }
        }
        let bookedRAM = g.customers.reduce(0) { $0+$1.booked.ram }
        if bookedRAM > g.capacity.ram*0.7 {
            if let server = g.servers.first(where: { $0.board == "board-old" }), g.cash > 2500 {
                try? ShopSystem.modernize(server.id, in: &g)
            } else if g.cash > 1300, g.servers.count < 3 {
                if let rack = g.racks.first(where: { $0.servers.count < Catalog.rack($0.specID).slots }) {
                    try? ShopSystem.buyServer(in: rack.id, state: &g)
                } else { try? ShopSystem.buyRack("home", in: &g) }
            }
        }
        for request in g.requests.sorted(by: { $0.monthlyPrice > $1.monthlyPrice }) {
            if g.usage.network > g.plan.up*0.8 { continue }
            if g.customers.count > 12 && request.monthlyPrice < 90 { CustomerSystem.decline(request.id, in: &g); continue }
            try? CustomerSystem.accept(request.id, in: &g)
        }
        if g.garageEligible { try? ShopSystem.moveToGarage(&g) }
        Simulation.advance(hours: 24, state: &g)
        if g.milestoneCompleted { break }
    }
    return (Double(g.hour)/24*Balance.secondsPerDay/60, g)
}
for seed: UInt64 in [1, 7, 42, 123, 999] {
    let result = play(seed: seed)
    print("seed=\(seed) minutes=\(result.minutes) garage=\(result.state.milestoneCompleted) cash=\(Int(result.state.cash)) clients=\(result.state.customers.count) MRR=\(Int(result.state.monthlyRevenue)) rep=\(Int(result.state.reputation)) servers=\(result.state.servers.count)")
    if !result.state.milestoneCompleted { exit(1) }
}
