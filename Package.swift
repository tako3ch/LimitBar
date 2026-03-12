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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "LimitBar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "LimitBar/Sources/LimitBar",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
