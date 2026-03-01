// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecurrenceEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RecurrenceEngine", targets: ["RecurrenceEngine"])
    ],
    targets: [
        .target(name: "RecurrenceEngine"),
        .testTarget(name: "RecurrenceEngineTests", dependencies: ["RecurrenceEngine"])
    ]
)
