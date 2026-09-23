// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NetworkSpeedApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetworkSpeedApp", targets: ["NetworkSpeedApp"])
    ],
    targets: [
        .executableTarget(
            name: "NetworkSpeedApp",
            path: "Sources/NetworkSpeedApp"
        )
    ]
)
