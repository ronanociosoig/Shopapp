import SwiftUI
import SwiftUINavigation
import Store
import Search
import Checkout
import Account
import Promotions
import PastPurchases
import Support
import Suggestions

public struct RootView: View {
    @Bindable public var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        TabView(selection: $model.selectedTab) {
            StoreView(
                model: model.storeModel,
                suggestionRow: { SuggestionsView(model: model.suggestionsModel) },
                promotionBanner: { PromotionBannerView(model: model.promotionsModel) }
            )
            .tabItem { Label(Strings.storeTab, systemImage: "storefront") }
            .tag(AppModel.Tab.store)

            SearchView(model: model.searchModel)
                .tabItem { Label(Strings.searchTab, systemImage: "magnifyingglass") }
                .tag(AppModel.Tab.search)

            CheckoutView(model: model.checkoutModel) {
                PromotionBannerView(model: model.promotionsModel, sectionTitle: "You may also like")
            }
            .tabItem { Label(Strings.cartTab, systemImage: "cart") }
                .badge(model.checkoutModel.itemCount)
                .tag(AppModel.Tab.cart)

            AccountView(model: model.accountModel)
                .tabItem { Label(Strings.accountTab, systemImage: "person") }
                .tag(AppModel.Tab.account)

            PastPurchasesView(model: model.pastPurchasesModel)
                .tabItem { Label(Strings.ordersTab, systemImage: "bag") }
                .tag(AppModel.Tab.orders)
        }
        .task {
            // load() guards itself against clobbering state a caller (or a
            // test) already set explicitly — see AccountModel.load(). This
            // fires independently of AccountView's own .task, which calls
            // the same load() and relies on the same guard.
            await model.accountModel.load()
            model.syncAddresses()
        }
        .onChange(of: model.accountModel.addresses) { model.syncAddresses() }
        .onChange(of: model.pastPurchasesModel.shouldNavigateToCart) { _, navigates in
            guard navigates else { return }
            model.selectedTab = .cart
            model.pastPurchasesModel.shouldNavigateToCart = false
        }
        .onChange(of: model.pastPurchasesModel.shouldOpenSupport) { _, open in
            guard open else { return }
            model.destination = .support
            model.pastPurchasesModel.shouldOpenSupport = false
        }
        .onChange(of: model.pastPurchasesModel.orderToRate) { _, order in
            guard let order else { return }
            model.destination = .rateOrder(order)
            model.pastPurchasesModel.orderToRate = nil
        }
        .sheet(isPresented: Binding($model.destination.support)) {
            SupportView(model: model.supportModel)
        }
        .sheet(item: $model.destination.rateOrder) { order in
            RateOrderView(order: order)
        }
    }
}

// MARK: - Strings

private enum Strings {
    static let storeTab   = "Store"
    static let searchTab  = "Search"
    static let cartTab    = "Cart"
    static let accountTab = "Account"
    static let ordersTab  = "Orders"
}
