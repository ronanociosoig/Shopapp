import SwiftUI
import Search
import SearchScenarios

@main
struct SearchApp: App {
    var body: some Scene {
        WindowGroup {
            SearchScenarioRootView()
        }
    }
}

/// Micro-app entry point for the Search module. Consumes scenarios, not
/// screens: picking a scenario from the menu rebuilds the model via
/// `SearchScenarioBuilder`, the same way any consumer of `SearchScenarios`
/// would — this app has no special access `SearchScenarios` doesn't offer.
///
/// The picker is an overlay, not a `.toolbar` item: `SearchView` owns its
/// own internal `NavigationStack`, and a `.toolbar` modifier applied from
/// outside that call doesn't reliably attach to a `NavigationStack` hidden
/// inside a child view — confirmed empirically (it silently didn't render)
/// before switching to this approach.
private struct SearchScenarioRootView: View {
    @State private var scenario: SearchScenario = .launch
    @State private var model = SearchScenarioBuilder().makeModel(for: .launch)

    var body: some View {
        SearchView(model: model)
            .overlay(alignment: .bottom) {
                Menu {
                    ForEach(SearchScenario.allCases) { scenario in
                        Button(scenario.title) { select(scenario) }
                    }
                } label: {
                    Label("Scenario: \(scenario.title)", systemImage: "theatermasks")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: Capsule())
                }
                .padding(.bottom, 90)
            }
    }

    private func select(_ scenario: SearchScenario) {
        self.scenario = scenario
        model = SearchScenarioBuilder().makeModel(for: scenario)
    }
}
