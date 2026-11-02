// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Anvil",
    platforms: [.macOS("14")],
    products: [
        .executable(
            name: "Anvil",
            targets: ["AnvilApp"]
        ),
        .library(
            name: "AnvilKit",
            targets: ["AnvilKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AnvilApp",
            dependencies: ["AnvilKit"],
            path: "Sources/AnvilApp",
            resources: [
                .copy("Assets.xcassets")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "AnvilKit",
            path: "Sources/AnvilKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AnvilTests",
            dependencies: ["AnvilKit"],
            path: "Tests/AnvilTests"
        ),
    ]
)
