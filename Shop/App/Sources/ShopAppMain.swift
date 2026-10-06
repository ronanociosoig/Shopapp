import SwiftUI
import ShopCore
import Store
import Search
import Checkout
import Account
import Promotions
import PastPurchases
import Suggestions
#if DEBUG
import StoreTesting
import AccountTesting
import CheckoutTesting
import PromotionsTesting
import SuggestionsTesting
#endif

@main
struct ShopAppMain: App {
    private let appModel: AppModel

    init() {
        // Stub repositories are reachable only in a Debug build. --ui-testing exists so
        // ShopAppUITests gets deterministic, network-free data (ADR-0009's philosophy,
        // applied to XCUITest, not just snapshot tests) without depending on whether a
        // local server happens to be running — not because any module lacks a real
        // backend. A Release build never imports the XxxTesting targets at all, so
        // --ui-testing has no effect in one: there is no fixture path left to enable,
        // by construction, not by convention (ADR-0006).
        #if DEBUG
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let storeRepository:      StoreRepository       = isUITesting ? StubStoreRepository()   : DefaultStoreRepository()
        let accountRepository:    AccountRepository      = isUITesting ? StubAccountRepository() : DefaultAccountRepository()
        let checkoutRepository:   CheckoutRepository      = isUITesting ? StubCheckoutRepository(delay: .zero) : DefaultCheckoutRepository()
        let promotionsRepository: PromotionsRepository  = isUITesting ? StubPromotionsRepository() : DefaultPromotionsRepository()
        let suggestionsRepository: SuggestionsRepository = isUITesting ? StubSuggestionsRepository() : DefaultSuggestionsRepository()
        #else
        let storeRepository:       StoreRepository       = DefaultStoreRepository()
        let accountRepository:     AccountRepository     = DefaultAccountRepository()
        let checkoutRepository:    CheckoutRepository    = DefaultCheckoutRepository()
        let promotionsRepository:  PromotionsRepository  = DefaultPromotionsRepository()
        let suggestionsRepository: SuggestionsRepository = DefaultSuggestionsRepository()
        #endif

        appModel = AppModel(
            // destination: .support,
            // selectedTab: .orders,
            storeRepository:         storeRepository,
            searchRepository:        DefaultSearchRepository(),
            accountRepository:       accountRepository,
            checkoutRepository:      checkoutRepository,
            promotionsRepository:    promotionsRepository,
            pastPurchasesRepository: DefaultPastPurchasesRepository(),
            suggestionsRepository:   suggestionsRepository
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: appModel)
                .onOpenURL { url in
                    Task { await appModel.handle(url: url) }
                }
        }
    }
}
