import SwiftUI

// MARK: - Loading

public struct DSLoadingView: View {
    public let message: String

    public init(message: String = "Loading…") {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error

public struct ErrorView: View {
    public let message: String
    public let retry: (() -> Void)?

    public init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry   = retry
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.dsDestructive)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let retry {
                Button(Strings.tryAgain, action: retry)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Primary Button

public struct DSPrimaryButton: View {
    public let title: String
    public let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title  = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.dsPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Price

public struct DSPriceLabel: View {
    public let amount: Decimal

    public init(_ amount: Decimal) {
        self.amount = amount
    }

    public var body: some View {
        Text(amount, format: .currency(code: "EUR"))
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - Strings

private enum Strings {
    static let defaultLoadingMessage = "Loading…"
    static let tryAgain              = "Try again"
}
