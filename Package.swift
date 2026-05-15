// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftGPX",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SwiftGPX", targets: ["SwiftGPX"]),
    ],
    targets: [
        .target(
            name: "SwiftGPX",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftGPXTests",
            dependencies: ["SwiftGPX"],
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
