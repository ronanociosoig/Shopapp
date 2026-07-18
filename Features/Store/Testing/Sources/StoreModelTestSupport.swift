import Store

public extension StoreModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubStoreRepository(), destination: destination)
    }
}
