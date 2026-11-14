// ADR-0007: navigation state is a single `Destination?` enum. ADR-0007 requires
// every `Destination` to be @CasePathable so views can bind to its cases.

import Harmonize
import Testing

@Suite("Destination enums")
struct DestinationIsCasePathable {
    @Test
    func destinationEnumsAreCasePathable() {
        // strict: true fails if the selector matches nothing, so a rename
        // cannot make this rule pass silently.
        Harmonize.productionCode()
            .enums(includeNested: true)
            .withName("Destination")
            // DesignSystemApp is a micro-app for the design system, not a feature
            // model, and its Destination is a private view-only enum.
            .withoutLastPathComponent(["DesignSystemApp.swift"])
            .assertTrue(rule: Self.rule, strict: true) {
                $0.hasAttribute(named: "CasePathable")
            }
    }

    private static let rule = Rule(
        title: "Every navigation `Destination` enum must be @CasePathable.",
        category: "navigation",
        rationale: "Views bind to the single `destination` property through case paths. Without @CasePathable, a model cannot drive `navigationDestination(item:)`, `.sheet`, or `.fullScreenCover` from one enum (ADR-0007).",
        howToFix: "Add `@CasePathable` above the enum declaration and import `CasePaths`.",
        badExample: """
        @MainActor
        @Observable
        public final class StoreModel {
            public enum Destination {
                case productDetail(StoreProduct)
            }
        }
        """,
        goodExample: """
        @MainActor
        @Observable
        public final class StoreModel {
            @CasePathable
            public enum Destination {
                case productDetail(StoreProduct)
            }
        }
        """
    )
}
