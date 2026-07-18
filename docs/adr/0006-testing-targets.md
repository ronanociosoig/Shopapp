# ADR-0006: Stub repositories live in XxxTesting library products, not production targets

**Date:** 2026-07-18  
**Status:** Accepted

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
// Features/Store/Testing/Sources/StoreModelTesting.swift
import Store

public extension StoreModel {
    convenience init() {
        self.init(repository: StubStoreRepository())
    }
}
```

Production model initialisers require an explicit `repository:` argument — no stub is reachable from production code.

Test targets and micro-app targets declare `XxxTesting` as a dependency. The main `ShopApp` target depends on `XxxTesting` for modules that do not yet have a live backend (Account, Checkout, Promotions, Suggestions).

The naming convention `XxxTesting` follows the Tuist modular architecture documentation, making the pattern directly applicable in a future Tuist migration (Article 5 of the series).

## Consequences

**Positive**

- Stubs are excluded from the production binary for modules with live backends.
- The production public API is clean: no stub types appear in autocomplete or documentation.
- The production/test boundary is enforced by the module graph. A developer cannot accidentally use a stub in production code.
- Convenience initialisers in testing targets preserve existing `XxxModel()` call syntax in tests; the only change required is adding `import XxxTesting`.
- The target naming aligns with Tuist conventions, reducing friction for a future migration.

**Negative**

- An additional library product and target must be maintained per feature module (eight in total at present).
- The main `ShopApp` target links `XxxTesting` for stub-only modules, so those stubs remain in the shipped binary until live backends are added. This is a temporary and explicit trade-off, documented in `project.yml`.
