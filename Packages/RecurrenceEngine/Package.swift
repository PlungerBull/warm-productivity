// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RecurrenceEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "RecurrenceEngine", targets: ["RecurrenceEngine"])
    ],
    targets: [
        .target(name: "RecurrenceEngine"),
        .testTarget(name: "RecurrenceEngineTests", dependencies: ["RecurrenceEngine"])
    ]
)
