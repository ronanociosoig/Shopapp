// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShopApp",
    platforms: [
        .iOS(.v17),
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
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-navigation",       from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
        // Article 2: uncomment to add Replay for network recording
        // .package(url: "https://github.com/NSHipster/Replay", from: "1.0.0"),
    ],
    targets: [

        // MARK: - Foundation (no feature deps)

        .target(name: "NetworkFoundation", path: "Core/NetworkFoundation/Framework/Sources"),
        .target(name: "DesignSystem",       path: "Core/DesignSystem/Framework/Sources"),
        .target(name: "Common", dependencies: ["NetworkFoundation"],
                path: "Core/Common/Framework/Sources"),

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
            ],
            path: "Features/Store/Framework/Sources"
        ),
        .target(
            name: "Account",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/Account/Framework/Sources"
        ),
        .target(
            name: "Search",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/Search/Framework/Sources"
        ),
        .target(
            name: "Checkout",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/Checkout/Framework/Sources"
        ),
        .target(
            name: "Support",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/Support/Framework/Sources"
        ),
        .target(
            name: "Suggestions",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/Suggestions/Framework/Sources"
        ),
        .target(
            name: "Promotions",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/Promotions/Framework/Sources"
        ),
        .target(
            name: "PastPurchases",
            dependencies: [
                "NetworkFoundation",
                "Common",
                "DesignSystem",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ],
            path: "Features/PastPurchases/Framework/Sources"
        ),

        // MARK: - Test targets

        .testTarget(
            name: "CommonTests",
            dependencies: [
                "Common",
                "NetworkFoundation",
            ],
            path: "Core/Common/Tests/Sources"
        ),
        .testTarget(
            name: "AccountTests",
            dependencies: [
                "Account",
                "NetworkFoundation",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Account/Tests/Sources"
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: [
                "Search",
                "NetworkFoundation",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Search/Tests/Sources"
        ),
        .testTarget(
            name: "CheckoutTests",
            dependencies: [
                "Checkout",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Checkout/Tests/Sources"
        ),
        .testTarget(
            name: "StoreTests",
            dependencies: [
                "Store",
                "NetworkFoundation",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Store/Tests/Sources"
        ),
        .testTarget(
            name: "PromotionsTests",
            dependencies: [
                "Promotions",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Promotions/Tests/Sources"
        ),
        .testTarget(
            name: "SuggestionsTests",
            dependencies: [
                "Suggestions",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Suggestions/Tests/Sources"
        ),
        .testTarget(
            name: "SupportTests",
            dependencies: [
                "Support",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/Support/Tests/Sources"
        ),
        .testTarget(
            name: "PastPurchasesTests",
            dependencies: [
                "PastPurchases",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Features/PastPurchases/Tests/Sources"
        ),

    ]
)
