import Suggestions

public extension SuggestionsModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubSuggestionsRepository(), destination: destination)
    }
}
