// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ValeurayAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ValeurayAI",
            targets: ["ValeurayAI"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ValeurayAI",
            path: "Sources"
        )
    ]
)
