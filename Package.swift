// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nvALL",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "nvALL",
            path: "Sources"
        ),
        .testTarget(
            name: "nvALLTests",
            dependencies: ["nvALL"],
            path: "Tests"
        )
    ]
)
