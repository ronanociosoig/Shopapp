import Foundation

public struct Promotion: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    public let discountPercent: Int
    public let expiresAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        discountPercent: Int,
        expiresAt: Date? = nil
    ) {
        self.id              = id
        self.title           = title
        self.subtitle        = subtitle
        self.discountPercent = discountPercent
        self.expiresAt       = expiresAt
    }
}

public extension Promotion {
    static let stubs: [Promotion] = [
        Promotion(
            title: "Weekend Flash Sale",
            subtitle: "Electronics & Accessories",
            discountPercent: 20,
            expiresAt: ISO8601DateFormatter().date(from: "2026-04-28T23:59:59Z")
        ),
        Promotion(
            title: "New Member Offer",
            subtitle: "First order discount",
            discountPercent: 15
        ),
    ]
}
