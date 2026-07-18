# ADR-0007: Navigation state is represented by enumerations, not booleans or strings

**Date:** 2026-07-18  
**Status:** Accepted

## Context

SwiftUI's early navigation APIs used boolean bindings (`isPresented: $showingSheet`) and string-tagged `NavigationLink` destinations. Each additional modal or destination screen adds another `@State var isShowingX: Bool`. With multiple screens, these flags can reach illegal combinations: two modals active simultaneously, a screen shown while its prerequisite hasn't completed, or a race where clearing one flag doesn't clear another.

The problem is not SwiftUI's API specifically — it is that booleans have two states (`true`/`false`) but the actual domain has many more, most of which are invalid. Encoding navigation as individual flags makes illegal states representable and, over time, reached.

## Decision

Every model that drives navigation carries a `destination` property typed as an optional enum:

```swift
@CasePathable
public enum Destination {
    case productDetail(StoreProduct)
    case categoryFilter
}

public var destination: Destination?
```

`nil` means no destination is active. A non-nil value means exactly one destination is active, carrying the data that destination requires. It is structurally impossible for two cases to be active simultaneously: the enum can hold only one value.

`@CasePathable` (from the `swift-navigation` package) generates key-path accessors for each case, enabling `$model.destination.productDetail` as a `Binding<StoreProduct?>` directly in `.navigationDestination` and `.sheet` modifiers — no manual binding extraction required.

The same pattern applies at every level of the hierarchy: `StoreModel.Destination`, `CheckoutModel.Destination`, `AppModel.Destination`, and so on.

## Consequences

**Positive**

- Illegal navigation states (two modals active, a destination shown with missing data) are not representable. The compiler enforces the constraint.
- Each case carries exactly the associated value its destination needs. A `productDetail` case carries the `StoreProduct`; there is no separate property to keep in sync.
- Navigation state is serialisable and inspectable. A test can set `model.destination = .productDetail(product)` and snapshot the result without tapping through the UI.
- Deep links map cleanly to enum mutations: a URL handler sets `model.destination` to the appropriate case and the UI responds.
- Adding a screen requires adding a case. The switch exhaustiveness check and snapshot test suite (ADR-0009) both surface the omission at compile time.

**Negative**

- Teams accustomed to boolean flags face a learning curve.
- `@CasePathable` is a dependency on `swift-navigation`. The pattern is expressible without it, but the binding ergonomics are significantly worse.
- For large feature areas with many destinations, the enum can grow. Nested destination types (a destination inside a destination) are sometimes necessary and add indirection.
