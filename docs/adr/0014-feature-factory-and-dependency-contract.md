# ADR-0014: A feature's public API is a CheckoutFactory contract, not its model or view

**Date:** 2026-09-13 · amended 2026-09-15
**Status:** Accepted

## Context

ADR-0001 established that a feature may split off a dependency-free `XxxAPI` target holding its
repository protocol and data types, and named `Checkout` as the first to do so — but nothing
actually depended on `CheckoutAPI` as a boundary since. In practice, `AppModel`, `RootView`, and
other consumers (`PromotionsApp`, a different feature's micro-app) constructed `CheckoutModel` and
`CheckoutView` directly, through `CheckoutModel`'s plain public initializer. That made the model
and view themselves the feature's real public contract: any internal change to either was
indistinguishable, from outside the module, from a change to the feature's actual entry point.
`Checkout`'s screens were already correctly `internal` (see ADR-0005); the gap was one level up.

## Decision

`CheckoutAPI` declares the feature's complete contract as a protocol, `CheckoutFactory`. `Checkout`
provides exactly one conformance, `DefaultCheckoutFactory`, built from `CheckoutDependencies`
(also in `CheckoutAPI`):

```swift
public struct CheckoutDependencies {
    public let repository: CheckoutRepository
    public let selectedAddressStore: SelectedAddressStore?
    public init(repository: CheckoutRepository, selectedAddressStore: SelectedAddressStore? = nil)
}

@MainActor
public protocol CheckoutFactory {
    associatedtype CheckoutContent: View
    func makeCheckout() -> CheckoutContent
    var itemCount: Int { get }
    func addToCart(id: UUID, name: String, price: Decimal, wantsGuarantee: Bool)
    func setSavedAddresses(_ addresses: [ShippingAddress])
    var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)? { get set }
}

@MainActor
public final class DefaultCheckoutFactory: CheckoutFactory {
    public init(dependencies: CheckoutDependencies)
    public func makeCheckout() -> some View                                    // satisfies the protocol
    public func makeCheckout<PromotionBanner: View>(@ViewBuilder promotionBanner: @escaping () -> PromotionBanner) -> some View
    public var itemCount: Int { get }
    public func addToCart(id: UUID, name: String, price: Decimal, wantsGuarantee: Bool)
    public func setSavedAddresses(_ addresses: [ShippingAddress])
    public var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)?
}
```

`CheckoutFactory` needs `import SwiftUI` in `CheckoutAPI` — a real, named departure from
`CheckoutAPI`'s prior "not even SwiftUI" purity, accepted because the whole app is iOS-only anyway.

Two things about its shape are load-bearing, not incidental:

**The protocol requirement is `func makeCheckout() -> CheckoutContent` (an associated type), not
`func makeCheckout() -> some View`.** Swift doesn't allow an opaque return type directly on a
protocol requirement — only on a concrete implementation, the same reason `View` itself is
`associatedtype Body: View; var body: Body { get }` rather than `var body: some View { get }`.
`DefaultCheckoutFactory.makeCheckout()` still implements it with `some View`; Swift infers the
associated-type binding from that. No `AnyView` anywhere in this design, at any point — an earlier
draft of this decision considered a protocol covering the generic, promotion-banner-accepting
`makeCheckout(promotionBanner:)` directly, held as `any CheckoutFactory` by consumers; that fails
for a different reason than the associated-type restriction above — consuming an opaque-returning
requirement through an existential forces the same erasure `AnyView` would, just relocated.

**The requirement takes no parameters, on purpose.** A per-call generic parameter — letting a
caller embed a custom promotion banner — can't be expressed as a single associated type, which is
fixed per conformance, not per call. `DefaultCheckoutFactory` offers the fuller
`makeCheckout<PromotionBanner: View>(promotionBanner:)` as an additional method beyond the
protocol. Every real caller today (`RootView`, `PromotionsApp`) uses that fuller method directly on
the concrete type, not through `CheckoutFactory` — `AppModel` and `RootView` hold
`DefaultCheckoutFactory` concretely, not `any CheckoutFactory` or a generic parameter constrained
to `CheckoutFactory`. The protocol exists as a complete, compiler-checked statement of the
feature's contract, ready for a future consumer that needs to hold it abstractly; today's
consumers don't, and forcing genericity through `AppModel` for no current observer was rejected
(see Consequences).

`CheckoutModel`'s designated initializer is gated `@_spi(Internals)` rather than deleted, and stays
reachable for two callers with a legitimate reason to bypass the factory: `CheckoutTesting` (needs
a stub convenience init with no view attached) and this module's own composition-root snapshot
tests (need to seed `cart`/`path` state directly — the cross-module equivalent of `@testable
import` for a type they don't own; `DefaultCheckoutFactory` exposes an `@_spi(Internals) var model:
CheckoutModel` for exactly this, deliberately not part of `CheckoutFactory`). `CheckoutView` stays
plain `public`, ungated: without a way to construct a `CheckoutModel` from outside the module,
nothing outside the module can call its initializer anyway. This is the same asymmetric-access
shape `CheckoutModel`'s pre-existing `@_spi(Scenarios)` initializer already uses for the
micro-app's mid-funnel scenario builder — a different reason to reach in, gated separately, under
its own group name.

Internally, `CheckoutModel` holds one `CheckoutEnvironment` (`struct`, `internal`, never appearing
in a public signature) instead of two loose collaborator properties, resolving
`CheckoutDependencies`' optional `selectedAddressStore` to its concrete
`UserDefaultsSelectedAddressStore()` default — a default `CheckoutDependencies` itself cannot
express, since `CheckoutAPI` has no dependency on `Checkout`.

Because the composition root holds `DefaultCheckoutFactory` for the app's whole lifetime rather
than for one construction call, it also carries the cross-feature port `AppModel` needs after
construction — `itemCount`, `addToCart`, `setSavedAddresses`, `onOrderPlaced` — the same
Foundation-primitive-typed shape ADR-0003 already established for Store/Search calling into
Checkout, applied symmetrically.

## Consequences

**Positive**

- `CheckoutAPI` states the feature's complete contract, including how to build the screen — not
  four of five members with the fifth left on the concrete type as an unavoidable compromise.
- Internal changes to `CheckoutModel`/`CheckoutView` that don't change the factory's shape no
  longer look like a public API change to an interface-diffing tool watching the module's public
  surface.
- `CheckoutDependencies`/`CheckoutFactory` and `CheckoutAPI` are now a real, exercised boundary —
  every production consumer goes through `CheckoutDependencies` to construct
  `DefaultCheckoutFactory` — closing the gap this decision was referenced but left open since
  ADR-0001.

**Negative**

- **This does not deliver selective-testing benefit under a naive, path-based CI mechanism** (map
  changed file paths to their owning target, then walk `Package.swift` dependency edges) —
  only under a tool that diffs a module's actual exported interface. Traced through `project.yml`
  directly: `ShopCore`'s target lists `Checkout` as a dependency regardless of how `AppModel`
  types its stored property, because `AppModel.init` constructs `DefaultCheckoutFactory` and
  `RootView` calls its `makeCheckout(promotionBanner:)`, both requiring the concrete type.
  `ShopAppTests` doesn't even depend on `ShopCore` — it depends on the whole `ShopApp` app target,
  which needs `Checkout` directly regardless, to construct the real `DefaultCheckoutRepository`.
  A path-based tool would mark `ShopCore` and `ShopAppTests` "affected" by any `Checkout` change
  under this design exactly as it would have without it. Making `AppModel`/`RootView` generic over
  `CheckoutFactory` (rather than holding the concrete type) was considered and rejected for this
  reason — it's real engineering effort with no current observer to benefit from it, since nothing
  in this codebase depends on `ShopCore` in isolation from `ShopApp`/`Checkout`.
- One more type per feature substantial enough to warrant it. Not proposed for every feature
  module on day one — only where a factory's port would replace real, repeated direct-model access
  the way it did here.
- `@_spi` is an underscored, unstabilized Swift attribute, not a language feature with a stability
  guarantee — a tactical, compiler-enforced bridge, not a permanent one.
- `CheckoutScenario`'s builder (`CheckoutApp`) is unaffected by this ADR and continues to construct
  `CheckoutModel` directly via `@_spi(Scenarios)` — `CheckoutFactory`'s narrow `makeCheckout` has,
  on purpose, no parameter for a mid-funnel `path`.
