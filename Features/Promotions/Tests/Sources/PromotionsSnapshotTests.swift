#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Promotions
import PromotionsTesting

// MARK: - CaseIterable conformance

extension PromotionsModel.Destination: CaseIterable {
    public static var allCases: [PromotionsModel.Destination] {
        [.promotionDetail(Promotion.stubs[0])]
    }
}

// MARK: - Snapshot Tests

@Suite("Promotions — Snapshot Tests")
@MainActor
struct PromotionsSnapshotTests {

    @Test("Promotions view renders correctly when loading")
    func loadingState() async throws {
        let model = PromotionsModel()
        model.isLoading = true
        assertSnapshot(
            of: PromotionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loading"
        )
    }

    @Test("Promotions view renders correctly with content")
    func loadedState() async throws {
        let model = PromotionsModel()
        model.promotions = Promotion.stubs
        assertSnapshot(
            of: PromotionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loaded"
        )
    }

    @Test("Promotions view renders correctly when empty")
    func emptyState() async throws {
        let model = PromotionsModel()
        assertSnapshot(
            of: PromotionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_empty"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: PromotionsModel.Destination.allCases
    )
    func destination(_ destination: PromotionsModel.Destination) async throws {
        let model = PromotionsModel()
        model.promotions = Promotion.stubs
        model.destination = destination
        assertSnapshot(
            of: PromotionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ destination: PromotionsModel.Destination) -> String {
    switch destination {
    case .promotionDetail: return "destination_promotion_detail"
    }
}
#endif
