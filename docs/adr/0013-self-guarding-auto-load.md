# ADR-0013: A model's auto-load guards itself against overwriting state a caller already set

**Date:** 2026-08-22
**Status:** Accepted · amended 2026-08-31 (the `suppressAutoLoad` half is to be superseded by ADR-0017)

## Context

Several feature views trigger their model's initial data fetch from a SwiftUI `.task` on the view
itself, so the screen loads automatically the first time it appears:

```swift
// The naive version
.task { await model.load() }
```

This is convenient in production — a view never needs an external caller to remember to kick off
loading — but it has a sharp edge. `.task` fires on every appearance, and `load()` unconditionally
overwrites the model's data properties. A snapshot test (or a UI test, or a composition-root caller)
that constructs a model and sets its state directly — `model.profile = .stub`,
`model.orders = PastOrder.stubs` — without going through `load()` is racing against that same
`.task`. Depending on timing, the result is one of three wrong outcomes: the snapshot captures
before the auto-load starts (correct, by luck), mid-load (a loading spinner where real content
should be), or after the auto-load completes (the test's carefully-set state silently overwritten by
whatever the injected repository's own defaults happen to return).

This was not a hypothetical risk. `StoreView` hit it first and was fixed with a guard
(commit `959ce17`). The same unguarded pattern was independently reintroduced in `AccountView`,
`PastPurchasesView`, `PromotionsView` (two call sites — the main view and the embeddable
`PromotionBannerView`), and `SuggestionsView` — five more places, because the fix wasn't written
down anywhere as a rule, only applied once. `RootView` additionally had its own **separate**,
independently unguarded `.task { await model.accountModel.load() }` at the composition-root level —
fixing `AccountView` alone did not fix that one, because it triggers `load()` a second, separate way.
One committed snapshot baseline (`AccountSnapshotTests`' `signed_out.png`) had been showing fully
signed-in data under a "signed out" label for some time before this was caught — a stale
committed artifact produced by exactly this bug.

## Decision

The guard lives **inside the model's own `load()` method**, not at each `.task` call site:

```swift
// AccountModel.swift
public func load() async {
    // Self-guarding rather than relying on every call site to check first —
    // AccountView's own .task and RootView's .task both trigger this
    // independently, and both need the same protection against
    // clobbering state a caller (or a test) already set explicitly.
    guard !suppressAutoLoad, !isLoading, profile == nil, addresses.isEmpty, cards.isEmpty else { return }
    isLoading = true
    defer { isLoading = false }
    // ...
}
```

Every call site — `AccountView`'s `.task`, `RootView`'s independent `.task`, a future retry button —
can call `load()` unconditionally and trust it to no-op when it shouldn't run. This is the only
workable option, not just the tidiest one: `RootView` lives in `ShopCore`, a different module than
`Account`, and can't see `AccountModel`'s internal properties (`profile`, `isLoading`, `cards` are
not `public`) to build its own guard even if it wanted to. Duplicating an equivalent guard at every
call site would also mean six places to keep in sync instead of one — exactly the kind of repetition
that let this bug recur five times in the first place.

Models with an explicit load-state enum (`StoreModel`'s `StoreLoadState`, `SearchModel`'s
`SearchState`) guard on the `.idle` case — the enum already distinguishes "never loaded" from every
other state, including a loaded-but-empty one. Models without that enum (`AccountModel`,
`PastPurchasesModel`, `PromotionsModel`, `SuggestionsModel` — all a plain `isLoading: Bool` plus one
or more data properties) can't make that distinction from data alone: "not loaded yet" and "loaded,
genuinely empty" both look like `nil`/`isEmpty` from the outside. For those, an explicit
`suppressAutoLoad` flag is the escape hatch
— set only by callers (in practice, snapshot tests exercising a genuinely-empty state) that need to
assert the empty case without an auto-load racing to fill it in:

```swift
// AccountSnapshotTests.swift
let model = AccountModel()
model.suppressAutoLoad = true
```

## Consequences

**Positive**

- The protection is automatic for every current and future caller of `load()` — a new view, a
  pull-to-refresh action, another composition-root wiring — without anyone needing to remember to
  add a guard at the call site.
- Fixes the exact bug class found independently in six places (`AccountView`, `PastPurchasesView`,
  `PromotionsView` ×2, `SuggestionsView`, `RootView`) by construction, not by convention someone has
  to remember to apply next time.

**Negative**

- `load()` calling itself a no-op under some conditions is a bit of implicit behavior — a developer
  unfamiliar with this ADR could reasonably expect `await model.load()` to always actually load, and
  be confused when it doesn't. Every `load()` implementing this guard carries a comment explaining
  why; that comment is load-bearing documentation, not decoration.
- Models without an explicit load-state enum need the extra `suppressAutoLoad` boolean as a second
  thing a test has to remember to set, on top of whatever data it configures. `StoreModel`'s and
  `SearchModel`'s `.idle` case doesn't need this at all. An explicit load-state enum on every model
  (rather than `isLoading: Bool` plus implicit "empty means unloaded") would remove the ambiguity at
  its source instead of working around it. **This is now the plan: ADR-0017 unifies every model on a
  single `LoadState<Value>` and removes `suppressAutoLoad` entirely.** Until that lands, the flag
  stays on the four `isLoading: Bool` models.
