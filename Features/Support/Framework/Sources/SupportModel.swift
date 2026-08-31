import Observation
import SwiftUINavigation

@MainActor
@Observable
public final class SupportModel {
    public var destination: Destination?

    public init() {}

    @CasePathable
    public enum Destination: Equatable, Sendable {
        case topic(SupportTopic)
    }

    public func select(_ topic: SupportTopic) {
        destination = .topic(topic)
    }
}
