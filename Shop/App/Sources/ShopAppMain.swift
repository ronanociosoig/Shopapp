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
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        appModel = AppModel(
            // destination: .support,
            // selectedTab: .orders,
            storeRepository:         isUITesting ? StubStoreRepository()              : DefaultStoreRepository(),
            searchRepository:        SearchRepository(),
            accountRepository:       StubAccountRepository(),
            checkoutRepository:      isUITesting ? StubCheckoutRepository(delay: .zero) : StubCheckoutRepository(),
            promotionsRepository:    StubPromotionsRepository(),
            pastPurchasesRepository: PastPurchasesRepository(),
            suggestionsRepository:   StubSuggestionsRepository()
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: appModel)
        }
    }
}
