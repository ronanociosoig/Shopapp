// ADR-0012: models use the Observation framework (@Observable). The legacy
// ObservableObject / @Published pair must not be reintroduced.

import Harmonize
import Testing

@Suite("No legacy observation")
struct NoLegacyObservableObject {
    @Test
    func noClassConformsToObservableObject() {
        Harmonize.productionCode()
            .classes()
            .conforming(to: "ObservableObject")
            .assertEmpty(rule: Self.classRule)
    }

    @Test
    func noPublishedProperties() {
        // includeNested: true, because @Published lives inside class bodies.
        Harmonize.productionCode()
            .variables(includeNested: true)
            .withAttribute(named: "Published")
            .assertEmpty(rule: Self.propertyRule)
    }

    private static let classRule = Rule(
        title: "Classes must not conform to ObservableObject.",
        category: "models",
        rationale: "ObservableObject with @Published is the pre-Observation model pattern. Mixing it with @Observable models splits the update mechanism, and the team has standardised on @Observable (ADR-0012).",
        howToFix: "Replace `ObservableObject` with `@Observable` and `@MainActor` on the class, and remove the `@Published` properties.",
        badExample: """
        final class StoreModel: ObservableObject {
            @Published var loadState: StoreLoadState = .idle
        }
        """,
        goodExample: """
        @MainActor
        @Observable
        final class StoreModel {
            var loadState: StoreLoadState = .idle
        }
        """
    )

    private static let propertyRule = Rule(
        title: "Properties must not use @Published.",
        category: "models",
        rationale: "@Published only works with ObservableObject. In an @Observable model it is either a no-op or a sign that the class was copied from the legacy pattern (ADR-0012).",
        howToFix: "Remove `@Published`. A stored property on an @Observable class is observed automatically.",
        badExample: """
        @Published var selectedCategory: String?
        """,
        goodExample: """
        var selectedCategory: String?
        """
    )
}
