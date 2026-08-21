#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
import NetworkFoundation
import Replay
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

        switch destination {
        case .productDetail:
            assertSnapshot(
                of: StoreView(model: model),
                as: .image(layout: .device(config: .iPhone13Pro)),
                named: snapshotName(destination)
            )
        case .categoryFilter:
            // swift-snapshot-testing's off-screen capture pass doesn't mount
            // .sheet content, so StoreView with this destination active
            // renders as if nothing were presented — a known limitation, not
            // a bug in StoreView. Asserting on StoreView here either fails
            // forever or, worse, lets a first run silently auto-record a
            // baseline that doesn't show the filter at all (confirmed: it
            // captures the product grid underneath). Assert on the sheet's
            // actual content view directly instead — same coverage of what
            // the screen looks like, without depending on sheet presentation
            // working in an off-screen render.
            assertSnapshot(
                of: CategoryFilterView(model: model),
                as: .image(layout: .device(config: .iPhone13Pro)),
                named: snapshotName(destination)
            )
        }
    }

    // MARK: - Composed with Replay

    /// The payoff: navigate (a real `StoreModel`), fetch (a real `StoreRepository`
    /// call, served by a recorded fixture — the same `fetchProducts.har` that
    /// `StoreRepositoryTests` decodes), render (a real `StoreView`), assert
    /// (a real snapshot). All three tiers, offline, in one test.
    ///
    /// `await model.load()` runs to completion before the view is even
    /// constructed — that's the whole fix for the timing problem `.task` would
    /// otherwise introduce here (see the guard added to `StoreView`'s `.task`).
    /// No delay, no polling, no third-party fork of SnapshotTesting required.
    @Test(
        "Root view renders real recorded product data end-to-end",
        .replay("fetchProducts", matching: .default, filters: replayFilters, rootURL: replaysRootURL)
    )
    func rootViewRendersRealRecordedData() async throws {
        let model = StoreModel(repository: StoreRepository(client: DefaultNetworkClient()))
        await model.load()
        assertSnapshot(
            of: StoreView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "loaded_from_replay"
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
