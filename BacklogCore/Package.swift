// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BacklogCore",
    platforms: [
        .iOS(.v18),
        .tvOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "BacklogCore", targets: ["BacklogCore"]),
    ],
    targets: [
        .target(name: "BacklogCore"),
        .testTarget(
            name: "BacklogCoreTests",
            dependencies: ["BacklogCore"]
        ),
    ]
)
