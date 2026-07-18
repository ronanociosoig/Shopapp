import Foundation
import Promotions

public final class StubPromotionsRepository: PromotionsRepositoryProtocol {
    private let promotions: [Promotion]

    public init(promotions: [Promotion] = Promotion.stubs) {
        self.promotions = promotions
    }

    public func fetchPromotions() async throws -> [Promotion] { promotions }
}
