// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    targets: [
        .target(name: "SharedUI"),
        .testTarget(name: "SharedUITests", dependencies: ["SharedUI"])
    ]
)
