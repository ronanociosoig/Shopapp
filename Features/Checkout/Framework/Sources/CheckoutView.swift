import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct CheckoutView<PromotionBanner: View>: View {
    @Bindable public var model: CheckoutModel
    private let promotionBanner: () -> PromotionBanner

    public init(
        model: CheckoutModel,
        @ViewBuilder promotionBanner: @escaping () -> PromotionBanner
    ) {
        self.model = model
        self.promotionBanner = promotionBanner
    }

    public var body: some View {
        NavigationStack(path: $model.path) {
            CartView(model: model, promotionBanner: promotionBanner)
                .navigationDestination(for: CheckoutStep.self) { step in
                    switch step {
                    case .address:
                        AddressFormView(model: model)
                    case .orderOptions(let address):
                        OrderOptionsView(model: model, address: address)
                    case .paymentMethod(let address):
                        PaymentMethodSelectionView(model: model, address: address)
                    case .paymentEntry(let address):
                        PaymentEntryView(model: model, address: address)
                    }
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

extension CheckoutView where PromotionBanner == EmptyView {
    public init(model: CheckoutModel) {
        self.init(model: model, promotionBanner: { EmptyView() })
    }
}
