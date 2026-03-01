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
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SupabaseClient",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        ),
        .testTarget(name: "SupabaseClientTests", dependencies: ["SupabaseClient"])
    ]
)
