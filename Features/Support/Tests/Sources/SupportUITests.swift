import Testing
import Foundation
@testable import Support

/// Tests that exercise complete user interaction flows through the Support module.
@Suite("Support — UI Interaction Tests")
@MainActor
struct SupportUITests {

    @Test("User selects each support topic", arguments: SupportTopic.allCases)
    func userSelectsTopic(topic: SupportTopic) {
        let model = SupportModel()
        model.select(topic)
        #expect(model.destination == .topic(topic))
    }

    @Test("User navigates to a topic and returns to the list")
    func userNavigatesToTopicAndBack() {
        let model = SupportModel()
        model.select(.faq)
        #expect(model.destination == .topic(.faq))
        model.destination = nil
        #expect(model.destination == nil)
    }

    @Test("User switches between topics")
    func userSwitchesBetweenTopics() {
        let model = SupportModel()
        model.select(.liveChat)
        #expect(model.destination == .topic(.liveChat))
        model.select(.returns)
        #expect(model.destination == .topic(.returns))
    }
}
