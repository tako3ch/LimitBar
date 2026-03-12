// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LimitBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LimitBar", targets: ["LimitBar"])
    ],
    targets: [
        .executableTarget(
            name: "LimitBar",
            path: "LimitBar/Sources/LimitBar"
        )
    ]
)
