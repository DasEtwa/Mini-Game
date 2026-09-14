import XCTest
@testable import TycoonCore

final class TycoonCoreTests: XCTestCase {
    func acceptedGame() throws -> GameState {
        var g = GameState(); try CustomerSystem.accept(g.requests[0].id,in:&g); return g
    }
    func testStartState() throws {
        let g = GameState()
        XCTAssertEqual(g.cash,5000); XCTAssertEqual(g.customers.count,0)
        XCTAssertEqual(g.capacity,.init(cpu:4,ram:8,storage:250,network:1000))
        XCTAssertEqual(g.plan.down,100); XCTAssertEqual(g.plan.up,50)
        try SaveStore.validate(g)
    }
    func testCustomerAcceptanceAndDecline() throws {
        var g = try acceptedGame()
        XCTAssertEqual(g.customers.count,1); XCTAssertEqual(g.requests.count,0)
        XCTAssertEqual(g.customers[0].serverID,g.servers[0].id)
        CustomerSystem.generate(in:&g)
        CustomerSystem.decline(g.requests[0].id,in:&g)
        XCTAssertTrue(g.requests.isEmpty)
        CustomerSystem.cancel(g.customers[0].id,in:&g)
        XCTAssertEqual(g.reputation,49)
    }
    func testCustomerDynamicallyUsesBookedResources() throws {
        let customer = try acceptedGame().customers[0]
        let samples = (0..<24).map { customer.usage(hour:$0) }
        XCTAssertTrue(samples.contains { $0.cpu == customer.booked.cpu })
        XCTAssertTrue(samples.contains { $0.cpu < customer.booked.cpu*0.1 })
        XCTAssertTrue(samples.allSatisfy { $0.ram <= customer.booked.ram && $0.storage == customer.booked.storage })
    }
    func testTimeZonesSpreadPeaks() throws {
        let europe = try acceptedGame().customers[0]
        var usa = europe; usa.region = .usa
        XCTAssertNotEqual(europe.usage(hour:18),usa.usage(hour:18))
        XCTAssertEqual((0..<24).map { europe.usage(hour:$0).cpu }.reduce(0,+),(0..<24).map { usa.usage(hour:$0).cpu }.reduce(0,+),accuracy:0.0001)
    }
    func testBillingIsProratedAndIncludesPowerRentInternet() throws {
        var g = try acceptedGame()
        for _ in 0..<720 { EconomySystem.accrueHour(&g) }
        XCTAssertEqual(g.earnedThisMonth,7,accuracy:0.001)
        XCTAssertEqual(g.electricityThisMonth,131.0/1000*720*0.3,accuracy:0.001)
        XCTAssertEqual(g.fixedCostsThisMonth,435,accuracy:0.001)
        g.hour = 720
        EconomySystem.closeMonth(&g)
        let expectedCash = 4972.0 - (131.0 / 1000.0 * 720.0 * 0.3)
        XCTAssertEqual(g.cash,expectedCash,accuracy:0.001)
        XCTAssertEqual(g.earnedThisMonth,0)
        XCTAssertEqual(g.lifetimeRevenue,7,accuracy:0.001)
    }
    func testPartialMonthRevenue() throws {
        var g = try acceptedGame()
        for _ in 0..<360 { EconomySystem.accrueHour(&g) }
        XCTAssertEqual(g.earnedThisMonth,3.5,accuracy:0.001)
    }
    func testSubsidyStopsAfterThreeMonths() {
        var g = GameState(); g.hour = 2880
        EconomySystem.closeMonth(&g)
        XCTAssertEqual(g.cash,5000)
    }
    func testInternetFeesProrate() throws {
        var g = GameState()
        for _ in 0..<360 { EconomySystem.accrueHour(&g) }
        try ShopSystem.internet("plus",in:&g)
        for _ in 0..<360 { EconomySystem.accrueHour(&g) }
        XCTAssertEqual(g.fixedCostsThisMonth,445,accuracy:0.001)
        XCTAssertEqual(g.cash,4850)
    }
    func testCPUPurchaseChangesOnlyTargetServer() throws {
        var g = GameState(); try ShopSystem.buyServer(in:g.racks[0].id,state:&g)
        let other = g.servers[1]
        try ShopSystem.replace(serverID:g.servers[0].id,partID:"cpu-home",in:&g)
        XCTAssertEqual(g.servers[0].capacity.cpu,12); XCTAssertEqual(g.servers[1],other)
        XCTAssertEqual(g.cash,3850)
    }
    func testIncompatibleHardwarePurchaseIsAtomic() {
        var g = GameState(); let before = g
        XCTAssertThrowsError(try ShopSystem.replace(serverID:g.servers[0].id,partID:"cpu-pro",in:&g))
        XCTAssertEqual(g,before)
        XCTAssertThrowsError(try ShopSystem.replace(serverID:g.servers[0].id,partID:"ram-32",in:&g))
        XCTAssertEqual(g,before)
    }
    func testRAMSlotsAndBoardLimits() throws {
        var g = GameState(); let id=g.servers[0].id
        try ShopSystem.replace(serverID:id,partID:"ram-home",in:&g)
        try ShopSystem.replace(serverID:id,partID:"ram-home",append:true,in:&g)
        XCTAssertEqual(g.capacity.ram,32)
        let before=g
        XCTAssertThrowsError(try ShopSystem.replace(serverID:id,partID:"ram-home",append:true,in:&g))
        XCTAssertEqual(g,before)
    }
    func testPlatformMigrationIsCompatible() throws {
        var g = GameState(); try ShopSystem.modernize(g.servers[0].id,in:&g)
        XCTAssertEqual(g.capacity.cpu,24); XCTAssertEqual(g.capacity.ram,64)
        XCTAssertEqual(g.cash,2890); try HardwareSystem.validate(g.servers[0])
    }
    func testStorageCannotDestroyCustomerData() throws {
        var g = try acceptedGame(); let id=g.servers[0].id
        try ShopSystem.replace(serverID:id,partID:"storage-ssd",in:&g)
        g.customers[0].booked.storage=500
        let before=g
        XCTAssertThrowsError(try ShopSystem.replace(serverID:id,partID:"storage-old",in:&g))
        XCTAssertEqual(g,before)
    }
    func testRackCapacityAndRoomLimit() throws {
        var g = GameState(); g.cash=10000
        try ShopSystem.buyServer(in:g.racks[0].id,state:&g)
        XCTAssertThrowsError(try ShopSystem.buyServer(in:g.racks[0].id,state:&g))
        try ShopSystem.buyRack("home",in:&g)
        XCTAssertThrowsError(try ShopSystem.buyRack("home",in:&g))
        XCTAssertThrowsError(try ShopSystem.buyRack("garage",in:&g))
        XCTAssertEqual(g.racks.count,2)
    }
    func testPowerLimitPreventsStartup() throws {
        var g = GameState(); g.racks=[Rack(specID:"medium",servers:Array(repeating:Server(),count:4)),Rack(servers:[Server(),Server()])]
        for r in g.racks.indices { for s in g.racks[r].servers.indices { g.racks[r].servers[s].id=UUID();g.racks[r].servers[s].isOn=false } }
        for server in g.servers.prefix(5) { try ShopSystem.toggle(server.id,in:&g) }
        let before=g
        XCTAssertThrowsError(try ShopSystem.toggle(g.servers.last!.id,in:&g))
        XCTAssertEqual(g,before)
    }
    func testOfflineHostCannotAccept() throws {
        var g = GameState();try ShopSystem.toggle(g.servers[0].id,in:&g)
        XCTAssertThrowsError(try CustomerSystem.accept(g.requests[0].id,in:&g))
    }
    func testOversubscriptionBookingCaps() throws {
        var g = try acceptedGame()
        var request=g.customers[0];request.id=UUID();request.serverID=nil;request.booked.ram=10
        XCTAssertFalse(HardwareSystem.canHost(request,on:g.servers[0],in:g))
        request.booked.ram=1;request.booked.cpu=8
        XCTAssertFalse(HardwareSystem.canHost(request,on:g.servers[0],in:g))
        request.booked.cpu=5
        XCTAssertTrue(HardwareSystem.canHost(request,on:g.servers[0],in:g))
        g.requests.append(request)
    }
    func testOverloadReducesQualityAndRevenue() throws {
        var g = try acceptedGame();g.customers[0].booked.network=1000
        XCTAssertLessThan(ResourceSystem.quality(for:g.customers[0],in:g),1)
        EconomySystem.accrueHour(&g)
        XCTAssertLessThan(g.earnedThisMonth,7/720)
    }
    func testPoweredOffHostHasZeroQuality() throws {
        var g = try acceptedGame(); try ShopSystem.toggle(g.servers[0].id,in:&g)
        XCTAssertEqual(ResourceSystem.quality(for:g.customers[0],in:g),0)
    }
    func testHeatThrottles() throws {
        var g = try acceptedGame()
        g.customers[0].booked.cpu=4;g.hour=18
        g.racks[0].servers.append(Server());g.racks[0].servers.append(Server())
        XCTAssertLessThan(ResourceSystem.quality(for:g.customers[0],in:g),1)
    }
    func testRepairRestoresHostAndCharges() throws {
        var g = GameState();g.racks[0].servers[0].fault="HDD defekt"
        try ShopSystem.repair(g.servers[0].id,in:&g)
        XCTAssertTrue(g.servers[0].online);XCTAssertEqual(g.cash,4880)
        XCTAssertThrowsError(try ShopSystem.repair(g.servers[0].id,in:&g))
    }
    func testGarageAllRequirementsAndPlay() throws {
        var g = try acceptedGame()
        XCTAssertThrowsError(try ShopSystem.moveToGarage(&g))
        g.cash=18000;g.reputation=60
        let template=g.customers[0]
        g.customers=(0..<12).map { i in var c=template;c.id=UUID();c.name="Client\(i)";c.monthlyPrice=250;c.booked = .init(cpu:0.1,ram:0.1,storage:1,network:0.1);return c }
        XCTAssertTrue(g.garageEligible)
        let originalRacks=g.racks
        try ShopSystem.moveToGarage(&g)
        XCTAssertEqual(g.location,.garage);XCTAssertEqual(g.racks,originalRacks);XCTAssertEqual(g.cash,0)
        XCTAssertEqual(g.room.racks,4);XCTAssertFalse(g.milestoneCompleted)
        Simulation.advance(hours:24,state:&g)
        XCTAssertTrue(g.milestoneCompleted)
        Simulation.advance(hours:24,state:&g)
        XCTAssertEqual(g.garageOperatingHours,24)
        XCTAssertThrowsError(try ShopSystem.moveToGarage(&g))
    }
    func testGarageRequirementsIndependently() throws {
        var g=try acceptedGame();g.cash=18000;g.reputation=60
        let c=g.customers[0];g.customers=(0..<12).map { _ in var n=c;n.id=UUID();n.monthlyPrice=250;return n }
        XCTAssertTrue(g.garageEligible)
        var copy=g;copy.cash=17999;XCTAssertFalse(copy.garageEligible)
        copy=g;copy.reputation=59;XCTAssertFalse(copy.garageEligible)
        copy=g;copy.customers.removeLast();XCTAssertFalse(copy.garageEligible)
        copy=g;for i in copy.customers.indices {copy.customers[i].monthlyPrice=10};XCTAssertFalse(copy.garageEligible)
    }
    func testSaveRoundTripAndBackup() throws {
        var g=try acceptedGame();Simulation.advance(hours:70,state:&g)
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let url=directory.appendingPathComponent("save.json")
        try SaveStore.save(g,to:url)
        XCTAssertEqual(try SaveStore.load(from:url),g)
        let old=g;g.cash+=50;try SaveStore.save(g,to:url)
        XCTAssertEqual(try SaveStore.load(from:url.appendingPathExtension("backup")),old)
        try Data("broken".utf8).write(to:url)
        XCTAssertThrowsError(try SaveStore.load(from:url))
        XCTAssertEqual(try SaveStore.load(from:url.appendingPathExtension("backup")),old)
    }
    func testInvalidSaveAndFutureVersionRejected() throws {
        var g=GameState();g.saveVersion=2
        XCTAssertThrowsError(try SaveStore.encode(g))
        XCTAssertThrowsError(try SaveStore.decode(Data("{\"saveVersion\":2}".utf8)))
        g=GameState();g.racks[0].servers[0].cpu="missing"
        XCTAssertThrowsError(try SaveStore.encode(g))
        g=GameState();g.cash = .nan
        XCTAssertThrowsError(try SaveStore.encode(g))
        g=GameState();g.racks[0].servers[0].ram=["cpu-old"]
        XCTAssertThrowsError(try SaveStore.encode(g))
    }
    func testOfflineCapAndClockRollback() {
        var g=GameState();let date=Date(timeIntervalSince1970:100000);g.lastSavedAt=date
        XCTAssertEqual(SaveStore.offline(&g,now:date.addingTimeInterval(-100)),0)
        XCTAssertEqual(g.lastSavedAt,date)
        let hours=SaveStore.offline(&g,now:date.addingTimeInterval(50000))
        XCTAssertEqual(hours,Int(Balance.offlineCap/(Balance.secondsPerDay/24)))
        XCTAssertEqual(SaveStore.offline(&g,now:date.addingTimeInterval(40000)),0)
        XCTAssertEqual(SaveStore.offline(&g,now:date.addingTimeInterval(50000)),0)
    }
    func testSimulationChunkingPreservesEconomyAndRNG() throws {
        let g=try acceptedGame();var a=g;var b=g
        Simulation.advance(hours:48,state:&a)
        for _ in 0..<48 {Simulation.advance(hours:1,state:&b)}
        XCTAssertEqual(a.cash,b.cash);XCTAssertEqual(a.earnedThisMonth,b.earnedThisMonth)
        XCTAssertEqual(a.requests.map(\.name),b.requests.map(\.name));XCTAssertEqual(a.randomSeed,b.randomSeed)
        XCTAssertEqual(a.history,b.history)
    }
    func testRescueOnlyOnceAndOnlyWhenNeeded() throws {
        var g=GameState();XCTAssertThrowsError(try ShopSystem.rescue(&g))
        g.cash=10;try ShopSystem.rescue(&g);XCTAssertEqual(g.cash,2010)
        g.cash=10;XCTAssertThrowsError(try ShopSystem.rescue(&g))
    }
}
