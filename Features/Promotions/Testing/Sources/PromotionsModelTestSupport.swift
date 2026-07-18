import Promotions

public extension PromotionsModel {
    convenience init() {
        self.init(repository: StubPromotionsRepository())
    }
}
