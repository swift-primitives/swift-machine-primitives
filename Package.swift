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
            name: "Machine Primitives Conveniences",
            targets: ["Machine Primitives Conveniences"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-handle-primitives"),
        .package(path: "../swift-identity-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-bit-primitives"),
    ],
    targets: [
        .target(
            name: "Machine Primitives",
            dependencies: [
                .product(name: "Handle Primitives", package: "swift-handle-primitives"),
                .product(name: "Identity Primitives", package: "swift-identity-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Bit Primitives", package: "swift-bit-primitives"),
            ],
            swiftSettings: [
                .strictMemorySafety()
            ]
        ),
        .target(
            name: "Machine Primitives Conveniences",
            dependencies: [
                "Machine Primitives",
            ],
            swiftSettings: [
                .strictMemorySafety()
            ]
        ),
        .testTarget(
            name: "Machine Primitives Tests",
            dependencies: [
                "Machine Primitives",
            ],
            swiftSettings: [
                .strictMemorySafety()
            ]
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
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
