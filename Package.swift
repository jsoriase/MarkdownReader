// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownReader",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MarkdownReader",
            path: "Sources/MarkdownReader",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MarkdownReaderTests",
            dependencies: ["MarkdownReader"],
            path: "Tests/MarkdownReaderTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
