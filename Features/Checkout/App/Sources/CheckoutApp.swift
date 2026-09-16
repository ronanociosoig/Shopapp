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
/// `CheckoutView` already configured in that state, via `CheckoutScenarioFactory`.
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
            ScenarioPreview(scenario: scenario)
        }
    }
}

/// Wraps the real `CheckoutView` with a way back to the scenario list.
/// `CheckoutView` has no dismiss affordance of its own — it doesn't need one
/// in the real app, where it's a permanent tab, never something presented
/// modally over other content. `fullScreenCover` also has no built-in
/// swipe-to-dismiss on iOS (unlike `.sheet`), so without this, restarting
/// the micro-app was the only way back to the list.
///
/// The way back lives in a dedicated strip above `CheckoutView`, not an
/// overlay on top of it — every funnel screen already has its own
/// navigation-bar buttons in both top corners (an automatic back button on
/// pushed screens, "Continue"/"Pay now" as the trailing action), so a
/// floating button in either corner sits exactly where a real button
/// already is and can steal its tap. A strip is real layout space, not
/// shared with anything `CheckoutView` draws, so it can never collide.
private struct ScenarioPreview: View {
    let scenario: CheckoutScenario
    @Environment(\.dismiss) private var dismiss

    // Built once, in `init`, and held in `@State` — not recomputed inline in
    // `body`. `body` re-evaluates more than once over this view's lifetime
    // (the nested `.confirmation` cover presenting is enough to trigger it,
    // via an environment change), and recomputing the model inline on every
    // pass would hand `CheckoutView` a brand-new `CheckoutModel` each time —
    // discarding whatever state the previous one was in, including the
    // `.confirmation` destination `submitPayment()` had just set.
    @State private var model: CheckoutModel

    init(scenario: CheckoutScenario) {
        self.scenario = scenario
        _model = State(initialValue: CheckoutScenarioFactory().makeModel(for: scenario))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Scenarios", systemImage: "chevron.left")
                }
                Spacer()
                Text(scenario.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            CheckoutView(model: model)
        }
    }
}
