# ADR-0003: Cross-module callbacks use Foundation primitives, not domain types

**Date:** 2026-07-18  
**Status:** Accepted

## Context

Feature modules are isolated (ADR-0001): Store cannot import Checkout, and Checkout cannot import Store. Yet the Store module must be able to trigger an "add to cart" event that Checkout handles. Three approaches exist:

1. **Shared type in a common target.** Extract `CartItem` to `Common` so both modules can reference it. This works but puts domain types in a foundation layer, which grows without bound as features proliferate.
2. **Domain type on the callback, requiring cross-feature import.** `onAddToCart: (StoreProduct) -> Void` — rejected because it requires Checkout to import Store or vice versa, violating ADR-0001.
3. **Foundation primitives on the callback.** The sender passes only types from Foundation (UUID, String, Decimal, Bool, Date). The composition root receives them and constructs whatever domain types it needs.

## Decision

All cross-module callbacks use only Foundation primitive types in their signatures. The pattern in use:

```swift
// In StoreModel (Store module — no knowledge of Checkout)
public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

public func addToCart(_ product: StoreProduct, wantsGuarantee: Bool = false) {
    onAddToCart?(product.id, product.name, product.price, wantsGuarantee)
}
```

```swift
// In AppModel (composition root — knows both Store and Checkout)
storeModel.onAddToCart = { id, name, price, wantsGuarantee in
    let product = CheckoutProduct(id: id, name: name, price: price,
                                  supportsExtendedGuarantee: wantsGuarantee)
    checkoutModel.addToCart(product)
}
```

The same pattern applies to `checkoutModel.onOrderPlaced`, `pastPurchasesModel.onRepeatOrder`, and `AppModel.syncAddresses()`.

The composition root is the only place that knows both the source type (`StoreProduct`) and the destination type (`CheckoutProduct`). It performs the translation.

## Consequences

**Positive**

- No shared domain types are needed in foundation layers. `Common` stays domain-agnostic.
- Each module's public API is free of references to other modules.
- Callbacks are easy to stub in tests: a closure over Foundation values requires no cross-module imports.

**Negative**

- The composition root must know both the source and destination types. As cross-module relationships grow, `AppModel.init` accumulates more translation logic.
- Primitive signatures lose the semantic clarity of named domain types. A signature of `(UUID, String, Decimal, Bool)` requires a comment to explain the intent of each parameter.
- If the source and destination modules evolve independently, the primitives may no longer map cleanly between their types; the composition root has to absorb the mismatch.
