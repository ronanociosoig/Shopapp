import SwiftUI
import CheckoutAPI
import DesignSystem

struct PaymentFailedView: View {
    let error: PaymentError
    let onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: error.systemImage)
                .font(.system(size: 64))
                .foregroundStyle(Color.dsDestructive)

            VStack(spacing: 8) {
                Text(Strings.title)
                    .font(.title2.bold())
                Text(error.localizedDescription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                PrimaryButton(Strings.tryDifferentCard) {
                    dismiss()
                    onRetry()
                }
                Button(Strings.cancelOrder) { dismiss() }
                    .foregroundStyle(Color.dsDestructive)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Strings

private enum Strings {
    static let title           = "Payment Failed"
    static let tryDifferentCard = "Try a different card"
    static let cancelOrder     = "Cancel order"
}
