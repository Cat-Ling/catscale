// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Catscale",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "Catscale",
            targets: ["Catscale"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Catscale",
            path: "Sources/Catscale",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
