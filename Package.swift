// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Mocktails",
    platforms: [
        .iOS(.v15)
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
