// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedModels",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "SharedModels", targets: ["SharedModels"])
    ],
    targets: [
        .target(name: "SharedModels"),
        .testTarget(name: "SharedModelsTests", dependencies: ["SharedModels"])
    ]
)
