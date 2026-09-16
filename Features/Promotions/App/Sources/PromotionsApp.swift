import SwiftUI
import Promotions
import Store
import Checkout
import PromotionsTesting
import StoreTesting
import CheckoutTesting

@main
struct PromotionsApp: App {
    private let promotionsModel = PromotionsModel(repository: StubPromotionsRepository())
    private let storeModel      = StoreModel()

    // PromotionsApp has no scenario to fabricate and never touches
    // CheckoutModel directly — it only wants a real Checkout tab to show
    // promotion banners next to. DefaultCheckoutFactory is exactly that
    // door: dependencies in, a screen and a small port out, nothing else
    // of Checkout's implementation reachable from here.
    private let checkoutFactory: DefaultCheckoutFactory = {
        let factory = DefaultCheckoutFactory(
            dependencies: CheckoutDependencies(repository: StubCheckoutRepository(delay: .zero))
        )
        for product in CheckoutProduct.stubs.prefix(2) {
            factory.addToCart(
                id: product.id,
                name: product.name,
                price: product.price,
                wantsGuarantee: product.supportsExtendedGuarantee
            )
        }
        factory.setSavedAddresses([.stub])
        return factory
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                StoreView(model: storeModel, promotionBanner: {
                    PromotionBannerView(model: promotionsModel)
                })
                .tabItem { Label("Store", systemImage: "storefront") }

                checkoutFactory.makeCheckout {
                    PromotionBannerView(model: promotionsModel, sectionTitle: "You may also like")
                }
                .tabItem { Label("Cart", systemImage: "cart") }
            }
        }
    }
}
