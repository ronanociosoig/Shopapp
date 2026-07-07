import Observation
import SwiftUINavigation

@Observable
public final class SupportModel {
    public var destination: Destination?

    public init() {}

    @CasePathable
    public enum Destination: Equatable {
        case topic(SupportTopic)
    }

    public func select(_ topic: SupportTopic) {
        destination = .topic(topic)
    }
}
