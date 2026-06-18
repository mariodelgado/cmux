// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CmuxTinyFish",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CmuxTinyFish",
            targets: ["CmuxTinyFish"]
        ),
    ],
    targets: [
        .target(
            name: "CmuxTinyFish",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CmuxTinyFishTests",
            dependencies: ["CmuxTinyFish"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
