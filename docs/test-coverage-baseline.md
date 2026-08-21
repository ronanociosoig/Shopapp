# Test coverage baseline

**Date:** 2026-08-21
**Git commit:** `c38c75299099ba9e0da7dfb33d33d1ae50cfd8cb`
**Purpose:** a quick reference snapshot of current coverage, taken alongside `docs/build-time-baseline.md`
while evaluating the Article 3 API-module split. Not load-bearing for that work — noted for the record,
not analyzed further at this point.

## Method

`xcodebuild test -scheme <XxxTests> -destination 'platform=iOS Simulator,id=6BC3B504-CD2B-4F38-9897-87217E9D3B45' -enableCodeCoverage YES`,
one run per module's package test scheme, plus the `ShopApp` scheme (hosts `ShopAppTests`, the
composition-root snapshot tests). Coverage extracted per run via `xcrun xccov view --report <bundle>`,
using each module's own top-level row (not its `XxxTests` row, which is the test target's own
self-coverage and not meaningful here).

**Not measured:** `Common`, `NetworkFoundation`, `DesignSystem`. `CommonTests` has no CLI-runnable
`.xcscheme` yet (unlike the 8 feature test targets, which all do). `NetworkFoundation` and
`DesignSystem` code does execute during the runs above — e.g. `NetworkClient.swift` shows
`82.14% (23/28)` inside the `StoreTests` report — but `xccov` attributes it as a file nested under the
consuming feature's target rather than breaking it out as its own top-level row, so it isn't cleanly
separable from the numbers below without more work than this "quick look" warranted.

## Per-module coverage (production target only)

| Module | Coverage | Lines |
|---|---|---|
| Support | 95.52% | 213/223 |
| Checkout | 95.99% | 1675/1745 |
| Store | 95.64% | 921/963 |
| Search | 95.24% | 761/799 |
| ShopCore | 91.32% | 505/553 |
| PastPurchases | 86.65% | 727/839 |
| Account | 85.70% | 845/986 |
| Promotions | 51.03% | 222/435 |
| Suggestions | 24.53% | 157/640 |

**Aggregate across the 9 rows above: 83.89% (6026/7183 lines).** A straight sum, not weighted or
adjusted — treat it as directional, not a precise whole-project figure, given the excluded targets
above.

Promotions and Suggestions are clear outliers — worth a look at some point, unrelated to the API-module
work this baseline was taken for.

## Merged coverage across every test target

The per-module numbers above each come from that module's own dedicated test scheme in isolation —
they don't credit a module for code exercised by a *different* target's tests (e.g. `ShopAppTests`
also runs code in `Checkout`, `PastPurchases`, `Promotions`, and `ShopCore`). Getting a true,
de-duplicated "how much of the app do all the tests together cover" number requires merging the raw
coverage profiles rather than adding up per-target percentages, since overlapping coverage between
targets isn't additive. `scripts/merge-coverage.sh` does this: it runs every test scheme (the 8 feature
`XxxTests` targets plus `ShopApp`, which hosts `ShopAppTests`) against a shared, isolated derived-data
directory, saves each run's raw `.profdata` and test binary before the next run overwrites the shared
profile location, then merges everything with `llvm-profdata merge` and reports with `llvm-cov report`
across all binaries at once.

**Note on scope, since this uses a different tool than the per-module table above:** `xcrun xccov`
(used above) reports coverage per *target name* and folds foundation-layer code (`NetworkFoundation`,
`Common`) into whichever feature target consumes it, without a clean way to include it standalone.
`llvm-cov` reports per *source file path* instead, so the numbers below include every source file
linked into each test binary — production code, `XxxTesting` stub code, and the test files themselves.
That's a wider scope than the per-module table above, which is part of why the two don't match file
descriptor for file descriptor; treat this section as the more complete picture.

Per-target totals (own source only, third-party dependencies excluded), computed from each target's own
isolated run before merging:

| Target | Lines covered | Line coverage |
|---|---|---|
| ShopApp (`ShopAppTests`) | 90/90 | 100.00% |
| CheckoutTests | 2398/2621 | 91.49% |
| StoreTests | 1468/1618 | 90.73% |
| SearchTests | 1201/1355 | 88.63% |
| AccountTests | 1412/1715 | 82.33% |
| PastPurchasesTests | 1201/1464 | 82.04% |
| SupportTests | 345/538 | 64.13% |
| PromotionsTests | 434/795 | 54.59% |
| SuggestionsTests | 380/1042 | 36.47% |

**Merged total, own source only: 86.61% (8624/9957 lines).** Higher than the 83.89% naive sum in the
per-module table above, confirming the expectation going in — the merge doesn't just avoid
double-counting, it credits real coverage (mainly from `ShopAppTests` exercising `ShopCore`/`Checkout`/
`PastPurchases`/`Promotions`) that no single module's own dedicated suite gets credit for on its own.

**Merged total, including every third-party dependency linked into the test binaries: 44.18%
(10623/24047 lines).** Not a meaningful "our code" number — included for completeness, since it's what
`llvm-cov` reports by default with no filename filter. The gap between this and the 86.61% figure is
almost entirely CasePaths/swift-navigation/SwiftSyntax/etc. source, most of which ShopApp's own tests
were never going to exercise and shouldn't be expected to.

**Two of the nine test runs reported failures during this pass** (`AccountTests`, and `ShopApp`'s
`ShopAppTests`) — consistent with the snapshot-drift finding below; coverage was still collected for
whatever code executed regardless of assertion outcome, per the script's design.

## Test failures observed during this run

10 tests failed, all snapshot tests, none logic tests:

- `ShopAppTests` / `RootSnapshotTests`: all 7 tests failed (every tab + the two sheet snapshots)
- `AccountTests` / `AccountSnapshotTests`: 2 of 2 failed ("signed out", "signed in with full data")
- `StoreTests` / `StoreSnapshotTests`: 1 failed (`categoryFilter` destination, presented via `.sheet`)

**Update: the Xcode/SDK-drift hypothesis above was wrong — root-caused and fixed instead of
re-recorded.** All 10 failures traced back to the same real bug, present in five places:
`AccountView`, `PastPurchasesView`, `PromotionsView` (×2 — the main view and the embeddable
`PromotionBannerView`), and `SuggestionsView` each had an unguarded `.task { await model.load() }`
that fired on every appearance and clobbered whatever state a snapshot test had already set directly
on the model (profile, addresses, orders, promotions, products) — the exact bug already found and
fixed once for `StoreView` in commit `959ce17`, just not propagated to the other five call sites at
the time. `RootView` additionally had its own **separate**, independently unguarded
`.task { await model.accountModel.load() }` at the composition-root level, which is why fixing
`AccountView` alone didn't fix `RootSnapshotTests`'s account-tab failure. Fix: moved the guard into
`AccountModel.load()` itself (self-guarding, so every caller benefits without duplicating the check)
and added a `suppressAutoLoad` escape hatch (on `AccountModel`/`PastPurchasesModel`/`PromotionsModel`/
`SuggestionsModel`) for the specific case where "not loaded yet" and "loaded, genuinely empty" are
indistinguishable from the outside — e.g. `AccountModel`'s `signedOut()` test. The `Store`
`categoryFilter` failure was a real, separate, correctly-diagnosed issue (`.sheet` doesn't mount in
off-screen capture) — fixed by asserting on the sheet's content view (`CategoryFilterView`) directly
instead of the presenting `StoreView`. All 9 test schemes pass from a cold `DerivedData` wipe as of
this update.
