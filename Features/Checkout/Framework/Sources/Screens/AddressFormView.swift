import SwiftUI
import DesignSystem

struct AddressFormView: View {
    let model: CheckoutModel

    var body: some View {
        Group {
            if model.savedAddresses.isEmpty {
                emptyState
            } else {
                addressList
            }
        }
        .navigationTitle(Strings.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !model.savedAddresses.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.continueButton) {
                        if let address = model.selectedAddress {
                            model.submitAddress(address)
                        }
                    }
                    .disabled(model.selectedAddress == nil)
                }
            }
        }
    }

    // MARK: - Address list

    private var addressList: some View {
        List(model.savedAddresses) { address in
            Button {
                model.selectAddress(address)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(address.fullName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(address.formatted)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: model.selectedAddressID == address.id
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.title3)
                        .foregroundStyle(model.selectedAddressID == address.id
                                         ? Color.dsPrimary
                                         : Color.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            Strings.emptyTitle,
            systemImage: "mappin.and.ellipse",
            description: Text(Strings.emptyDescription)
        )
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle  = "Shipping Address"
    static let continueButton   = "Continue"
    static let emptyTitle       = "No saved addresses"
    static let emptyDescription = "Add a shipping address in the Account tab to continue."
}
