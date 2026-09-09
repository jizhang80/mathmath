// swift-tools-version: 6.2
// Core — graph data, L0 validation, layout, scheduler, state transitions (D33).
// Imports Foundation only. No SwiftUI / UIKit / SpriteKit / SwiftData (I14) — asserted by CoreTests.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v18),  // D34: Doors B/C and Tier 0 diagnosis on iOS/iPadOS 18+
        .macOS(.v15),  // host platform for the CLI target and the pipeline (D42)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "core-cli", targets: ["CoreCLI"]),
    ],
    targets: [
        .target(
            name: "Core",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .executableTarget(
            name: "CoreCLI",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
