// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CanIDeleteThisRepo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CanIDeleteThisRepo",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CanIDeleteThisRepoTests",
            dependencies: ["CanIDeleteThisRepo"]
        )
    ]
)
