// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUtilities",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "SharedUtilities", targets: ["SharedUtilities"])
    ],
    targets: [
        .target(name: "SharedUtilities"),
        .testTarget(name: "SharedUtilitiesTests", dependencies: ["SharedUtilities"])
    ]
)
