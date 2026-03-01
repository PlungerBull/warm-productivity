// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    targets: [
        .target(name: "SharedUI"),
        .testTarget(name: "SharedUITests", dependencies: ["SharedUI"])
    ]
)
