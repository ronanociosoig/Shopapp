# ADR-0015: Deep links are decoded by the feature they point to, not by the composition root

**Date:** 2026-10-18
**Status:** Accepted

## Context

A deep link (`shopapp://promotions/<id>`, `shopapp://checkout/delivery`, `shopapp://orders/<id>`)
arrives at exactly one place: `ShopAppMain.swift`'s `.onOpenURL`, attached to the content view inside
`WindowGroup` (not to `WindowGroup` itself — it has no such member — and not chained onto `RootView`'s
own modifier list, which never fires). From there, something has to turn a `URL` into a concrete
screen.

The naive version of that something is `AppModel` doing the whole job: parse the full path, decide
which `Destination` case it names, construct that case, assign it to the owning feature's
`destination` property. ADR-0007 already settled that every feature owns one `Destination` enum;
ADR-0001 already settled that feature modules never import each other and `ShopCore` is the one
place allowed to see all of them. Taken together, `AppModel` constructing `PromotionsModel.Destination`
or `PastPurchasesModel.Destination` directly is legal Swift — `ShopCore` already depends on every
feature — but it means the composition root has to know each feature's internal data shape (a
`Promotion`, a `PastOrder`) well enough to build one from a bare `UUID`, and that knowledge has nowhere
to live except `AppModel` itself. Every new deep-linkable screen would grow `AppModel`'s understanding
of that feature's domain, the opposite of what ADR-0001's module boundary is for.

Five deep links exist now, each discovered through actually building and dispatching one, not
through designing the mechanism up front:

- `shopapp://promotions/<id>` — `PromotionsModel.handleDeepLink(promotionID:)`
- `shopapp://checkout/delivery`, `shopapp://checkout/payment-retry`, and
  `shopapp://checkout/add/<id>?name=...&price=...&guarantee=...` — all three decoded by one entry
  point, `CheckoutModel.handleDeepLink(url:)` / `DefaultCheckoutFactory.handleDeepLink(url:)`
- `shopapp://orders/<id>` — `PastPurchasesModel.handleDeepLink(orderID:)`

## Decision

`AppModel.handle(url:)` (`Shop/Framework/Sources/AppModel+DeepLinks.swift`) reads exactly one thing
off the URL to route: `url.host`, used only to pick which feature gets the rest of it. Everything
past that — whether a path component parses as a UUID, whether that id resolves to a real object,
whether the current app state can even satisfy the request — is the feature's own problem, decided
behind one public method per feature that is the *only* place outside the feature allowed to produce
that feature's `Destination`:

```swift
extension AppModel {
    public func handle(url: URL) async {
        guard let host = url.host else { return }
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "promotions":
            guard let idString = pathComponents.first, let id = UUID(uuidString: idString) else { return }
            selectedTab = .store
            await promotionsModel.handleDeepLink(promotionID: id)

        case "checkout":
            if checkoutFactory.handleDeepLink(url: url) {
                selectedTab = .cart
            }

        case "orders":
            guard let idString = pathComponents.first, let id = UUID(uuidString: idString) else { return }
            selectedTab = .orders
            await pastPurchasesModel.handleDeepLink(orderID: id)

        default:
            break
        }
    }
}
```

`AppModel` still parses the id string into a `UUID` before calling in — that much is unavoidable,
since `AppModel` is the one holding the raw `URL` — but it never looks inside `Promotion` or
`PastOrder` to do it, and it switches tabs itself because tab selection is `AppModel`'s own state,
not any feature's. Everything that requires knowing what a `Promotion` or a `PastOrder` *is* happens
on the other side of the call.

Each feature exposes its decoding entry point the way its existing public API already shapes that
feature, rather than all three being forced into one new uniform mechanism:

- **Promotions and PastPurchases** have no factory type (ADR-0014 only applies to Checkout so far) —
  their model class *is* their public surface, so the entry point is simply a new `public func` on
  `PromotionsModel` / `PastPurchasesModel`:

  ```swift
  // PromotionsModel
  public func handleDeepLink(promotionID: UUID) async {
      if promotions.isEmpty { await load() }
      guard let promotion = promotions.first(where: { $0.id == promotionID }) else { return }
      destination = .promotionDetail(promotion)
  }

  // PastPurchasesModel — same shape
  public func handleDeepLink(orderID: UUID) async {
      if orders.isEmpty { await load() }
      guard let order = orders.first(where: { $0.id == orderID }) else { return }
      destination = .orderDetail(order)
  }
  ```

  Both load first if nothing's loaded yet, because a deep link can arrive at cold launch, before
  anything has populated the list the ordinary way — an ordering concern that only exists for a deep
  link, never for a normal in-app selection.

- **Checkout** already has a complete public contract, `CheckoutFactory` (ADR-0014) — `AppModel`
  holds a `DefaultCheckoutFactory`, never a bare `CheckoutModel`. Since that protocol claims to be the
  feature's *complete* contract, a deep-link entry point that only existed on the concrete type would
  make the claim false the moment a second conformance ever showed up, and a separate public method
  per deep-linkable screen would make the same claim false a different way — the contract grows one
  requirement per screen forever. So Checkout gets exactly one, regardless of how many screens or
  actions it covers:

  ```swift
  // CheckoutAPI
  @discardableResult
  func handleDeepLink(url: URL) -> Bool
  ```

  `AppModel` hands the whole `URL` across, unexamined past `host` — which path segment it names
  (`"delivery"`, `"payment-retry"`, `"add"`) and which query items it needs are entirely Checkout's to
  decide, inside the module, the same way `Promotion`/`PastOrder` lookups are entirely Promotions'/
  PastPurchases' to decide. The `Bool` returned answers one question only — was this URL shaped like
  something Checkout recognizes — deliberately not the same question as "did the request succeed."
  An empty cart can make a recognized `/checkout/delivery` link unable to reach its screen while
  `handleDeepLink(url:)` still returns `true`, because the URL itself was valid; `AppModel` only needs
  that outer answer, to decide whether to switch to the Cart tab.

## Consequences

**Positive**

- `AppModel+DeepLinks.swift` is small on purpose and stays small as more deep links are added — it
  grows one `case` per feature, never a case per *screen*. A feature adding another deep-linkable
  destination touches only that feature's own module: a fourth Checkout deep link costs zero lines in
  `AppModel+DeepLinks.swift`.
- The module-isolation boundary ADR-0001 established for ordinary navigation holds for deep links
  too: `AppModel` never sees inside a `Promotion`, a `PastOrder`, or a `ShippingAddress` to route to
  one. Nothing about this feature's design required *weakening* that boundary to make deep links work.
- Each feature's entry point reuses that feature's own existing machinery for reaching a screen
  rather than a parallel path built just for URLs — `handleDeepLink(promotionID:)` calls the same
  `load()` an ordinary screen view would trigger; `handleDeepLinkToDeliveryOptions()` calls the same
  `proceedToAddress()` a real funnel step would. A deep link is a different *caller* of the feature's
  logic, not different logic.
- Building all three real, before writing anything about the pattern, surfaced three genuinely
  different reasons a deep link can fail to reach its destination — not three variations on one
  cause:
  - **Id mismatch** (Promotions) — the real, non-stub repository hits a local server whose seed data
    assigns different ids to the same titles than the client's own `Promotion.stubs`; a URL built
    from one source of ids silently fails to match against the other.
  - **Conditional, state-dependent refusal** (Checkout) — `handleDeepLinkToDeliveryOptions()` and
    `handleDeepLinkToPaymentRetry()` can both correctly return `false`: an empty cart or no saved
    address means the screen the link names isn't reachable *right now*, through no fault of the
    link itself.
  - **Local state shadows remote state** (PastPurchases) — `DefaultPastPurchasesRepository` prefers a
    per-device, already-populated local order history over the remote/seed data; a device with any
    real prior order history will never see a seeded id, because the local store wins before the
    remote one is even asked.

  None of these are bugs in the deep-link code — each is `#expect`-tested as the *correct* outcome
  (`checkoutDeliveryDeepLinkEmptyCart`, `checkoutDeliveryDeepLinkNoSavedAddress`, `unknownOrderID`,
  `unknownPromotionID` in `DeepLinkTests.swift`). They're three different shapes a feature's existing
  state and data can take that a cold URL, arriving with none of a normal navigation's context, runs
  into.

**Negative**

- No single file states "here is every deep link this app supports" — that list only exists as the
  union of `AppModel.handle(url:)`'s `switch` and whatever each feature's own entry point accepts.
  Acceptable here because the `switch` is still the one required stop for every URL; a feature can't
  add a deep link `AppModel` never routes to.
- The entry points are not uniform in shape across features — two are `async` functions returning
  `Void` on a bare model class, one is a synchronous `Bool`-returning protocol requirement taking the
  raw `URL`. That's a direct consequence of respecting each feature's existing public-API shape
  (ADR-0014 for Checkout, nothing equivalent yet for the other two) rather than inventing one
  `DeepLinkHandling` protocol all features conform to — rejected because Promotions and PastPurchases
  have no factory type to hang it on today, and retrofitting one only for this would be exactly the
  kind of design-ahead-of-use ADR-0014 itself argues against (see its Negative: "not proposed for
  every feature module on day one").
- `AppModel` still has to parse a path component into a `UUID` for Promotions and PastPurchases —
  a minimal decoding duty that can't be pushed any further out for an id-lookup deep link, since
  `AppModel` is the only place holding the raw `URL`. Checkout needs none of that: `AppModel` hands
  the whole `URL` across without looking at anything past `host`.
