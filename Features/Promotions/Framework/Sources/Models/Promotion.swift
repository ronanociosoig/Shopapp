import Foundation

public struct Promotion: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    let title: String
    let subtitle: String
    let discountPercent: Int
    let expiresAt: Date?

    init(
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
    /// Fixed, not the default random `UUID()` — these ids are cited directly
    /// by `scripts/deep-link-promotion.sh`'s default argument, which needs a
    /// real id that's the same on every run, not one that only exists for
    /// the lifetime of whatever process happened to generate it.
    static let stubs: [Promotion] = [
        Promotion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Weekend Flash Sale",
            subtitle: "Electronics & Accessories",
            discountPercent: 20,
            expiresAt: ISO8601DateFormatter().date(from: "2026-04-28T23:59:59Z")
        ),
        Promotion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "New Member Offer",
            subtitle: "First order discount",
            discountPercent: 15
        ),
    ]
}
