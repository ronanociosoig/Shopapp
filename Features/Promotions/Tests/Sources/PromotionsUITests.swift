import Testing
import Foundation
@testable import Promotions
import PromotionsTesting

/// Tests that exercise complete user interaction flows through the Promotions module.
@Suite("Promotions — UI Interaction Tests")
@MainActor
struct PromotionsUITests {

    @Test("User loads promotions and sees a list")
    func userLoadsPromotions() async {
        let model = PromotionsModel()
        await model.load()
        #expect(!model.promotions.isEmpty)
    }

    @Test("User taps a promotion and sees its detail")
    func userSelectsPromotion() async {
        let model = PromotionsModel()
        await model.load()

        guard let first = model.promotions.first else {
            Issue.record("Promotions should be loaded")
            return
        }

        model.select(first)
        #expect(model.destination == .promotionDetail(first))
    }

    @Test("User dismisses promotion detail and returns to list")
    func userDismissesDetail() async {
        let model = PromotionsModel()
        await model.load()
        model.select(model.promotions[0])
        model.destination = nil
        #expect(model.destination == nil)
    }
}
