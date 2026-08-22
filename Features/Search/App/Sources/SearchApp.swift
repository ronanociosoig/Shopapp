import SwiftUI
import Search

@main
struct SearchApp: App {
    var body: some Scene {
        WindowGroup {
            ScenarioListView()
        }
    }
}

/// Micro-app entry point for the Search module. The root screen is a list of
/// scenarios, not a single hardcoded screen — picking one opens the real
/// `SearchView` already configured in that state, via `SearchScenarioBuilder`.
///
/// Navigation follows the same convention as every feature model in this
/// project (see AGENTS.md): one optional selection driving
/// `.navigationDestination(item:)`, never `NavigationLink(destination:)`.
private struct ScenarioListView: View {
    @State private var selectedScenario: SearchScenario?

    var body: some View {
        NavigationStack {
            List(SearchScenario.allCases) { scenario in
                Button(scenario.title) { selectedScenario = scenario }
            }
            .navigationTitle("Search Scenarios")
            .navigationDestination(item: $selectedScenario) { scenario in
                SearchView(model: SearchScenarioBuilder().makeModel(for: scenario))
            }
        }
    }
}
