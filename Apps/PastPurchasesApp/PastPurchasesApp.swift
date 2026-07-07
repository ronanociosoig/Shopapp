import SwiftUI
import PastPurchases

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
