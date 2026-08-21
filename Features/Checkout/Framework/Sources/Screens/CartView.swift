import SwiftUI
import DesignSystem

struct CartView<PromotionBanner: View>: View {
    let model: CheckoutModel
    private let promotionBanner: () -> PromotionBanner

    init(model: CheckoutModel, @ViewBuilder promotionBanner: @escaping () -> PromotionBanner) {
        self.model = model
        self.promotionBanner = promotionBanner
    }

    var body: some View {
        Group {
            if model.isEmpty {
                emptyState
            } else {
                cartList
            }
        }
        .navigationTitle(Strings.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    private var cartList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(model.cart) { item in
                    CartItemRow(item: item, model: model)
                }
                .onDelete { indexSet in
                    indexSet.forEach { model.removeItem(model.cart[$0]) }
                }
            }
            .listStyle(.plain)

            promotionBanner()
                .padding(.vertical, 8)

            orderSummary
        }
    }

    private var orderSummary: some View {
        VStack(spacing: 12) {
            Divider()
            HStack {
                Text(Strings.subtotal(count: model.itemCount))
                    .foregroundStyle(.secondary)
                Spacer()
                PriceLabel(model.subtotal)
            }
            .padding(.horizontal)
            PrimaryButton(Strings.proceedToCheckout) {
                model.proceedToAddress()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.dsBackground)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            Strings.emptyTitle,
            systemImage: "cart",
            description: Text(Strings.emptyDescription)
        )
    }
}

struct CartItemRow: View {
    let item: CartItem
    let model: CheckoutModel

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurface)
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                PriceLabel(item.subtotal)
            }

            Spacer()

            Stepper(
                value: Binding(
                    get: { item.quantity },
                    set: { model.updateQuantity(for: item, quantity: $0) }
                ),
                in: 0...99
            ) {
                Text("\(item.quantity)")
                    .font(.subheadline.monospacedDigit())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle   = "Your Cart"
    static let proceedToCheckout = "Proceed to Checkout"
    static let emptyTitle        = "Your cart is empty"
    static let emptyDescription  = "Add items from the store to get started."
    private static let item      = "item"
    private static let items     = "items"
    static func subtotal(count: Int) -> String {
        "Subtotal (\(count) \(count == 1 ? item : items))"
    }
}
