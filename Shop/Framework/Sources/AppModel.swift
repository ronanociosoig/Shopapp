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
@MainActor
@Observable
public final class AppModel {

    // MARK: - Navigation state

    var selectedTab: Tab
    var destination: Destination?

    // MARK: - Feature models

    let storeModel:         StoreModel
    let searchModel:        SearchModel
    let accountModel:       AccountModel
    let checkoutFactory:    DefaultCheckoutFactory
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
        storeRepository:         any StoreRepository,
        searchRepository:        any SearchRepository,
        accountRepository:       any AccountRepository,
        checkoutRepository:      any CheckoutRepository,
        promotionsRepository:    any PromotionsRepository,
        pastPurchasesRepository: any PastPurchasesRepository,
        suggestionsRepository:   any SuggestionsRepository
    ) {
        self.destination = destination
        self.selectedTab = selectedTab
        
        let checkoutFactory    = DefaultCheckoutFactory(dependencies: CheckoutDependencies(repository: checkoutRepository))
        let pastPurchasesModel = PastPurchasesModel(repository: pastPurchasesRepository)
        let storeModel         = StoreModel(repository: storeRepository)
        let searchModel        = SearchModel(repository: searchRepository)
        let suggestionsModel   = SuggestionsModel(repository: suggestionsRepository)

        // Wire add-to-cart: each source module passes Foundation primitives
        // straight through to the factory's port — the composition root
        // never needs to see a CheckoutProduct or a CheckoutModel to do this.
        storeModel.onAddToCart = { id, name, price, wantsGuarantee in
            checkoutFactory.addToCart(id: id, name: name, price: price, wantsGuarantee: wantsGuarantee)
        }
        searchModel.onAddToCart = { id, name, price, wantsGuarantee in
            checkoutFactory.addToCart(id: id, name: name, price: price, wantsGuarantee: wantsGuarantee)
        }
        suggestionsModel.onAddToCart = { id, name, price, wantsGuarantee in
            checkoutFactory.addToCart(id: id, name: name, price: price, wantsGuarantee: wantsGuarantee)
        }

        // Wire order persistence: PlacedOrder + guarantee set → PastOrder.
        checkoutFactory.onOrderPlaced = { placedOrder, guaranteeItems in
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

        // Wire repeat-order: PastOrderLines → the factory's add-to-cart port.
        pastPurchasesModel.onRepeatOrder = { pastOrder in
            for line in pastOrder.lines {
                for _ in 0 ..< line.quantity {
                    checkoutFactory.addToCart(
                        id: line.productID,
                        name: line.name,
                        price: line.unitPrice,
                        wantsGuarantee: line.hasExtendedGuarantee
                    )
                }
            }
        }

        self.checkoutFactory    = checkoutFactory
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
        checkoutFactory.setSavedAddresses(accountModel.addresses.map { a in
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
        })
    }
}
