// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-machine-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Machine Primitives",
            targets: ["Machine Primitives"]
        ),
        .library(
            name: "Machine Primitives Core",
            targets: ["Machine Primitives Core"]
        ),
        .library(
            name: "Machine Value Primitives",
            targets: ["Machine Value Primitives"]
        ),
        .library(
            name: "Machine Capture Primitives",
            targets: ["Machine Capture Primitives"]
        ),
        .library(
            name: "Machine Transform Primitives",
            targets: ["Machine Transform Primitives"]
        ),
        .library(
            name: "Machine Combine Primitives",
            targets: ["Machine Combine Primitives"]
        ),
        .library(
            name: "Machine Next Primitives",
            targets: ["Machine Next Primitives"]
        ),
        .library(
            name: "Machine Finalize Primitives",
            targets: ["Machine Finalize Primitives"]
        ),
        .library(
            name: "Machine Frame Primitives",
            targets: ["Machine Frame Primitives"]
        ),
        .library(
            name: "Machine Node Primitives",
            targets: ["Machine Node Primitives"]
        ),
        .library(
            name: "Machine Program Primitives",
            targets: ["Machine Program Primitives"]
        ),
        .library(
            name: "Machine Convenience Primitives",
            targets: ["Machine Convenience Primitives"]
        ),
        .library(
            name: "Machine Primitives Test Support",
            targets: ["Machine Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-handle-primitives"),
        .package(path: "../swift-graph-primitives"),
    ],
    targets: [
        // MARK: - Core

        .target(
            name: "Machine Primitives Core"
        ),

        // MARK: - Value & Capture

        .target(
            name: "Machine Value Primitives",
            dependencies: [
                "Machine Primitives Core",
                .product(name: "Handle Primitives", package: "swift-handle-primitives"),
            ]
        ),
        .target(
            name: "Machine Capture Primitives",
            dependencies: [
                "Machine Primitives Core",
            ]
        ),

        // MARK: - Carriers

        .target(
            name: "Machine Transform Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),
        .target(
            name: "Machine Combine Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),
        .target(
            name: "Machine Next Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),
        .target(
            name: "Machine Finalize Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Capture Primitives",
            ]
        ),

        // MARK: - Composition

        .target(
            name: "Machine Frame Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Transform Primitives",
                "Machine Combine Primitives",
                "Machine Next Primitives",
                "Machine Finalize Primitives",
            ]
        ),
        .target(
            name: "Machine Node Primitives",
            dependencies: [
                "Machine Value Primitives",
                "Machine Transform Primitives",
                "Machine Combine Primitives",
                "Machine Next Primitives",
                "Machine Finalize Primitives",
                .product(name: "Graph Primitives Core", package: "swift-graph-primitives"),
            ]
        ),
        .target(
            name: "Machine Program Primitives",
            dependencies: [
                "Machine Node Primitives",
                "Machine Capture Primitives",
                .product(name: "Graph Primitives Core", package: "swift-graph-primitives"),
            ]
        ),

        // MARK: - Convenience

        .target(
            name: "Machine Convenience Primitives",
            dependencies: [
                "Machine Program Primitives",
            ]
        ),

        // MARK: - Umbrella

        .target(
            name: "Machine Primitives",
            dependencies: [
                "Machine Primitives Core",
                "Machine Value Primitives",
                "Machine Capture Primitives",
                "Machine Transform Primitives",
                "Machine Combine Primitives",
                "Machine Next Primitives",
                "Machine Finalize Primitives",
                "Machine Frame Primitives",
                "Machine Node Primitives",
                "Machine Program Primitives",
                "Machine Convenience Primitives",
                .product(name: "Graph Primitives", package: "swift-graph-primitives"),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "Machine Value Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Combine Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Transform Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Next Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Finalize Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Frame Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Node Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),
        .testTarget(
            name: "Machine Program Primitives Tests",
            dependencies: ["Machine Primitives"]
        ),

        // MARK: - Test Support
        .target(
            name: "Machine Primitives Test Support",
            dependencies: [
                "Machine Primitives",
                .product(name: "Graph Primitives Test Support", package: "swift-graph-primitives"),
            ],
            path: "Tests/Support"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
