// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SyncEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "SyncEngine", targets: ["SyncEngine"])
    ],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(path: "../SupabaseClient")
    ],
    targets: [
        .target(
            name: "SyncEngine",
            dependencies: ["SharedModels", "SupabaseClient"]
        ),
        .testTarget(name: "SyncEngineTests", dependencies: ["SyncEngine"])
    ]
)
