import SwiftUI
import CheckoutAPI
import DesignSystem

struct AddressFormView: View {
    let model: CheckoutModel
    @State private var searchText = ""

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
    }

    // MARK: - Address list

    /// Client-side only — filters the already-loaded `savedAddresses`, no model or
    /// repository involvement. A real multi-address account could outgrow a bare list,
    /// the same reasoning a Mail/Contacts picker already applies.
    private var filteredAddresses: [ShippingAddress] {
        guard !searchText.isEmpty else { return model.savedAddresses }
        return model.savedAddresses.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
                || $0.formatted.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var addressList: some View {
        VStack(spacing: 0) {
            subtitle
            searchField

            List(filteredAddresses) { address in
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
            .overlay {
                if filteredAddresses.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }

            continueButton
        }
    }

    private var subtitle: some View {
        Text(Strings.subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(Strings.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.dsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// Bottom-anchored, full-width — replaces the old `.confirmationAction` toolbar
    /// button per the DeliveryAddress Figma reference.
    private var continueButton: some View {
        VStack(spacing: 12) {
            Divider()
            PrimaryButton(Strings.continueButton) {
                if let address = model.selectedAddress {
                    model.submitAddress(address)
                }
            }
            .disabled(model.selectedAddress == nil)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.dsBackground)
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
    static let navigationTitle   = "Shipping Address"
    static let subtitle          = "Choose where you'd like your order delivered."
    static let searchPlaceholder = "Search addresses"
    static let continueButton    = "Use selected address"
    static let emptyTitle        = "No saved addresses"
    static let emptyDescription  = "Add a shipping address in the Account tab to continue."
}
