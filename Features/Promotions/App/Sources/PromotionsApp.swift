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
    private let checkoutModel: CheckoutModel = {
        let model = CheckoutModel(cart: CartItem.stubs, repository: StubCheckoutRepository(delay: .zero))
        model.savedAddresses = [.stub]
        return model
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                StoreView(model: storeModel, promotionBanner: {
                    PromotionBannerView(model: promotionsModel)
                })
                .tabItem { Label("Store", systemImage: "storefront") }

                CheckoutView(model: checkoutModel) {
                    PromotionBannerView(model: promotionsModel, sectionTitle: "You may also like")
                }
                .tabItem { Label("Cart", systemImage: "cart") }
            }
        }
    }
}
