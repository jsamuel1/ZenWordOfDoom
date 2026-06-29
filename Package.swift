// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZenWordOfDoomKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "WordEngine", targets: ["WordEngine"]),
    ],
    targets: [
        // Pure rules/models — no Apple-UI dependencies, runs anywhere.
        .target(name: "GameCore"),
        // Dictionary / word validation. Depends on GameCore protocols.
        .target(name: "WordEngine", dependencies: ["GameCore"]),

        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "WordEngineTests", dependencies: ["WordEngine", "GameCore"]),
    ]
)
