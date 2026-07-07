import SwiftUI
import Search

@main
struct SearchApp: App {
    // Micro-app entry point for the Search module.
    // Uses StubSearchRepository so the app runs without a live backend.
    var body: some Scene {
        WindowGroup {
            SearchView(model: SearchModel(repository: StubSearchRepository()))
        }
    }
}
