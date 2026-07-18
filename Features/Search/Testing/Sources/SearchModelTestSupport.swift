import Search

public extension SearchModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubSearchRepository(), destination: destination)
    }
}
