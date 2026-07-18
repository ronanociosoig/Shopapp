import PastPurchases

public extension PastPurchasesModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubPastPurchasesRepository(), destination: destination)
    }
}
