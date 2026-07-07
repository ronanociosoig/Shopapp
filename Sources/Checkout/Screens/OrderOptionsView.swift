import SwiftUI
import DesignSystem

struct OrderOptionsView: View {
    @Bindable var model: CheckoutModel
    let address: ShippingAddress

    var body: some View {
        Form {
            deliverySection
            if model.hasGuaranteeEligibleItems {
                guaranteeSection
            }
            orderSummarySection
        }
        .navigationTitle(Strings.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Strings.continueButton) {
                    model.proceedToPaymentMethod(address: address)
                }
            }
        }
    }

    // MARK: - Sections

    private var deliverySection: some View {
        Section {
            ForEach(DeliveryOption.allCases) { option in
                Button {
                    model.deliveryOption = option
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.icon)
                            .font(.title3)
                            .foregroundStyle(.dsPrimary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(option.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(option.priceLabel)
                            .font(.subheadline)
                            .foregroundStyle(option.price == 0 ? .secondary : .primary)

                        Image(systemName: model.deliveryOption == option
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(model.deliveryOption == option
                                             ? Color.dsPrimary : .secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(Strings.deliveryHeader)
        }
    }

    private var guaranteeSection: some View {
        Section {
            ForEach(model.cart.filter { $0.product.supportsExtendedGuarantee }) { item in
                let opted = model.extendedGuaranteeItems.contains(item.product.id)
                Button {
                    model.toggleGuarantee(for: item.product)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.checkered")
                            .font(.title3)
                            .foregroundStyle(.dsPrimary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(Strings.guaranteeCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(Strings.guaranteePrice)
                            .font(.subheadline)

                        Image(systemName: opted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(opted ? Color.dsPrimary : .secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(Strings.guaranteeHeader)
        } footer: {
            Text(Strings.guaranteeFooter)
        }
    }

    private var orderSummarySection: some View {
        Section(Strings.Summary.header) {
            LabeledContent(Strings.Summary.subtotal, value: model.subtotal, format: .currency(code: "EUR"))
            LabeledContent(Strings.Summary.delivery, value: model.deliveryOption.price, format: .currency(code: "EUR"))
            if model.guaranteeCost > 0 {
                LabeledContent(Strings.Summary.extendedGuarantee, value: model.guaranteeCost, format: .currency(code: "EUR"))
            }
            HStack {
                Text(Strings.Summary.total).font(.headline)
                Spacer()
                DSPriceLabel(model.checkoutTotal)
            }
        }
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle  = "Delivery & Extras"
    static let continueButton   = "Continue"
    static let deliveryHeader   = "Delivery"
    static let guaranteeCaption = "+1 year beyond manufacturer warranty"
    static let guaranteePrice   = "+€9.99"
    static let guaranteeHeader  = "Extended Guarantee"
    static let guaranteeFooter  = "Extends the manufacturer warranty by 1 year for consumer electronics."

    enum Summary {
        static let header            = "Order Summary"
        static let subtotal          = "Subtotal"
        static let delivery          = "Delivery"
        static let extendedGuarantee = "Extended Guarantee"
        static let total             = "Total"
    }
}
