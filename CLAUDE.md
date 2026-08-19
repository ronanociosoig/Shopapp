# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

ShopApp is a reference implementation for programmatic navigation in SwiftUI, built as a companion
project to an article series. It's a multi-module e-commerce shell (27 screens, 8 feature modules,
Swift 6, `@Observable`, iOS 17 minimum). Every repository is stubbed — this is not a production app,
it demonstrates architectural patterns at realistic scale. Full narrative detail lives in `README.md`;
each pattern also has a rationale doc in `docs/adr/0001` through `0012` (why-not-alternatives for
module isolation, the composition root, callback contracts, ViewBuilder injection, micro-apps, testing
targets, enum-based navigation, one-destination-type-per-concern, snapshot-tests-not-XCUITest,
CaseIterable structural coverage, repository abstraction, `@Observable`).

**`AGENTS.md` is the canonical rules file** — read it before making any change. Its content must stay
identical across `AGENTS.md` (Codex), `CLAUDE.md` (this file), `.cursor/rules/conventions.mdc`
(Cursor), and `.github/copilot-instructions.md` (Copilot). If you edit navigation, testing, DI, or
module-boundary conventions here, propagate the edit to `AGENTS.md` too.

## Project setup

The Xcode project (`ShopApp.xcodeproj`) is **generated** from `project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — `project.yml` is the source of truth, the
`.xcodeproj` is committed output. Run `xcodegen generate` any time `project.yml` changes (new target,
new source file, new dependency).

```bash
brew install xcodegen
xcodegen generate
```

## Building and testing

This is an SPM package wrapped by an Xcode project. **Plain `swift build`/`swift test` cannot build
this project** — ShopApp is iOS-only and uses UIKit-only SwiftUI APIs, so a macOS host build fails
outright. Everything must go through `xcodebuild` against an iOS Simulator destination.

### Full app

```bash
xcodebuild build -scheme ShopApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Per-module package tests (StoreTests, AccountTests, CheckoutTests, etc.)

Each `XxxTests` SPM test target needs its own scheme under
`.swiftpm/xcode/xcshareddata/xcschemes/`. XcodeGen **cannot** wire an SPM test target into a native
scheme's `TestAction` (no corresponding `.library` product exists for a `.testTarget`), so these
schemes are hand-maintained, force-added past `.swiftpm/`'s blanket gitignore (`git add -f`), and must
be copied from an existing one (e.g. `StoreTests.xcscheme`) when a new module's test target needs CLI
coverage.

```bash
xcodebuild test -scheme StoreTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a single test — Swift Testing requires the full signature including "()";
# omitting it silently matches zero tests and reports a spurious pass.
xcodebuild test -scheme StoreTests -destination 'platform=iOS Simulator,name=iPhone 15' \
  '-only-testing:StoreTests/StoreRepositoryTests/fetchProductsDecodesResponse()'
```

Not every feature module has a CLI-runnable scheme yet — check for `Features/<Name>/…/<Name>Tests.xcscheme`
under `.swiftpm/xcode/xcshareddata/xcschemes/` first; if missing, copy `StoreTests.xcscheme`'s pattern.

### Replay-recorded network tests

`StoreTests`, `AccountTests`, `SearchTests`, `CheckoutTests`, `PromotionsTests`, `SuggestionsTests`,
and `PastPurchasesTests` use [Replay](https://github.com/mattt/Replay) HAR fixtures
(`Features/<Name>/Tests/Sources/Replays/*.har`) instead of live network calls or hand-rolled stubs for
repository tests. `SupportTests` does not use Replay.

To re-record a fixture against the real local backend (see `~/Projects/ShopAppServer`), env vars must
be injected via the scheme, not the shell — `xcodebuild test` does not honor `SIMCTL_CHILD_*`:

```bash
scripts/replay-record.sh on [once|rewrite] [scheme]   # default: once, StoreTests
# run xcodebuild test for that scheme now
scripts/replay-record.sh off [scheme]                 # always run this after — a scheme left
                                                        # recording silently re-records every future run
scripts/replay-record.sh status [scheme]
```

The `swift package replay record` CLI subcommand does **not** work in this repo (it shells out to
`swift test`, which hangs on this iOS-only package) — recording always goes through
`replay-record.sh` + `xcodebuild`.

## Architecture

### Module layers and the dependency rule

```
Shop/App          → any feature module, ShopCore
ShopCore          → all 8 feature modules (the only target that may do this)
Feature modules   → NetworkFoundation, DesignSystem, Common only
Foundation        → no feature deps
```

Feature modules (`Store`, `Account`, `Search`, `Checkout`, `Support`, `Suggestions`, `Promotions`,
`PastPurchases`) **must never import each other**. `ShopCore` (`AppModel`, `RootView`,
`RateOrderView`) is the single composition root permitted to see every feature. This is enforced by
the package graph itself — a forbidden `import` is a compile error — and mirrored for humans/agents in
`allowed-dependencies.json`. If you're about to write `import Search` inside `Checkout`, stop; the fix
is `Core/Common` for shared types, a Foundation-primitive callback, or `@ViewBuilder` generic
injection — see below.

Each feature also has a standalone micro-app target (`Features/Xxx/App/`, e.g. `SearchApp`,
`CheckoutApp`) — an `@main` `SwiftUI.App` that imports only that feature's production + `XxxTesting`
targets. This lets a screen be launched and iterated on without building the full app.

### Navigation: one `destination` enum per model, no Bool flags

Every model owning navigation state exposes exactly one `var destination: Destination?`, a
`@CasePathable` enum with one case per reachable screen/sheet/cover. Views take the model `@Bindable`
and drive every presentation (`navigationDestination(item:)`, `.sheet`, `.fullScreenCover`) off case-path
bindings into that single property — never `@State var isShowingX: Bool`, never
`NavigationLink(destination:)`. `n` independent Booleans yield `2ⁿ` representable states, almost all
illegal; one `Destination?` enum yields exactly `n+1`, all legal. `CheckoutModel.Destination` (7 cases,
one per funnel step, several carrying their own associated data like `PlacedOrder`/`PaymentError`) is
the canonical example — see `README.md` for the full walkthrough.

`AppModel` (in `ShopCore`) owns app-level nav (`selectedTab`, `destination: AppModel.Destination?`) —
`RootView` holds no navigation `@State` of its own, which is what makes composition-root snapshot
testing possible.

### Cross-module wiring patterns (all live in `AppModel.init` / `RootView`, `Shop/App/Sources`)

- **Foundation-primitive callbacks** — a feature exposes `var onSomething: ((UUID, String, Decimal, Bool) -> Void)?`
  typed only in Foundation primitives (never a domain type from another feature). `AppModel.init`
  assigns the closure and does the type conversion at the boundary. Example:
  `storeModel.onAddToCart` → `checkoutModel.addToCart(CheckoutProduct(...))`.
- **Generic `@ViewBuilder` injection** — a view that needs to embed another feature's UI (e.g.
  `StoreView` embedding a `SuggestionsView` strip) is generic over the injected view type; only
  `RootView` (or the micro-app, with an `EmptyView` default) supplies the concrete type.
- **Signal properties** — for navigation a model can't own itself (switching tabs, opening another
  feature's sheet), the model exposes a plain signal property (`shouldOpenSupport: Bool`,
  `orderToRate: PastOrder?`) that `RootView` observes via `.onChange` and translates into an
  `AppModel.Destination` assignment, then clears.

### Dependency injection

Production model inits require an explicit repository protocol parameter with **no default** —
`init(repository: FeatureRepositoryProtocol, ...)`. Never default to a concrete/live type, and never
default to a stub in the production init. Each feature's companion `XxxTesting` library product (a
separate SPM product, not shipped in the app target) supplies a `convenience init` that defaults to the
module's stub repository, so tests and micro-apps need no setup. Live implementations are wired only at
the composition root (`Shop/App/Sources`); feature modules never reference them.

### Test tiers (per feature module)

- **`*ModelTests`** — unit tests on state transitions/computed properties/callbacks, no simulator.
- **`*UITests`** (naming only — these are model-layer interaction tests, not XCUITest) — multi-step
  flows exercised through the model.
- **`*SnapshotTests`** — off-screen rendering via `swift-snapshot-testing`; since nav state lives on
  the model, any screen is reached by `model.destination = .someCase(...)`, no simulator interaction
  needed. Every module's snapshot test file extends its `Destination` enum with `CaseIterable` in the
  test target (not production) and parametrizes a test over `allCases` — adding a case without adding
  it to `allCases` is a compile error, making coverage of new destinations structural. Never commit
  `record: true`; re-record locally, verify the PNG, then commit code + PNG together. A snapshot
  failure with no intentional UI change is a regression, not a baseline update.
- **`*RepositoryTests`/`*StoreTests`** — persistence/network-decoding, via Replay HAR fixtures where
  applicable (see above).
- **`ShopAppTests`** — composition-root snapshot tests, hosted inside `ShopApp.app`. Uses
  `@testable import Checkout`/`PastPurchases`/etc. to reach internal state (`cart`, `orders`) not
  exposed publicly, then asserts on `RootView(model:)` — only possible because `AppModel` is injected
  rather than built internally by `RootView`.

XCUITest is reserved for things that genuinely need a real app process (deep links, push
notifications, system permission dialogs) — if a screen's state can be set by mutating a model
property, it gets a snapshot test, not an XCUITest.

## Known gaps (see README "Areas for improvement" for detail)

- Stub repositories currently still live in production framework targets (not yet split into
  `XxxTesting`-only) for some modules — check before assuming a given module's stub is already
  test-only.
- `AppModel.init`'s cross-module wiring (`onAddToCart`, `onOrderPlaced`, `onRepeatOrder`,
  `syncAddresses`) and `RootView`'s signal-property `.onChange` → `Destination` mapping are untested.
- `SearchView.FiltersView` category selection is local `@State` and doesn't write back to
  `SearchModel` — Apply is a no-op.
- `AccountModel.setDefaultAddress` has no test asserting only the targeted address ends up marked
  default.
