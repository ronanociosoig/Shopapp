// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShopApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NetworkFoundation", targets: ["NetworkFoundation"]),
        .library(name: "DesignSystem",       targets: ["DesignSystem"]),
        .library(name: "Common",             targets: ["Common"]),
        .library(name: "Store",              targets: ["Store"]),
        .library(name: "Account",            targets: ["Account"]),
        .library(name: "Search",             targets: ["Search"]),
        .library(name: "Checkout",           targets: ["Checkout"]),
        .library(name: "Support",            targets: ["Support"]),
        .library(name: "Suggestions",        targets: ["Suggestions"]),
        .library(name: "Promotions",         targets: ["Promotions"]),
        .library(name: "PastPurchases",      targets: ["PastPurchases"]),
        // Micro-app executables (macOS) — run with: swift run <name>
        // Prefixed with "Run" to avoid name collisions with the Xcode iOS targets.
        .executable(name: "RunShopApp",          targets: ["RunShopApp"]),
        .executable(name: "RunCheckoutApp",      targets: ["RunCheckoutApp"]),
        .executable(name: "RunSearchApp",        targets: ["RunSearchApp"]),
        .executable(name: "RunSuggestionsApp",   targets: ["RunSuggestionsApp"]),
        .executable(name: "RunSupportApp",       targets: ["RunSupportApp"]),
        .executable(name: "RunPromotionsApp",    targets: ["RunPromotionsApp"]),
        .executable(name: "RunPastPurchasesApp", targets: ["RunPastPurchasesApp"]),
        .executable(name: "RunDesignSystemApp",  targets: ["RunDesignSystemApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-navigation",       from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
        // Article 2: uncomment to add Replay for network recording
        // .package(url: "https://github.com/NSHipster/Replay", from: "1.0.0"),
    ],
    targets: [

        // MARK: - Foundation (no feature deps)

        .target(name: "NetworkFoundation"),
        .target(name: "DesignSystem"),
        .target(name: "Common", dependencies: ["NetworkFoundation"]),

        // MARK: - Feature modules
        //
        // Rule: feature modules may only depend on NetworkFoundation and DesignSystem.
        // No feature module imports another feature module.
        // Cross-feature composition happens exclusively in the main app target (composition root).

        .target(
            name: "Store",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Account",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Search",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Checkout",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Support",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Suggestions",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Promotions",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "PastPurchases",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),

        // MARK: - Test targets

        .testTarget(
            name: "CommonTests",
            dependencies: [
                "Common",
                "NetworkFoundation",
            ]
        ),
        .testTarget(
            name: "AccountTests",
            dependencies: [
                "Account",
                "NetworkFoundation",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: [
                "Search",
                "NetworkFoundation",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "CheckoutTests",
            dependencies: [
                "Checkout",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "StoreTests",
            dependencies: [
                "Store",
                "NetworkFoundation",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "PromotionsTests",
            dependencies: [
                "Promotions",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "SuggestionsTests",
            dependencies: [
                "Suggestions",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "SupportTests",
            dependencies: [
                "Support",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "PastPurchasesTests",
            dependencies: [
                "PastPurchases",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),

        // MARK: - Micro-app executables (macOS runners)
        // Each target wraps the corresponding Apps/<Name>/ source files.
        // Run from the command line with: swift run Run<Name>
        // (Prefixed with "Run" so they don't conflict with the Xcode iOS schemes.)

        .executableTarget(
            name: "RunShopApp",
            dependencies: [
                "Store", "Search", "Checkout", "Account",
                "Promotions", "PastPurchases", "Support", "Suggestions",
            ],
            path: "Apps/ShopApp"
        ),
        .executableTarget(
            name: "RunCheckoutApp",
            dependencies: ["Checkout"],
            path: "Apps/CheckoutApp"
        ),
        .executableTarget(
            name: "RunSearchApp",
            dependencies: ["Search"],
            path: "Apps/SearchApp"
        ),
        .executableTarget(
            name: "RunSuggestionsApp",
            dependencies: ["Suggestions"],
            path: "Apps/SuggestionsApp"
        ),
        .executableTarget(
            name: "RunSupportApp",
            dependencies: ["Support"],
            path: "Apps/SupportApp"
        ),
        .executableTarget(
            name: "RunPromotionsApp",
            dependencies: ["Promotions"],
            path: "Apps/PromotionsApp"
        ),
        .executableTarget(
            name: "RunPastPurchasesApp",
            dependencies: ["PastPurchases"],
            path: "Apps/PastPurchasesApp"
        ),
        .executableTarget(
            name: "RunDesignSystemApp",
            dependencies: ["DesignSystem"],
            path: "Apps/DesignSystemApp"
        ),
    ]
)
