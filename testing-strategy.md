# Testing Strategy

## The Premise

Every screen in ShopApp is a pure function of model state. A model owns exactly one
`destination: Destination?` (ADR-0007) — sometimes a second, orthogonal navigation
property for a genuinely different concern (ADR-0008) — and the view renders whatever
that state says, nothing else. No `@State` navigation lives in any view.

That one fact is what the entire testing strategy is built on. If rendering is a pure
function of state, then reaching any screen is not a UI problem, it's an assignment:

```swift
let model = CheckoutModel(cart: CartItem.stubs, repository: StubCheckoutRepository(delay: .zero))
model.path = [.address, .orderOptions(.stub)]
assertSnapshot(of: CheckoutView(model: model), as: .image(layout: .device(config: .iPhone13Pro)))
```

No simulator interaction, no tap sequence, no waiting for an animation to settle. This is
ADR-0009's whole argument, and it's why most of ShopApp's UI coverage runs in-process,
in well under a second per screen, instead of through XCUITest.

---

## Determinism Is Necessary, Not Sufficient

It's tempting to read the premise above as "programmatic, state-driven navigation means
every screen is reachable" and stop there. That's true, but it elides a second question
that matters just as much for a testing *strategy* as it does for a public API: reachable
**by whom**?

Determinism guarantees that *something* can construct any state and get a correct
render. It says nothing about whether that something is allowed to be outside the
module. Those are two different claims, and Checkout is where they come apart.

`CheckoutModel` has two navigation properties (ADR-0008), and they answer the
reachability question differently:

- **`destination: Destination?`** — `.processing`, `.confirmation(order)`,
  `.paymentFailed(error)`. These are reachable through the plain, ordinary public
  initializer, by anyone: `CheckoutModel(destination: .processing, repository:)`
  compiles for any consumer of `Checkout`.
- **`path: [CheckoutStep]`** — the sequential funnel screens. `path` is `internal`.
  There is no public setter, no public init parameter for it on the designated
  initializer. The only ways in are `@testable import Checkout` (the module's own
  tests) or the `@_spi(Scenarios)` initializer — a second, explicitly gated
  initializer that exists for exactly one external caller, the micro-app's scenario
  builder.

Both properties are equally deterministic. Setting either one and rendering costs
nothing and needs no simulator. But one is publicly constructible and one isn't,
because `path` carries an invariant a caller outside the module could violate — a
`.paymentEntry(address)` for an `address` that was never added to `savedAddresses`,
or steps in an order the real funnel never produces — and `destination`'s cases don't.
Determinism didn't settle that question. It couldn't have: "this state can be
constructed and rendered without a simulator" and "this state can be constructed by
code that isn't part of this module" are orthogonal facts about a piece of state, and
conflating them is how a testing strategy quietly turns into an API-widening argument
("we need to test this, so it has to be public") that doesn't actually follow.

The practical rule that falls out of this, and the one worth carrying into every future
module: there are three tiers of "who can inject a given piece of navigation state,"
and determinism only guarantees the first one is possible.

| Tier | Who | Mechanism | Guaranteed by determinism? |
|---|---|---|---|
| Internal | The module's own tests | `@testable import Xxx` | Yes — always available |
| Scoped | One named external caller (a scenario builder) | `@_spi(SomeName)` | No — a deliberate API decision |
| Public | Anyone | An ordinary `public init` parameter | No — a deliberate API decision |

Which tier a given piece of state belongs in is decided by whether an external caller
holding it could construct something the real app never produces — not by whether
something outside the module happens to want it. See `CheckoutModel`'s doc comment and
the `@_spi(Scenarios)` initializer for the concrete example this table is drawn from.

---

## The Other Payoff: Every Screen Stays Internal, Permanently

The reachability question above is about *state*. There's a second, unconditional
payoff of state-driven navigation that's about *views*, and it doesn't have the same
caveat: not one individual screen in any funnel needs to be `public`, ever, no matter
how many new external callers show up wanting to reach one.

Checked directly against Checkout's screens: `CartView`, `CartItemRow`,
`AddressFormView`, `OrderOptionsView`, `PaymentMethodSelectionView`,
`PaymentEntryView`, `OrderProcessingView`, `OrderConfirmationView`,
`PaymentFailedView` — nine structs, all `internal`. The only public type in the
`Checkout` module's view layer is `CheckoutView` itself, the single container that
switches on `path`/`destination` and constructs whichever of the nine it needs.

This is only possible because a caller reaches a screen by naming a *value* — a
`CheckoutStep` case, a `Destination` case — never by naming the screen's *type*.
Compare the counterfactual: a router protocol, a segue identifier, or a micro-app that
imports a screen's concrete View type directly to jump straight to it. Any of those
forces that screen `public` the first time something outside the module needs it — and
the next screen, and the one after that. That's the exact one-`public`-keyword-at-a-time
accretion described in the Article 3 material (`Dont_Make_It_Public_draft.txt`) for a
naive micro-app. Enum-driven navigation state doesn't avoid that failure mode through
discipline; it makes it structurally impossible, because the thing a caller holds is
never the screen.

---

## What Can Silently Break the Premise

The whole strategy rests on "state in, correct render out, deterministically." Twice in
this project's history, something has quietly violated that:

- **ADR-0013.** Five views (`AccountView`, `PastPurchasesView`, `PromotionsView` twice,
  `SuggestionsView`) plus `RootView`'s own composition-root instance triggered
  `model.load()` from an unguarded `.task`. A test that set state directly — `model.profile
  = .stub` — was racing that `.task`; depending on timing, the auto-load would silently
  overwrite the state the test had just set. One committed snapshot baseline had been
  showing the wrong state for some time before this was caught. The fix (`load()` guards
  itself, not each call site) restores the premise: state you set is state that renders,
  full stop, regardless of what a view's own lifecycle does around it.

- **This session's nested-`NavigationStack` bug.** ADR-0009 already lists as a known
  negative that snapshot tests "cannot exercise interaction... or anything that requires
  a running event loop." That's not hypothetical: `.navigationDestination(item:)`
  silently no-ops when its destination view's own `NavigationStack` is bound to an
  external path (`CheckoutView`'s is) — confirmed with a real tap via
  `CheckoutFunnelUITests`, and invisible to every snapshot test, because a snapshot test
  never asks whether a *push* happened, only whether a given state *renders* correctly
  once reached. Rendering-determinism and navigation-mechanics-determinism are different
  claims; the first is what snapshot tests verify, the second needs an occasional real
  interaction to confirm at all.

Both are the same lesson from different directions: the premise this strategy depends on
is real, but it is not automatic. It has to be actively protected (self-guarding loads)
and occasionally spot-checked against the live platform (a real tap through a real
`NavigationStack`), not just assumed because the architecture makes it *possible* in
principle.

---

## The Test Tiers

| Tier | File pattern | What it verifies | Needs a simulator running the app? |
|---|---|---|---|
| Unit | `*ModelTests` | State transitions, computed properties, callbacks | No |
| Interaction | `*UITests` (model-layer, not XCUITest) | Multi-step flows through the model's action methods | No |
| Snapshot | `*SnapshotTests` | Rendered output at a given state, `CaseIterable`-enforced (ADR-0010) | No — off-screen render, in-process |
| Repository/network | `*RepositoryTests`, `*StoreTests` | Decoding, request shape — via Replay HAR fixtures where applicable | No |
| Composition root | `ShopAppTests` | `RootView` given a fully-wired `AppModel`, all stub repositories | No — hosted inside `ShopApp.app`, but off-screen |
| Real interaction | `*UITests` (genuine XCUITest, e.g. `CheckoutFunnelUITests`, `SearchScenarioUITests`) | Real `NavigationStack`/tap mechanics, deep links, system dialogs | Yes |

The bottom row is deliberately the smallest. XCUITest is reserved for what nothing else
can check: whether a real tap on a real accessibility element actually produces the
transition the state model predicts. Everything above it is off-screen, in-process, and
fast precisely because of the premise this document opened with. The nested-
`NavigationStack` bug is the concrete argument for keeping that bottom row rather than
letting snapshot coverage stand in for it entirely — it is the one thing the other five
rows structurally cannot see.

---

## The Scenario Tier (Article 3)

A newer, sixth kind of coverage sits alongside these, and it's worth being precise about
what it is and isn't: each micro-app's `XxxScenario`/`XxxScenarioFactory`
(`CheckoutScenario.swift`, `SearchScenario.swift`) is not an automated test. Nothing
asserts pass/fail. It's a `CaseIterable` catalog of named, realistic states a person can
launch into and look at, or interact with — the manual/exploratory counterpart to
`*SnapshotTests`' automated one, sharing the same underlying idea (deterministic state,
no need to navigate there by hand) but aimed at a human, not CI.

What a scenario builder reuses from the automated tiers, and what it doesn't, follows
the same rule as everywhere else in this document — not "tests vs. micro-app" as a
blanket line, but "is this genuinely shared, or genuinely one-off":

- Scenario *state* (which `path`/`destination` combination a given scenario represents)
  is unique to the catalog and lives in the micro-app target — nothing else needs it.
- Scenario *behavior* (a fake repository, a fake store) reuses `XxxTesting` when it's
  the same thing the module's own tests already depend on. Checkout's `.cart` scenario
  needs to be walked to a genuine confirmation, exactly like `CheckoutSnapshotTests`'
  happy-path test — so it reuses `CheckoutTesting`'s `StubCheckoutRepository` rather
  than hand-rolling a second copy.

Being manual/exploratory doesn't mean unprotected, though — see the next section.

---

## Scenarios Need Their Own Regression Coverage, Not a Snapshot Test

A scenario catalog's cases are framed, in their own doc comments, as the states that
matter — "the funnel's actual starting point", "one item opted in", "payment was
declined". That framing is a claim about business-relevant state, and until
`CheckoutAppTests` was added, nothing enforced it. `CheckoutScenarioFactory.makeModel(for:)`
always compiles — Swift's type system guarantees that much — but compiling is not the
same as still producing the state a scenario's name promises. A refactor that changed
how `extendedGuaranteeItems` gets populated could silently stop `.orderOptions` from
demonstrating the guarantee toggle it exists to demonstrate, and nothing would fail; a
person would have to happen to notice, next time they opened that scenario by hand. This
is the same "premise silently breaks, nobody notices for a while" failure mode as
ADR-0013's unguarded `.task` and the nested-`NavigationStack` bug above — a third
instance, previously with zero protection at all.

The fix is deliberately not a snapshot test. `CheckoutSnapshotTests` already asserts
pixel-correctness for these same underlying model states — a second snapshot test
driven through the scenario builder would duplicate coverage that already exists, the
same mistake this document argues against everywhere else. What's actually missing is a
state-correctness check: does the model each scenario builds actually hold the specific
facts its name claims. That's a unit-test question, not a rendering one, and it now has
a home: `CheckoutAppTests`, a unit-test bundle hosted inside `Checkout.app`
(`TEST_HOST`, the same pattern `ShopAppTests` already uses for `ShopApp`) — no simulator
interaction, `@testable import` reaching both `CheckoutApp` (for `CheckoutScenario`/
`CheckoutScenarioFactory`) and `Checkout` (for the model's internal `path`/`destination`).

One test, parametrized over `CheckoutScenario.allCases`, with an exhaustive `switch`
asserting the specific business fact each case claims — `.orderOptions`'s guarantee item
is actually opted in, `.paymentFailed`'s funnel is still intact underneath the sheet,
`.confirmation`'s order actually has line items. A new scenario case with no
corresponding assertion is a compile error, the same structural-coverage discipline
ADR-0010 already applies to `Destination`, one level up the stack. Verified by deliberately
breaking `.orderOptions`'s guarantee assignment and confirming the test catches it
before restoring it — the test fails exactly where it should and nowhere else.

`SearchAppTests` gives `SearchScenario` the same coverage, following the identical
shape — one test parametrized over `SearchScenario.allCases`, `@testable` reaching
`SearchApp` (for the catalog/builder) and `Search` (for `searchState`/`query`, both
internal). Verified the same way: deliberately broke `.searchFailed`'s message,
confirmed the test caught it, restored it.

---

## Public API Shape, Restated

The tiers above only work as cheaply as they do because of how each module's public
surface is drawn — this is the other half of Article 3, and the two documents describe
the same boundary from different angles. In short (see `Dont_Make_It_Public_draft.txt`
for the full argument):

- The repository protocol is the real seam — the thing that actually has two
  implementations worth having.
- The model's initializer is the substitution point — construction-time, not
  conformance-time.
- `@_spi` is a third tier between "internal" and "public" for state that's genuinely
  needed outside the module but carries invariants an ordinary public caller could
  violate.
- No screen is ever public. The View is a leaf, not a seam, and enum-driven navigation
  is what keeps it that way permanently rather than by convention.

---

## Further Reading

- [ADR-0006](docs/adr/0006-testing-targets.md) — stub repositories in `XxxTesting`
- [ADR-0007](docs/adr/0007-enumeration-based-navigation-state.md) — enum-based navigation state
- [ADR-0008](docs/adr/0008-one-type-per-navigation-concern.md) — one navigation type per concern
- [ADR-0009](docs/adr/0009-snapshot-tests-as-ui-regression-layer.md) — snapshot tests as the UI regression layer
- [ADR-0010](docs/adr/0010-caseiterable-for-structural-test-coverage.md) — `CaseIterable` structural coverage
- [ADR-0011](docs/adr/0011-repository-protocol-abstraction.md) — repository protocol abstraction
- [ADR-0013](docs/adr/0013-self-guarding-auto-load.md) — self-guarding auto-load
- [navigation-state.md](navigation-state.md) — the enum-based navigation pattern in full
- *Article 3 draft* (`Dont_Make_It_Public_draft.txt`, outside this repo) — what a SwiftUI
  feature's public API actually is, in full: the `@_spi(Scenarios)` table above and the
  "every screen stays internal" section are both drawn from that piece

Note: [ADR-0005](docs/adr/0005-micro-apps.md) still shows Checkout's micro-app as a single
hardcoded screen — it predates the scenario-list rework described above and is due a
refresh, not contradicted by this document.
