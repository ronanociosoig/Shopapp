#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Support

// MARK: - CaseIterable conformance

extension SupportModel.Destination: CaseIterable {
    public static var allCases: [SupportModel.Destination] {
        SupportTopic.allCases.map { .topic($0) }
    }
}

// MARK: - Snapshot Tests

@Suite("Support — Snapshot Tests")
@MainActor
struct SupportSnapshotTests {

    @Test("Support view renders correctly in its initial state")
    func initialState() async throws {
        let model = SupportModel()
        assertSnapshot(
            of: SupportView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_initial"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: SupportModel.Destination.allCases
    )
    func destination(_ destination: SupportModel.Destination) async throws {
        let model = SupportModel()
        model.destination = destination
        assertSnapshot(
            of: SupportView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ destination: SupportModel.Destination) -> String {
    switch destination {
    case .topic(let topic): return "destination_topic_\(topic.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
}
#endif
