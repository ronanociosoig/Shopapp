import SwiftUI
import Support

@main
struct SupportApp: App {
    var body: some Scene {
        WindowGroup {
            SupportView(model: SupportModel())
        }
    }
}
