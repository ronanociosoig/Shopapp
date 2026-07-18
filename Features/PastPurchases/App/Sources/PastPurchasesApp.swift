import SwiftUI
import PastPurchases
import PastPurchasesTesting

@main
struct PastPurchasesApp: App {
    var body: some Scene {
        WindowGroup {
            PastPurchasesView(model: PastPurchasesModel(
                repository: StubPastPurchasesRepository()
            ))
        }
    }
}
