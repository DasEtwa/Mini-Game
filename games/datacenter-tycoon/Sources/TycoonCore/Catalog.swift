import Foundation

public enum LocationID: String, Codable, CaseIterable, Sendable { case bedroom, garage }
public enum PartKind: String, Codable, CaseIterable, Sendable { case board, cpu, ram, storage, psu }
public struct Part: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let kind: PartKind
    public let price: Double
    public var socket: String = ""
    public var cores: Double = 0
    public var performance: Double = 1
    public var capacity: Double = 0
    public var watts: Double = 0
    public var maxRAM: Double = 0
    public var ramSlots: Int = 0
    public var storageSlots: Int = 0
    public var generation: String = ""
}
public struct RackSpec: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let slots: Int
    public let price: Double
    public let watts: Double
    public let cooling: Double
    public let garageOnly: Bool
}
public struct InternetPlan: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let down: Double
    public let up: Double
    public let monthly: Double
    public let setup: Double
    public let garageOnly: Bool
}
public struct PowerPlan: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let watts: Double
    public let kWh: Double
    public let monthly: Double
    public let setup: Double
    public let garageOnly: Bool
}
public struct LocationSpec: Sendable {
    public let name: String
    public let racks: Int
    public let power: Double
    public let cooling: Double
    public let rent: Double
}
public struct CustomerType: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let resources: Resources
    public let price: Double
    public let minReputation: Double
    public let peakHour: Int
    public let uptime: Double
}
public enum Balance {
    public static let startCash = 1_900.0
    public static let secondsPerDay = 18.0
    public static let daysPerMonth = 30.0
    public static let electricity = 0.30
    public static let garagePrice = 18_000.0
    public static let garageCustomers = 12
    public static let garageRevenue = 2_500.0
    public static let garageReputation = 60.0
    public static let offlineCap = 2.0 * 60 * 60
    public static let serverPrice = 700.0
    public static let repairPrice = 120.0
    public static let cpuBookingFactor = 2.0
    public static let ramBookingFactor = 1.25
    public static let burstEnabled = false
}
public enum Catalog {
    public static let parts: [Part] = [
        Part(id: "board-old", name: "AMT Sockelbrett 3", kind: .board, price: 180, socket: "A3", maxRAM: 32, ramSlots: 2, storageSlots: 2, generation: "DDD3"),
        Part(id: "board-pro", name: "AMT Sockelbrett 5", kind: .board, price: 600, socket: "A5", maxRAM: 128, ramSlots: 4, storageSlots: 4, generation: "DDD5"),
        Part(id: "cpu-old", name: "AMT FX 4200", kind: .cpu, price: 90, socket: "A3", cores: 4, performance: 1, watts: 85),
        Part(id: "cpu-home", name: "AMT FX 8400", kind: .cpu, price: 450, socket: "A3", cores: 8, performance: 1.5, watts: 95),
        Part(id: "cpu-pro", name: "AMT Rhyzen 12", kind: .cpu, price: 950, socket: "A5", cores: 12, performance: 2, watts: 105),
        Part(id: "cpu-max", name: "AMT ThreadHamster 24", kind: .cpu, price: 2200, socket: "A5", cores: 24, performance: 2, watts: 150),
        Part(id: "ram-old", name: "KingRAM 8 GB DDD3", kind: .ram, price: 60, capacity: 8, watts: 4, generation: "DDD3"),
        Part(id: "ram-home", name: "KingRAM 16 GB DDD3", kind: .ram, price: 160, capacity: 16, watts: 5, generation: "DDD3"),
        Part(id: "ram-pro", name: "HyperLamb 16 GB DDD5", kind: .ram, price: 140, capacity: 16, watts: 4, generation: "DDD5"),
        Part(id: "ram-32", name: "HyperLamb 32 GB DDD5", kind: .ram, price: 280, capacity: 32, watts: 6, generation: "DDD5"),
        Part(id: "storage-old", name: "SeaCrate 250 GB HDD", kind: .storage, price: 50, capacity: 250, watts: 12),
        Part(id: "storage-ssd", name: "SamSing 1 TB SATA SSD", kind: .storage, price: 220, capacity: 1000, watts: 5),
        Part(id: "storage-nvme", name: "WD Plaid 2 TB NVMe", kind: .storage, price: 450, capacity: 2000, watts: 7, generation: "DDD5"),
        Part(id: "psu-old", name: "WattEver 300 W", kind: .psu, price: 80, capacity: 300),
        Part(id: "psu-pro", name: "WattEver 650 W Gold-ish", kind: .psu, price: 220, capacity: 650)
    ]
    public static let racks = [
        RackSpec(id: "home", name: "Home Rack", slots: 2, price: 350, watts: 500, cooling: 420, garageOnly: false),
        RackSpec(id: "medium", name: "Studio Rack", slots: 4, price: 1100, watts: 1000, cooling: 900, garageOnly: true),
        RackSpec(id: "garage", name: "Garage Rack", slots: 6, price: 1800, watts: 2200, cooling: 1800, garageOnly: true)
    ]
    public static let powerPlans = [
        PowerPlan(id: "family", name: "Familienstrom", watts: 350, kWh: 0.34, monthly: 0, setup: 0, garageOnly: false),
        PowerPlan(id: "home", name: "Home Power Plus", watts: 700, kWh: 0.30, monthly: 18, setup: 280, garageOnly: false),
        PowerPlan(id: "home-max", name: "Home Power Max", watts: 1200, kWh: 0.28, monthly: 40, setup: 550, garageOnly: false),
        PowerPlan(id: "business", name: "Garage Energy", watts: 3200, kWh: 0.24, monthly: 85, setup: 750, garageOnly: true)
    ]
    public static let internet = [
        InternetPlan(id: "basic", name: "Familien-WLAN", down: 100, up: 50, monthly: 35, setup: 0, garageOnly: false),
        InternetPlan(id: "plus", name: "Home Plus", down: 250, up: 100, monthly: 55, setup: 150, garageOnly: false),
        InternetPlan(id: "gigabit", name: "Gigabit Home", down: 1000, up: 200, monthly: 85, setup: 450, garageOnly: false),
        InternetPlan(id: "fiber", name: "Business Fiber", down: 1000, up: 1000, monthly: 180, setup: 900, garageOnly: true)
    ]
    public static func location(_ id: LocationID) -> LocationSpec {
        switch id {
        case .bedroom: return LocationSpec(name: "Kinderzimmer", racks: 2, power: 1200, cooling: 350, rent: 400)
        case .garage: return LocationSpec(name: "Garage", racks: 4, power: 3200, cooling: 1800, rent: 700)
        }
    }
    public static let customers: [CustomerType] = [
        .init(id: "tiny", name: "BlockBuilder", resources: .init(cpu: 1, ram: 1, storage: 15, network: 2), price: 7, minReputation: 0, peakHour: 19, uptime: 0.90),
        .init(id: "game", name: "PixelParty", resources: .init(cpu: 2, ram: 4, storage: 30, network: 4), price: 28, minReputation: 0, peakHour: 21, uptime: 0.92),
        .init(id: "web", name: "KeksBlog", resources: .init(cpu: 1, ram: 2, storage: 20, network: 3), price: 24, minReputation: 0, peakHour: 13, uptime: 0.94),
        .init(id: "dev", name: "DeployDuck", resources: .init(cpu: 3, ram: 4, storage: 45, network: 4), price: 80, minReputation: 54, peakHour: 14, uptime: 0.93),
        .init(id: "shop", name: "Sockenshop", resources: .init(cpu: 2, ram: 3, storage: 35, network: 5), price: 160, minReputation: 60, peakHour: 17, uptime: 0.96),
        .init(id: "agency", name: "Studio Wolke", resources: .init(cpu: 3, ram: 5, storage: 80, network: 7), price: 300, minReputation: 66, peakHour: 11, uptime: 0.97),
        .init(id: "build", name: "Compile Club", resources: .init(cpu: 5, ram: 8, storage: 100, network: 6), price: 440, minReputation: 72, peakHour: 16, uptime: 0.95),
        .init(id: "team", name: "Remote Raccoons", resources: .init(cpu: 4, ram: 6, storage: 120, network: 8), price: 540, minReputation: 78, peakHour: 10, uptime: 0.98)
    ]
    // IDs in save files are validated before these lookups are used.
    public static func part(_ id: String) -> Part { parts.first { $0.id == id }! }
    public static func rack(_ id: String) -> RackSpec { racks.first { $0.id == id }! }
    public static func plan(_ id: String) -> InternetPlan { internet.first { $0.id == id }! }
}
