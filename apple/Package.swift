// swift-tools-version:5.9
// Builds only the game rules so they can be unit-tested with `swift test`; the app itself is built from Game2048.xcodeproj.
import PackageDescription

let package = Package(
    name: "Game2048Core",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "Game2048Core", path: "Game2048/Model"),
        .testTarget(name: "Game2048CoreTests", dependencies: ["Game2048Core"], path: "Tests/Game2048CoreTests"),
    ]
)
