import PastPurchases

public extension PastPurchasesModel {
    convenience init() {
        self.init(repository: StubPastPurchasesRepository())
    }
}
