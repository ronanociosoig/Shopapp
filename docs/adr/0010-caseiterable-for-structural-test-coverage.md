# ADR-0010: Navigation enums conform to CaseIterable to enforce structural test coverage

**Date:** 2026-07-18  
**Status:** Accepted

## Context

With enumeration-based navigation (ADR-0007), every navigation destination is a case on an enum. Adding a new screen means adding a new case. The risk is that a developer adds the case and wires the UI but forgets to add a snapshot test for the new screen. The gap is not visible until a regression in that screen goes undetected.

The test suite needs a mechanism that makes the omission a compile error, not a silent gap.

## Decision

Navigation enums conform to `CaseIterable` in the test target, not in production code. The conformance is declared in the snapshot test file, and `allCases` returns a representative instance of each case:

```swift
// In CheckoutSnapshotTests.swift (test target only)
extension CheckoutStep: CaseIterable {
    public static var allCases: [CheckoutStep] {
        [
            .address,
            .orderOptions(.stub),
            .paymentMethod(.stub),
            .paymentEntry(.stub),
        ]
    }
}
```

A parameterised test iterates `allCases` and asserts a snapshot for each:

```swift
@Test("Each funnel step renders correctly", arguments: CheckoutStep.allCases)
func step(_ step: CheckoutStep) async throws {
    let model = CheckoutModel(cart: CartItem.stubs)
    model.savedAddresses = ShippingAddress.stubs
    model.path = [step]
    assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)),
                   named: snapshotName(step))
}
```

When a new `CheckoutStep` case is added to the production enum, the `allCases` implementation in the test file no longer compiles: Swift exhaustive switches and explicit array literals both require the new case to be present. The developer must add the case to `allCases` — which forces them to provide a representative instance — and add the corresponding named snapshot.

`CaseIterable` is kept out of production code because: (a) the production enum may have associated values that make a default `allCases` synthesis meaningless, and (b) shipping test infrastructure in the production binary is the problem ADR-0006 was introduced to solve.

## Consequences

**Positive**

- Adding a navigation case without updating the test suite is a compile error, not a silent gap.
- The parameterised test loop replaces N individual test functions with one. New cases require adding one entry to `allCases` and one reference snapshot, not a new test function.
- The `allCases` array doubles as a manifest of every reachable screen in the module, which aids onboarding and documentation.

**Negative**

- `allCases` must be manually maintained. The compiler enforces completeness but cannot synthesise the representative associated values (e.g. `.stub` instances).
- Placing `CaseIterable` conformance in test-only code means it is not available to non-test consumers who might benefit from it (e.g. a settings screen that lists all supported payment methods). In those cases, a separate production conformance is required.
