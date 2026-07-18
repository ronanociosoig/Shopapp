import Account

public extension AccountModel {
    convenience init() {
        self.init(repository: StubAccountRepository())
    }
}
