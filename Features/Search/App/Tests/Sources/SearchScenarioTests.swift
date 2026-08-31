import Testing
import Foundation
@testable import Search
@testable import SearchApp

/// Regression coverage for the scenario catalog itself — not the funnel's
/// rendering (SearchSnapshotTests already owns that), but whether each named
/// scenario still produces the business state it claims to. Mirrors
/// CheckoutAppTests/CheckoutScenarioTests; see that file's comment for the
/// full rationale (deliberately not a snapshot test — this is a
/// state-correctness question, not a rendering one).
///
/// Parametrized over SearchScenario.allCases with an exhaustive switch, so a
/// new scenario case with no corresponding assertion is a compile error —
/// the same structural-coverage discipline ADR-0010 applies to Destination,
/// one level up the stack.
@Suite("Search Scenarios — business-state coverage")
@MainActor
struct SearchScenarioTests {

    @Test(
        "Each scenario's built model matches what it claims to represent",
        arguments: SearchScenario.allCases
    )
    func scenario(_ scenario: SearchScenario) {
        let model = SearchScenarioFactory().makeModel(for: scenario)

        switch scenario {
        case .launch:
            #expect(model.query.isEmpty)
            #expect(model.searchState == .idle)
            #expect(model.destination == nil)

        case .resultsLoaded:
            #expect(model.query == "MacBook")
            #expect(model.searchState == .results(Array(SearchProduct.stubs.prefix(6))))

        case .noResults:
            #expect(model.query == "xyzzy")
            #expect(model.searchState == .empty)

        case .searchFailed:
            #expect(model.query == "MacBook")
            #expect(model.searchState == .error("The request timed out."))

        case .productDetail:
            #expect(model.destination == .productDetail(.stub))

        case .filtersOpen:
            #expect(model.destination == .filters)
        }
    }
}
