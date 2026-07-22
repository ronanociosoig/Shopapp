#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import ShopCore
@testable import Store
@testable import Search
@testable import Checkout
@testable import Account
@testable import PastPurchases
import Suggestions
import Promotions
import StoreTesting
import SearchTesting
import CheckoutTesting
import AccountTesting
import PastPurchasesTesting
import SuggestionsTesting
import PromotionsTesting

// MARK: - Snapshot Tests

@Suite("Root — Snapshot Tests")
@MainActor
struct RootSnapshotTests {

    // MARK: - Tabs

    @Test("Store tab renders correctly with products loaded")
    func storeTab() {
        let model = makeModel()
        model.storeModel.loadState = .loaded(StoreProduct.stubs)
        model.selectedTab = .store
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "tab_store"
        )
    }

    @Test("Search tab renders correctly in idle state")
    func searchTab() {
        let model = makeModel()
        model.selectedTab = .search
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "tab_search"
        )
    }

    @Test("Cart tab renders correctly with items")
    func cartTab() {
        let model = makeModel()
        model.checkoutModel.cart = CartItem.stubs
        model.checkoutModel.savedAddresses = ShippingAddress.stubs
        model.selectedTab = .cart
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "tab_cart"
        )
    }

    @Test("Account tab renders correctly with profile and addresses loaded")
    func accountTab() {
        let model = makeModel()
        model.accountModel.profile = .stub
        model.accountModel.addresses = SavedAddress.stubs
        model.selectedTab = .account
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "tab_account"
        )
    }

    @Test("Orders tab renders correctly with past orders")
    func ordersTab() {
        let model = makeModel()
        model.pastPurchasesModel.orders = PastOrder.stubs
        model.selectedTab = .orders
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "tab_orders"
        )
    }

    // MARK: - Root-level destinations

    @Test("Support sheet renders correctly")
    func supportDestination() {
        let model = makeModel()
        model.storeModel.loadState = .loaded(StoreProduct.stubs)
        model.destination = .support
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "destination_support"
        )
    }

    @Test("Rate Order sheet renders correctly")
    func rateOrderDestination() {
        let model = makeModel()
        model.pastPurchasesModel.orders = PastOrder.stubs
        model.selectedTab = .orders
        model.destination = .rateOrder(PastOrder.stubs[0])
        assertSnapshot(
            of: RootView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "destination_rate_order"
        )
    }
}

// MARK: - Helpers

/// Creates an `AppModel` wired entirely with synchronous stubs.
@MainActor
private func makeModel() -> AppModel {
    AppModel(
        storeRepository:         StubStoreRepository(),
        searchRepository:        StubSearchRepository(),
        accountRepository:       StubAccountRepository(),
        checkoutRepository:      StubCheckoutRepository(delay: .zero),
        promotionsRepository:    StubPromotionsRepository(),
        pastPurchasesRepository: StubPastPurchasesRepository(),
        suggestionsRepository:   StubSuggestionsRepository()
    )
}

#endif
