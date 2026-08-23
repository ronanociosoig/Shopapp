import Foundation
import CheckoutAPI

// Canned sample data for CheckoutAPI's plain types — used by CheckoutTests,
// CheckoutApp's scenario builder, and PromotionsApp's host screens. This is
// testing/demo fixture data, not part of the contract, so it lives here
// rather than in CheckoutAPI itself: a consumer that only needs
// CheckoutRepository/SelectedAddressStore and the data types they require
// has no reason to also carry sample products and addresses.

extension CheckoutProduct {

    // UUID helper: "00000000-0000-0000-0004-00000000NNNN"
    // Module prefix 0004 = Checkout; NNNN = sequential product number.
    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0004-%012X", n))!
    }

    /// A curated cross-category set used to seed the cart in tests and previews.
    /// Electronics items have `supportsExtendedGuarantee: true`.
    public static let stubs: [CheckoutProduct] = [
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

    public static var stub: CheckoutProduct { stubs[0] }
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

extension PlacedOrder {
    public static let stub = PlacedOrder(
        id: UUID(uuidString: "00000000-0000-0000-0007-000000000001")!,
        items: [OrderLineItem(product: .stub, quantity: 1)],
        shippingAddress: .stub,
        deliveryOption: .standard,
        total: 299.99,
        estimatedDelivery: Date(timeIntervalSinceNow: 5 * 24 * 3600)
    )
}
