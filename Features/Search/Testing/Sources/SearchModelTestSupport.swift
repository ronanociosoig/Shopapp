import Search

public extension SearchModel {
    convenience init() {
        self.init(repository: StubSearchRepository())
    }
}
