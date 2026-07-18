import Suggestions

public extension SuggestionsModel {
    convenience init() {
        self.init(repository: StubSuggestionsRepository())
    }
}
