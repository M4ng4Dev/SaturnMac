// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SaturnMacGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SaturnMacGUI", targets: ["SaturnMacGUI"])
    ],
    targets: [
        .executableTarget(
            name: "SaturnMacGUI",
            path: "Sources"
        )
    ]
)
