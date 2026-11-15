---
name: shopapp-module-boundaries-and-deeplinks
description: Rules and definitions for ShopApp module public API (minimal surface, @_spi groups, factories returning some View, dependency structs, module-scoped Environment keys) and feature-decoded deep links (Destination enum, host-only routing in AppModel, debug-only agent routes, micro-app schemes). Use when adding or changing a feature module's public surface, a factory, an @_spi import, a deep link, or a micro-app entry point in ShopApp.
---

# ShopApp module boundaries and deep links

Rules for module public API and deep links, as used in the ShopApp reference implementation. The
canonical rules file is `AGENTS.md`, and the decisions behind these rules are in `docs/adr/`
(ADR-0001, 0003, 0007, 0015 are the most relevant). If this skill and those disagree, they win.

## Definitions

- **Public API of a feature module**: its repository protocol, its factory protocol, and the data
  types those require. Nothing else is public by default.
- **Micro-app**: an installable `@main` app target for one feature (`Features/<Name>/App/`). It
  imports only that feature's production and `<Name>Testing` targets, so a screen can be iterated
  on without launching the full app.
- **`@_spi(Group)`**: a Swift attribute that makes a declaration public to the compiler but
  invisible to ordinary consumers (no autocomplete, no API diff entry, compile error without the
  import). Each group names one caller type. Current groups:
  - `@_spi(Internals)`: `CheckoutTesting` and composition-root snapshot tests constructing models
    and injecting dependencies.
  - `@_spi(Scenarios)`: a micro-app reaching screens a user could not produce in one step.
- **`Destination`**: one `@CasePathable` enum per model owning navigation, with one case per
  reachable screen, sheet, or cover. Exposed as a single `var destination: Destination?`.
- **Deep link**: a URL that lands a user or a test on a screen without walking the taps.
- **Debug-only route**: a deep link case or launch argument compiled only under `#if DEBUG`.

## Module public API

1. **A View is never the seam.** Do not declare a protocol that requires `body`
   (`protocol XViewing: View`). `View` has `associatedtype Body`, so such a protocol cannot unify
   concrete types behind `any`. Put the seam at the repository or the factory.
   ```swift
   // Correct
   public protocol CheckoutFactory {
       associatedtype CheckoutContent: View
       func makeCheckout() -> CheckoutContent
   }
   // Never
   protocol CheckoutViewing: View { }
   ```
2. **Return `some View` from a concrete factory method, never `AnyView`.** `AnyView` erases the
   static type SwiftUI diffing needs to tell an update from a replacement. `some View` does not
   erase anything at runtime.
3. **Keep the public surface minimal.** Every `public` is a contract. For each one, name the
   consumer it serves. Mark a type `@_spi(Group)` when the only callers are test or micro-app
   targets; leave it internal when only the module itself needs it.
4. **Expose navigation state internally.** Model state such as `cart` and `path` stays `internal`.
   Tests reach it with `@testable import`. Use `@_spi` only for the one door `@testable` cannot
   open, such as `@_spi(Internals) @testable import Checkout` in a composition-root test.
5. **A model's designated initializer is `@_spi(Internals)`, not `public`**, once a factory is the
   intended entry point.
6. **The composition root never imports a feature via `@_spi`.** `AppModel` and `RootView` import
   the feature normally and see only the factory. An `@_spi` import there means something reached
   past the front door.
7. **Package dependencies as one explicit struct per module.** `CheckoutDependencies` holds only
   what Checkout needs. Do not introduce an `AppDependencies` god object.
8. **Environment keys defined for one module stay internal.** Use a `private struct ...:
   EnvironmentKey` with an internal accessor on `EnvironmentValues`. Never a shared public key for
   an app-wide dependency bag. A missing `.environment(...)` silently falls back to `defaultValue`,
   so do not put anything the module must have set correctly there.
9. **Build the boundary before optimising CI.** Selective testing depends on API discipline. A
   bloated API target forces rebuilds of every consumer.
10. **Add a second-level composition root only when a feature has grown.** A single developer does
    not need a factory between `AppModel` and `CheckoutView`. Add each boundary once you can name
    the specific caller it protects.

## Deep links

1. **The composition root reads only the host.** `AppModel.handle(url:)`
   (`Shop/Framework/Sources/AppModel+DeepLinks.swift`) uses `url.host` to choose a feature and
   passes the whole URL to that feature. It never parses a path segment, never reads an id, and
   never constructs a feature's `Destination`.
   ```swift
   // Correct
   case "promotions":
       if await promotionsModel.handleDeepLink(url: url) {
           selectedTab = .store
       }

   // Never
   case "promotions":
       promotionsModel.destination = .promotionDetail(Promotion(id: id, title: ..., ...))
   ```
2. **Each feature decodes its own URL.** It exposes one public method that takes the `URL`, decodes
   its own path segments, and is the only code outside the feature allowed to produce its
   `Destination`. A feature that adds routes changes its own decoding, not the composition root.
3. **The feature's entry point follows its existing public API.** Do not invent a uniform
   `DeepLinkable` protocol. `CheckoutFactory` already is the contract, so Checkout's deep-link
   entry point belongs there. Add a factory only when a feature needs one for a real caller.
4. **The `Bool` return answers "is this URL shaped like a link this feature accepts?"** The
   composition root switches tabs only on `true`. A well-formed link that matches nothing, or that is
   refused for a state reason (for example, delivery options with no address yet), still returns
   `true`, because the link belongs to the feature. Only a URL the feature doesn't recognize returns
   `false`.
5. **Test the failure path with the same care as success.** Name tests for what they prove
   (`unknownOrderID`, `checkoutDeliveryDeepLinkEmptyCart`), not for the method they call.
6. **Gate deep links by build configuration, not by convention.** Routes that open unrestricted
   state are wrapped in `#if DEBUG`. Nothing should let a URL bypass a login or paywall.
7. **Launch arguments are an alternative to URL schemes.** A debug-only
   `--agent-route <feature>/<rest>` argument, read from `ProcessInfo.processInfo.arguments`, routes
   the same way with no registered URL scheme. Keep it under `#if DEBUG`. Where it is present in
   the code, it dispatches to the feature named by its first segment.
8. **Micro-app deep links use their own scheme.** `checkoutscenarios://<CheckoutScenario rawValue>`
   names one scenario. There is no feature-selecting host, because the micro-app serves one
   feature. An unknown or host-less URL decodes to `nil` and does nothing.
