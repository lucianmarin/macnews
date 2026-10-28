// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macnews",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Macnews", targets: ["Macnews"])
    ],
    targets: [
        .executableTarget(
            name: "Macnews",
            path: "Sources/Macnews",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MacnewsTests",
            dependencies: ["Macnews"],
            path: "Tests/MacnewsTests"
        )
    ]
)
