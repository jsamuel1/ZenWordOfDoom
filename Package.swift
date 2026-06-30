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
        .library(name: "LevelKit", targets: ["LevelKit"]),
        .library(name: "LevelGen", targets: ["LevelGen"]),
    ],
    targets: [
        // Pure rules/models — no Apple-UI dependencies, runs anywhere.
        .target(name: "GameCore"),
        // Dictionary / word validation. Depends on GameCore protocols.
        .target(name: "WordEngine", dependencies: ["GameCore"]),
        // Between-levels cut-scene data shared by the app.
        .target(name: "LevelKit", dependencies: ["GameCore"]),
        // Procedural level generation.
        .target(
            name: "LevelGen",
            dependencies: ["GameCore"],
            resources: [.process("Resources")]
        ),

        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "WordEngineTests", dependencies: ["WordEngine", "GameCore"]),
        .testTarget(name: "LevelKitTests", dependencies: ["LevelKit"]),
        .testTarget(name: "LevelGenTests", dependencies: ["LevelGen", "GameCore"]),
    ]
)
