import Foundation
import Checkout

public extension CheckoutModel {
    convenience init(
        cart: [CartItem] = [],
        destination: Destination? = nil
    ) {
        self.init(
            cart: cart,
            destination: destination,
            repository: StubCheckoutRepository(),
            selectedAddressStore: StubSelectedAddressStore()
        )
    }
}
