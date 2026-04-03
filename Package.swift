// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TimeZoneMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TimeZoneMenuBar",
            targets: ["TimeZoneMenuBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TimeZoneMenuBar",
            resources: [
                .copy("Resources/TZDB")
            ]
        ),
        .testTarget(
            name: "TimeZoneMenuBarTests",
            dependencies: ["TimeZoneMenuBar"]
        )
    ]
)
