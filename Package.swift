// swift-tools-version: 6.3.3

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
        // MARK: - Namespace
        .library(
            name: "Machine Primitive",
            targets: ["Machine Primitive"]
        ),
        .library(
            name: "Machine Primitives",
            targets: ["Machine Primitives"]
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
        .package(url: "https://github.com/swift-primitives/swift-graph-primitives.git", branch: "main"),
    ],
    targets: [
        // MARK: - Namespace
        .target(
            name: "Machine Primitive",
            dependencies: []
        ),

        // MARK: - Value & Capture

        .target(
            name: "Machine Value Primitives",
            dependencies: [
                "Machine Primitive",
            ]
        ),
        .target(
            name: "Machine Capture Primitives",
            dependencies: [
                "Machine Primitive",
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
                // Node.ID = Graph.Node, Adjacency.Extract — declared directly per [MOD-038]
                // (previously reached transitively via the dissolved Core funnel).
                .product(name: "Graph Sequential Primitives", package: "swift-graph-primitives"),
            ]
        ),
        .target(
            name: "Machine Program Primitives",
            dependencies: [
                "Machine Node Primitives",
                "Machine Capture Primitives",
                // Program/Builder use Graph.Sequential storage directly per [MOD-038]
                // (previously reached transitively via the dissolved Core funnel).
                .product(name: "Graph Sequential Primitives", package: "swift-graph-primitives"),
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
                "Machine Primitive",
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
                // Narrowed to Graph Primitives: the Machine umbrella only ever
                // surfaces Graph.Node/Adjacency/Sequential/Analyze (all in Core).
                // Depending on the full Graph umbrella over-broadly re-exported the
                // graph algorithms + their data-structure cohort ([MOD-006]/[MOD-015]).
                .product(name: "Graph Sequential Primitives", package: "swift-graph-primitives"),
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
