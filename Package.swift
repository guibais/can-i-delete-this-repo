// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GitManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GitManager",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GitManagerTests",
            dependencies: ["GitManager"]
        )
    ]
)
