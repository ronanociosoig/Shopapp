# Deep Linking — State Coverage

This document maps every reachable UI state in ShopApp to a proposed URL, identifies what data is required to reach it, and notes whether that data can be resolved synchronously or requires an async fetch.

---

## URL scheme

```
shopapp://<host>/<path>?<query>
```

Custom scheme: `shopapp`. The app would register this in `Info.plist` under `CFBundleURLTypes`. Universal links (`https://`) are an alternative but require a hosted `apple-app-site-association` file and an associated-domains entitlement; the routing logic is identical either way.

---

## State categories

| Category | Description |
|---|---|
| **Immediate** | State is set synchronously — no fetch needed |
| **Async** | Requires a repository fetch before the destination can be set |
| **Not linkable** | Transient in-flight state that should not be reached from outside the funnel |

---

## AppModel — tab selection

These set `AppModel.selectedTab` only. No destination is set.

| State | URL | Category | Notes |
|---|---|---|---|
| Store tab | `shopapp://store` | Immediate | Default tab; redundant but valid |
| Search tab | `shopapp://search` | Immediate | |
| Cart tab | `shopapp://cart` | Immediate | |
| Account tab | `shopapp://account` | Immediate | |
| Orders tab | `shopapp://orders` | Immediate | |

```swift
switch url.host {
case "store":   model.selectedTab = .store
case "search":  model.selectedTab = .search
case "cart":    model.selectedTab = .cart
case "account": model.selectedTab = .account
case "orders":  model.selectedTab = .orders
default: break
}
```

---

## AppModel — root destinations

These set `AppModel.destination`, which presents a sheet over the entire tab bar.

| State | URL | Category | Notes |
|---|---|---|---|
| Support sheet | `shopapp://support` | Immediate | `SupportModel` has no <br>preloaded data requirement |
| Rate Order sheet | `shopapp://rate-order` <BR>`/<order-uuid>` | Async | Must fetch `PastOrder` <br>by UUID before setting `.rateOrder(order)` |

```swift
// Immediate
model.destination = .support

// Async
let order = try await pastPurchasesRepository.fetchOrder(id: uuid)
model.destination = .rateOrder(order)
```

---

## Store

Tab: `.store`. Feature destination on `AppModel.storeModel.destination`.

| State | URL | Category | Notes |
|---|---|---|---|
| Store (idle) | `shopapp://store` | Immediate | Lands on loading state; <br>`load()` fires via `.task` |
| Store filtered by category | `shopapp://store?` <BR>`category=Electronics` | Immediate | Set `storeModel.selectedCategory` after load |
| Product detail | `shopapp://store` <BR>`/product/<uuid>` | Async | Fetch `StoreProduct` by UUID, <br>then set `.productDetail(product)` |
| Category filter sheet | `shopapp://store` <BR>`/filter` | Immediate | Set `.categoryFilter`; products must be <br>loaded to populate the list |

```swift
model.selectedTab = .store

switch path {
case "/filter":
    model.storeModel.destination = .categoryFilter

case _ where path.hasPrefix("/product/"):
    let product = try await storeRepository.fetchProduct(id: uuid)
    model.storeModel.destination = .productDetail(product)

default:
    if let category = queryItems["category"] {
        // storeModel.load() fires via .task; observe loadState to apply filter after load
        model.storeModel.selectedCategory = category
    }
}
```

**Note:** `selectedCategory` and `destination = .productDetail` both require products to be loaded first. The `.task` on `StoreView` triggers `load()` automatically, but the destination should only be set after `loadState` transitions to `.loaded`.

---

## Search

Tab: `.search`. Feature destination on `AppModel.searchModel.destination`.

| State | URL | Category | Notes |
|---|---|---|---|
| Search (idle) | `shopapp://search` | Immediate | |
| Search with pre-filled query | `shopapp://search?` <BR>`q=macbook` | Immediate | Set `searchModel.query`; <br>caller triggers `search()` |
| Filters sheet | `shopapp://search` <BR>`/filters` | Immediate | Set `.filters` |
| Category browse | `shopapp://search` <BR>`/category/Electronics` | Immediate | Set `.categoryBrowse("Electronics")` — <br>value is in the URL path |
| Product detail | `shopapp://search` <BR>`/product/<uuid>` | Async | Fetch `SearchProduct` by UUID, <br>then set `.productDetail(product)` |

```swift
model.selectedTab = .search

switch path {
case "/filters":
    model.searchModel.destination = .filters

case _ where path.hasPrefix("/category/"):
    let category = String(path.dropFirst("/category/".count))
    model.searchModel.destination = .categoryBrowse(category)

case _ where path.hasPrefix("/product/"):
    let product = try await searchRepository.fetchProduct(id: uuid)
    model.searchModel.destination = .productDetail(product)

default:
    if let query = queryItems["q"] {
        model.searchModel.query = query
        await model.searchModel.search()
    }
}
```

---

## Checkout

Tab: `.cart`. Feature destination on `AppModel.checkoutModel.destination`.

| State | URL | Category | Notes |
|---|---|---|---|
| Cart | `shopapp://cart` | Immediate | Shows cart contents as currently <br>in memory |
| Address form | `shopapp://cart` <BR>`/address` | Immediate | Only meaningful if cart is non-empty |
| Order options | `shopapp://cart` <BR>`/options?address` <BR>`=<uuid>` | Async | Fetch `ShippingAddress` by UUID <br>from saved addresses |
| Payment method selection | `shopapp://cart` <BR>`/payment-method?address` <BR>`=<uuid>` | Async | Same address fetch as above |
| Payment entry | `shopapp://cart` <BR>`/payment?address` <BR>`=<uuid>` | Async | Same address fetch as above |
| Order confirmation | `shopapp://cart` <BR>`/confirmation?order` <BR>`=<uuid>` | Async | Fetch `PlacedOrder` from past purchases by UUID |
| ~~Processing~~ | — | **Not linkable** | In-flight network state; meaningless outside <br>an active submission |
| ~~Payment failed~~ | — | **Not linkable** | Error state tied to a specific failed attempt; <br>cannot be reproduced from a URL |

```swift
model.selectedTab = .cart

switch path {
case "/address":
    model.checkoutModel.path = [.address]

case "/options":
    let address = savedAddresses.first(where: { $0.id == addressUUID })
        ?? (try await accountRepository.fetchAddresses()).first(where: { $0.id == addressUUID })
    model.checkoutModel.path = [.address, .orderOptions(address)]

case "/payment-method":
    let address = try await resolveAddress(uuid: addressUUID)
    model.checkoutModel.path = [.address, .orderOptions(address), .paymentMethod(address)]

case "/payment":
    let address = try await resolveAddress(uuid: addressUUID)
    model.checkoutModel.path = [.address, .orderOptions(address), .paymentMethod(address), .paymentEntry(address)]

case "/confirmation":
    let order = try await pastPurchasesRepository.fetchOrder(id: orderUUID)
    // PlacedOrder and PastOrder are different types — a mapping step is needed
    model.checkoutModel.destination = .confirmation(placedOrder)

default: break
}
```

**Note:** `.confirmation(PlacedOrder)` takes a `PlacedOrder`, but what is persisted after checkout is a `PastOrder`. A deep link to the confirmation screen would require either storing `PlacedOrder` separately (it is currently discarded after `onOrderPlaced` fires) or navigating to the order detail in `PastPurchasesView` instead, which holds equivalent information.

---

## Account

Tab: `.account`. Feature destination on `AppModel.accountModel.destination`.

`AccountModel.load()` is async; `editProfile` carries the loaded `UserProfile`. The profile must be loaded before `.editProfile` can be set.

| State | URL | Category | Notes |
|---|---|---|---|
| Account | `shopapp://account` | Immediate | `load()` fires via `.task` |
| Edit profile | `shopapp://account` <BR>`/edit-profile` | Async | `load()` must complete; <BR>then `showEditProfile()` guards on `profile != nil` |
| Add address | `shopapp://account` <BR>`/add-address` | Immediate | `destination = .addAddress`; no data dependency |
| Saved cards | `shopapp://account` <BR>`/cards` | Immediate | `destination = .savedCards`; no data dependency |

```swift
model.selectedTab = .account

switch path {
case "/edit-profile":
    await model.accountModel.load()
    model.accountModel.showEditProfile() // no-op if profile is nil

case "/add-address":
    model.accountModel.destination = .addAddress

case "/cards":
    model.accountModel.destination = .savedCards

default: break
}
```

---

## Past Purchases

Tab: `.orders`. Feature destination on `AppModel.pastPurchasesModel.destination`.

| State | URL | Category | Notes |
|---|---|---|---|
| Orders list | `shopapp://orders` | Immediate | `load()` fires via `.task` |
| Order detail | `shopapp://orders` <BR>`/<order-uuid>` | Async | Fetch `PastOrder` by UUID, then set `.orderDetail(order)` |

```swift
model.selectedTab = .orders

if let uuid {
    let order = try await pastPurchasesRepository.fetchOrder(id: uuid)
    model.pastPurchasesModel.destination = .orderDetail(order)
}
```

---

## Support

Support is presented as a sheet from the root (`AppModel.destination = .support`) rather than as a tab. The `SupportModel` itself has one destination.

| State | URL | Category | Notes |
|---|---|---|---|
| Support sheet | `shopapp://support` | Immediate | Sets `AppModel.destination = .support` |
| Support topic | `shopapp://support` <BR>`/<topic-slug>` | Immediate | `SupportTopic` is an enum; map slug to case |

`SupportTopic` cases would need stable URL slugs:

```swift
extension SupportTopic {
    init?(slug: String) {
        switch slug {
        case "live-chat":       self = .liveChat
        case "returns":         self = .returns
        case "faq":             self = .faq
        // … remaining cases
        default: return nil
        }
    }
}
```

```swift
model.destination = .support

if let slug = pathComponents.first,
   let topic = SupportTopic(slug: slug) {
    model.supportModel.destination = .topic(topic)
}
```

---

## Promotions

Promotions are not currently a tab in `AppModel.Tab`. `PromotionsView` is only accessible from the standalone `PromotionsApp` micro-app. Adding a promotions tab or embedding it inside an existing tab would be a prerequisite for this deep link to work in the main app.

| State | URL | Category | Notes |
|---|---|---|---|
| Promotion detail | `shopapp://promotions` <BR>`/<promo-uuid>` | Async | Fetch `Promotion` <BR>by UUID, then set `.promotionDetail(promotion)` |

---

## Suggestions

`SuggestionsView` is embedded inside `StoreView` as an interleaved strip — it is not a standalone navigable destination. A tap on a suggestion pushes onto `StoreView`'s `NavigationStack`.

| State | URL | Category | Notes |
|---|---|---|---|
| Suggested product detail | `shopapp://store` <BR>`/suggestion/<uuid>` | Async | Fetch `SuggestedProduct` by UUID, set `suggestionsModel.destination ` <BR>`= .productDetail(product)` and `selectedTab = .store` |

---

## Implementation sketch

The full router would live in `ShopCore` so it has access to `AppModel` and all repository protocols.

```swift
public struct DeepLinkRouter {
    let model: AppModel
    let storeRepository:         any StoreRepositoryProtocol
    let searchRepository:        any SearchRepositoryProtocol
    let accountRepository:       any AccountRepositoryProtocol
    let pastPurchasesRepository: any PastPurchasesRepositoryProtocol
    let suggestionsRepository:   any SuggestionsRepositoryProtocol

    public func handle(_ url: URL) async {
        guard url.scheme == "shopapp" else { return }
        let components  = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems  = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap {
                $0.value.map { ($0.name, $0) }
            }
        )
        let pathParts = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "store":   await handleStore(pathParts, query: queryItems)
        case "search":  await handleSearch(pathParts, query: queryItems)
        case "cart":    await handleCart(pathParts, query: queryItems)
        case "account": await handleAccount(pathParts)
        case "orders":  await handleOrders(pathParts)
        case "support": handleSupport(pathParts)
        case "rate-order": await handleRateOrder(pathParts)
        default: break
        }
    }
}
```

### Entry point in `ShopAppMain`

```swift
var body: some Scene {
    WindowGroup {
        RootView(model: appModel)
            .onOpenURL { url in
                Task { await router.handle(url) }
            }
    }
}
```

---

## Summary table

| Module | Immediate states | Async states | Not linkable |
|---|---|---|---|
| AppModel tabs | 5 | — | — |
| AppModel destinations | 1 (support) | 1 (rateOrder) | — |
| Store | 2 (idle, filter sheet) | 1 (productDetail) | — |
| Search | 3 (idle, filters, categoryBrowse) | 1 (productDetail) | — |
| Checkout | 2 (cart, addressForm) | 3 (orderOptions, paymentMethod, paymentEntry) | 2 (processing, paymentFailed) |
| Account | 3 (account, addAddress, savedCards) | 1 (editProfile) | — |
| Past Purchases | 1 (orders list) | 1 (orderDetail) | — |
| Support | 2 (sheet, topic) | — | — |
| Promotions | — | 1 (promotionDetail) | — |
| Suggestions | — | 1 (productDetail via store) | — |

**Totals: 19 immediate · 10 async · 2 not linkable**

The two not-linkable states (`.processing`, `.paymentFailed`) are transient — they only make sense mid-funnel and cannot be meaningfully reproduced from a URL.
