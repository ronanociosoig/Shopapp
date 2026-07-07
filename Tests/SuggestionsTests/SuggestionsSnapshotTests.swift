#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Suggestions

// MARK: - CaseIterable conformance

extension SuggestionsModel.Destination: CaseIterable {
    public static var allCases: [SuggestionsModel.Destination] {
        [.productDetail(SuggestedProduct.stubs[0])]
    }
}

// MARK: - Snapshot Tests

@Suite("Suggestions — Snapshot Tests")
@MainActor
struct SuggestionsSnapshotTests {

    @Test("Suggestions view renders correctly when loading")
    func loadingState() async throws {
        let model = SuggestionsModel()
        model.isLoading = true
        assertSnapshot(
            of: SuggestionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loading"
        )
    }

    @Test("Suggestions view renders correctly with products")
    func loadedState() async throws {
        let model = SuggestionsModel()
        model.products = SuggestedProduct.stubs
        assertSnapshot(
            of: SuggestionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loaded"
        )
    }

    @Test("Suggestions view renders correctly when empty")
    func emptyState() async throws {
        let model = SuggestionsModel()
        assertSnapshot(
            of: SuggestionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_empty"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: SuggestionsModel.Destination.allCases
    )
    func destination(_ destination: SuggestionsModel.Destination) async throws {
        let model = SuggestionsModel()
        model.products = SuggestedProduct.stubs
        model.destination = destination
        assertSnapshot(
            of: SuggestionsView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ destination: SuggestionsModel.Destination) -> String {
    switch destination {
    case .productDetail: return "destination_product_detail"
    }
}
#endif
