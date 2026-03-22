// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SupabaseClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SupabaseClient", targets: ["SupabaseClient"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(path: "../SharedUtilities")
    ],
    targets: [
        .target(
            name: "SupabaseClient",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                "SharedUtilities"
            ]
        ),
        .testTarget(name: "SupabaseClientTests", dependencies: ["SupabaseClient"])
    ]
)
