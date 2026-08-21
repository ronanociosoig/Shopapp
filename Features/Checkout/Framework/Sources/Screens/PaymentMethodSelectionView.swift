import SwiftUI
import DesignSystem

struct PaymentMethodSelectionView: View {
    let model: CheckoutModel
    let address: ShippingAddress

    var body: some View {
        List {
            Section(Strings.shippingToHeader) {
                Text(address.formatted)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(Strings.paymentHeader) {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        model.selectPaymentMethod(method, address: address)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: method.icon)
                                .font(.title3)
                                .foregroundStyle(.dsPrimary)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(method.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(method.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(method.rawValue)
                }
            }

            Section {
                HStack {
                    Text(Strings.orderTotal)
                    Spacer()
                    PriceLabel(model.checkoutTotal)
                }
            }
        }
        .navigationTitle(Strings.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle  = "Payment"
    static let shippingToHeader = "Shipping to"
    static let paymentHeader    = "Payment method"
    static let orderTotal       = "Order total"
}
