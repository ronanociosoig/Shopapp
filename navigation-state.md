# Enumeration-Based Navigation State

## The Problem

It often starts with one flag. Then another is added, and another. Months later a feature lands and brings one more. No one is checking every combination on each update. The original developer has left the team and those that remain don't have all the context. Under pressure to roll out another update, no one wants to do a thankless rewrite.

The result is a view driven by multiple independent boolean flags, each controlling a different navigation surface:

```swift
@State private var showReviews   = false
@State private var showShare     = false
@State private var showAddReview = false
@State private var showError     = false
@State private var errorMessage  = ""
```

Nothing prevents more than one of these from being `true` at the same time. For `n` flags there are `2ⁿ` combinations — only a fraction of which are valid. The invalid combinations are not prevented by the type system; they are prevented only by the discipline of every developer who touches the code.

---

## Making Impossible States Impossible

Richard Feldman introduced this idea in his 2016 talk of the same name: use the type system to make invalid states unrepresentable. The insight applies directly to navigation. Instead of independent boolean flags, model the screen's possible states as a single enumerated type — and let the compiler enforce that only one can be active at a time.

```swift
@State private var destination: Destination?

enum Destination {
    case reviews
    case share
    case addReview
    case error(String)
}
```

`nil` means nothing is shown. Setting `.share` while `.addReview` is already active is structurally impossible — there is only one variable. The error message is no longer a separate floating `String`; it lives inside the `.error` case as an associated value, inseparable from the state that needs it.

The view modifiers become pattern matches against the enum:

```swift
.navigationDestination(isPresented: Binding(
    get: { if case .reviews = destination { return true }; return false },
    set: { if !$0 { destination = nil } }
)) {
    ReviewsView(product: product)
}
.sheet(isPresented: Binding(
    get: { if case .addReview = destination { return true }; return false },
    set: { if !$0 { destination = nil } }
)) {
    AddReviewView(product: product)
}
.alert("Error", isPresented: Binding(
    get: { if case .error = destination { return true }; return false },
    set: { if !$0 { destination = nil } }
)) {
    Button("OK") { destination = nil }
} message: {
    if case .error(let message) = destination { Text(message) }
}
```

The manual `Binding(get:set:)` is the remaining friction — see [swift-navigation](#swift-navigation) below.

---

## Scaling Up

The argument gets more concrete with a realistic feature. An account settings screen might let the user edit their profile, add a shipping address, or manage their saved cards. Three destinations, each reachable from the same parent view.

With boolean flags:

```swift
var isShowingEditProfile = false
var isShowingAddAddress  = false
var isShowingCards       = false
```

Three booleans produce eight possible combinations. Only four are valid: all false, or exactly one true. The other four — two or three flags true simultaneously — are illegal states the type system cannot prevent. Every transition function must clear the others before setting the new one, and every destination added later requires updating every existing transition.

The enum collapses this:

```swift
@CasePathable
public enum Destination: Equatable {
    case editProfile(UserProfile)
    case addAddress
    case savedCards
}

var destination: Destination?
```

Four states: `nil` and each case. All valid. Setting `.addAddress` while `.savedCards` is active is structurally impossible — there is only one property.

The associated value in `.editProfile` compounds the advantage. With boolean flags, `isShowingEditProfile = true` while the profile itself is `nil` is a legal combination in the type system — an edit screen with nothing to display. The enum makes that inexpressible: `.editProfile` carries the `UserProfile` it needs. The data and the state are the same value; they cannot be separated.

This is the pattern every model in the project follows. ShopApp has 27 screens across 8 feature modules. Each one is reached by assigning a single `destination` property — no clearing, no coordination, no defensive guards against combinations that should never exist.

The model side of the pattern is straightforward. The friction is on the SwiftUI side: connecting a single `destination` property to the full range of SwiftUI's presentation APIs — push navigation, sheets, full-screen covers, alerts — is not something SwiftUI supports natively from a single source of truth. Understanding why requires a short detour through what `NavigationStack` actually solves, and what it does not.

---

## NavigationStack

Before iOS 16, push navigation in SwiftUI was driven by `NavigationLink(destination:)` — a view-level declaration that embedded the destination directly in the link. There was no way to trigger navigation from model code, no way to restore a navigation stack from state, and no way to deep link into a specific screen without constructing the entire view hierarchy up front. Navigation was a view concern, not a model concern.

`NavigationStack`, introduced in iOS 16, changed this. The navigation path is now a value — an array you own, assign, and observe. Push navigation follows from data, not from view structure. That is a genuine step forward: the stack is inspectable, restorable, and testable without running the app.

But `NavigationStack` covers only push navigation. Sheets, alerts, confirmation dialogs, and popovers each still require their own independent state, with nothing to coordinate them or prevent conflicts. It solves one surface well, but navigation is all of them.

---

## swift-navigation

The Point-Free team describe their libraries as filling "fundamental gaps in the Apple ecosystem that we think should some day be a part of Swift or SwiftUI natively." [swift-navigation](https://github.com/pointfreeco/swift-navigation) is exactly that — the consistent, data-driven navigation model that `NavigationStack` hinted at but didn't finish.

The key addition is the `@CasePathable` macro. It allows a binding to be derived directly from any case of a `Destination` enum, eliminating the manual `Binding(get:set:)` code entirely:

```swift
// Push
.navigationDestination(isPresented: Binding($model.destination.reviews)) {
    ReviewsView(product: model.product)
}

// Sheet
.sheet(isPresented: Binding($model.destination.addReview)) {
    AddReviewView(product: model.product)
}

// Alert with associated value
.alert("Error", isPresented: Binding($model.destination.error)) {
    Button("OK") { model.destination = nil }
} message: {
    if case .error(let message) = model.destination { Text(message) }
}
```

Swift's type system is doing the heavy lifting — the SwiftUI API just doesn't go far enough out of the box.

---

## Pattern in ShopApp

Every feature model follows the same structure:

```swift
@Observable
public final class SomeModel {
    var destination: Destination?

    @CasePathable
    public enum Destination {
        case caseWithData(SomeType)
        case caseWithoutData
    }
}
```

Every view takes its model as `@Bindable` and drives all navigation surfaces through case-path bindings. There is no `@State` navigation in any view. Navigation state lives entirely in the model, which means any screen can be reached in a test by assigning `model.destination = .someCase(...)` — no simulator required.

---

## One type per concern

The goal is not "one enum per model" — it is "one type per navigation concern." A model with two independent navigation concerns warrants two independent types.

`AppModel` is the clearest example. It carries `selectedTab: Tab` (which tab is active — always exactly one) and `destination: Destination?` (a root-level modal that floats above the tab bar — zero or one). These are independent: showing the Support sheet does not change the selected tab. Conflating them into a single type would create invalid combinations rather than eliminate them.

`CheckoutModel` makes the same point more explicitly. The sequential funnel (`path: [CheckoutStep]`) and the modal surfaces (`destination: Destination?`) are different in kind, not just in name:

- The funnel is a **sequence** — each step is pushed on top of the previous and the user can navigate back. A `[CheckoutStep]` array expresses this naturally. Boolean flags cannot represent sequence or back navigation at all.
- The modals (processing, confirmation, payment failed) are **non-sequential** — they float above the stack and are never back-navigated to.

One flat enum trying to cover both concerns would either lose back navigation or make modal and funnel states appear to be of the same kind, which they are not.

---

## Dependency Concerns

swift-navigation historically introduced a number of transitive dependencies, which was a reasonable objection to adoption at scale. The library has since been updated with a traits-based architecture that allows each module to pull in only what it needs. A feature module that adopts `@CasePathable` for navigation state does not need to take on the full dependency graph.

Each feature module can adopt the pattern independently. The enum and the `@Observable` model require no library at all — that is pure Swift. The library is only needed at the point where the view bindings are wired up. A module owner can assess the dependency impact in isolation without it affecting other modules.

---

## Further Reading

- [Making Impossible States Impossible](https://www.youtube.com/watch?v=IcgmSRJHu_8) — Richard Feldman (Elm Conf 2016)
- [swift-navigation](https://github.com/pointfreeco/swift-navigation) — Point-Free
- [deep-linking.md](deep-linking.md) — every reachable state in ShopApp mapped to a URL
