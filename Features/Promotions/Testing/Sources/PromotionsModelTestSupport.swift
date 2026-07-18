import Promotions

public extension PromotionsModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubPromotionsRepository(), destination: destination)
    }
}
