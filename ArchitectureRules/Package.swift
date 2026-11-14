// swift-tools-version: 5.9

import PackageDescription

// Architecture lint rules for ShopApp, written as unit tests with Harmonize.
// Run with: swift test --package-path Harmonize
let package = Package(
    name: "ArchitectureRules",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Beta: the 2.0.0-beta.2 API is the one these rules were written against.
        .package(url: "https://github.com/perrystreetsoftware/Harmonize.git", exact: "2.0.0-beta.2"),
    ],
    targets: [
        .testTarget(
            name: "ArchitectureRulesTests",
            dependencies: [
                .product(name: "Harmonize", package: "Harmonize"),
            ],
            path: "Tests/ArchitectureRulesTests"
        ),
    ]
)
