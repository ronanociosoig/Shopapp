import Observation
import SwiftUINavigation

@Observable
public final class PromotionsModel {
    var promotions: [Promotion] = []
    var isLoading               = false
    var destination: Destination?

    private let repository: PromotionsRepositoryProtocol

    public init(repository: PromotionsRepositoryProtocol, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    @CasePathable
    public enum Destination: Equatable {
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
