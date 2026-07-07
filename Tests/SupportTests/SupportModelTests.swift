import Testing
import Foundation
@testable import Support

@Suite("SupportModel — Unit Tests")
struct SupportModelTests {

    @Test("Initial destination is nil")
    func initialDestinationNil() {
        #expect(SupportModel().destination == nil)
    }

    @Test("select sets destination to topic for every SupportTopic case", arguments: SupportTopic.allCases)
    func selectSetsTopic(topic: SupportTopic) {
        let model = SupportModel()
        model.select(topic)
        #expect(model.destination == .topic(topic))
    }

    @Test("Selecting a different topic replaces the destination")
    func selectingDifferentTopicReplaces() {
        let model = SupportModel()
        model.select(.liveChat)
        model.select(.returns)
        #expect(model.destination == .topic(.returns))
    }

    @Test("Dismissing destination returns it to nil")
    func dismissingDestination() {
        let model = SupportModel()
        model.select(.faq)
        model.destination = nil
        #expect(model.destination == nil)
    }
}
