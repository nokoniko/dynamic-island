// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hevel",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Hevel",
            path: "Sources/Hevel",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "HevelTests",
            dependencies: ["Hevel"],
            path: "Tests/HevelTests",
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
