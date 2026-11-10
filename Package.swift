// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "MocoBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MocoBar", path: "Sources/MocoBar"),
        .testTarget(name: "MocoBarTests", dependencies: ["MocoBar"])
    ]
)
