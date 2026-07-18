#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Store
import StoreTesting

// MARK: - CaseIterable conformances

extension StoreLoadState: CaseIterable {
    public static var allCases: [StoreLoadState] {
        [
            .idle,
            .loading,
            .loaded(StoreProduct.stubs),
            .failed("Something went wrong. Please try again."),
        ]
    }
}

extension StoreModel.Destination: CaseIterable {
    public static var allCases: [StoreModel.Destination] {
        [
            .productDetail(.stub),
            .categoryFilter,
        ]
    }
}

// MARK: - Snapshot Tests

@Suite("Store — Snapshot Tests")
@MainActor
struct StoreSnapshotTests {

    @Test(
        "Root view renders correctly in every load state",
        arguments: StoreLoadState.allCases
    )
    func rootViewState(state: StoreLoadState) async throws {
        let model = StoreModel()
        model.loadState = state
        assertSnapshot(
            of: StoreView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(state)
        )
    }

    @Test("Root view renders correctly with a category filter applied")
    func loadedWithCategorySelected() async throws {
        let model = StoreModel()
        model.loadState = .loaded(StoreProduct.stubs)
        model.selectedCategory = "Electronics"
        assertSnapshot(
            of: StoreView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loaded_filtered"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: StoreModel.Destination.allCases
    )
    func destination(_ destination: StoreModel.Destination) async throws {
        let model = StoreModel()
        model.loadState = .loaded(StoreProduct.stubs)
        model.destination = destination
        assertSnapshot(
            of: StoreView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ state: StoreLoadState) -> String {
    switch state {
    case .idle:    return "state_idle"
    case .loading: return "state_loading"
    case .loaded:  return "state_loaded"
    case .failed:  return "state_failed"
    }
}

private func snapshotName(_ destination: StoreModel.Destination) -> String {
    switch destination {
    case .productDetail:  return "destination_product_detail"
    case .categoryFilter: return "destination_category_filter"
    }
}
#endif
