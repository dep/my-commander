// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyCommander",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MyCommander",
            path: "Sources/MyCommander"
        )
    ]
)
