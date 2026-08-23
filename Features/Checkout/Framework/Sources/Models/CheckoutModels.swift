import Foundation
import CheckoutAPI

// MARK: - PaymentMethod

enum PaymentMethod: String, CaseIterable, Identifiable, Sendable {
    case creditCard = "Credit / Debit Card"
    case applePay   = "Apple Pay"
    case sofort     = "Sofort"
    case bizum      = "Bizum"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .creditCard: return "creditcard"
        case .applePay:   return "apple.logo"
        case .sofort:     return "building.columns"
        case .bizum:      return "iphone"
        }
    }

    var subtitle: String {
        switch self {
        case .creditCard: return "Visa, Mastercard, Amex"
        case .applePay:   return "Face ID or Touch ID"
        case .sofort:     return "Instant bank transfer"
        case .bizum:      return "Pay with your mobile number"
        }
    }

    /// Token stub used when submitting without a card form.
    var stubToken: String { "tok_\(rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))" }
}

// MARK: - PlaceOrderRequest

/// Request body for `POST /orders`.
struct PlaceOrderRequest: Encodable {
    let items: [CartItem]
    let shippingAddress: ShippingAddress
    let cardToken: String
    let deliveryOption: DeliveryOption
    let guaranteeCost: Decimal
}
