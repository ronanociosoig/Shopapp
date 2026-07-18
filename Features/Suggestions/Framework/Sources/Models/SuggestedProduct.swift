import Foundation

// MARK: - ProductColour

/// A named colour option available for a product.
struct ProductColour: Identifiable, Equatable, Hashable, Sendable, Codable {
    let name: String
    let hex: String   // 6-digit RGB hex, no leading `#`
    var id: String { name }

    init(name: String, hex: String) {
        self.name = name
        self.hex  = hex
    }
}

// MARK: - SuggestedProduct

public struct SuggestedProduct: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    let name: String
    let description: String
    let price: Decimal
    let category: String
    let availableColours: [ProductColour]
    let supportsExtendedGuarantee: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        price: Decimal,
        category: String,
        availableColours: [ProductColour] = [],
        supportsExtendedGuarantee: Bool = false
    ) {
        self.id                       = id
        self.name                     = name
        self.description              = description
        self.price                    = price
        self.category                 = category
        self.availableColours         = availableColours
        self.supportsExtendedGuarantee = supportsExtendedGuarantee
    }
}

// MARK: - Stubs

public extension SuggestedProduct {

    // UUID helper: "00000000-0000-0000-0008-00000000NNNN"
    // Module prefix 0008 = Suggestions; NNNN = sequential product number.
    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0008-%012X", n))!
    }

    /// A curated cross-category set for the suggestions strip.
    static let stubs: [SuggestedProduct] = [
        // Electronics
        SuggestedProduct(id: id(1),  name: "MacBook Pro 16\"",
            description: "Apple M3 Pro chip, 18 GB RAM, up to 22-hour battery. The ultimate professional laptop. Available in Space Black, Silver, and Space Grey.",
            price: 2499.99, category: "Electronics",
            availableColours: [.init(name: "Space Black", hex: "2C2C2E"), .init(name: "Silver", hex: "E8E8ED"), .init(name: "Space Grey", hex: "6E6E73")],
            supportsExtendedGuarantee: true),

        SuggestedProduct(id: id(2),  name: "Sony WH-1000XM5 Headphones",
            description: "Industry-leading ANC headphones with 30-hour battery and multipoint pairing. Available in Black, Silver, and Midnight Blue.",
            price: 349.99, category: "Electronics",
            availableColours: [.init(name: "Black", hex: "191919"), .init(name: "Silver", hex: "E8E8E8"), .init(name: "Midnight Blue", hex: "1B3A5C")],
            supportsExtendedGuarantee: true),

        SuggestedProduct(id: id(3),  name: "Sonos Era 300 Speaker",
            description: "Spatial audio speaker with Dolby Atmos, Trueplay tuning, and multi-room audio. Available in Black and White.",
            price: 449.99, category: "Electronics",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5")],
            supportsExtendedGuarantee: true),

        SuggestedProduct(id: id(4),  name: "Logitech MX Master 3S Mouse",
            description: "Ergonomic wireless mouse with 8K DPI, MagSpeed scroll wheel, and whisper-quiet clicks. Available in Space Grey and Graphite.",
            price: 99.99, category: "Electronics",
            availableColours: [.init(name: "Space Grey", hex: "4A4A52"), .init(name: "Graphite", hex: "3D3D3D")],
            supportsExtendedGuarantee: true),

        SuggestedProduct(id: id(5),  name: "Dell UltraSharp 32\" Monitor",
            description: "32-inch 4K IPS with ComfortView Plus, USB-C 90W, and fully adjustable stand.",
            price: 699.99, category: "Electronics",
            supportsExtendedGuarantee: true),

        // Furniture
        SuggestedProduct(id: id(6),  name: "Ergonomic Office Chair",
            description: "Adjustable lumbar support, breathable mesh back, and 4D armrests for all-day comfort. Available in Black, Grey, and Blue.",
            price: 299.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Grey", hex: "6B7280"), .init(name: "Blue", hex: "1A56DB")]),

        SuggestedProduct(id: id(7),  name: "Standing Desk 160cm",
            description: "Spacious dual-motor standing desk, 80 kg capacity, programmable heights, 160×80 cm. Available in White and Black.",
            price: 499.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A")]),

        SuggestedProduct(id: id(8),  name: "Lounge Chair with Ottoman",
            description: "Mid-century leather lounge chair with matching footstool and foam cushioning. Available in Tan, Walnut, and White.",
            price: 599.99, category: "Furniture",
            availableColours: [.init(name: "Tan", hex: "C19A6B"), .init(name: "Walnut", hex: "4A2B0F"), .init(name: "White", hex: "F5F5F5")]),

        SuggestedProduct(id: id(9),  name: "Arc Floor Lamp",
            description: "Modern arc floor lamp with linen shade, weighted marble base, and inline dimmer switch. Available in White, Black, and Brass.",
            price: 99.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Brass", hex: "B08B3A")]),

        SuggestedProduct(id: id(10), name: "5-Shelf Bookcase",
            description: "Tall industrial bookcase with black metal frame, solid wood shelves, and wall-anchor kit. Available in Black, White, and Oak.",
            price: 219.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5"), .init(name: "Oak", hex: "C19A6B")]),

        // Garden
        SuggestedProduct(id: id(11), name: "6-Piece Garden Dining Set",
            description: "Extendable table and 6 stacking chairs in powder-coated aluminium, seats up to 8. Available in Anthracite and White.",
            price: 749.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "White", hex: "F5F5F5")]),

        SuggestedProduct(id: id(12), name: "Reclining Sun Lounger",
            description: "Adjustable 7-position sun lounger with padded mattress, side table, and rolling wheels. Available in Grey and Anthracite.",
            price: 249.99, category: "Garden",
            availableColours: [.init(name: "Grey", hex: "6B7280"), .init(name: "Anthracite", hex: "3D3D3D")]),

        SuggestedProduct(id: id(13), name: "Outdoor Corner Sofa Set",
            description: "Modular 5-seater corner sofa with coffee table and all-weather cushions included. Available in Anthracite and Sandstone.",
            price: 1249.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Sandstone", hex: "D2B48C")]),

        SuggestedProduct(id: id(14), name: "Cantilever Parasol 3m",
            description: "3 m cantilever parasol with 360° rotation, cross base, and easy winding handle. Available in Taupe, Cream, Anthracite, and Blue.",
            price: 229.99, category: "Garden",
            availableColours: [.init(name: "Taupe", hex: "8B7355"), .init(name: "Cream", hex: "FFFDD0"), .init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Blue", hex: "1A56DB")]),

        SuggestedProduct(id: id(15), name: "Garden String Lights 10m",
            description: "10-metre outdoor string lights with warm white filament bulbs and waterproof connectors.",
            price: 29.99, category: "Garden"),

        // Kitchen
        SuggestedProduct(id: id(16), name: "Extending Dining Table",
            description: "Butterfly-leaf table seating 6–10, lacquered MDF with solid oak veneer and chrome feet.",
            price: 849.99, category: "Kitchen"),

        SuggestedProduct(id: id(17), name: "Padded Dining Chair (set of 4)",
            description: "Set of 4 upholstered chairs with foam-padded seat, linen fabric, and solid beech legs. Available in Natural Linen, Charcoal, Navy, and Blush.",
            price: 319.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Linen", hex: "F5F0E8"), .init(name: "Charcoal", hex: "374151"), .init(name: "Navy", hex: "1E3A5F"), .init(name: "Blush", hex: "C4A4A4")]),

        SuggestedProduct(id: id(18), name: "Kitchen Island on Wheels",
            description: "Rolling island with butcher-block top, 2 drawers, open shelves, and locking casters. Available in White, Black, and Natural Oak.",
            price: 329.99, category: "Kitchen",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Natural Oak", hex: "C19A6B")]),

        SuggestedProduct(id: id(19), name: "Adjustable Bar Stool (set of 2)",
            description: "Set of 2 gas-lift counter stools with padded seat, chrome footrest, and swivel function. Available in Black, White, and Grey.",
            price: 169.99, category: "Kitchen",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5"), .init(name: "Grey", hex: "6B7280")]),

        SuggestedProduct(id: id(20), name: "Bar Cabinet with Glass Doors",
            description: "Mid-century bar cabinet with smoked glass doors, interior lighting, and bottle storage. Available in Black and Walnut.",
            price: 399.99, category: "Kitchen",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Walnut", hex: "773B1A")]),
    ]
}
