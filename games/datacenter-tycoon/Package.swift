// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TycoonCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "TycoonCore", targets: ["TycoonCore"]),
               .executable(name: "BalanceLab", targets: ["BalanceLab"])],
    targets: [.target(name: "TycoonCore"),
              .executableTarget(name: "BalanceLab", dependencies: ["TycoonCore"]),
              .testTarget(name: "TycoonCoreTests", dependencies: ["TycoonCore"])]
)
