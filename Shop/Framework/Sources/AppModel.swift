import Foundation
import Observation
import SwiftUINavigation
import Store
import Search
import Checkout
import Account
import Promotions
import PastPurchases
import Support
import Suggestions

/// Composition-root model. Owns every feature model and all cross-module wiring.
///
/// Holding navigation state (`selectedTab`, `destination`) here rather than in
/// `RootView` as `@State` makes the full application state injectable and
/// snapshot-testable: create an instance, set whatever properties you need,
/// and hand it straight to `RootView`.
///
/// ## One type per concern
///
/// `AppModel` carries two navigation types, which is intentional:
///
/// - `Tab` — which tab is selected. Exactly one tab is always active; this is
///   independent of any modal surface.
/// - `Destination` — a root-level modal (Support sheet, Rate Order sheet) that
///   floats above the tab bar. Only one can be shown at a time.
///
/// The goal is not "one enum per model" but "one type per navigation concern."
/// Two independent concerns on the same model warrant two independent types.
@Observable
public final class AppModel {

    // MARK: - Navigation state

    var selectedTab: Tab
    var destination: Destination?

    // MARK: - Feature models

    let storeModel:         StoreModel
    let searchModel:        SearchModel
    let accountModel:       AccountModel
    let checkoutModel:      CheckoutModel
    let promotionsModel:    PromotionsModel
    let pastPurchasesModel: PastPurchasesModel
    let supportModel:       SupportModel
    let suggestionsModel:   SuggestionsModel

    // MARK: - Enums

    public enum Tab: Hashable {
        case store, search, cart, account, orders
    }

    @CasePathable
    public enum Destination {
        case support
        case rateOrder(PastOrder)
    }

    // MARK: - Init

    public init(
        destination: Destination? = nil,
        selectedTab: Tab = .store,
        storeRepository:         any StoreRepositoryProtocol,
        searchRepository:        any SearchRepositoryProtocol,
        accountRepository:       any AccountRepositoryProtocol,
        checkoutRepository:      any CheckoutRepositoryProtocol,
        promotionsRepository:    any PromotionsRepositoryProtocol,
        pastPurchasesRepository: any PastPurchasesRepositoryProtocol,
        suggestionsRepository:   any SuggestionsRepositoryProtocol
    ) {
        self.destination = destination
        self.selectedTab = selectedTab
        
        let checkoutModel      = CheckoutModel(repository: checkoutRepository)
        let pastPurchasesModel = PastPurchasesModel(repository: pastPurchasesRepository)
        let storeModel         = StoreModel(repository: storeRepository)
        let searchModel        = SearchModel(repository: searchRepository)
        let suggestionsModel   = SuggestionsModel(repository: suggestionsRepository)

        // Wire add-to-cart: each source module passes Foundation primitives;
        // the composition root converts them into CheckoutProduct.
        storeModel.onAddToCart = { id, name, price, wantsGuarantee in
            let product = CheckoutProduct(id: id, name: name, price: price,
                                          supportsExtendedGuarantee: wantsGuarantee)
            checkoutModel.addToCart(product)
            if wantsGuarantee { checkoutModel.extendedGuaranteeItems.insert(id) }
        }
        searchModel.onAddToCart = { id, name, price, wantsGuarantee in
            let product = CheckoutProduct(id: id, name: name, price: price,
                                          supportsExtendedGuarantee: wantsGuarantee)
            checkoutModel.addToCart(product)
            if wantsGuarantee { checkoutModel.extendedGuaranteeItems.insert(id) }
        }
        suggestionsModel.onAddToCart = { id, name, price, wantsGuarantee in
            let product = CheckoutProduct(id: id, name: name, price: price,
                                          supportsExtendedGuarantee: wantsGuarantee)
            checkoutModel.addToCart(product)
            if wantsGuarantee { checkoutModel.extendedGuaranteeItems.insert(id) }
        }

        // Wire order persistence: PlacedOrder + guarantee set → PastOrder.
        checkoutModel.onOrderPlaced = { placedOrder, guaranteeItems in
            let lines: [PastOrderLine] = placedOrder.items.map { item in
                PastOrderLine(
                    productID:            item.product.id,
                    name:                 item.product.name,
                    unitPrice:            item.product.price,
                    quantity:             item.quantity,
                    hasExtendedGuarantee: guaranteeItems.contains(item.product.id)
                )
            }
            let addr = placedOrder.shippingAddress
            let pastOrder = PastOrder(
                id:                 placedOrder.id,
                placedAt:           Date(),
                estimatedDelivery:  placedOrder.estimatedDelivery,
                status:             .processing,
                lines:              lines,
                deliveryOptionName: placedOrder.deliveryOption.rawValue,
                itemsSubtotal:      placedOrder.items.reduce(0) { $0 + $1.product.price * Decimal($1.quantity) },
                deliveryCost:       placedOrder.deliveryOption.price,
                guaranteeCost:      Decimal(guaranteeItems.count) * 9.99,
                total:              placedOrder.total,
                shippingAddress:    PastOrderAddress(
                    fullName:   addr.fullName,
                    line1:      addr.line1,
                    line2:      addr.line2,
                    city:       addr.city,
                    state:      addr.state,
                    postalCode: addr.postalCode,
                    country:    addr.country
                )
            )
            Task { await pastPurchasesModel.saveOrder(pastOrder) }
        }

        // Wire repeat-order: PastOrderLines → CheckoutProducts.
        pastPurchasesModel.onRepeatOrder = { pastOrder in
            for line in pastOrder.lines {
                let product = CheckoutProduct(
                    id:                        line.productID,
                    name:                      line.name,
                    price:                     line.unitPrice,
                    supportsExtendedGuarantee: line.hasExtendedGuarantee
                )
                for _ in 0 ..< line.quantity { checkoutModel.addToCart(product) }
                if line.hasExtendedGuarantee {
                    checkoutModel.extendedGuaranteeItems.insert(line.productID)
                }
            }
        }

        self.checkoutModel      = checkoutModel
        self.pastPurchasesModel = pastPurchasesModel
        self.storeModel         = storeModel
        self.searchModel        = searchModel
        self.suggestionsModel   = suggestionsModel
        self.accountModel       = AccountModel(repository: accountRepository)
        self.promotionsModel    = PromotionsModel(repository: promotionsRepository)
        self.supportModel       = SupportModel()
    }

    // MARK: - Address sync

    /// Converts Account's `SavedAddress` list into Checkout's `ShippingAddress` list.
    /// Typed on Foundation primitives at the boundary so neither module imports the other.
    public func syncAddresses() {
        checkoutModel.savedAddresses = accountModel.addresses.map { a in
            ShippingAddress(
                id:         a.id,
                fullName:   a.fullName,
                line1:      a.line1,
                line2:      a.line2,
                city:       a.city,
                state:      a.state,
                postalCode: a.postalCode,
                country:    a.country,
                isDefault:  a.isDefault
            )
        }
    }
}
