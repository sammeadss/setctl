// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SetctlModules",
    platforms: [
        .iOS(.v18),
        // macOS is declared only so the package builds/tests on the host
        // (swift build/test); the app ships iOS-only.
        .macOS(.v14),
    ],
    products: [
        .library(name: "SetctlDesignSystem", targets: ["SetctlDesignSystem"]),
        .library(name: "SetctlCore", targets: ["SetctlCore"]),
        .library(name: "SetctlData", targets: ["SetctlData"]),
        .library(name: "SetctlFeatures", targets: ["SetctlFeatures"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        // Leaf modules
        .target(name: "SetctlDesignSystem", resources: [.process("Scanlines.metal"), .process("Bloom.metal")]),

        .target(name: "SetctlCore"),
        .target(
            name: "SetctlData",
            dependencies: [
                "SetctlCore",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            resources: [.copy("Resources/exercise-catalog.json")]
        ),

        // Feature layer
        .target(
            name: "SetctlFeatures",
            dependencies: ["SetctlData", "SetctlCore", "SetctlDesignSystem"],
            resources: [.copy("Resources/frames.json"), .copy("Resources/setctl_resolve.txt")]
        ),

        // One test target per module
        .testTarget(name: "SetctlDesignSystemTests", dependencies: ["SetctlDesignSystem"]),
        .testTarget(name: "SetctlCoreTests", dependencies: ["SetctlCore"]),
        .testTarget(
            name: "SetctlDataTests",
            dependencies: [
                "SetctlData",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .testTarget(name: "SetctlFeaturesTests", dependencies: ["SetctlFeatures"]),
    ]
)
