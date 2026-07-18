import SwiftUI
import Checkout
import CheckoutTesting

@main
struct CheckoutApp: App {
    // Micro-app entry point for the Checkout module.
    // Pre-populated cart and a saved address make every screen of the funnel
    // reachable immediately — no need to navigate from a product listing or
    // set up an account first. delay: .zero keeps the processing step instant
    // so manual testing and XCUITests don't wait for the simulated network call.
    var body: some Scene {
        WindowGroup {
            CheckoutView(model: {
                let model = CheckoutModel(
                    cart: CartItem.stubs,
                    //destination: .processing,
                    repository: StubCheckoutRepository(delay: .zero)
                )
                model.savedAddresses = [.stub]
                return model
            }())
        }
    }
}
