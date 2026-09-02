# ADR-0009: Snapshot tests are the primary UI regression layer; XCUITest is a narrow exception

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

> **2026-08-31 amendment.** The original title said "no XCUITest." Three XCUITest
> targets have since been added for things a snapshot test structurally cannot
> reach — see the new *Where XCUITest is still used* section. The rule is
> unchanged: if a screen's state can be set by mutating a model property, it gets
> a snapshot test.

## Context

UI regression testing in iOS projects typically means one of two things: XCUITest (launching the app, driving it through the UI, asserting on accessibility labels) or manual testing. XCUITest has high value for end-to-end flows but is slow, flaky under CI conditions, and cannot easily target a specific screen without navigating the full UI path to reach it.

The alternative is to test the rendered output of a SwiftUI view directly, in-process, without launching an application. This is possible when navigation state is owned by a model (ADR-0007): a test creates the model, sets its state directly, renders the view, and compares the result to a reference image.

## Decision

`swift-snapshot-testing` is the primary UI regression layer. Every feature module has a `XxxSnapshotTests.swift` file that:

1. Creates a model with the desired state set directly on its properties.
2. Calls `assertSnapshot(of: SomeView(model: model), as: .image(layout: .device(config: .iPhone13Pro)))`.
3. On first run, records the reference image. On subsequent runs, compares pixel-by-pixel.

Because navigation state is a value on the model, reaching any screen requires no UI interaction:

```swift
// Snapshot the order options screen — no tapping required
let model = CheckoutModel(cart: CartItem.stubs, repository: StubCheckoutRepository(delay: .zero))
model.savedAddresses = [.stub]
model.path = [.address, .orderOptions(.stub)]
assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)))
```

Integration-level snapshot tests exist in `RootSnapshotTests.swift`, which constructs a full `AppModel` with all stub repositories and asserts on `RootView` — covering the composition root and tab-level navigation without launching the app.

Funnel flow tests use the model's action methods directly (`model.proceedToAddress()`, `model.submitAddress(.stub)`) to walk through state transitions and snapshot each step, verifying that the sequence of screens is correct.

## Where XCUITest is still used

Three XCUITest targets exist, each exercising a real app process for something snapshot tests structurally cannot cover:

- **`ShopAppUITests`** (`Shop/App/UITests`) — one end-to-end walk of the full purchase funnel through the real `ShopApp`, launched with `--ui-testing` for deterministic fixtures. Covers cross-tab navigation and fixture-content assertions against the assembled app.
- **`CheckoutFunnelUITests`** (`Features/Checkout/App/UITests`) — the XCUITest counterpart to the snapshot funnel-flow test: the same six screens, but driven through a real `NavigationStack` with real animations. It exists partly as a deliberate teaching contrast (speed vs. fragility vs. what each layer actually exercises) and partly to catch push regressions that only reproduce with live UIKit navigation.
- **`SearchScenarioUITests`** (`Features/Search/App/UITests`) — verifies that tapping a row in the scenario catalog actually pushes the real `SearchView`. A programmatic test cannot confirm a UIKit navigation push happened.

The rule stands: a screen whose state can be set by mutating a model property gets a snapshot test, not an XCUITest. XCUITest is reserved for deep links, push notifications, system dialogs, and genuine UIKit-integration behaviour.

## Consequences

**Positive**

- Snapshot tests run in the test process, not a simulator UI. They are fast and deterministic.
- Any screen is reachable in one step by setting model state directly, regardless of how many taps would be required in the real app.
- A visual regression anywhere in the UI is caught immediately on the next test run, without waiting for a manual review cycle.
- The full application state (`AppModel` with all stubs) can be asserted without launching the app, giving integration coverage at the root level.
- Tests double as documentation: each named snapshot records exactly what a screen looks like at a specific state.

**Negative**

- Reference images must be committed to the repository. They grow the repo size and produce large diffs when the design changes.
- Snapshots are device- and OS-specific. Images recorded on one simulator configuration will fail on another. Tests are pinned to a specific device configuration (`iPhone13Pro`).
- Snapshot tests cannot exercise interaction, animation, or anything that requires a running event loop. Gesture-driven flows require separate manual or XCUITest coverage.
- When the design system changes (colours, typography, spacing), all affected snapshots must be re-recorded. This is intentional — it makes design regressions visible — but it means a design change touches many test files.
