import XCTest
@testable import TycoonCore

final class PolishTests: XCTestCase {
    func testBedroomStrictRackClassesAndAtomicRejection() throws {
        var g = GameState(); g.cash = 10000
        let before = g
        XCTAssertThrowsError(try ShopSystem.buyRack("medium", in: &g))
        XCTAssertEqual(g, before)
        XCTAssertThrowsError(try ShopSystem.upgradeRack(g.racks[0].id, to: "medium", in: &g))
        XCTAssertEqual(g, before)
        try ShopSystem.buyRack("home", in: &g)
        XCTAssertThrowsError(try ShopSystem.buyRack("home", in: &g))
        try ShopSystem.power("home", in: &g)
        for rack in g.racks {
            while g.racks.first(where: { $0.id == rack.id })!.servers.count < 2 { try ShopSystem.buyServer(in: rack.id, state: &g) }
            XCTAssertThrowsError(try ShopSystem.buyServer(in: rack.id, state: &g))
        }
        XCTAssertEqual(g.servers.count, 4)
    }
    func testGarageLargerRackClasses() throws {
        var g = GameState(); g.location = .garage; g.cash = 20000
        try ShopSystem.upgradeRack(g.racks[0].id, to: "medium", in: &g)
        try ShopSystem.buyRack("garage", in: &g)
        XCTAssertEqual(Catalog.rack(g.racks[0].specID).slots, 4)
        XCTAssertEqual(Catalog.rack(g.racks[1].specID).slots, 6)
    }
    func testPowerContractsReservePeaksAndPreventDowngrade() throws {
        var g = GameState(); g.cash = 10000
        try ShopSystem.buyServer(in: g.racks[0].id, state: &g)
        try ShopSystem.buyRack("home", in: &g)
        XCTAssertThrowsError(try ShopSystem.buyServer(in: g.racks[1].id, state: &g))
        try ShopSystem.power("home", in: &g)
        try ShopSystem.buyServer(in: g.racks[1].id, state: &g)
        XCTAssertGreaterThan(g.reservedWatts, 350)
        XCTAssertLessThan(g.watts, g.reservedWatts)
        let before = g
        XCTAssertThrowsError(try ShopSystem.power("family", in: &g))
        XCTAssertEqual(g, before)
        XCTAssertThrowsError(try ShopSystem.power("business", in: &g))
    }
    func testPowerBillingUsesLoadAndProratesContractFees() throws {
        var g = GameState(); g.cash = 10000
        let idle = g.watts
        XCTAssertEqual(idle, 45.85, accuracy: 0.01)
        let rack = Rack(); g.racks.append(rack)
        XCTAssertEqual(g.watts, idle)
        for _ in 0..<360 { EconomySystem.accrueHour(&g) }
        try ShopSystem.power("home", in: &g)
        for _ in 0..<360 { EconomySystem.accrueHour(&g) }
        XCTAssertEqual(g.electricityThisMonth, idle/1000*360*(0.34+0.30)+9, accuracy: 0.001)
        try CustomerSystem.accept(g.requests[0].id, in: &g)
        g.hour = 18
        XCTAssertGreaterThan(g.watts, idle)
    }
    func testTermAssignedOnAcceptanceAndSurvivesSave() throws {
        var g = GameState(); g.hour = 50
        try CustomerSystem.accept(g.requests[0].id, in: &g)
        let term = try XCTUnwrap(g.customers[0].contract)
        XCTAssertEqual(term.months, 1); XCTAssertEqual(term.endHour, 770)
        XCTAssertEqual(term.daysRemaining(hour: 51), 30)
        XCTAssertEqual(try SaveStore.decode(SaveStore.encode(g)), g)
    }
    func testExpirationRenewsOrLeavesWithoutEarlyRandomLoss() throws {
        var renewed = 0; var departed = 0
        for seed in 0..<100 {
            var g = GameState(seed: UInt64(seed))
            try CustomerSystem.accept(g.requests[0].id, in: &g)
            g.hour = 719; ContractSystem.resolve(in: &g)
            XCTAssertEqual(g.customers.count, 1)
            g.hour = 720; ContractSystem.resolve(in: &g)
            if let c = g.customers.first {
                renewed += 1
                XCTAssertEqual(c.contract?.endHour, 1440)
                XCTAssertEqual(c.contract?.renewals, 1)
            } else { departed += 1 }
        }
        XCTAssertGreaterThan(renewed, 70)
        XCTAssertGreaterThan(departed, 0)
    }
    func testPoorServiceAndHighPricesReduceRetention() throws {
        var g = GameState(); try CustomerSystem.accept(g.requests[0].id, in: &g)
        let healthy = ContractSystem.renewalChance(g.customers[0], reputation: 80)
        g.customers[0].satisfaction = 30
        g.customers[0].contract?.serviceHours = 100
        g.customers[0].contract?.qualitySum = 40
        g.customers[0].contract?.poorHours = 90
        g.customers[0].contract?.priceFactor = 1.3
        XCTAssertLessThan(ContractSystem.renewalChance(g.customers[0], reputation: 40), healthy - 0.4)
        g.customers[0].satisfaction = 10; g.racks[0].servers[0].isOn = false
        Simulation.advance(hours: 24, state: &g)
        XCTAssertTrue(g.customers.isEmpty)
        XCTAssertTrue(g.events.contains { $0.text.contains("kündigt") })
    }
    func legacyData(_ state: GameState) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json["saveVersion"] = 1; json.removeValue(forKey: "powerID")
        if var customers = json["customers"] as? [[String: Any]] {
            for i in customers.indices { customers[i].removeValue(forKey: "contract") }
            json["customers"] = customers
        }
        return try JSONSerialization.data(withJSONObject: json)
    }
    func testLegacyMigrationPreservesClientsAndRedistributesIllegalRacks() throws {
        var g = GameState(); try CustomerSystem.accept(g.requests[0].id, in: &g)
        g.racks[0].specID = "medium"; g.racks[0].servers += [Server(), Server()]
        let oldIDs = g.servers.map(\.id)
        let loaded = try SaveStore.decode(legacyData(g))
        XCTAssertEqual(loaded.saveVersion, 3)
        XCTAssertEqual(loaded.servers.map(\.id), oldIDs)
        XCTAssertEqual(loaded.customers[0].id, g.customers[0].id)
        XCTAssertEqual(loaded.customers[0].contract?.months, 3)
        XCTAssertEqual(loaded.racks.count, 2)
        XCTAssertTrue(loaded.racks.allSatisfy { $0.specID == "home" && $0.servers.count <= 2 })
        XCTAssertGreaterThan(loaded.cash, g.cash)
        try SaveStore.validate(loaded)
    }
    func testLegacyOverflowMovesWithoutDeletingHardware() throws {
        var g = GameState()
        g.racks = [Rack(specID: "medium", servers: (0..<4).map { _ in Server() }), Rack(servers: [Server()])]
        let loaded = try SaveStore.decode(legacyData(g))
        XCTAssertEqual(loaded.location, .garage)
        XCTAssertEqual(loaded.servers, g.servers)
        XCTAssertFalse(loaded.milestoneCompleted)
    }
    func testAudioBurstHasBoundedVoiceAndDoesNotGateActions() {
        var gate = AudioGate(); var played = 0; var actions = 0
        for i in 0..<1000 {
            actions += 1
            if gate.trigger(at: Double(i)/10000) { played += 1 }
        }
        XCTAssertEqual(actions, 1000)
        XCTAssertEqual(AudioGate.maximumVoices, 1)
        XCTAssertEqual(played, 2)
    }
    func testDemandIsBoundedAndSlowerAtStart() {
        var g = GameState()
        Simulation.advance(hours: 71, state: &g)
        XCTAssertEqual(g.requests.count, 1)
        Simulation.advance(hours: 720, state: &g)
        XCTAssertLessThanOrEqual(g.requests.count, 3)
    }
    func testRecoveryWorkIsAvailableWithoutResetAndRateLimited() throws {
        var g = GameState(); g.cash = -130; g.rescueUsed = true
        try ShopSystem.sideJob(&g)
        XCTAssertEqual(g.cash, 470)
        XCTAssertThrowsError(try ShopSystem.sideJob(&g))
        g.hour = 720
        try ShopSystem.sideJob(&g)
        XCTAssertEqual(g.cash, 1070)
        XCTAssertEqual(try SaveStore.decode(SaveStore.encode(g)), g)
    }
    func testMalformedLegacyHardwareFailsWithoutCrashing() throws {
        var g = GameState(); g.racks[0].specID = "missing"
        XCTAssertThrowsError(try SaveStore.decode(legacyData(g)))
        g = GameState(); g.racks[0].servers[0].cpu = "missing"
        XCTAssertThrowsError(try SaveStore.decode(legacyData(g)))
    }

    func testDuplicateComponentDoesNotChargeAgain() {
        var g = GameState(); let before = g
        XCTAssertThrowsError(try ShopSystem.replace(serverID: g.servers[0].id, partID: "cpu-old", in: &g))
        XCTAssertEqual(g, before)
    }

}
