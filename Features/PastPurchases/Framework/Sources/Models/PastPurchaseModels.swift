import Foundation

// MARK: - PastOrderLine

/// A single product line within a past order.
/// Captures the name, price paid, and guarantee selection at the moment of purchase.
public struct PastOrderLine: Equatable, Sendable, Codable {
    public let productID: UUID
    public let name: String
    public let unitPrice: Decimal
    public let quantity: Int
    public let hasExtendedGuarantee: Bool

    public init(
        productID: UUID,
        name: String,
        unitPrice: Decimal,
        quantity: Int,
        hasExtendedGuarantee: Bool = false
    ) {
        self.productID            = productID
        self.name                 = name
        self.unitPrice            = unitPrice
        self.quantity             = quantity
        self.hasExtendedGuarantee = hasExtendedGuarantee
    }

    var subtotal: Decimal { unitPrice * Decimal(quantity) }
}

// MARK: - PastOrderAddress

/// Snapshot of the shipping address captured at the time of purchase.
/// Kept independent of the Checkout module so PastPurchases has no cross-module dependency.
public struct PastOrderAddress: Equatable, Sendable, Codable {
    public let fullName: String
    public let line1: String
    public let line2: String?
    public let city: String
    public let state: String
    public let postalCode: String
    public let country: String

    public init(
        fullName: String,
        line1: String,
        line2: String? = nil,
        city: String,
        state: String,
        postalCode: String,
        country: String = "Ireland"
    ) {
        self.fullName   = fullName
        self.line1      = line1
        self.line2      = line2
        self.city       = city
        self.state      = state
        self.postalCode = postalCode
        self.country    = country
    }

    var formatted: String {
        var parts = [fullName, line1]
        if let line2 { parts.append(line2) }
        parts.append("\(city), \(state) \(postalCode)")
        parts.append(country)
        return parts.joined(separator: "\n")
    }
}

// MARK: - PastOrder

public struct PastOrder: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let placedAt: Date
    let estimatedDelivery: Date
    var status: OrderStatus

    // Contents
    public let lines: [PastOrderLine]
    let deliveryOptionName: String

    // Price breakdown — each component stored separately for the receipt view
    let itemsSubtotal: Decimal
    let deliveryCost: Decimal
    let guaranteeCost: Decimal
    let total: Decimal

    // Shipping
    let shippingAddress: PastOrderAddress

    public init(
        id: UUID = UUID(),
        placedAt: Date,
        estimatedDelivery: Date,
        status: OrderStatus = .processing,
        lines: [PastOrderLine],
        deliveryOptionName: String,
        itemsSubtotal: Decimal,
        deliveryCost: Decimal,
        guaranteeCost: Decimal,
        total: Decimal,
        shippingAddress: PastOrderAddress
    ) {
        self.id                 = id
        self.placedAt           = placedAt
        self.estimatedDelivery  = estimatedDelivery
        self.status             = status
        self.lines              = lines
        self.deliveryOptionName = deliveryOptionName
        self.itemsSubtotal      = itemsSubtotal
        self.deliveryCost       = deliveryCost
        self.guaranteeCost      = guaranteeCost
        self.total              = total
        self.shippingAddress    = shippingAddress
    }

    /// Total number of individual units across all lines.
    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
}

// MARK: - OrderStatus

public enum OrderStatus: String, Equatable, Sendable, Codable {
    case processing = "Processing"
    case shipped    = "Shipped"
    case delivered  = "Delivered"
    case cancelled  = "Cancelled"
}

// MARK: - Stubs

private let iso = ISO8601DateFormatter()

extension PastOrderAddress {
    static let stub = PastOrderAddress(
        fullName:   "Alex Johnson",
        line1:      "123 Main Street",
        line2:      "Apt 4B",
        city:       "San Francisco",
        state:      "CA",
        postalCode: "94105",
        country:    "United States"
    )
}

public extension PastOrder {
    static let stubs: [PastOrder] = [
        PastOrder(
            id: UUID(uuidString: "00000000-0000-0000-0009-000000000001")!,
            placedAt: iso.date(from: "2026-03-15T10:00:00Z")!,
            estimatedDelivery: iso.date(from: "2026-03-20T10:00:00Z")!,
            status: .delivered,
            lines: [
                PastOrderLine(
                    productID: UUID(uuidString: "00000000-0000-0000-0004-000000000001")!,
                    name: "MacBook Pro 16\"",
                    unitPrice: 2499.99,
                    quantity: 1,
                    hasExtendedGuarantee: true
                ),
                PastOrderLine(
                    productID: UUID(uuidString: "00000000-0000-0000-0004-000000000004")!,
                    name: "Sony WH-1000XM5 Headphones",
                    unitPrice: 349.99,
                    quantity: 1,
                    hasExtendedGuarantee: false
                ),
            ],
            deliveryOptionName: "Standard Delivery",
            itemsSubtotal: 2849.98,
            deliveryCost: 0,
            guaranteeCost: 9.99,
            total: 2859.97,
            shippingAddress: .stub
        ),
        PastOrder(
            id: UUID(uuidString: "00000000-0000-0000-0009-000000000002")!,
            placedAt: iso.date(from: "2026-04-01T14:30:00Z")!,
            estimatedDelivery: iso.date(from: "2026-04-02T14:30:00Z")!,
            status: .shipped,
            lines: [
                PastOrderLine(
                    productID: UUID(uuidString: "00000000-0000-0000-0004-000000000007")!,
                    name: "Ergonomic Office Chair",
                    unitPrice: 299.99,
                    quantity: 1,
                    hasExtendedGuarantee: false
                ),
            ],
            deliveryOptionName: "Express Delivery",
            itemsSubtotal: 299.99,
            deliveryCost: 9.99,
            guaranteeCost: 0,
            total: 309.98,
            shippingAddress: .stub
        ),
    ]

    internal static var stub: PastOrder { stubs[0] }
}
