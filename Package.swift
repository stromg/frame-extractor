// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "FrameExtractor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FrameExtractor",
            path: "Sources/FrameExtractor"
        )
    ]
)
