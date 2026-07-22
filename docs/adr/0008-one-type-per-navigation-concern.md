# ADR-0008: One navigation type per concern, not one per model

**Date:** 2026-07-18  
**Status:** Accepted

## Context

The enumeration-based navigation pattern (ADR-0007) establishes that a model's active destination is an optional enum. A question arises when a model drives two structurally different kinds of navigation simultaneously: for example, a multi-step funnel where the user progresses forward through sequential screens (push navigation) and also has modal surfaces (processing overlay, error sheet) that appear outside the funnel stack.

A single `Destination` enum could accommodate both:

```swift
enum Destination {
    case address
    case orderOptions(ShippingAddress)
    case paymentMethod(ShippingAddress)
    case paymentEntry(ShippingAddress)
    case processing          // modal
    case confirmation(PlacedOrder)  // modal
    case paymentFailed(PaymentError)  // modal
}
```

But this merges two unrelated concerns. Push destinations are sequential and back-navigable; modal destinations float above the stack and are not part of the back-navigation history. Mixing them in one enum makes it harder to reason about either.

## Decision

`CheckoutModel` carries two navigation properties, each typed for its own concern:

```swift
var path: [CheckoutStep]    // sequential, back-navigable funnel
var destination: Destination?  // modal surfaces outside the funnel
```

`CheckoutStep` is an enum of the ordered funnel screens:

```swift
enum CheckoutStep {
    case address
    case orderOptions(ShippingAddress)
    case paymentMethod(ShippingAddress)
    case paymentEntry(ShippingAddress)
}
```

`CheckoutModel.Destination` covers only the modal surfaces:

```swift
@CasePathable
public enum Destination {
    case processing
    case confirmation(PlacedOrder)
    case paymentFailed(PaymentError)
}
```

`path` is bound to a `NavigationStack(path:)`, giving the user a full back-navigation stack through the funnel. `destination` is bound to `.fullScreenCover` and `.sheet` modifiers, which sit above the stack.

The guiding principle — stated in `CheckoutModel`'s documentation comment — is *one type per navigation concern*, not one type per model. Two properties on one model is the right outcome when the model genuinely owns two independent navigation concerns.

`AppModel` follows the same principle: it carries `selectedTab: Tab` (which tab is active) and `destination: Destination?` (root-level modals such as the Support sheet). These are independent: a modal can float above any tab.

## Consequences

**Positive**

- Each type describes exactly its concern. `[CheckoutStep]` expresses "an ordered sequence of funnel screens"; `Destination?` expresses "at most one modal surface".
- The back-navigation stack is manipulated directly as an array: `model.path = [.address, .orderOptions(address)]` positions the funnel at any screen in tests.
- Snapshot tests can parameterise over `CheckoutStep.allCases` and `CheckoutModel.Destination.allCases` independently, giving full coverage of both concerns with two test loops.
- A modal appearing while the user is mid-funnel does not interfere with `path` state; clearing the modal does not reset the funnel position.

**Negative**

- Two navigation properties on one model may surprise developers who expect a single `destination` property by convention.
- The distinction between push and modal must be communicated to contributors; without it, new screens may be added to the wrong type.
