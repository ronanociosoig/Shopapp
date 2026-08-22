import Foundation
import Checkout

public extension CheckoutModel {
    convenience init(
        cart: [CartItem] = [],
        destination: Destination? = nil,
        selectedAddressStore: SelectedAddressStore = StubSelectedAddressStore()
    ) {
        self.init(
            cart: cart,
            destination: destination,
            repository: StubCheckoutRepository(),
            selectedAddressStore: selectedAddressStore
        )
    }
}
