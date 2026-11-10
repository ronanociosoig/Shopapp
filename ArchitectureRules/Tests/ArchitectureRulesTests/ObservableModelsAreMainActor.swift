// ADR-0012: every feature model is both @Observable and @MainActor, so UI state
// is only mutated on the main actor.

import Harmonize
import Testing

@Suite("Observable models")
struct ObservableModelsAreMainActor {
    @Test
    func observableClassesAreMainActor() {
        // strict: true fails if no @Observable class is found at all.
        Harmonize.productionCode()
            .classes()
            .withAttribute(named: "Observable")
            .assertTrue(rule: Self.rule, strict: true) {
                $0.hasAttribute(named: "MainActor")
            }
    }

    private static let rule = Rule(
        title: "Every @Observable class must also be @MainActor.",
        category: "models",
        rationale: "Feature models own UI state that SwiftUI reads on the main actor. Without @MainActor, mutations can race with view updates and the compiler cannot prove isolation (ADR-0012).",
        howToFix: "Add `@MainActor` above `@Observable` on the class declaration.",
        badExample: """
        @Observable
        public final class StoreModel {
            var loadState: StoreLoadState = .idle
        }
        """,
        goodExample: """
        @MainActor
        @Observable
        public final class StoreModel {
            var loadState: StoreLoadState = .idle
        }
        """
    )
}
