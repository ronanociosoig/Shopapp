import SwiftUI
import Suggestions
import SuggestionsTesting

@main
struct SuggestionsApp: App {
    var body: some Scene {
        WindowGroup {
            SuggestionsContainerView(model: SuggestionsModel(
                repository: StubSuggestionsRepository()
            ))
        }
    }
}
