import SwiftUI
import Checkout

@main
struct CheckoutApp: App {
    // Micro-app entry point for the Checkout module.
    // Pre-populated cart makes every screen of the funnel reachable
    // immediately — no need to navigate from a product listing first.
    var body: some Scene {
        WindowGroup {
            CheckoutView(model: CheckoutModel(
                cart: CartItem.stubs,
                repository: StubCheckoutRepository()
            ))
        }
    }
}
