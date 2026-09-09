// swift-tools-version: 6.2
// Rendering — the math-display layer over SwiftMath (D32): a SwiftUI view for LaTeX and the
// renderability check used by the Demo's rendering spike and by learning-objects W1 5b.
// Separate from `Core` so that `Core` stays Foundation-only (I14).

import PackageDescription

let package = Package(
    name: "Rendering",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "Rendering", targets: ["Rendering"])],
    dependencies: [
        .package(url: "https://github.com/mgriebling/SwiftMath.git", exact: "1.7.3")
    ],
    targets: [
        .target(name: "Rendering", dependencies: ["SwiftMath"]),
        .testTarget(name: "RenderingTests", dependencies: ["Rendering"]),
    ],
    swiftLanguageModes: [.v6]
)
