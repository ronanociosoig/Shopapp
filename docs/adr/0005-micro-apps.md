# ADR-0005: Each feature module has a standalone micro-app

**Date:** 2026-07-18  
**Status:** Accepted · amended 2026-08-31

## Context

Developing and testing a feature inside the full ShopApp means building the entire application graph — all eight feature modules, the composition root, and all of their dependencies — before a single line of the target feature executes. This is slow to iterate on and forces developers to navigate from the app entry point to reach deep screens.

Unit tests address logic in isolation, but they do not exercise the UI. A developer working on the Checkout payment screen ideally wants to launch it directly, at any step in the funnel, with pre-populated state, without running the full app.

## Decision

Each feature module provides a standalone executable target in `Features/Xxx/App/`. This is an `@main` SwiftUI `App` struct that imports only the feature's own production target and, where one exists, its companion `XxxTesting` target (`Support` has none — it has no repository, see ADR-0011):

```swift
// Features/Checkout/App/Sources/CheckoutApp.swift
import SwiftUI
import Checkout
import CheckoutTesting

@main
struct CheckoutApp: App {
    var body: some Scene {
        WindowGroup {
            CheckoutView(model: {
                let model = CheckoutModel(
                    cart: CartItem.stubs,
                    repository: StubCheckoutRepository(delay: .zero)
                )
                model.savedAddresses = [.stub]
                return model
            }())
        }
    }
}
```

Micro-apps use stub repositories from `XxxTesting` (ADR-0006) to run without a live backend. State can be pre-populated to make any screen of the flow immediately reachable — the Checkout micro-app starts with a cart and a saved address so every step of the funnel is accessible with one tap.

Each micro-app maps to a separate Xcode scheme in `project.yml`, making it runnable directly from the scheme switcher.

### Single screen vs. scenario catalog

The example above launches straight into one screen. For a feature with several
distinct meaningful states — a funnel, a search that can be empty / loaded / failed —
the micro-app's root is instead a **scenario catalog**: a `CaseIterable` `XxxScenario`
enum and an `XxxScenarioFactory` that maps each case to a fully-configured model,
presented as a pickable list so a developer (or an agent) can jump to any state in one
tap. `SearchApp` and `CheckoutApp` work this way today; the remaining micro-apps are
still single-screen. The catalog, and the `XxxAppTests` that assert each scenario still
produces the business state it claims, are covered in ADR-0014.

## Consequences

**Positive**

- A feature can be built and run in the simulator without compiling unrelated modules.
- Pre-populated state eliminates the setup steps needed to reach deep screens manually.
- `delay: .zero` in stub repositories makes processing steps instant, removing artificial waits during manual testing.
- Micro-apps serve as living documentation of the feature's entry point and required dependencies.
- The pattern supports agentic validation: an AI agent can launch the Search micro-app and validate the search flow independently of the rest of the application.

**Negative**

- Each micro-app requires its own `Info.plist` and Xcode scheme, adding maintenance overhead.
- State pre-population in the micro-app must be kept in sync with the real data shapes as models evolve.
- Micro-apps do not exercise cross-module behaviour (e.g. add-to-cart routing to Checkout), because the composition root is absent. That coverage belongs to integration and snapshot tests on `AppModel`.
