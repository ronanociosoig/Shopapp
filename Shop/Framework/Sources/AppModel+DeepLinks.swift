import Foundation

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
        case "promotions":
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
        case "checkout":
            if checkoutFactory.handleDeepLink(url: url) {
                selectedTab = .cart
            }

        case "orders":
            guard
                let idString = pathComponents.first,
                let id = UUID(uuidString: idString)
            else { return }
            selectedTab = .orders
            await pastPurchasesModel.handleDeepLink(orderID: id)

        default:
            break
        }
    }
}
