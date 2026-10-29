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

        case "checkout":
            switch pathComponents.first {
            case "delivery":
                selectedTab = .cart
                checkoutFactory.handleDeepLinkToDeliveryOptions()

            case "payment-retry":
                selectedTab = .cart
                checkoutFactory.handleDeepLinkToPaymentRetry()

            // "add" has no id to look up against a catalog Checkout doesn't
            // own — the URL carries the full product record, the same
            // (id, name, price, wantsGuarantee) shape every other
            // add-to-cart caller (Store, Search, Suggestions) already
            // passes through `checkoutFactory.addToCart`. A marketing
            // email's "Add" button is just a new caller of that existing
            // port, not a new one.
            case "add":
                guard
                    let idString = pathComponents.dropFirst().first,
                    let id = UUID(uuidString: idString),
                    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                    let name = queryItems.first(where: { $0.name == "name" })?.value,
                    let priceString = queryItems.first(where: { $0.name == "price" })?.value,
                    let price = Decimal(string: priceString)
                else { return }
                let wantsGuarantee = queryItems.first(where: { $0.name == "guarantee" })?.value == "true"
                selectedTab = .cart
                checkoutFactory.addToCart(id: id, name: name, price: price, wantsGuarantee: wantsGuarantee)

            default:
                break
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
