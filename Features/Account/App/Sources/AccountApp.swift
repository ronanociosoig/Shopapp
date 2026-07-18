import SwiftUI
import Account
import AccountTesting

@main
struct AccountApp: App {
    var body: some Scene {
        WindowGroup {
            AccountView(model: AccountModel(repository: StubAccountRepository()))
        }
    }
}
