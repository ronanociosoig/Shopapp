import Foundation

// MARK: - ProductColour

/// A named colour option available for a product.
public struct ProductColour: Identifiable, Equatable, Hashable, Sendable, Codable {
    /// 6-digit RGB hex, no leading `#` (e.g. `"2C2C2E"`).
    public let name: String
    public let hex: String
    public var id: String { name }

    public init(name: String, hex: String) {
        self.name = name
        self.hex  = hex
    }
}

// MARK: - StoreProduct

public struct StoreProduct: Identifiable, Equatable, Hashable, Sendable, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let price: Decimal
    public let imageURL: URL?
    public let category: String
    public let isAvailable: Bool
    /// Selectable colour variants. Empty means no colour choice for this product.
    public let availableColours: [ProductColour]
    /// `true` for consumer electronics — enables the 1-year extended guarantee upsell.
    public let supportsExtendedGuarantee: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        price: Decimal,
        imageURL: URL? = nil,
        category: String,
        isAvailable: Bool = true,
        availableColours: [ProductColour] = [],
        supportsExtendedGuarantee: Bool = false
    ) {
        self.id                       = id
        self.name                     = name
        self.description              = description
        self.price                    = price
        self.imageURL                 = imageURL
        self.category                 = category
        self.isAvailable              = isAvailable
        self.availableColours         = availableColours
        self.supportsExtendedGuarantee = supportsExtendedGuarantee
    }
}

// MARK: - Stubs

public extension StoreProduct {

    // UUID helper: "00000000-0000-0000-0001-00000000NNNN"
    // Module prefix 0001 = Store; NNNN = sequential product number.
    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0001-%012X", n))!
    }

    static let stubs: [StoreProduct] = electronics + furniture + garden + kitchen

    static var stub: StoreProduct { stubs[0] }

    // MARK: Electronics (IDs 1–22)

    static let electronics: [StoreProduct] = [
        StoreProduct(id: id(1),  name: "MacBook Pro 16\"",
            description: "Apple M3 Pro chip, 18 GB RAM, up to 22-hour battery. The ultimate professional laptop. Available in Space Black, Silver, and Space Grey.",
            price: 2499.99, category: "Electronics",
            availableColours: [.init(name: "Space Black", hex: "2C2C2E"), .init(name: "Silver", hex: "E8E8ED"), .init(name: "Space Grey", hex: "6E6E73")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(2),  name: "MacBook Air 15\"",
            description: "Thin and light with M2 chip, 15-inch Liquid Retina display, and all-day battery life. Available in Midnight, Starlight, Space Grey, and Silver.",
            price: 1299.99, category: "Electronics",
            availableColours: [.init(name: "Midnight", hex: "1B2638"), .init(name: "Starlight", hex: "F5E6D2"), .init(name: "Space Grey", hex: "6E6E73"), .init(name: "Silver", hex: "E8E8ED")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(3),  name: "Dell XPS 15 Laptop",
            description: "OLED InfinityEdge display, 13th Gen Intel Core i7, and NVIDIA GeForce RTX 4060. Available in Platinum Silver and Frost White.",
            price: 1799.99, category: "Electronics",
            availableColours: [.init(name: "Platinum Silver", hex: "C4C4C4"), .init(name: "Frost White", hex: "F8F8F8")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(4),  name: "HP Spectre x360 14\"",
            description: "2-in-1 convertible laptop with OLED touchscreen, Intel Core Ultra, and 360° hinge. Available in Nightfall Black, Natural Silver, and Warm Gold.",
            price: 1499.99, category: "Electronics",
            availableColours: [.init(name: "Nightfall Black", hex: "1A1A2E"), .init(name: "Natural Silver", hex: "C0C8D0"), .init(name: "Warm Gold", hex: "C8A04A")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(5),  name: "Lenovo ThinkPad X1 Carbon",
            description: "Business ultrabook with 14-inch IPS display, Intel Core i7, and legendary keyboard.",
            price: 1399.99, category: "Electronics", isAvailable: false,
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(6),  name: "LG 27\" 4K Monitor",
            description: "27-inch UHD IPS panel with USB-C connectivity and 99% sRGB colour accuracy.",
            price: 449.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(7),  name: "Dell UltraSharp 32\" Monitor",
            description: "32-inch 4K IPS with ComfortView Plus, USB-C 90W, and fully adjustable stand.",
            price: 699.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(8),  name: "Samsung 34\" Curved Monitor",
            description: "Ultrawide WQHD curved display, AMD FreeSync, 100 Hz refresh, and 1800R curvature.",
            price: 599.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(9),  name: "BenQ 24\" IPS Monitor",
            description: "Full HD IPS panel with Eye-Care technology, dual HDMI, and built-in speakers.",
            price: 329.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(10), name: "AOC 27\" QHD Monitor",
            description: "2560×1440 IPS display with 75 Hz refresh rate, slim bezels, and VESA mount.",
            price: 249.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(11), name: "Sony WH-1000XM5 Headphones",
            description: "Industry-leading ANC headphones with 30-hour battery and multipoint pairing. Available in Black, Silver, and Midnight Blue.",
            price: 349.99, category: "Electronics",
            availableColours: [.init(name: "Black", hex: "191919"), .init(name: "Silver", hex: "E8E8E8"), .init(name: "Midnight Blue", hex: "1B3A5C")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(12), name: "Apple AirPods Pro",
            description: "Active noise cancellation earbuds with Adaptive Audio and MagSafe charging case.",
            price: 249.99, category: "Electronics",
            availableColours: [.init(name: "White", hex: "FAFAFA")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(13), name: "Bose QuietComfort 45",
            description: "Wireless noise-cancelling headphones with 24-hour battery and comfortable fit. Available in White Smoke and Black.",
            price: 279.99, category: "Electronics",
            availableColours: [.init(name: "White Smoke", hex: "F5F5F5"), .init(name: "Black", hex: "202020")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(14), name: "Sennheiser HD 660S2",
            description: "Open-back audiophile headphones with natural, detailed sound and low impedance.",
            price: 499.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(15), name: "Jabra Evolve2 85",
            description: "Professional wireless headset with ANC, 37-hour battery, and superior call quality. Available in Black and Beige.",
            price: 379.99, category: "Electronics",
            availableColours: [.init(name: "Black", hex: "202020"), .init(name: "Beige", hex: "E8D5B7")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(16), name: "Sonos Era 300 Speaker",
            description: "Spatial audio speaker with Dolby Atmos, Trueplay tuning, and multi-room audio. Available in Black and White.",
            price: 449.99, category: "Electronics",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(17), name: "Bose SoundLink Max",
            description: "Premium portable Bluetooth speaker with IP67 waterproofing and 20-hour battery. Available in Black and Blue.",
            price: 329.99, category: "Electronics",
            availableColours: [.init(name: "Black", hex: "202020"), .init(name: "Blue", hex: "1A56DB")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(18), name: "JBL Charge 5 Speaker",
            description: "Portable IP67 speaker with punchy bass, PartyBoost, and built-in power bank. Available in Blue, Black, Red, and Teal.",
            price: 179.99, category: "Electronics",
            availableColours: [.init(name: "Blue", hex: "0047AB"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Red", hex: "CC0000"), .init(name: "Teal", hex: "008080")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(19), name: "Anker USB-C Hub 7-in-1",
            description: "7-in-1 hub with 4K HDMI, 100W Power Delivery, USB-A 3.0 ports, and SD card reader.",
            price: 49.99, category: "Electronics", supportsExtendedGuarantee: true),

        StoreProduct(id: id(20), name: "Logitech MX Keys Keyboard",
            description: "Advanced wireless keyboard with backlit keys, USB-C charging, and multi-device pairing. Available in Space Grey and Graphite.",
            price: 119.99, category: "Electronics",
            availableColours: [.init(name: "Space Grey", hex: "4A4A52"), .init(name: "Graphite", hex: "3D3D3D")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(21), name: "Logitech MX Master 3S Mouse",
            description: "Ergonomic wireless mouse with 8K DPI, MagSpeed scroll wheel, and whisper-quiet clicks. Available in Space Grey and Graphite.",
            price: 99.99, category: "Electronics",
            availableColours: [.init(name: "Space Grey", hex: "4A4A52"), .init(name: "Graphite", hex: "3D3D3D")],
            supportsExtendedGuarantee: true),

        StoreProduct(id: id(22), name: "Elgato 4K Webcam",
            description: "4K Pro webcam with Sony sensor, wide-angle lens, and superior low-light performance.",
            price: 149.99, category: "Electronics", supportsExtendedGuarantee: true),
    ]

    // MARK: Furniture (IDs 23–44)

    static let furniture: [StoreProduct] = [
        StoreProduct(id: id(23), name: "Ergonomic Office Chair",
            description: "Adjustable lumbar support, breathable mesh back, and 4D armrests for all-day comfort. Available in Black, Grey, and Blue.",
            price: 299.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Grey", hex: "6B7280"), .init(name: "Blue", hex: "1A56DB")]),

        StoreProduct(id: id(24), name: "Mesh Task Chair",
            description: "Lightweight task chair with contoured mesh back, seat depth adjustment, and tilt lock. Available in Black and Grey.",
            price: 219.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Grey", hex: "9CA3AF")]),

        StoreProduct(id: id(25), name: "Executive Leather Chair",
            description: "High-back leather chair with padded armrests, lumbar support, and smooth recline. Available in Black and Brown.",
            price: 449.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Brown", hex: "92400E")]),

        StoreProduct(id: id(26), name: "Height-Adjustable Desk 140cm",
            description: "Electric sit-stand desk with memory presets, anti-collision sensor, and cable tray. Available in White, Black, and Natural Oak.",
            price: 399.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Natural Oak", hex: "C19A6B")]),

        StoreProduct(id: id(27), name: "Standing Desk 160cm",
            description: "Spacious dual-motor standing desk, 80 kg capacity, programmable heights, 160×80 cm. Available in White and Black.",
            price: 499.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A")]),

        StoreProduct(id: id(28), name: "L-Shaped Corner Desk",
            description: "Large L-shaped workstation with cable grommet, reversible layout, and scratch-resistant top. Available in White, Black, and Walnut.",
            price: 579.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Walnut", hex: "773B1A")]),

        StoreProduct(id: id(29), name: "Compact Writing Desk",
            description: "Minimalist writing desk with cable slot, solid wood legs, and a Scandi-inspired design. Available in White and Oak.",
            price: 179.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Oak", hex: "C19A6B")]),

        StoreProduct(id: id(30), name: "Lounge Chair with Ottoman",
            description: "Mid-century leather lounge chair with matching footstool, foam cushioning, and swivel base. Available in Tan, Walnut, and White.",
            price: 599.99, category: "Furniture",
            availableColours: [.init(name: "Tan", hex: "C19A6B"), .init(name: "Walnut", hex: "4A2B0F"), .init(name: "White", hex: "F5F5F5")]),

        StoreProduct(id: id(31), name: "Mid-Century Accent Chair",
            description: "Solid walnut legs, foam cushioning, and bouclé fabric upholstery in a timeless silhouette. Available in Natural, Charcoal, and Terracotta.",
            price: 349.99, category: "Furniture",
            availableColours: [.init(name: "Natural", hex: "E8D5B7"), .init(name: "Charcoal", hex: "374151"), .init(name: "Terracotta", hex: "C2714B")]),

        StoreProduct(id: id(32), name: "Reading Chair with Footrest",
            description: "Reclining reading chair with adjustable footrest, swivel base, and plush microfibre fabric. Available in Navy, Grey, and Rust.",
            price: 429.99, category: "Furniture",
            availableColours: [.init(name: "Navy", hex: "1E3A5F"), .init(name: "Grey", hex: "6B7280"), .init(name: "Rust", hex: "B44C1A")]),

        StoreProduct(id: id(33), name: "2-Seater Sofa",
            description: "Contemporary sofa with deep-seated comfort, removable washable covers, and solid oak feet. Available in Charcoal, Sand, and Sage.",
            price: 849.99, category: "Furniture",
            availableColours: [.init(name: "Charcoal", hex: "374151"), .init(name: "Sand", hex: "D2B48C"), .init(name: "Sage", hex: "6B8E6B")]),

        StoreProduct(id: id(34), name: "3-Seater Sofa",
            description: "Generously proportioned with pocket springs, high-density foam, and linen upholstery. Available in Charcoal, Sand, Navy, and Sage.",
            price: 1099.99, category: "Furniture",
            availableColours: [.init(name: "Charcoal", hex: "374151"), .init(name: "Sand", hex: "D2B48C"), .init(name: "Navy", hex: "1E3A5F"), .init(name: "Sage", hex: "6B8E6B")]),

        StoreProduct(id: id(35), name: "L-Shaped Corner Sofa",
            description: "Modular corner sofa with chaise longue, premium stain-resistant fabric, and USB ports. Available in Charcoal and Navy.",
            price: 1399.99, category: "Furniture",
            availableColours: [.init(name: "Charcoal", hex: "374151"), .init(name: "Navy", hex: "1E3A5F")]),

        StoreProduct(id: id(36), name: "3-Shelf Bookcase",
            description: "Simple solid pine bookcase with adjustable shelf heights and a natural lacquered finish. Available in White, Black, and Oak.",
            price: 139.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Oak", hex: "C19A6B")]),

        StoreProduct(id: id(37), name: "5-Shelf Bookcase",
            description: "Tall industrial bookcase with black metal frame, solid wood shelves, and wall-anchor kit. Available in Black, White, and Oak.",
            price: 219.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5"), .init(name: "Oak", hex: "C19A6B")]),

        StoreProduct(id: id(38), name: "Storage Cabinet with Doors",
            description: "Two-door storage cabinet with adjustable internal shelf and magnetic push-to-open doors. Available in White, Black, and Oak.",
            price: 279.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Oak", hex: "C19A6B")]),

        StoreProduct(id: id(39), name: "Storage Box Set (4-pack)",
            description: "Set of 4 collapsible fabric boxes in graduated sizes with reinforced handles and lids.",
            price: 34.99, category: "Furniture", isAvailable: false),

        StoreProduct(id: id(40), name: "Anti-fatigue Standing Mat",
            description: "Ergonomic mat with bevelled edges, ribbed surface, and foam core for standing desks. Available in Black and Grey.",
            price: 39.99, category: "Furniture",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Grey", hex: "6B7280")]),

        StoreProduct(id: id(41), name: "Office Chair Mat",
            description: "Transparent PVC floor protector for hard floors, 120×90 cm, with non-slip backing.",
            price: 54.99, category: "Furniture"),

        StoreProduct(id: id(42), name: "LED Desk Lamp",
            description: "Adjustable LED lamp with 5 colour temperatures, touch dimmer, and USB-A charging port. Available in White, Black, and Silver.",
            price: 69.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Silver", hex: "C0C0C0")]),

        StoreProduct(id: id(43), name: "Arc Floor Lamp",
            description: "Modern arc floor lamp with linen shade, weighted marble base, and inline dimmer switch. Available in White, Black, and Brass.",
            price: 99.99, category: "Furniture",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Brass", hex: "B08B3A")]),

        StoreProduct(id: id(44), name: "Monitor Riser Stand",
            description: "Bamboo monitor riser with two USB-A ports, storage drawer, and non-slip rubber pads. Available in Natural Bamboo, Black, and White.",
            price: 39.99, category: "Furniture",
            availableColours: [.init(name: "Natural Bamboo", hex: "C8A26A"), .init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5")]),
    ]

    // MARK: Garden (IDs 45–66)

    static let garden: [StoreProduct] = [
        StoreProduct(id: id(45), name: "Acacia Garden Dining Table",
            description: "FSC-certified acacia wood table for 6, with natural grain and weather-resistant oil finish.",
            price: 379.99, category: "Garden"),

        StoreProduct(id: id(46), name: "Rattan Garden Coffee Table",
            description: "All-weather synthetic rattan coffee table with tempered glass top and powder-coated frame.",
            price: 199.99, category: "Garden"),

        StoreProduct(id: id(47), name: "Folding Garden Chair",
            description: "Lightweight aluminium folding chair with textilene mesh seat, stackable and UV-resistant. Available in Anthracite, White, and Green.",
            price: 44.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "White", hex: "F5F5F5"), .init(name: "Green", hex: "2D5A27")]),

        StoreProduct(id: id(48), name: "Stacking Rattan Armchair",
            description: "Comfortable outdoor armchair with synthetic rattan weave, cushion included, stackable. Available in Natural and Mocha.",
            price: 89.99, category: "Garden",
            availableColours: [.init(name: "Natural", hex: "C8A26A"), .init(name: "Mocha", hex: "6B4423")]),

        StoreProduct(id: id(49), name: "Garden Lounge Chair",
            description: "Deep-seat outdoor chair with aluminium frame, thick UV-resistant cushion, and cup holder. Available in Anthracite and Taupe.",
            price: 179.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Taupe", hex: "8B7355")]),

        StoreProduct(id: id(50), name: "Reclining Sun Lounger",
            description: "Adjustable 7-position sun lounger with padded mattress, side table, and rolling wheels. Available in Grey and Anthracite.",
            price: 249.99, category: "Garden",
            availableColours: [.init(name: "Grey", hex: "6B7280"), .init(name: "Anthracite", hex: "3D3D3D")]),

        StoreProduct(id: id(51), name: "2-Seater Garden Bench",
            description: "Solid teak garden bench with slatted seat, weather-resistant oil finish, and classic lines.",
            price: 159.99, category: "Garden"),

        StoreProduct(id: id(52), name: "3-Seater Garden Bench",
            description: "Generous 3-person bench in powder-coated steel with hardwood slatted seat and back. Available in Anthracite and Forest Green.",
            price: 219.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Forest Green", hex: "2D5016")]),

        StoreProduct(id: id(53), name: "Rattan Bistro Set",
            description: "3-piece bistro set — round table and 2 armchairs in all-weather rattan, cushions included. Available in Natural and Coffee.",
            price: 199.99, category: "Garden",
            availableColours: [.init(name: "Natural", hex: "C8A26A"), .init(name: "Coffee", hex: "6B4423")]),

        StoreProduct(id: id(54), name: "6-Piece Garden Dining Set",
            description: "Extendable table and 6 stacking chairs in powder-coated aluminium, seats up to 8. Available in Anthracite and White.",
            price: 749.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "White", hex: "F5F5F5")]),

        StoreProduct(id: id(55), name: "Outdoor Corner Sofa Set",
            description: "Modular 5-seater corner sofa with coffee table and all-weather cushions included. Available in Anthracite and Sandstone.",
            price: 1249.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Sandstone", hex: "D2B48C")]),

        StoreProduct(id: id(56), name: "Hammock with Steel Stand",
            description: "Brazilian-style cotton rope hammock with powder-coated steel stand, 150 kg capacity.",
            price: 259.99, category: "Garden"),

        StoreProduct(id: id(57), name: "Garden Parasol 2.5m",
            description: "Crank-operated parasol with tilt function, 8-rib frame, and UV50+ protective canopy. Available in Blue, Beige, Green, and Grey.",
            price: 129.99, category: "Garden",
            availableColours: [.init(name: "Blue", hex: "1A56DB"), .init(name: "Beige", hex: "D2B48C"), .init(name: "Green", hex: "2D5A27"), .init(name: "Grey", hex: "6B7280")]),

        StoreProduct(id: id(58), name: "Cantilever Parasol 3m",
            description: "3 m cantilever parasol with 360° rotation, cross base, and easy winding handle. Available in Taupe, Cream, Anthracite, and Blue.",
            price: 229.99, category: "Garden",
            availableColours: [.init(name: "Taupe", hex: "8B7355"), .init(name: "Cream", hex: "FFFDD0"), .init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Blue", hex: "1A56DB")]),

        StoreProduct(id: id(59), name: "Large Planter Box",
            description: "Tall rectangular planter in powder-coated galvanised steel with drainage holes and liner. Available in Anthracite, Terracotta, and Sage.",
            price: 74.99, category: "Garden",
            availableColours: [.init(name: "Anthracite", hex: "3D3D3D"), .init(name: "Terracotta", hex: "C2714B"), .init(name: "Sage", hex: "6B8E6B")]),

        StoreProduct(id: id(60), name: "Raised Garden Bed 120cm",
            description: "120 cm raised planting bed in FSC-certified pre-treated pine with corner posts.",
            price: 94.99, category: "Garden"),

        StoreProduct(id: id(61), name: "Outdoor Storage Box 300L",
            description: "300-litre weather-proof storage box in UV-resistant resin, doubles as seating. Available in Beige and Grey.",
            price: 139.99, category: "Garden",
            availableColours: [.init(name: "Beige", hex: "D2B48C"), .init(name: "Grey", hex: "6B7280")]),

        StoreProduct(id: id(62), name: "Outdoor Rug 200×300cm",
            description: "Flatweave polypropylene rug in a geometric pattern, suitable outdoors and indoors. Available in Terracotta, Blue, Sand, and Sage.",
            price: 84.99, category: "Garden",
            availableColours: [.init(name: "Terracotta", hex: "C2714B"), .init(name: "Blue", hex: "1A56DB"), .init(name: "Sand", hex: "D2B48C"), .init(name: "Sage", hex: "6B8E6B")]),

        StoreProduct(id: id(63), name: "Solar Path Lights (set of 8)",
            description: "Set of 8 stainless steel solar lights with warm white LEDs and automatic dusk-to-dawn.",
            price: 44.99, category: "Garden"),

        StoreProduct(id: id(64), name: "Garden String Lights 10m",
            description: "10-metre outdoor string lights with warm white filament bulbs and waterproof connectors.",
            price: 29.99, category: "Garden"),

        StoreProduct(id: id(65), name: "Bird Bath Pedestal",
            description: "Cast stone bird bath with deep basin, antique mossy finish, and stable pedestal base.",
            price: 64.99, category: "Garden"),

        StoreProduct(id: id(66), name: "Patio Gas Heater",
            description: "Freestanding stainless steel heater, 12 kW output, auto ignition, and safety tip-over switch.",
            price: 319.99, category: "Garden", isAvailable: false),
    ]

    // MARK: Kitchen (IDs 67–88)

    static let kitchen: [StoreProduct] = [
        StoreProduct(id: id(67), name: "Solid Oak Dining Table",
            description: "4-seater solid oak table with tapered legs, natural grain, and protective oil finish.",
            price: 699.99, category: "Kitchen"),

        StoreProduct(id: id(68), name: "Extending Dining Table",
            description: "Butterfly-leaf table seating 6–10, lacquered MDF with solid oak veneer and chrome feet.",
            price: 849.99, category: "Kitchen"),

        StoreProduct(id: id(69), name: "Round Pedestal Table",
            description: "Marble-effect round table on a chrome pedestal, seats 4, scratch-resistant surface.",
            price: 479.99, category: "Kitchen"),

        StoreProduct(id: id(70), name: "Marble-top Dining Table",
            description: "6-seater table with genuine Carrara marble top, solid brass hairpin legs, and felt feet.",
            price: 1099.99, category: "Kitchen"),

        StoreProduct(id: id(71), name: "Industrial Dining Table",
            description: "Reclaimed pine top on a black powder-coated metal frame, seats 6, 180×90 cm.",
            price: 579.99, category: "Kitchen"),

        StoreProduct(id: id(72), name: "Dining Chair Oak (set of 2)",
            description: "Set of 2 solid oak dining chairs with woven rush seat and traditional ladder-back design. Available in Natural Oak, Black, and White.",
            price: 159.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Oak", hex: "C19A6B"), .init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5")]),

        StoreProduct(id: id(73), name: "Padded Dining Chair (set of 4)",
            description: "Set of 4 upholstered chairs with foam-padded seat, linen fabric, and solid beech legs. Available in Natural Linen, Charcoal, Navy, and Blush.",
            price: 319.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Linen", hex: "F5F0E8"), .init(name: "Charcoal", hex: "374151"), .init(name: "Navy", hex: "1E3A5F"), .init(name: "Blush", hex: "C4A4A4")]),

        StoreProduct(id: id(74), name: "Faux Leather Dining Chair (set of 2)",
            description: "Set of 2 button-tufted faux leather chairs with brushed gold legs and easy-clean seat. Available in White, Black, and Mink.",
            price: 229.99, category: "Kitchen",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Mink", hex: "B8A090")]),

        StoreProduct(id: id(75), name: "Stackable Dining Chair (set of 4)",
            description: "Set of 4 polypropylene shell chairs in a sleek modern form, stackable up to 8 high. Available in White, Black, Sage, and Terracotta.",
            price: 199.99, category: "Kitchen",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Sage", hex: "6B8E6B"), .init(name: "Terracotta", hex: "C2714B")]),

        StoreProduct(id: id(76), name: "Upholstered Dining Bench",
            description: "140 cm bench with foam cushion, linen cover, and solid beech legs, seats 2–3 people. Available in Natural Linen, Charcoal, and Navy.",
            price: 139.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Linen", hex: "F5F0E8"), .init(name: "Charcoal", hex: "374151"), .init(name: "Navy", hex: "1E3A5F")]),

        StoreProduct(id: id(77), name: "Adjustable Bar Stool (set of 2)",
            description: "Set of 2 gas-lift counter stools with padded seat, chrome footrest, and swivel function. Available in Black, White, and Grey.",
            price: 169.99, category: "Kitchen",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5"), .init(name: "Grey", hex: "6B7280")]),

        StoreProduct(id: id(78), name: "Fixed-Height Bar Stool (set of 4)",
            description: "Set of 4 solid wood breakfast bar stools with foot rail and a natural wax finish. Available in Natural Oak and Black.",
            price: 259.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Oak", hex: "C19A6B"), .init(name: "Black", hex: "1A1A1A")]),

        StoreProduct(id: id(79), name: "Kitchen Island on Wheels",
            description: "Rolling island with butcher-block top, 2 drawers, open shelves, and locking casters. Available in White, Black, and Natural Oak.",
            price: 329.99, category: "Kitchen",
            availableColours: [.init(name: "White", hex: "F5F5F5"), .init(name: "Black", hex: "1A1A1A"), .init(name: "Natural Oak", hex: "C19A6B")]),

        StoreProduct(id: id(80), name: "High Bar Table",
            description: "Poseur-height table with solid oak top and black metal hairpin legs, seats 4 bar stools.",
            price: 219.99, category: "Kitchen"),

        StoreProduct(id: id(81), name: "Corner Bench Dining Set",
            description: "L-shaped corner bench plus dining table, seats up to 6, with under-seat storage drawers.",
            price: 549.99, category: "Kitchen"),

        StoreProduct(id: id(82), name: "Sideboard Buffet Cabinet",
            description: "4-door sideboard in solid oak veneer with soft-close doors and adjustable inner shelves. Available in Natural Oak, Black, and White.",
            price: 479.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Oak", hex: "C19A6B"), .init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5")]),

        StoreProduct(id: id(83), name: "Display Hutch Cabinet",
            description: "Glazed display top with solid wood base, adjustable shelves, and interior LED strip light. Available in Natural Oak and Black.",
            price: 369.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Oak", hex: "C19A6B"), .init(name: "Black", hex: "1A1A1A")]),

        StoreProduct(id: id(84), name: "Wine Rack 12-bottle",
            description: "Freestanding 12-bottle wine rack in solid pine with a minimalist slatted design. Available in Natural Pine and Black.",
            price: 64.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Pine", hex: "C8A878"), .init(name: "Black", hex: "1A1A1A")]),

        StoreProduct(id: id(85), name: "Kitchen Trolley on Wheels",
            description: "Bamboo kitchen trolley with 2 shelves, towel rail, and locking wheels, 60×40 cm. Available in Natural Bamboo and White.",
            price: 129.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Bamboo", hex: "C8A26A"), .init(name: "White", hex: "F5F5F5")]),

        StoreProduct(id: id(86), name: "Wall-Mounted Pot Rack",
            description: "Stainless steel pot rack with 10 S-hooks and a 60 cm hanging rail for kitchen walls.",
            price: 54.99, category: "Kitchen"),

        StoreProduct(id: id(87), name: "Bar Cabinet with Glass Doors",
            description: "Mid-century bar cabinet with smoked glass doors, interior lighting, and bottle storage. Available in Black and Walnut.",
            price: 399.99, category: "Kitchen",
            availableColours: [.init(name: "Black", hex: "1A1A1A"), .init(name: "Walnut", hex: "773B1A")]),

        StoreProduct(id: id(88), name: "Extendable Bench Seat",
            description: "Solid pine bench that extends from 140 to 180 cm, seats 3–4, with protective wax finish. Available in Natural Pine, Black, and White.",
            price: 109.99, category: "Kitchen",
            availableColours: [.init(name: "Natural Pine", hex: "C8A878"), .init(name: "Black", hex: "1A1A1A"), .init(name: "White", hex: "F5F5F5")]),
    ]
}
