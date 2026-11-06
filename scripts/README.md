# scripts/

Small CLI helpers for workflows that would otherwise mean hand-editing XML or
retyping the same `xcodebuild` invocation. Each script is self-contained;
run one with no arguments (or see its own header comment) for full usage.

## run-tests.sh

Runs one or all of the feature-module test schemes via `xcodebuild` (the only
way to run them — see the root `CLAUDE.md`/`AGENTS.md`, plain `swift test`
fails outright), and resets stale snapshot references so they get
re-recorded on the next run.

```
scripts/run-tests.sh list
scripts/run-tests.sh test <target|all> [device]
scripts/run-tests.sh reset-snapshots <target|all> [name-substring]
```

- `list` — prints the known targets (the 8 feature modules, plus `ShopApp`
  for the composition-root `ShopAppTests`).
- `test` — runs the given target's scheme (or all of them) against a
  simulator, default device `iPhone 17`.
- `reset-snapshots` — lists the `__Snapshots__` PNGs matching a target
  (optionally filtered by a filename substring), lets you pick which to
  delete, then reminds you of the two-run workflow: the next `test` run
  fails on purpose while recording new references, the one after that
  should pass. Always inspect a newly-recorded PNG before committing it — a
  snapshot failure with no intentional UI change is a regression, not a
  baseline to paper over.

## replay-record.sh

Toggles `REPLAY_RECORD_MODE` on/off for a test scheme, to re-record a
[Replay](https://github.com/mattt/Replay) HAR fixture against a real local
backend (see `~/Projects/ShopAppServer`) instead of replaying the committed
one. Exists because `xcodebuild test` doesn't forward the invoking shell's
environment to the test process the way `swift test` does, so the env var
has to be injected via the scheme itself — this script makes (and reverts)
that scheme edit instead of hand-editing it each time.

```
scripts/replay-record.sh on [once|rewrite] [scheme]   (default: once, StoreTests)
scripts/replay-record.sh off [scheme]                 (default: StoreTests)
scripts/replay-record.sh status [scheme]              (default: StoreTests)
```

A scheme left in recording mode silently re-records on every future run —
always run `off` again after recording.

## deep-link-promotion.sh

Dispatches a real `shopapp://promotions/<id>` deep link to a running
simulator via `simctl openurl` — the manual check used to confirm the
Promotions deep link end-to-end (real OS URL-scheme registration, real
dispatch, real navigation), distinct from what `DeepLinkTests.swift` already
proves at the unit level.

```
scripts/deep-link-promotion.sh [promotion-id] [udid-or-booted]
```

Requires ShopApp to already be installed and running on the target
simulator — this only dispatches the URL, it doesn't build, install, or
launch. Launch with `--ui-testing` (`xcrun simctl launch booted
com.shopapp.demo.app --ui-testing`) so the app uses `StubPromotionsRepository`
— without it, promotions come from `ShopAppServer`'s own seed data, which
uses different ids for the same titles than `Promotion.stubs`, and this
script's default id will dispatch but silently fail to match anything. Expect
a system "Open in \"ShopApp\"?" confirmation sheet the first time in a
simulator session — `simctl openurl` looks like an external caller (Safari,
Messages, another app) to iOS, not the app opening itself.

## deep-link-checkout-delivery.sh

Dispatches a real `shopapp://checkout/delivery` deep link to a running
simulator via `simctl openurl` — the manual check used to confirm the
Checkout "Delivery & Extras" deep link end-to-end, distinct from what
`DeepLinkTests.swift` already proves at the unit level.

```
scripts/deep-link-checkout-delivery.sh [udid-or-booted]
```

Unlike the Promotions deep link, this one carries no id — Checkout resolves
"Delivery & Extras" from its own state (the cart, and a saved shipping
address), the same way a real user reaching that step through the funnel
would, and legitimately refuses (switches to the Cart tab but goes no
further) when the cart is empty or there's no saved address. Launch with
`--ui-testing` (`xcrun simctl launch booted com.shopapp.demo.app
--ui-testing`) for deterministic stub data — `StubAccountRepository` ships a
default saved address — and add an item to the cart to see the success path.

## deep-link-checkout-payment-retry.sh

Dispatches a real `shopapp://checkout/payment-retry` deep link to a running simulator via `simctl
openurl` — the manual check used to confirm the "select a new payment method" deep link
end-to-end, distinct from what `DeepLinkTests.swift` already proves at the unit level.

```
scripts/deep-link-checkout-payment-retry.sh [udid-or-booted]
```

For a payment problem detected after the customer has already left the payment step (a delayed
authorization check, a fraud review) rather than the synchronous decline `submitPayment` already
surfaces via the `paymentFailed` sheet. Lands directly on Payment Method, skipping Address and
Delivery & Extras. Carries no id — like `checkout/delivery`, it resolves the shipping address from
Checkout's own state and legitimately refuses (switches to the Cart tab but goes no further) when
the cart is empty or there's no saved address. Launch with `--ui-testing`
(`xcrun simctl launch booted com.shopapp.demo.app --ui-testing`) for deterministic stub data, and
add an item to the cart to see the success path.

## deep-link-checkout-add.sh

Dispatches a real `shopapp://checkout/add/<id>?name=...&price=...&guarantee=...` deep link to a
running simulator via `simctl openurl` — the manual check used to confirm the "add to cart" deep
link end-to-end, distinct from what `DeepLinkTests.swift` already proves at the unit level.

```
scripts/deep-link-checkout-add.sh [product-id] [name] [price] [guarantee] [udid-or-booted]
```

Unlike the other three deep links, this one carries the full product record in the URL instead of
a bare id — Checkout has no product catalog of its own to resolve an id against, so the record has
to travel with the link, the same way it already arrives from Store/Search/Suggestions tapping
"Add to Cart" in-app. It lands on `CheckoutFactory.addToCart(id:name:price:wantsGuarantee:)`, the
same cross-feature port those three already call through — not a new deep-link-specific method.
Requires ShopApp to already be installed and running on the target simulator.

## deep-link-checkout-scenario.sh

Experiment: dispatches a real `checkoutscenarios://<scenario>` deep link to the **Checkout
micro-app** (`com.shopapp.demo.checkout`, not the production ShopApp) via `simctl openurl` —
the manual check used to confirm the micro-app's own deep-link support end-to-end, distinct
from what `CheckoutScenarioTests.swift`'s `CheckoutScenarioDeepLinkTests` already proves at
the unit level.

```
scripts/deep-link-checkout-scenario.sh [scenario-raw-value] [udid-or-booted]
```

This targets a different kind of destination than every other script in this file: a named
`CheckoutScenario` (see `CheckoutScenario.swift`) — a freshly-constructed `CheckoutModel` from
`CheckoutScenarioFactory`, not a live model's real cart/address state. There's no feature host
to match the way `shopapp://` has (`promotions`, `checkout`, `orders`); the scenario's own
`rawValue` is the URL host (`cart`, `emptyCart`, `addressSelection`, `orderOptions`,
`paymentMethod`, `cardEntry`, `processing`, `confirmation`, `paymentFailed`). An unrecognized
name decodes to `nil` and does nothing, same refusal shape as every other deep link in this
app. Requires the Checkout micro-app to already be installed and running on the target
simulator — this only dispatches the URL, it doesn't build, install, or launch.

## deep-link-order.sh

Dispatches a real `shopapp://orders/<id>` deep link to a running simulator
via `simctl openurl` — the manual check used to confirm the PastPurchases
"Order Detail" deep link end-to-end, distinct from what `DeepLinkTests.swift`
already proves at the unit level.

```
scripts/deep-link-order.sh [order-id] [udid-or-booted]
```

`PastPurchasesRepository` has no `--ui-testing` stub path — it always loads
from this simulator's local `UserDefaults` order history first, falling back
to the real local `ShopAppServer` only when that's empty. A device with any
order history already saved locally will never see this script's default
id, because local storage wins and the remote seed never gets fetched; the
deep link then silently lands on the order list instead of a detail screen.
Uninstall the app first (`xcrun simctl uninstall booted com.shopapp.demo.app`)
to clear local state and force a fresh remote fetch.

## merge-coverage.sh

Computes true, de-duplicated code coverage across *every* package test
target at once. No single scheme runs all of them together, and adding up
each target's own top-line percentage would double-count nothing but also
never credit one target's tests for exercising another's code (e.g.
`ShopAppTests` exercising `ShopCore`/`Checkout`/`PastPurchases`/`Promotions`).
This merges the raw `.profdata` files with `llvm-profdata` and reports
against every test binary at once with `llvm-cov`.

```
scripts/merge-coverage.sh [simulator-id]
```

Output lands in `.build/coverage-merge/`: each target's own `.profdata`/
`.bin`/`.log`, the merged `merged.profdata`, and per-target + merged summary
tables printed to stdout.
