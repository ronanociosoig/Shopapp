import SwiftUI
import DesignSystem

struct PaymentEntryView: View {
    let model: CheckoutModel
    let address: ShippingAddress

    @State private var cardNumber   = ""
    @State private var expiry       = ""
    @State private var cvv          = ""
    @State private var isSubmitting = false

    var body: some View {
        Form {
            Section(Strings.shippingToHeader) {
                Text(address.formatted)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(Strings.cardSectionHeader) {
                TextField(Strings.cardNumberPlaceholder, text: $cardNumber)
                #if os(iOS)
                    .keyboardType(.numberPad)
                    .textContentType(.creditCardNumber)
                #endif
                HStack {
                    TextField(Strings.expiryPlaceholder, text: $expiry)
                    #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                    #endif
                    TextField(Strings.cvvPlaceholder, text: $cvv)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                }
            }

            Section {
                HStack {
                    Text(Strings.orderTotal)
                    Spacer()
                    DSPriceLabel(model.subtotal)
                }
            }
        }
        .navigationTitle(Strings.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Button(Strings.payNow) { submitPayment() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        cardNumber.count >= 15 && expiry.count == 5 && cvv.count >= 3
    }

    private func submitPayment() {
        isSubmitting = true
        let token = "tok_\(cardNumber.suffix(4))"
        Task {
            await model.submitPayment(address: address, cardToken: token)
            isSubmitting = false
        }
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle       = "Payment"
    static let shippingToHeader      = "Shipping to"
    static let cardSectionHeader     = "Credit / Debit Card"
    static let cardNumberPlaceholder = "Card number"
    static let expiryPlaceholder     = "MM/YY"
    static let cvvPlaceholder        = "CVV"
    static let orderTotal            = "Order total"
    static let payNow                = "Pay now"
}
