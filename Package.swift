// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            path: "Sources/DynamicIsland",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
