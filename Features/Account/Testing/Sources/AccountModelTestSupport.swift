import Account

public extension AccountModel {
    convenience init(destination: Destination? = nil) {
        self.init(repository: StubAccountRepository(), destination: destination)
    }
}
