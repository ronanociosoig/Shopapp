import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct SupportView: View {
    @Bindable public var model: SupportModel

    public init(model: SupportModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(Strings.contactSection) {
                    ForEach(SupportTopic.allCases.filter { $0.section == Strings.contactSection }) { topic in
                        Button {
                            model.select(topic)
                        } label: {
                            Label(topic.rawValue, systemImage: topic.systemImage)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                Section(Strings.selfServiceSection) {
                    ForEach(SupportTopic.allCases.filter { $0.section == Strings.selfServiceSection }) { topic in
                        Button {
                            model.select(topic)
                        } label: {
                            Label(topic.rawValue, systemImage: topic.systemImage)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle(Strings.navigationTitle)
            .navigationDestination(item: $model.destination.topic) { topic in
                SupportTopicView(topic: topic)
            }
        }
    }
}

// MARK: - Detail view

struct SupportTopicView: View {
    let topic: SupportTopic

    var body: some View {
        List {
            Section {
                Label(topic.rawValue, systemImage: topic.systemImage)
                    .font(.headline)
                    .foregroundStyle(.dsPrimary)
            }
            Section(Strings.helpPrompt) {
                Text(Strings.topicPlaceholder(topic.rawValue))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(topic.rawValue)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle   = "Support"
    static let contactSection    = "Contact"
    static let selfServiceSection = "Self-service"
    static let helpPrompt        = "What would you like help with?"
    static func topicPlaceholder(_ topic: String) -> String {
        "Support content for \"\(topic)\" will appear here."
    }
}
