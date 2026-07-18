# ADR-0002: AppModel is the composition root and the only type that imports all features

**Date:** 2026-07-18  
**Status:** Accepted

## Context

Feature module isolation (ADR-0001) forbids cross-feature imports. Features still need to communicate: when a user adds a product to cart in the Store, the Checkout module must receive the item; when an order is placed, PastPurchases must be updated; when addresses are added in Account, Checkout must see them. Something has to own this wiring.

An alternative is a shared event bus or notification centre. That approach decouples senders from receivers but obscures the dependency graph and makes the data flow hard to trace or test.

## Decision

`AppModel`, defined in the `ShopCore` target, is the composition root. It is the single type in the application that imports every feature module. `ShopCore` depends on all eight feature targets; no other target does.

`AppModel` is responsible for:

1. **Creating all feature models.** Each model is constructed with its concrete repository dependency — the composition root is the right place to perform dependency injection.
2. **Wiring cross-module callbacks.** After constructing the models, `AppModel.init` assigns closures to each model's callback properties (e.g. `storeModel.onAddToCart`, `checkoutModel.onOrderPlaced`, `pastPurchasesModel.onRepeatOrder`). See ADR-0003 for the callback contract.
3. **Owning top-level navigation state.** `selectedTab` and `destination` live on `AppModel` rather than in `RootView` as `@State`, making the full application state injectable.

Because `AppModel` is an `@Observable` class with all state as stored properties, the entire application state can be created in one line. `RootView` and its snapshot tests receive a configured `AppModel` with no additional setup.

## Consequences

**Positive**

- All cross-module wiring is in one file. A developer can read `AppModel.swift` to understand every cross-module event in the application.
- `AppModel` is testable without launching the application. Snapshot tests inject a configured instance directly.
- Dependency injection is explicit and compile-checked: `AppModel.init` lists every repository the application needs.
- Deep-link handlers can reach any screen by mutating `AppModel` properties, because all navigation state is owned there.

**Negative**

- `AppModel.init` grows as more features are added. Each new feature adds a repository parameter, a model property, and potentially several wiring closures.
- `ShopCore` cannot be tested independently of all feature modules; it inherits their full dependency graph.
