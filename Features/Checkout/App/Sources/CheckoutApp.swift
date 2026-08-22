import SwiftUI
import Checkout

@main
struct CheckoutApp: App {
    var body: some Scene {
        WindowGroup {
            ScenarioListView()
        }
    }
}

/// Micro-app entry point for the Checkout module. The root screen is a list of
/// scenarios, not a single hardcoded funnel state — picking one opens the real
/// `CheckoutView` already configured in that state, via `CheckoutScenarioBuilder`.
///
/// Navigation follows the same convention as every feature model in this
/// project (see AGENTS.md): one optional selection property drives the
/// presentation, never `NavigationLink(destination:)`. It's a full-screen
/// cover rather than a `navigationDestination(item:)` push, deliberately:
/// `CheckoutView` owns its own internal `NavigationStack` (for the funnel), and
/// nesting that as a *pushed* destination inside this list's own NavigationStack
/// silently no-ops the push — confirmed with a real tap via `CheckoutAppUITests`,
/// not just a screenshot. A cover gives `CheckoutView`'s stack its own
/// presentation context instead of nesting it, which also better matches what a
/// scenario actually is: launching straight into that state, not drilling down
/// from the list.
private struct ScenarioListView: View {
    @State private var selectedScenario: CheckoutScenario?

    var body: some View {
        NavigationStack {
            List(CheckoutScenario.allCases) { scenario in
                Button(scenario.title) { selectedScenario = scenario }
            }
            .navigationTitle("Checkout Scenarios")
        }
        .fullScreenCover(item: $selectedScenario) { scenario in
            CheckoutView(model: CheckoutScenarioBuilder().makeModel(for: scenario))
        }
    }
}
