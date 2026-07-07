import SwiftUI
import DesignSystem

struct OrderProcessingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text(Strings.title)
                .font(.headline)
            Text(Strings.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
    }
}

// MARK: - Strings

private enum Strings {
    static let title    = "Processing your order…"
    static let subtitle = "Please don't close this screen."
}
