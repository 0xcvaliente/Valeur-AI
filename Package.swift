// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ValeurAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ValeurAI",
            targets: ["ValeurAI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ValeurAI",
            path: "Sources"
        ),
        .testTarget(
            name: "ValeurAITestsSPM",
            dependencies: ["ValeurAI"],
            path: "Tests/ValeurAITestsSPM"
        )
    ]
)
