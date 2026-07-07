import SwiftUI
import Promotions

@main
struct PromotionsApp: App {
    var body: some Scene {
        WindowGroup {
            PromotionsView(model: PromotionsModel(repository: StubPromotionsRepository()))
        }
    }
}
