import Foundation
@_spi(Internals) import Checkout

public extension CheckoutModel {
    convenience init(
        cart: [CartItem] = [],
        destination: Destination? = nil,
        selectedAddressStore: SelectedAddressStore = StubSelectedAddressStore()
    ) {
        self.init(
            cart: cart,
            destination: destination,
            dependencies: CheckoutDependencies(
                repository: StubCheckoutRepository(),
                selectedAddressStore: selectedAddressStore
            )
        )
    }
}
