// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macnews",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacnewsCore", targets: ["MacnewsCore"]),
        .library(name: "HotnewsWidgetCore", targets: ["HotnewsWidgetCore"]),
        .executable(name: "Macnews", targets: ["Macnews"]),
        .executable(name: "HotnewsWidget", targets: ["HotnewsWidget"])
    ],
    targets: [
        .target(
            name: "MacnewsCore",
            path: "Sources/MacnewsCore"
        ),
        .target(
            name: "HotnewsWidgetCore",
            dependencies: ["MacnewsCore"],
            path: "Sources/HotnewsWidgetCore"
        ),
        .executableTarget(
            name: "Macnews",
            dependencies: ["MacnewsCore"],
            path: "Sources/Macnews",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "HotnewsWidget",
            dependencies: ["MacnewsCore", "HotnewsWidgetCore"],
            path: "Sources/HotnewsWidget",
            exclude: ["HotnewsWidget.entitlements"],
            swiftSettings: [
                .unsafeFlags(["-application-extension"])
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-application_extension", "-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        ),
        .testTarget(
            name: "MacnewsTests",
            dependencies: ["Macnews", "MacnewsCore", "HotnewsWidgetCore"],
            path: "Tests/MacnewsTests"
        )
    ]
)
