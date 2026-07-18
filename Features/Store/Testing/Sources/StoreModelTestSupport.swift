import Store

public extension StoreModel {
    convenience init() {
        self.init(repository: StubStoreRepository())
    }
}
