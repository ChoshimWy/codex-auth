// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexSwitcher",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "CodexSwitcher", targets: ["CodexSwitcher"]),
    ],
    targets: [
        .executableTarget(
            name: "CodexSwitcher",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CodexSwitcherTests",
            dependencies: ["CodexSwitcher"]
        ),
    ]
)
