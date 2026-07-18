import Testing
import Foundation
@testable import Promotions
import PromotionsTesting

// MARK: - Helpers

private final class FailingPromotionsRepository: PromotionsRepositoryProtocol {
    func fetchPromotions() async throws -> [Promotion] { throw URLError(.notConnectedToInternet) }
}

// MARK: - Unit Tests

@Suite("PromotionsModel — Unit Tests")
struct PromotionsModelTests {

    // MARK: - Initial state

    @Test("Initial promotions array is empty")
    func initialPromotionsEmpty() {
        #expect(PromotionsModel().promotions.isEmpty)
    }

    @Test("Initial isLoading is false")
    func initialIsLoadingFalse() {
        #expect(PromotionsModel().isLoading == false)
    }

    @Test("Initial destination is nil")
    func initialDestinationNil() {
        #expect(PromotionsModel().destination == nil)
    }

    // MARK: - load()

    @Test("load populates promotions on success")
    @MainActor
    func loadPopulatesPromotions() async {
        let model = PromotionsModel()
        await model.load()
        #expect(!model.promotions.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test("load results in empty array on failure (silent fail)")
    @MainActor
    func loadSilentlyFailsOnError() async {
        let model = PromotionsModel(repository: FailingPromotionsRepository())
        await model.load()
        #expect(model.promotions.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test("isLoading is false after load completes")
    @MainActor
    func isLoadingFalseAfterLoad() async {
        let model = PromotionsModel()
        await model.load()
        #expect(model.isLoading == false)
    }

    // MARK: - select()

    @Test("select sets destination to promotionDetail")
    func selectSetsDestination() {
        let model = PromotionsModel()
        let promo = Promotion.stubs[0]
        model.select(promo)
        #expect(model.destination == .promotionDetail(promo))
    }

    @Test("Selecting a different promotion updates destination")
    func selectingDifferentPromotionUpdatesDestination() {
        let model = PromotionsModel()
        model.select(Promotion.stubs[0])
        model.select(Promotion.stubs[1])
        #expect(model.destination == .promotionDetail(Promotion.stubs[1]))
    }
}
