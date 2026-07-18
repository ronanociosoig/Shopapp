import Foundation

// MARK: - User profile

public struct UserProfile: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    let email: String
    let displayName: String
    let avatarURL: URL?

    init(id: UUID = UUID(), email: String, displayName: String, avatarURL: URL? = nil) {
        self.id          = id
        self.email       = email
        self.displayName = displayName
        self.avatarURL   = avatarURL
    }
}

// MARK: - Saved address

public struct SavedAddress: Identifiable, Equatable, Hashable, Sendable, Codable {
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
        country: String = "US",
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

    func settingDefault(_ value: Bool) -> SavedAddress {
        SavedAddress(id: id, fullName: fullName, line1: line1, line2: line2,
                     city: city, state: state, postalCode: postalCode,
                     country: country, isDefault: value)
    }
}

// MARK: - Saved payment card

public struct SavedCard: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    let token: String
    let lastFour: String
    let brand: CardBrand
    let expiryMonth: Int
    let expiryYear: Int
    let isDefault: Bool

    init(
        id: UUID = UUID(),
        token: String,
        lastFour: String,
        brand: CardBrand,
        expiryMonth: Int,
        expiryYear: Int,
        isDefault: Bool = false
    ) {
        self.id          = id
        self.token       = token
        self.lastFour    = lastFour
        self.brand       = brand
        self.expiryMonth = expiryMonth
        self.expiryYear  = expiryYear
        self.isDefault   = isDefault
    }

    var displayLabel: String { "\(brand.rawValue) •••• \(lastFour)" }
}

enum CardBrand: String, Equatable, Sendable, Codable {
    case visa       = "Visa"
    case mastercard = "Mastercard"
    case amex       = "Amex"
    case other      = "Card"
}

// MARK: - Stubs

public extension UserProfile {
    static let stub = UserProfile(
        id: UUID(uuidString: "00000000-0000-0000-BBBB-000000000001")!,
        email: "alex@example.com",
        displayName: "Alex Johnson"
    )
}

public extension SavedAddress {
    static let stub = SavedAddress(
        id: UUID(uuidString: "00000000-0000-0000-BBBB-000000000002")!,
        fullName: "Alex Johnson",
        line1: "123 Main Street",
        line2: "Apt 4B",
        city: "San Francisco",
        state: "CA",
        postalCode: "94105",
        country: "United States",
        isDefault: true
    )

    static let stubs: [SavedAddress] = [
        stub,
        SavedAddress(
            id: UUID(uuidString: "00000000-0000-0000-BBBB-000000000004")!,
            fullName: "Alex Johnson",
            line1: "14 Grafton Street",
            city: "Dublin",
            state: "Dublin 2",
            postalCode: "D02 HH57",
            country: "Ireland"
        ),
        SavedAddress(
            id: UUID(uuidString: "00000000-0000-0000-BBBB-000000000005")!,
            fullName: "Alex Johnson",
            line1: "22 Baker Street",
            line2: "Flat 3",
            city: "London",
            state: "England",
            postalCode: "NW1 6XE",
            country: "United Kingdom"
        ),
    ]
}

public extension SavedCard {
    static let stub = SavedCard(
        id: UUID(uuidString: "00000000-0000-0000-BBBB-000000000003")!,
        token: "tok_stub_visa_4242",
        lastFour: "4242",
        brand: .visa,
        expiryMonth: 12,
        expiryYear: 2028,
        isDefault: true
    )
}
