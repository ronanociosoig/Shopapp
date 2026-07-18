import SwiftUI
import PastPurchases

public struct RateOrderView: View {
    let order: PastOrder
    @State private var rating = 0
    @State private var comment = ""
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Text(Strings.orderNumber(order.id.uuidString.prefix(8).uppercased()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(order.placedAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

                Section(Strings.overallRatingHeader) {
                    HStack(spacing: 12) {
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(star <= rating ? Color.yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section(Strings.commentsHeader) {
                    TextField(Strings.commentsPlaceholder, text: $comment, axis: .vertical)
                        .lineLimit(4...6)
                }
            }
            .navigationTitle(Strings.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.cancelButton) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.submitButton) { dismiss() }
                        .disabled(rating == 0)
                }
            }
        }
    }
}

private enum Strings {
    static let navigationTitle      = "Rate Your Order"
    static let overallRatingHeader  = "Overall Rating"
    static let commentsHeader       = "Comments (optional)"
    static let commentsPlaceholder  = "What did you think?"
    static let cancelButton         = "Cancel"
    static let submitButton         = "Submit"
    static func orderNumber(_ id: String) -> String { "Order #\(id)" }
}
