import Foundation

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

// MARK: - DeliveryOption

public enum DeliveryOption: String, CaseIterable, Identifiable, Sendable, Codable {
    case standard = "Standard Delivery"
    case express  = "Express Delivery"
    case collect  = "Collect from Store"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard: return "shippingbox"
        case .express:  return "bolt.fill"
        case .collect:  return "storefront"
        }
    }

    var detail: String {
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

    var priceLabel: String {
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
    let supportsExtendedGuarantee: Bool

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

extension CheckoutProduct {

    // UUID helper: "00000000-0000-0000-0004-00000000NNNN"
    // Module prefix 0004 = Checkout; NNNN = sequential product number.
    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0004-%012X", n))!
    }

    /// A curated cross-category set used to seed the cart in tests and previews.
    /// Electronics items have `supportsExtendedGuarantee: true`.
    static let stubs: [CheckoutProduct] = [
        // Electronics — eligible for 1-year extended guarantee
        CheckoutProduct(id: id(1),  name: "MacBook Pro 16\"",             price: 2499.99, supportsExtendedGuarantee: true),
        CheckoutProduct(id: id(2),  name: "MacBook Air 15\"",             price: 1299.99, supportsExtendedGuarantee: true),
        CheckoutProduct(id: id(3),  name: "Dell UltraSharp 32\" Monitor", price: 699.99,  supportsExtendedGuarantee: true),
        CheckoutProduct(id: id(4),  name: "Sony WH-1000XM5 Headphones",  price: 349.99,  supportsExtendedGuarantee: true),
        CheckoutProduct(id: id(5),  name: "Logitech MX Keys Keyboard",   price: 119.99,  supportsExtendedGuarantee: true),
        CheckoutProduct(id: id(6),  name: "Anker USB-C Hub 7-in-1",      price: 49.99,   supportsExtendedGuarantee: true),
        // Furniture
        CheckoutProduct(id: id(7),  name: "Ergonomic Office Chair",       price: 299.99),
        CheckoutProduct(id: id(8),  name: "Standing Desk 160cm",          price: 499.99),
        CheckoutProduct(id: id(9),  name: "Lounge Chair with Ottoman",    price: 599.99),
        CheckoutProduct(id: id(10), name: "3-Seater Sofa",                price: 1099.99),
        CheckoutProduct(id: id(11), name: "LED Desk Lamp",                price: 69.99),
        CheckoutProduct(id: id(12), name: "Monitor Riser Stand",          price: 39.99),
        // Garden
        CheckoutProduct(id: id(13), name: "Acacia Garden Dining Table",   price: 379.99),
        CheckoutProduct(id: id(14), name: "6-Piece Garden Dining Set",    price: 749.99),
        CheckoutProduct(id: id(15), name: "Reclining Sun Lounger",        price: 249.99),
        CheckoutProduct(id: id(16), name: "Garden String Lights 10m",     price: 29.99),
        // Kitchen
        CheckoutProduct(id: id(17), name: "Solid Oak Dining Table",       price: 699.99),
        CheckoutProduct(id: id(18), name: "Padded Dining Chair (set of 4)", price: 319.99),
        CheckoutProduct(id: id(19), name: "Kitchen Island on Wheels",     price: 329.99),
        CheckoutProduct(id: id(20), name: "Adjustable Bar Stool (set of 2)", price: 169.99),
    ]

    static var stub: CheckoutProduct { stubs[0] }
}

// MARK: - CartItem

public struct CartItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let product: CheckoutProduct
    public var quantity: Int

    init(id: UUID = UUID(), product: CheckoutProduct, quantity: Int = 1) {
        self.id       = id
        self.product  = product
        self.quantity = quantity
    }

    public var subtotal: Decimal { product.price * Decimal(quantity) }
}

public extension CartItem {
    static let stubs: [CartItem] = [
        CartItem(
            id: UUID(uuidString: "00000000-0000-0000-0005-000000000001")!,
            product: .stubs[0],
            quantity: 1
        ),
        CartItem(
            id: UUID(uuidString: "00000000-0000-0000-0005-000000000002")!,
            product: .stubs[1],
            quantity: 2
        ),
    ]
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

    var formatted: String {
        var lines = [fullName, line1]
        if let line2 { lines.append(line2) }
        lines.append("\(city), \(state) \(postalCode)")
        lines.append(country)
        return lines.joined(separator: "\n")
    }
}

public extension ShippingAddress {
    static let stub = ShippingAddress(
        id: UUID(uuidString: "00000000-0000-0000-0006-000000000001")!,
        fullName: "Jane Appleseed",
        line1: "1 Infinite Loop",
        city: "Cupertino",
        state: "CA",
        postalCode: "95014",
        country: "United States",
        isDefault: true
    )

    static let stubs: [ShippingAddress] = [
        stub,
        ShippingAddress(
            id: UUID(uuidString: "00000000-0000-0000-0006-000000000002")!,
            fullName: "Jane Appleseed",
            line1: "14 Grafton Street",
            city: "Dublin",
            state: "Dublin 2",
            postalCode: "D02 HH57",
            country: "Ireland"
        ),
        ShippingAddress(
            id: UUID(uuidString: "00000000-0000-0000-0006-000000000003")!,
            fullName: "Jane Appleseed",
            line1: "22 Baker Street",
            line2: "Flat 3",
            city: "London",
            state: "England",
            postalCode: "NW1 6XE",
            country: "United Kingdom"
        ),
    ]
}

// MARK: - CheckoutStep

/// Each value represents one screen in the sequential checkout funnel.
/// Appended to `CheckoutModel.path` to push screens onto the NavigationStack.
/// The user can navigate back through the stack at any point.
enum CheckoutStep: Hashable {
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

extension PlacedOrder {
    static let stub = PlacedOrder(
        id: UUID(uuidString: "00000000-0000-0000-0007-000000000001")!,
        items: [OrderLineItem(product: .stub, quantity: 1)],
        shippingAddress: .stub,
        deliveryOption: .standard,
        total: 299.99,
        estimatedDelivery: Date(timeIntervalSinceNow: 5 * 24 * 3600)
    )
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
