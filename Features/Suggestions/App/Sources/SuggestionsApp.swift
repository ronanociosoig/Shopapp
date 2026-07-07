import SwiftUI
import Suggestions

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
