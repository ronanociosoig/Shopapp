import Observation
import SwiftUINavigation

@Observable
public final class PromotionsModel {
    var promotions: [Promotion] = []
    var isLoading               = false
    var destination: Destination?

    private let repository: PromotionsRepositoryProtocol

    public init(repository: PromotionsRepositoryProtocol) {
        self.repository = repository
    }

    @CasePathable
    enum Destination: Equatable {
        case promotionDetail(Promotion)
    }

    func select(_ promotion: Promotion) {
        destination = .promotionDetail(promotion)
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        promotions = (try? await repository.fetchPromotions()) ?? []
    }
}
