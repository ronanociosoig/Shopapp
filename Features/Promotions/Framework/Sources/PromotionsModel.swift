import Observation
import SwiftUINavigation

@MainActor
@Observable
public final class PromotionsModel {
    var promotions: [Promotion] = []
    var isLoading               = false
    var destination: Destination?

    /// Lets a caller (in practice, a snapshot test) opt a model out of
    /// PromotionsView's/PromotionBannerView's auto-load entirely — "not
    /// loaded yet" and "loaded, genuinely no promotions" both look like an
    /// empty array from the outside, so a guard keyed on that state alone
    /// can't tell them apart.
    var suppressAutoLoad = false

    private let repository: PromotionsRepository

    public init(repository: PromotionsRepository, destination: Destination? = nil) {
        self.repository = repository
        self.destination = destination
    }

    @CasePathable
    public enum Destination: Equatable, Sendable {
        case promotionDetail(Promotion)
    }

    func select(_ promotion: Promotion) {
        destination = .promotionDetail(promotion)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        promotions = (try? await repository.fetchPromotions()) ?? []
    }
}
