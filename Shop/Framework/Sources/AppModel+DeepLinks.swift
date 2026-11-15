import Foundation

enum DeepLinkFeature {
    static let account = "account"
    static let search  = "search"
    static let promotions = "promotions"
    static let checkout = "checkout"
    static let orders = "orders"
}

/// The composition root's one job for an incoming URL: read enough of it to
/// pick a feature by name, then hand the rest to that feature's own public
/// decoding surface. `AppModel` never constructs a `PromotionsModel.Destination`
/// itself — `PromotionsModel.handleDeepLink` does, which is the only place
/// that's allowed to. Adding a new deep-linkable screen inside a feature
/// never touches this file unless the feature itself is new.
extension AppModel {
    public func handle(url: URL) async {
        guard let host = url.host else { return }
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        // Every feature gets the whole URL and decodes its own path segments.
        // A feature returns `false` for a link it doesn't accept, and the tab
        // stays where it is. The composition root never reads an ID or any
        // other part of the path.
        case DeepLinkFeature.promotions:
            if await promotionsModel.handleDeepLink(url: url) {
                selectedTab = .store
            }

        case DeepLinkFeature.checkout:
            if checkoutFactory.handleDeepLink(url: url) {
                selectedTab = .cart
            }

        case DeepLinkFeature.orders:
            if await pastPurchasesModel.handleDeepLink(url: url) {
                selectedTab = .orders
            }

        // Debug-only routes. These cases do not exist in a Release build, so the
        // same URL does nothing there. Each feature decodes its own path segments
        // (see `handleAgentRoute` in AccountModel and SearchModel).
        #if DEBUG
        case DeepLinkFeature.account:
            if accountModel.handleAgentRoute(pathComponents) {
                selectedTab = .account
            }

        case DeepLinkFeature.search:
            if await searchModel.handleAgentRoute(pathComponents) {
                selectedTab = .search
            }
        #endif

        default:
            break
        }
    }
}
