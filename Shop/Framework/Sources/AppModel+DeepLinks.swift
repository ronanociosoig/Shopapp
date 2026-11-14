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
        case DeepLinkFeature.promotions:
            guard
                let idString = pathComponents.first,
                let id = UUID(uuidString: idString)
            else { return }
            selectedTab = .store
            await promotionsModel.handleDeepLink(promotionID: id)

        // Checkout gets the whole URL, unexamined past the host. It alone
        // knows which path segments ("delivery", "payment-retry", "add")
        // its deep links use — see `CheckoutModel.handleDeepLink(url:)`.
        // `handleDeepLink` returns `false` for anything it doesn't
        // recognize, so an unmatched checkout URL leaves the tab untouched,
        // same as the two id-lookup cases above and below.
        case DeepLinkFeature.checkout:
            if checkoutFactory.handleDeepLink(url: url) {
                selectedTab = .cart
            }

        case DeepLinkFeature.orders:
            guard
                let idString = pathComponents.first,
                let id = UUID(uuidString: idString)
            else { return }
            selectedTab = .orders
            await pastPurchasesModel.handleDeepLink(orderID: id)

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
