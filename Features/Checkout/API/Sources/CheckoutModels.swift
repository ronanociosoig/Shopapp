import Foundation

// MARK: - DeliveryOption

public enum DeliveryOption: String, CaseIterable, Identifiable, Sendable, Codable {
    case standard = "Standard Delivery"
    case express  = "Express Delivery"
    case collect  = "Collect from Store"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .standard: return "shippingbox"
        case .express:  return "bolt.fill"
        case .collect:  return "storefront"
        }
    }

    public var detail: String {
        switch self {
        case .standard: return "3–5 business days"
        case .express:  return "Next business day"
        case .collect:  return "Ready within 2 hours"
        }
    }

    public var price: Decimal {
        switch self {
        case .standard: return 0
        case .express:  return 9.99
        case .collect:  return 0
        }
    }

    public var priceLabel: String {
        price == 0 ? "Free" : "+€\(price)"
    }
}

// MARK: - CheckoutProduct

/// Lightweight product representation owned by the Checkout module.
/// Contains only the fields needed for cart display and order placement.
/// `supportsExtendedGuarantee` is true for consumer electronics.
public struct CheckoutProduct: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let name: String
    public let price: Decimal
    public let supportsExtendedGuarantee: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        price: Decimal,
        supportsExtendedGuarantee: Bool = false
    ) {
        self.id                       = id
        self.name                     = name
        self.price                    = price
        self.supportsExtendedGuarantee = supportsExtendedGuarantee
    }
}

// MARK: - CartItem

public struct CartItem: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let product: CheckoutProduct
    public var quantity: Int

    public init(id: UUID = UUID(), product: CheckoutProduct, quantity: Int = 1) {
        self.id       = id
        self.product  = product
        self.quantity = quantity
    }

    public var subtotal: Decimal { product.price * Decimal(quantity) }
}

// MARK: - ShippingAddress

public struct ShippingAddress: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let fullName: String
    public let line1: String
    public let line2: String?
    public let city: String
    public let state: String
    public let postalCode: String
    public let country: String
    public let isDefault: Bool

    public init(
        id: UUID = UUID(),
        fullName: String,
        line1: String,
        line2: String? = nil,
        city: String,
        state: String,
        postalCode: String,
        country: String = "Ireland",
        isDefault: Bool = false
    ) {
        self.id         = id
        self.fullName   = fullName
        self.line1      = line1
        self.line2      = line2
        self.city       = city
        self.state      = state
        self.postalCode = postalCode
        self.country    = country
        self.isDefault  = isDefault
    }

    public var formatted: String {
        var lines = [fullName, line1]
        if let line2 { lines.append(line2) }
        lines.append("\(city), \(state) \(postalCode)")
        lines.append(country)
        return lines.joined(separator: "\n")
    }
}

// MARK: - CheckoutStep

/// Each value represents one screen in the sequential checkout funnel.
/// Appended to `CheckoutModel.path` to push screens onto the NavigationStack.
/// The user can navigate back through the stack at any point.
///
/// Public only because it is a parameter type of `CheckoutModel`'s `@_spi(Scenarios)`
/// convenience init — ordinary consumers of `Checkout` have no legitimate reason to
/// construct a mid-funnel `path` themselves and don't see that initializer at all.
public enum CheckoutStep: Hashable, Sendable {
    case address
    case orderOptions(ShippingAddress)
    case paymentMethod(ShippingAddress)
    case paymentEntry(ShippingAddress)
}

// MARK: - PlacedOrder

public struct PlacedOrder: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let items: [OrderLineItem]
    public let shippingAddress: ShippingAddress
    public let deliveryOption: DeliveryOption
    public let total: Decimal
    public let estimatedDelivery: Date

    public init(
        id: UUID = UUID(),
        items: [OrderLineItem],
        shippingAddress: ShippingAddress,
        deliveryOption: DeliveryOption,
        total: Decimal,
        estimatedDelivery: Date
    ) {
        self.id              = id
        self.items           = items
        self.shippingAddress = shippingAddress
        self.deliveryOption  = deliveryOption
        self.total           = total
        self.estimatedDelivery = estimatedDelivery
    }
}

// MARK: - OrderLineItem

public struct OrderLineItem: Equatable, Sendable, Codable {
    public let product: CheckoutProduct
    public let quantity: Int

    public init(product: CheckoutProduct, quantity: Int) {
        self.product  = product
        self.quantity = quantity
    }
}
