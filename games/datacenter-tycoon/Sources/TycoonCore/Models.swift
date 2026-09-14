import Foundation

public struct Resources: Codable, Equatable, Sendable {
    public var cpu: Double = 0
    public var ram: Double = 0
    public var storage: Double = 0
    public var network: Double = 0
    public init(cpu: Double = 0, ram: Double = 0, storage: Double = 0, network: Double = 0) {
        self.cpu = cpu; self.ram = ram; self.storage = storage; self.network = network
    }
    public static func + (a: Self, b: Self) -> Self {
        .init(cpu: a.cpu+b.cpu, ram: a.ram+b.ram, storage: a.storage+b.storage, network: a.network+b.network)
    }
}
public struct Server: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name = "Papás alter Server"
    public var board = "board-old"
    public var cpu = "cpu-old"
    public var ram = ["ram-old"]
    public var storage = ["storage-old"]
    public var psu = "psu-old"
    public var gpu: String? = nil
    public var isOn = true
    public var fault: String? = nil
    public init() {}
    public var capacity: Resources {
        .init(cpu: Catalog.part(cpu).cores * Catalog.part(cpu).performance,
              ram: ram.reduce(0) { $0 + Catalog.part($1).capacity },
              storage: storage.reduce(0) { $0 + Catalog.part($1).capacity }, network: 1000)
    }
    public var watts: Double {
        30 + Catalog.part(cpu).watts + ram.reduce(0) { $0+Catalog.part($1).watts } + storage.reduce(0) { $0+Catalog.part($1).watts }
    }
    public var online: Bool { isOn && fault == nil }
}
public struct Rack: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var specID = "home"
    public var servers: [Server] = []
    public init(specID: String = "home", servers: [Server] = []) { self.specID = specID; self.servers = servers }
    public var watts: Double { servers.filter(\.online).reduce(0) { $0+$1.watts } }
}
public enum Region: String, Codable, CaseIterable, Sendable {
    case europe = "Europa", usa = "USA", asia = "Asien"
    public var offset: Int { switch self { case .europe: return 1; case .usa: return -7; case .asia: return 8 } }
}
public enum Activity: String, Sendable { case idle = "Idle", normal = "Normal", busy = "Busy", peak = "Peak" }
public struct Customer: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var name: String
    public var typeID: String
    public var booked: Resources
    public var monthlyPrice: Double
    public var region: Region
    public var phase: Int
    public var uptimeExpectation: Double
    public var serverID: UUID?
    public var satisfaction: Double = 100
    public var expiresHour: Int
    public var burstMinutesUsed: Double = 0
    public func activity(hour: Int) -> Activity {
        let local = ((hour + region.offset + phase) % 24 + 24) % 24
        let peak = Catalog.customers.first { $0.id == typeID }?.peakHour ?? 18
        let distance = min(abs(local-peak), 24-abs(local-peak))
        if distance == 0 { return .peak }
        if distance < 3 { return .busy }
        if distance < 8 { return .normal }
        return .idle
    }
    public func usage(hour: Int) -> Resources {
        let cpu: Double
        let ram: Double
        switch activity(hour: hour) {
        case .idle: cpu = 0.08; ram = 0.4
        case .normal: cpu = 0.3; ram = 0.6
        case .busy: cpu = 0.65; ram = 0.8
        case .peak: cpu = 1; ram = 1
        }
        return .init(cpu: booked.cpu*cpu, ram: booked.ram*ram, storage: booked.storage, network: booked.network*(0.2+cpu*0.8))
    }
}
public struct LedgerEntry: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var hour: Int
    public var label: String
    public var amount: Double
}
public struct Sample: Identifiable, Codable, Equatable, Sendable {
    public var id: Int { hour }
    public var hour: Int
    public var cpu: Double
    public var ram: Double
    public var network: Double
    public var revenue: Double
    public var customers: Int
}
public struct GameEvent: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var hour: Int
    public var text: String
}
public struct GameState: Codable, Equatable, Sendable {
    public var saveVersion = 1
    public var cash = Balance.startCash
    public var hour = 0
    public var location: LocationID = .bedroom
    public var racks = [Rack(servers: [Server()])]
    public var customers: [Customer] = []
    public var requests: [Customer] = []
    public var reputation = 50.0
    public var internetID = "basic"
    public var coolingLevel = 0
    public var priceFactor = 1.0
    public var ledger: [LedgerEntry] = []
    public var history: [Sample] = []
    public var events: [GameEvent] = []
    public var earnedThisMonth = 0.0
    public var electricityThisMonth = 0.0
    public var fixedCostsThisMonth = 0.0
    public var lifetimeRevenue = 0.0
    public var hardwareSpend = 0.0
    public var acceptedTotal = 0
    public var tutorialDismissed = false
    public var tutorialLaptopOpened = false
    public var milestoneCompleted = false
    public var garageOperatingHours = 0
    public var soundEnabled = false
    public var randomSeed: UInt64 = 42
    public var lastSavedAt: Date = Date()
    public var offlineRemainder = 0.0
    public var rescueUsed = false
    public init(seed: UInt64 = 42) {
        randomSeed = seed
        requests = [Customer(name: "BlockBuilder21", typeID: "tiny", booked: Catalog.customers[0].resources,
                             monthlyPrice: 7, region: .europe, phase: 0, uptimeExpectation: 0.9, expiresHour: 240)]
    }
    public var servers: [Server] { racks.flatMap(\.servers) }
    public var room: LocationSpec { Catalog.location(location) }
    public var plan: InternetPlan { Catalog.plan(internetID) }
    public var cooling: Double { room.cooling + Double(coolingLevel) * (location == .bedroom ? 200 : 600) }
    public var monthlyRevenue: Double { customers.reduce(0) { $0+$1.monthlyPrice } }
    public var watts: Double { racks.reduce(0) { $0+$1.watts } + Double(coolingLevel)*35 }
    public var monthlyPowerCost: Double { watts/1000*24*30*Balance.electricity }
    public var monthlyCosts: Double { monthlyPowerCost + plan.monthly + room.rent }
    public var monthlyProfit: Double { monthlyRevenue-monthlyCosts }
    public var capacity: Resources {
        servers.reduce(Resources()) { total, server in
            total + (server.online ? server.capacity : Resources(storage: server.capacity.storage))
        }
    }
    public var usage: Resources {
        let online = Set(servers.filter(\.online).map(\.id))
        return customers.reduce(Resources()) { total, customer in
            let running = customer.serverID.map { online.contains($0) } ?? false
            return total + (running ? customer.usage(hour: hour) : Resources(storage: customer.booked.storage))
        }
    }
    public var garageEligible: Bool {
        location == .bedroom && cash >= Balance.garagePrice && customers.count >= Balance.garageCustomers && monthlyRevenue >= Balance.garageRevenue && reputation >= Balance.garageReputation
    }
    public mutating func log(_ text: String) {
        events.insert(.init(hour: hour, text: text), at: 0)
        events = Array(events.prefix(30))
    }
    public mutating func record(_ amount: Double, _ label: String) {
        cash += amount
        ledger.insert(.init(hour: hour, label: label, amount: amount), at: 0)
        ledger = Array(ledger.prefix(120))
    }
    public mutating func random() -> Double {
        randomSeed = randomSeed &* 6364136223846793005 &+ 1442695040888963407
        return Double(randomSeed >> 11) / Double(UInt64.max >> 11)
    }
}
