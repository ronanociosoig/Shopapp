import SwiftUI
import Store
import Search
import Checkout
import Account
import Promotions
import PastPurchases
import Support
import Suggestions

@main
struct ShopAppMain: App {
    // MARK: - Composition root
    //
    // All repositories are created here and injected into feature models.
    // Swap StubXRepository for LiveXRepository to connect to a real backend.

    private let storeRepository          = StoreRepository()
    private let searchRepository         = SearchRepository()
    private let accountRepository        = StubAccountRepository()
    private let checkoutRepository       = StubCheckoutRepository()
    private let promotionsRepository     = StubPromotionsRepository()
    private let pastPurchasesRepository  = PastPurchasesRepository()
    private let suggestionsRepository    = StubSuggestionsRepository()

    var body: some Scene {
        WindowGroup {
            RootView(
                storeRepository:          storeRepository,
                searchRepository:         searchRepository,
                accountRepository:        accountRepository,
                checkoutRepository:       checkoutRepository,
                promotionsRepository:     promotionsRepository,
                pastPurchasesRepository:  pastPurchasesRepository,
                suggestionsRepository:    suggestionsRepository
            )
        }
    }
}
