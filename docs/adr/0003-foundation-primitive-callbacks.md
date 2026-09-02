# ADR-0003: Cross-module callbacks never name another feature's types

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

> **2026-08-31 amendment.** The original rule was stated as "callbacks use *only*
> Foundation primitives." That is true for peer-to-peer callbacks but too strong
> in general: `checkoutModel.onOrderPlaced` and `pastPurchasesModel.onRepeatOrder`
> pass a value type the *emitting* module owns. The Decision below is restated to
> cover both shapes; the underlying constraint — never name **another** feature's
> type — is unchanged.

## Context

Feature modules are isolated (ADR-0001): Store cannot import Checkout, and Checkout cannot import Store. Yet the Store module must be able to trigger an "add to cart" event that Checkout handles. Three approaches exist:

1. **Shared type in a common target.** Extract `CartItem` to `Common` so both modules can reference it. This works but puts domain types in a foundation layer, which grows without bound as features proliferate.
2. **Domain type on the callback, requiring cross-feature import.** `onAddToCart: (StoreProduct) -> Void` — rejected because it requires Checkout to import Store or vice versa, violating ADR-0001.
3. **Foundation primitives on the callback.** The sender passes only types from Foundation (UUID, String, Decimal, Bool, Date). The composition root receives them and constructs whatever domain types it needs.

## Decision

A cross-module callback's signature **must never name a type owned by another feature module.** Two shapes satisfy this, and which one applies depends on who is on the other end of the callback.

### Foundation primitives — when both endpoints are peer features

A `StoreProduct` has to become a `CheckoutProduct`, but neither module may see the other's type. The callback is typed only on Foundation types (`UUID`, `String`, `Decimal`, `Bool`, `Date`), and the composition root rebuilds the domain type at the boundary:

```swift
// StoreModel (Store — no knowledge of Checkout)
public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

public func addToCart(_ product: StoreProduct, wantsGuarantee: Bool = false) {
    onAddToCart?(product.id, product.name, product.price, wantsGuarantee)
}
```

```swift
// AppModel (composition root — sees both Store and Checkout)
storeModel.onAddToCart = { id, name, price, wantsGuarantee in
    checkoutModel.addToCart(CheckoutProduct(id: id, name: name, price: price,
                                            supportsExtendedGuarantee: wantsGuarantee))
}
```

### The emitting module's own type — when only the composition root is on the other end

A callback may pass a value type the emitting module itself defines, because its only consumer is `AppModel`, never a peer feature. `CheckoutModel.onOrderPlaced` passes its own `PlacedOrder`; `PastPurchasesModel.onRepeatOrder` passes its own `PastOrder`. `AppModel` receives the concrete type and adapts it:

```swift
// CheckoutModel (Checkout — passes a type it owns, from CheckoutAPI)
public var onOrderPlaced: ((PlacedOrder, Set<UUID>) -> Void)?

// AppModel — maps PlacedOrder into PastPurchases' PastOrder
checkoutModel.onOrderPlaced = { placedOrder, guaranteeItems in
    Task { await pastPurchasesModel.saveOrder(PastOrder(/* field-by-field from placedOrder */)) }
}
```

### Rule of thumb

**Primitives when the two endpoints are peer features; the owned type when only the composition root is on the other end.** `AppModel.syncAddresses()` is the same idea in method form — it reads `accountModel.addresses` (`[SavedAddress]`, Account's type) and writes `checkoutModel.savedAddresses` (`[ShippingAddress]`, Checkout's type), doing the field mapping itself. In every case the composition root is the only place that names both concrete types.

## Consequences

**Positive**

- No shared domain types are needed in foundation layers. `Common` stays domain-agnostic.
- Each module's public API is free of references to other modules.
- Callbacks are easy to stub in tests: a closure over Foundation values requires no cross-module imports.

**Negative**

- The composition root must know both the source and destination types. As cross-module relationships grow, `AppModel.init` accumulates more translation logic.
- Primitive signatures lose the semantic clarity of named domain types. A signature of `(UUID, String, Decimal, Bool)` requires a comment to explain the intent of each parameter.
- If the source and destination modules evolve independently, the primitives may no longer map cleanly between their types; the composition root has to absorb the mismatch.
