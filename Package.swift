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
        .library(name: "LevelGen", targets: ["LevelGen"]),
    ],
    targets: [
        // Pure rules/models — no Apple-UI dependencies, runs anywhere.
        .target(name: "GameCore"),
        // Procedural level generation.
        .target(
            name: "LevelGen",
            dependencies: ["GameCore"],
            resources: [.process("Resources")]
        ),

        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "LevelGenTests", dependencies: ["LevelGen", "GameCore"]),
    ]
)
