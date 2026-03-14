// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pixpets",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "pixpets",
            path: "Sources"
        )
    ]
)
