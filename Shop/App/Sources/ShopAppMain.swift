import SwiftUI
import ShopCore
import Store
import Search
import Checkout
import Account
import Promotions
import PastPurchases
import Suggestions
import StoreTesting
import AccountTesting
import CheckoutTesting
import PromotionsTesting
import SuggestionsTesting

@main
struct ShopAppMain: App {
    private let appModel: AppModel

    init() {
        // Stub repositories below are not standing in for a missing backend — every
        // module has a live Default*Repository against ShopAppServer. They exist solely
        // so --ui-testing gets deterministic, network-free data (ADR-0009's philosophy,
        // applied to XCUITest, not just snapshot tests): ShopAppUITests asserts on exact
        // fixture content ("Alex Johnson", "MacBook Pro 16\"") and must not depend on
        // whether a local server happens to be running.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        appModel = AppModel(
            // destination: .support,
            // selectedTab: .orders,
            storeRepository:         isUITesting ? StubStoreRepository()   : DefaultStoreRepository(),
            searchRepository:        DefaultSearchRepository(),
            accountRepository:       isUITesting ? StubAccountRepository() : DefaultAccountRepository(),
            checkoutRepository:      isUITesting ? StubCheckoutRepository(delay: .zero) : DefaultCheckoutRepository(),
            promotionsRepository:    isUITesting ? StubPromotionsRepository() : DefaultPromotionsRepository(),
            pastPurchasesRepository: DefaultPastPurchasesRepository(),
            suggestionsRepository:   isUITesting ? StubSuggestionsRepository() : DefaultSuggestionsRepository()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: appModel)
        }
    }
}
