import Observation
import SwiftUINavigation

@Observable
public final class PromotionsModel {
    public var promotions: [Promotion] = []
    public var isLoading               = false
    public var destination: Destination?

    private let repository: PromotionsRepositoryProtocol

    public init(repository: PromotionsRepositoryProtocol) {
        self.repository = repository
    }

    @CasePathable
    public enum Destination: Equatable {
        case promotionDetail(Promotion)
    }

    public func select(_ promotion: Promotion) {
        destination = .promotionDetail(promotion)
    }

    @MainActor
    public func load() async {
        isLoading = true
        defer { isLoading = false }
        promotions = (try? await repository.fetchPromotions()) ?? []
    }
}
