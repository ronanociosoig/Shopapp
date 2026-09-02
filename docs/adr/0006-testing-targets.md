# ADR-0006: Stub repositories live in XxxTesting library products, not production targets

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

## Context

Tests and micro-apps need stub implementations of repository protocols — controlled replacements that return fixed data without making network calls. The initial approach placed stub classes (e.g. `StubStoreRepository`) directly in the production framework target alongside the protocol they implement. This worked but had three problems:

1. **Stubs ship in the production binary.** Any consumer of the `Store` library gets `StubStoreRepository` whether they want it or not. This inflates binary size and pollutes the public API surface.
2. **Test infrastructure leaks into production.** Stub classes appear in documentation, autocomplete, and static analysis alongside production types.
3. **Circular dependency when moving stubs.** Naively extracting a stub into a separate `StoreTesting` target that the production `Store` target depends on for default parameter values creates a cycle: `Store → StoreTesting → Store`.

## Decision

Each feature module has a companion `XxxTesting` library product in `Package.swift`. The dependency direction is:

```
XxxTesting → Xxx   (Testing imports production)
Xxx         → (nothing in Testing)   (no cycle)
```

Stub classes live in `Features/Xxx/Testing/Sources/`. Each testing target also contains a convenience `init()` extension on the feature's model that injects the stub, allowing test code to write `StoreModel()` after `import StoreTesting` without constructing a stub explicitly:

```swift
// Features/Store/Testing/Sources/StoreModelTestSupport.swift
import Store

public extension StoreModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubStoreRepository(), destination: destination)
    }
}
```

Production model initialisers require an explicit `repository:` argument — no stub is reachable from production code.

Test targets and micro-app targets declare `XxxTesting` as a dependency. `ShopApp` itself links five of them — `StoreTesting`, `AccountTesting`, `CheckoutTesting`, `PromotionsTesting`, `SuggestionsTesting` — **not** because those modules lack a backend (every module has a live `Default*Repository` against `ShopAppServer`) but so a `--ui-testing` launch gets deterministic, network-free fixture data: `ShopAppUITests` asserts on exact fixture content ("Alex Johnson", `MacBook Pro 16"`) and must not depend on whether a local server is running. `Search` and `PastPurchases` stay live even under `--ui-testing`.

Not every module has a `XxxTesting` target. `Support` has no repository at all — its content is a static `SupportTopic` enum — so it has neither a repository protocol (ADR-0011) nor a companion Testing target.

The naming convention `XxxTesting` follows the Tuist modular architecture documentation, making the pattern directly applicable in a future Tuist migration (Article 5 of the series).

## Consequences

**Positive**

- Stubs are excluded from the production binary for modules with live backends.
- The production public API is clean: no stub types appear in autocomplete or documentation.
- The production/test boundary is enforced by the module graph. A developer cannot accidentally use a stub in production code.
- Convenience initialisers in testing targets preserve existing `XxxModel()` call syntax in tests; the only change required is adding `import XxxTesting`.
- The target naming aligns with Tuist conventions, reducing friction for a future migration.

**Negative**

- An additional library product and target must be maintained per feature module with a data layer (seven at present — every feature except `Support`).
- `ShopApp` links five `XxxTesting` products, so their stubs are in the shipped binary. This is a deliberate, ongoing trade-off for the `--ui-testing` fixture path — not a temporary state pending backends — and is documented in `project.yml`.
