# ADR-0006: Stub repositories live in XxxTesting library products, not production targets

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31, 2026-09-27

> **2026-09-27 amendment.** The "shipped in the binary" line under Negative was originally written
> as a bounded, accepted trade-off. It's a known **XcodeGen limitation** instead, not an
> architectural choice: confirmed directly against the tool's own spec, `project.yml` dependencies
> have no per-build-configuration scoping at all — `config`/`configs` exist only at the scheme
> level (which action runs which configuration), never on a dependency entry itself. A `#if DEBUG`
> guard was added around `ShopAppMain.swift`'s five `XxxTesting` imports and the `isUITesting`
> construction — correct to keep, since it stops the app's own code from referencing a stub outside
> Debug — but it does not remove the libraries from a Release archive. Checked directly: `nm` on
> both compiled binaries shows every stub class, with every method, present and identical in
> Release. A real fix needs the `--ui-testing` fixture path moved onto a target `ShopApp` itself
> doesn't depend on, which is out of scope here — this project is XcodeGen-based for the life of
> this article series specifically, with a planned move to Tuist afterward, and this limitation is
> being named rather than solved for that reason.

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

The naming convention `XxxTesting` follows the Tuist modular architecture documentation — a naming precedent that would reduce friction if this project were ever migrated to Tuist, not a planned step in this article series.

## Consequences

**Positive**

- Stubs are excluded from the production binary for modules with live backends.
- The production public API is clean: no stub types appear in autocomplete or documentation.
- The production/test boundary is enforced by the module graph. A developer cannot accidentally use a stub in production code.
- Convenience initialisers in testing targets preserve existing `XxxModel()` call syntax in tests; the only change required is adding `import XxxTesting`.
- The target naming aligns with Tuist conventions, reducing friction for a future migration.

**Negative**

- An additional library product and target must be maintained per feature module with a data layer (seven at present — every feature except `Support`).
- `ShopApp` links five `XxxTesting` products, so their stubs are in the shipped binary, in every configuration including Release — a known **XcodeGen limitation** (no per-configuration dependency scoping exists in the tool), not a deliberate trade-off. A `#if DEBUG` guard around the usage in `ShopAppMain.swift` keeps the source honest but does not remove the linked code, verified directly against the compiled binary. See the 2026-09-27 amendment above.
