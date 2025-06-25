// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Mocktails",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Mocktails",
            targets: ["Mocktails"]
        ),
    ],
    targets: [
        .target(
            name: "Mocktails",
            dependencies: []
        ),
        .testTarget(
            name: "MocktailsTests",
            dependencies: ["Mocktails"]
        ),
    ]
)