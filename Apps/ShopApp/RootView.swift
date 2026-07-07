import SwiftUI
import Store
import Search
import Checkout
import Account
import Promotions
import PastPurchases
import Support
import Suggestions

struct RootView: View {
    // Each model is created once at the composition root and passed down.
    // Feature modules are decoupled from each other — only this file knows
    // about all of them.
    //
    // Add-to-cart is wired here via onAddToCart closures typed on Foundation
    // primitives (UUID, String, Decimal), so no feature module imports Checkout.

    private let storeModel:         StoreModel
    private let searchModel:        SearchModel
    private let accountModel:       AccountModel
    private let checkoutModel:      CheckoutModel
    private let promotionsModel:    PromotionsModel
    private let pastPurchasesModel: PastPurchasesModel
    private let supportModel:       SupportModel
    private let suggestionsModel:   SuggestionsModel

    @State private var selectedTab         = 0
    @State private var isShowingSupport    = false

    private static let cartTabIndex = 2

    init(
        storeRepository:          StoreRepositoryProtocol,
        searchRepository:         SearchRepositoryProtocol,
        accountRepository:        AccountRepositoryProtocol,
        checkoutRepository:       CheckoutRepositoryProtocol,
        promotionsRepository:     PromotionsRepositoryProtocol,
        pastPurchasesRepository:  PastPurchasesRepositoryProtocol,
        suggestionsRepository:    SuggestionsRepositoryProtocol
    ) {
        let checkoutModel      = CheckoutModel(repository: checkoutRepository)
        let pastPurchasesModel = PastPurchasesModel(repository: pastPurchasesRepository)
        let storeModel         = StoreModel(repository: storeRepository)
        let searchModel        = SearchModel(repository: searchRepository)
        let suggestionsModel   = SuggestionsModel(repository: suggestionsRepository)

        // Wire add-to-cart: each source module passes (id, name, price) primitives;
        // the composition root converts them into CheckoutProduct and updates the cart.
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

        // Wire order persistence: after a successful payment the composition root
        // converts PlacedOrder + guarantee set → PastOrder and saves it locally.
        // Both modules are only imported here, keeping them decoupled from each other.
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

        // Wire repeat-order: each PastOrderLine is converted back into a
        // CheckoutProduct and added to the cart. Extended guarantee is re-applied
        // for lines that had it.
        pastPurchasesModel.onRepeatOrder = { pastOrder in
            for line in pastOrder.lines {
                let product = CheckoutProduct(
                    id:                       line.productID,
                    name:                     line.name,
                    price:                    line.unitPrice,
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

    var body: some View {
        TabView(selection: $selectedTab) {
            StoreView(model: storeModel)
                .tabItem { Label(Strings.storeTab, systemImage: "storefront") }
                .tag(0)

            SearchView(model: searchModel)
                .tabItem { Label(Strings.searchTab, systemImage: "magnifyingglass") }
                .tag(1)

            CheckoutView(model: checkoutModel)
                .tabItem { Label(Strings.cartTab, systemImage: "cart") }
                .badge(checkoutModel.itemCount)
                .tag(2)

            AccountView(model: accountModel)
                .tabItem { Label(Strings.accountTab, systemImage: "person") }
                .tag(3)

            PastPurchasesView(model: pastPurchasesModel)
                .tabItem { Label(Strings.ordersTab, systemImage: "bag") }
                .tag(4)
        }
        .task { syncAddresses() }
        .onChange(of: accountModel.addresses) { syncAddresses() }
        .onChange(of: pastPurchasesModel.shouldNavigateToCart) { _, navigates in
            guard navigates else { return }
            selectedTab = Self.cartTabIndex
            pastPurchasesModel.shouldNavigateToCart = false
        }
        .onChange(of: pastPurchasesModel.shouldOpenSupport) { _, open in
            guard open else { return }
            isShowingSupport = true
            pastPurchasesModel.shouldOpenSupport = false
        }
        .sheet(isPresented: $isShowingSupport) {
            SupportView(model: supportModel)
        }
    }

    /// Converts Account's SavedAddress list into Checkout's ShippingAddress list.
    /// Typed on Foundation primitives at the boundary so neither module imports the other.
    private func syncAddresses() {
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

// MARK: - Strings

private enum Strings {
    static let storeTab   = "Store"
    static let searchTab  = "Search"
    static let cartTab    = "Cart"
    static let accountTab = "Account"
    static let ordersTab  = "Orders"
}
