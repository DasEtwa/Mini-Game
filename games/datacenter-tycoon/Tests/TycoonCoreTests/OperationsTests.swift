import XCTest
@testable import TycoonCore

final class OperationsTests: XCTestCase {
    func hosting() throws -> GameState {
        var g = GameState()
        try CustomerSystem.accept(g.requests[0].id, in: &g)
        g.customers[0].contract = CustomerContract(months: 6, hour: 0)
        return g
    }
    func testIndividualPaymentDatesAndNoDoubleMonthEndPayment() throws {
        var g = GameState()
        g.hour = 16 * 24
        try CustomerSystem.accept(g.requests[0].id, in: &g)
        let first = g.customers[0].id
        g.customers[0].contract = CustomerContract(months: 6, hour: g.hour)
        Simulation.advance(hours: 48, state: &g)
        var offer = g.customers[0]; offer.id = UUID(); offer.name = "Second"; offer.serverID = nil
        g.requests.append(offer)
        try CustomerSystem.accept(offer.id, in: &g)
        g.customers[1].contract = CustomerContract(months: 6, hour: g.hour)
        XCTAssertEqual(GameState.dateLabel(hour: g.customers[0].billing!.nextPaymentHour), "17.2.1111")
        XCTAssertEqual(GameState.dateLabel(hour: g.customers[1].billing!.nextPaymentHour), "19.2.1111")
        Simulation.advance(hours: 672, state: &g)
        XCTAssertEqual(g.lifetimeRevenue, 7, accuracy: 0.001)
        XCTAssertEqual(g.operations.receipts.count, 1)
        XCTAssertEqual(g.operations.receipts[0].rackID, g.racks[0].id)
        XCTAssertEqual(g.customers.first { $0.id == first }?.billing?.nextPaymentHour, 1824)
        Simulation.advance(hours: 48, state: &g)
        XCTAssertEqual(g.lifetimeRevenue, 14, accuracy: 0.001)
        XCTAssertEqual(g.operations.receipts.count, 2)
    }
    func testCancellationSettlesEarnedMoneyExactlyOnce() throws {
        var g = try hosting()
        Simulation.advance(hours: 360, state: &g)
        let cash = g.cash
        CustomerSystem.cancel(g.customers[0].id, in: &g)
        XCTAssertEqual(g.cash-cash, 3.5, accuracy: 0.001)
        EconomySystem.closeMonth(&g)
        XCTAssertEqual(g.lifetimeRevenue, 3.5, accuracy: 0.001)
    }
    func testDegradedServiceReducesIndividualPayment() throws {
        var g = try hosting()
        for _ in 0..<720 { EconomySystem.accrueHour(&g, qualities: [g.servers[0].id: 0.5]) }
        g.hour = 720; EconomySystem.payDue(&g)
        XCTAssertEqual(g.lifetimeRevenue, 3.5, accuracy: 0.001)
        EconomySystem.payDue(&g)
        XCTAssertEqual(g.lifetimeRevenue, 3.5, accuracy: 0.001)
    }
    func testDemandRecoversAtZeroReputation() {
        var g = GameState(); g.reputation = 0; g.requests = []
        XCTAssertGreaterThan(Simulation.requestChance(in: g), 0)
        var receivedRequest = false
        for _ in 0..<100 {
            Simulation.advance(hours: 72, state: &g)
            receivedRequest = receivedRequest || !g.requests.isEmpty
        }
        XCTAssertTrue(receivedRequest)
        for rep in 0...13 { g.reputation = Double(rep); XCTAssertGreaterThan(Simulation.requestChance(in: g), 0) }
    }
    func testQuoteFactorSurvivesSliderChangesAndReload() throws {
        var g = GameState(); g.requests = []; g.priceFactor = 1.3
        CustomerSystem.generate(in: &g)
        let quote = g.requests[0]
        g.priceFactor = 0.8
        g = try SaveStore.decode(SaveStore.encode(g))
        try CustomerSystem.accept(quote.id, in: &g)
        XCTAssertEqual(g.customers[0].monthlyPrice, quote.monthlyPrice)
        XCTAssertEqual(g.customers[0].contract?.priceFactor, 1.3)
    }
    func testBulkStockAndAtomicInstall() throws {
        var g = GameState(); g.cash = 10000
        try InventorySystem.buy("cpu-home", quantity: 3, in: &g)
        XCTAssertEqual(g.operations.stock["cpu-home"], 3)
        XCTAssertEqual(g.cash, 8650)
        try ShopSystem.replace(serverID: g.servers[0].id, partID: "cpu-home", fromStock: true, in: &g)
        XCTAssertEqual(g.operations.stock["cpu-home"], 2)
        XCTAssertEqual(g.cash, 8650)
        try InventorySystem.buy("ram-32", quantity: 4, in: &g)
        let before = g
        XCTAssertThrowsError(try ShopSystem.replace(serverID: g.servers[0].id, partID: "ram-32", fromStock: true, in: &g))
        XCTAssertEqual(g, before)
    }
    func testManualRepairConsumesOnlyOneMatchingModule() throws {
        var g = GameState(); g.cash = 10000
        try ShopSystem.replace(serverID: g.servers[0].id, partID: "ram-old", append: true, in: &g)
        try InventorySystem.buy("ram-old", quantity: 4, in: &g)
        let modules = g.servers[0].ram
        InventorySystem.fail(g.servers[0].id, partID: "ram-old", in: &g)
        try InventorySystem.repair(g.servers[0].id, in: &g)
        XCTAssertEqual(g.operations.stock["ram-old"], 3)
        XCTAssertEqual(g.servers[0].ram, modules)
        XCTAssertTrue(g.servers[0].online)
        let before = g
        XCTAssertThrowsError(try InventorySystem.repair(g.servers[0].id, in: &g))
        XCTAssertEqual(g, before)
    }
    func testAutoRepairWaitsForDelayAndStock() throws {
        var g = GameState(); let id = g.servers[0].id
        InventorySystem.fail(id, partID: "cpu-old", in: &g)
        Simulation.advance(hours: 40, state: &g)
        XCTAssertFalse(g.servers[0].online)
        try InventorySystem.buy("cpu-old", quantity: 1, in: &g)
        g.operations.automaticRepairs = false
        Simulation.advance(hours: 1, state: &g)
        XCTAssertFalse(g.servers[0].online)
        g.operations.automaticRepairs = true
        Simulation.advance(hours: 1, state: &g)
        XCTAssertTrue(g.servers[0].online)
        XCTAssertEqual(g.operations.stock["cpu-old"], 0)
    }
    func testRepairCannotConsumeStockIfPowerLimitWouldBeExceeded() throws {
        var g = GameState(); g.cash = 10000
        try ShopSystem.buyServer(in: g.racks[0].id, state: &g)
        let id = g.servers[0].id
        InventorySystem.fail(id, partID: "cpu-old", in: &g)
        try ShopSystem.buyRack("home", in: &g)
        try ShopSystem.buyServer(in: g.racks[1].id, state: &g)
        try InventorySystem.buy("cpu-old", quantity: 1, in: &g)
        let before = g
        XCTAssertThrowsError(try InventorySystem.repair(id, in: &g))
        XCTAssertEqual(g, before)
    }
    func testTalentsScaleAndHaveBoundedCost() throws {
        var g = try hosting(); g.operations.coins = 15
        let watts = g.watts
        try TalentSystem.upgrade(.efficiency, in: &g)
        XCTAssertEqual(g.watts, watts*0.97, accuracy: 0.0001)
        g.operations.coins = 15
        for _ in 0..<5 { try TalentSystem.upgrade(.revenue, in: &g) }
        XCTAssertEqual(g.operations.coins, 0)
        XCTAssertEqual(g.monthlyRevenue, 7.7, accuracy: 0.0001)
        let before = g
        XCTAssertThrowsError(try TalentSystem.upgrade(.revenue, in: &g))
        XCTAssertEqual(g, before)
        EconomySystem.accrueHour(&g)
        XCTAssertEqual(g.customers[0].billing!.accrued, 7.7/720, accuracy: 0.0001)
    }
    func testJobReservesCPUThenRewardsAndReleasesIt() throws {
        var g = try hosting(); let cpu = g.customers[0].booked.cpu
        JobSystem.generate(in: &g)
        let id = try XCTUnwrap(g.operations.jobs.first?.id)
        try JobSystem.accept(id, in: &g)
        XCTAssertEqual(g.customers[0].booked.cpu, cpu+2)
        XCTAssertThrowsError(try JobSystem.accept(id, in: &g))
        Simulation.advance(hours: 168, state: &g)
        XCTAssertEqual(g.operations.coins, 1)
        XCTAssertEqual(g.customers[0].booked.cpu, cpu)
        XCTAssertFalse(g.operations.jobs.contains { $0.id == id })
    }
    func testFailedJobDoesNotRewardAndRestoresCapacity() throws {
        var g = try hosting()
        JobSystem.generate(in: &g); try JobSystem.accept(g.operations.jobs[0].id, in: &g)
        for hour in 1...168 { g.hour = hour; JobSystem.tick(&g, qualities: [:]) }
        XCTAssertEqual(g.operations.coins, 0)
        XCTAssertEqual(g.customers[0].booked.cpu, 1)
        XCTAssertTrue(g.operations.jobs.isEmpty)
    }
    func testJobRejectsInsufficientCapacityAtomicallyAndCleansUpOnCancel() throws {
        var g = try hosting(); g.customers[0].booked.cpu = 8
        JobSystem.generate(in: &g); let before = g
        XCTAssertThrowsError(try JobSystem.accept(g.operations.jobs[0].id, in: &g))
        XCTAssertEqual(g, before)
        CustomerSystem.cancel(g.customers[0].id, in: &g)
        XCTAssertTrue(g.operations.jobs.isEmpty)
    }
    func testEmployeeSalaryAnniversaryAndResignation() throws {
        var g = GameState(); g.cash = 2000
        XCTAssertThrowsError(try StaffSystem.hire(.maintenance, in: &g))
        g.location = .garage; g.hour = 100
        try StaffSystem.hire(.maintenance, in: &g)
        XCTAssertEqual(g.cash, 1550)
        XCTAssertEqual(g.autoRepairHours, 8)
        g.hour = 819; StaffSystem.tick(&g)
        XCTAssertEqual(g.cash, 1550)
        g.hour = 820; StaffSystem.tick(&g)
        XCTAssertEqual(g.cash, 1100)
        g.cash = 449; g.hour = 1540; StaffSystem.tick(&g)
        XCTAssertNil(g.operations.employee)
        XCTAssertEqual(g.cash, 449)
    }
    func testEmployeeSalesOnlyAcceptsHealthyWork() throws {
        var g = GameState(); g.location = .garage
        try StaffSystem.hire(.sales, in: &g)
        Simulation.advance(hours: 8, state: &g)
        XCTAssertEqual(g.customers.count, 1)
        var impossible = g.customers[0]; impossible.id = UUID(); impossible.booked.network = 500
        g.requests = [impossible]
        Simulation.advance(hours: 8, state: &g)
        XCTAssertEqual(g.customers.count, 1)
    }
    func testOfflineRepairAndPaymentMatchOnlineAndDoNotRepeatOnReload() throws {
        var online = try hosting(); online.location = .garage; online.cash = 10000
        try StaffSystem.hire(.maintenance, in: &online)
        try InventorySystem.buy("cpu-old", quantity: 1, in: &online)
        InventorySystem.fail(online.servers[0].id, partID: "cpu-old", in: &online)
        online.lastSavedAt = Date(timeIntervalSince1970: 100000)
        var offline = try SaveStore.decode(SaveStore.encode(online))
        Simulation.advance(hours: 721, state: &online)
        let now = offline.lastSavedAt.addingTimeInterval(721 * Balance.secondsPerDay/24)
        XCTAssertEqual(SaveStore.offline(&offline, now: now), 721)
        XCTAssertEqual(online.cash, offline.cash, accuracy: 0.000001)
        XCTAssertEqual(online.operations.stock, offline.operations.stock)
        XCTAssertEqual(online.operations.coins, offline.operations.coins)
        XCTAssertEqual(online.customers.map(\.billing), offline.customers.map(\.billing))
        offline = try SaveStore.decode(SaveStore.encode(offline))
        XCTAssertEqual(SaveStore.offline(&offline, now: now), 0)
    }
    func testLegacyEarningsRemainPayableOnceAndMissingNewFieldsMigrate() throws {
        var g = try hosting(); g.hour = 360; g.earnedThisMonth = 3.5
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(g)) as? [String: Any])
        json["saveVersion"] = 2; json.removeValue(forKey: "operations")
        var customers = try XCTUnwrap(json["customers"] as? [[String: Any]])
        customers[0].removeValue(forKey: "billing"); customers[0].removeValue(forKey: "quotedPriceFactor")
        json["customers"] = customers
        var loaded = try SaveStore.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(loaded.operations.legacyReceivable, 3.5)
        XCTAssertEqual(loaded.customers[0].billing?.nextPaymentHour, 720)
        Simulation.advance(hours: 360, state: &loaded)
        XCTAssertEqual(loaded.lifetimeRevenue, 7, accuracy: 0.001)
        XCTAssertEqual(loaded.operations.legacyReceivable, 0)
        loaded = try SaveStore.decode(SaveStore.encode(loaded))
        XCTAssertEqual(loaded.lifetimeRevenue, 7, accuracy: 0.001)
    }
    func testInvalidOperationsRejected() throws {
        var g = GameState(); g.operations.stock["missing"] = 1
        XCTAssertThrowsError(try SaveStore.encode(g))
        g = GameState(); g.operations.talents["revenue"] = 6
        XCTAssertThrowsError(try SaveStore.encode(g))
        g = GameState(); g.operations.coins = -1
        XCTAssertThrowsError(try SaveStore.encode(g))
        g = try hosting(); g.customers[0].billing?.accrued = .nan
        XCTAssertThrowsError(try SaveStore.encode(g))
    }
    func testSalesDoesNotAcceptExpiredOffer() throws {
        var g = GameState(); g.location = .garage
        try StaffSystem.hire(.sales, in: &g)
        g.requests[0].expiresHour = 8
        Simulation.advance(hours: 8, state: &g)
        XCTAssertTrue(g.customers.isEmpty)
        XCTAssertTrue(g.requests.isEmpty)
    }
    func testRepairDelayAndTalentAndStaffEffects() throws {
        var g = GameState(); g.cash = 10000; g.location = .garage
        try StaffSystem.hire(.maintenance, in: &g)
        g.operations.coins = 15
        for _ in 0..<5 { try TalentSystem.upgrade(.repairs, in: &g) }
        XCTAssertEqual(g.autoRepairHours, 4)
        try InventorySystem.buy("cpu-old", quantity: 1, in: &g)
        InventorySystem.fail(g.servers[0].id, partID: "cpu-old", in: &g)
        Simulation.advance(hours: 3, state: &g)
        XCTAssertFalse(g.servers[0].online)
        Simulation.advance(hours: 1, state: &g)
        XCTAssertTrue(g.servers[0].online)
    }
    func testTipIsRateLimitedAndPersists() throws {
        var g = try hosting()
        TalentSystem.tip(in: &g, chance: 1, reason: "Test")
        TalentSystem.tip(in: &g, chance: 1, reason: "Test")
        XCTAssertEqual(g.operations.coins, 1)
        g = try SaveStore.decode(SaveStore.encode(g))
        TalentSystem.tip(in: &g, chance: 1, reason: "Test")
        XCTAssertEqual(g.operations.coins, 1)
        g.hour = 24
        TalentSystem.tip(in: &g, chance: 1, reason: "Test")
        XCTAssertEqual(g.operations.coins, 2)
    }
}
