import Foundation
import Checkout

public extension CheckoutModel {
    convenience init(
        cart: [CartItem] = [],
        destination: Destination? = nil,
        selectedAddressStore: SelectedAddressStoreProtocol = StubSelectedAddressStore()
    ) {
        self.init(
            cart: cart,
            destination: destination,
            repository: StubCheckoutRepository(),
            selectedAddressStore: selectedAddressStore
        )
    }
}
