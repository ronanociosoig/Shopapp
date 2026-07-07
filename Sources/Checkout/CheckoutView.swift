import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct CheckoutView: View {
    @Bindable public var model: CheckoutModel

    public init(model: CheckoutModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            CartView(model: model)
                // Push: address form (no associated value)
                .navigationDestination(
                    isPresented: Binding($model.destination.addressForm)
                ) {
                    AddressFormView(model: model)
                }
                // Push: delivery options + extended guarantee
                .navigationDestination(
                    item: $model.destination.orderOptions
                ) { address in
                    OrderOptionsView(model: model, address: address)
                }
                // Push: payment method selection (carries the confirmed address)
                .navigationDestination(
                    item: $model.destination.paymentMethodSelection
                ) { address in
                    PaymentMethodSelectionView(model: model, address: address)
                }
                // Push: credit card entry (carries the confirmed address)
                .navigationDestination(
                    item: $model.destination.paymentEntry
                ) { address in
                    PaymentEntryView(model: model, address: address)
                }
        }
        // Sheet: processing — non-dismissable, shown during API call
        .sheet(isPresented: Binding($model.destination.processing)) {
            OrderProcessingView()
                .interactiveDismissDisabled()
        }
        // Full-screen cover: order confirmed (iOS only; macOS uses sheet)
        #if os(iOS)
        .fullScreenCover(item: $model.destination.confirmation) { order in
            OrderConfirmationView(order: order)
        }
        #else
        .sheet(item: $model.destination.confirmation) { order in
            OrderConfirmationView(order: order)
        }
        #endif
        // Sheet: payment failed — allows retry or cancel
        .sheet(item: $model.destination.paymentFailed) { error in
            PaymentFailedView(error: error, onRetry: model.retryPayment)
        }
    }
}
