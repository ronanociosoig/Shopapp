import SwiftUI
import CheckoutAPI
import DesignSystem

struct OrderConfirmationView: View {
    let order: PlacedOrder
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.dsSuccess)

            VStack(spacing: 8) {
                Text(Strings.title)
                    .font(.title.bold())
                Text(Strings.orderNumber(order.id.uuidString.prefix(8).uppercased()))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label(Strings.shippingToLabel, systemImage: "location")
                    .font(.headline)
                Text(order.shippingAddress.formatted)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()

                Label(order.deliveryOption.rawValue, systemImage: order.deliveryOption.icon)
                    .font(.headline)
                Text(order.estimatedDelivery, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Text(Strings.totalCharged)
                        .font(.headline)
                    Spacer()
                    PriceLabel(order.total)
                }
            }
            .padding()
            .background(Color.dsSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            PrimaryButton(Strings.continueShopping) { dismiss() }
                .padding(.horizontal)
                .padding(.bottom)
        }
    }
}

// MARK: - Strings

private enum Strings {
    static let title            = "Order Confirmed!"
    static let shippingToLabel  = "Shipping to"
    static let totalCharged     = "Total charged"
    static let continueShopping = "Continue Shopping"
    static func orderNumber(_ id: String) -> String { "Order #\(id)" }
}
