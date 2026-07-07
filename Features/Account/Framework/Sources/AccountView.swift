import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct AccountView: View {
    @Bindable public var model: AccountModel

    public init(model: AccountModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    DSLoadingView(message: Strings.loadingMessage)
                } else {
                    accountContent
                }
            }
            .navigationTitle(Strings.navigationTitle)
            .navigationDestination(item: $model.destination.editProfile) { profile in
                EditProfileView(profile: profile, model: model)
            }
            .navigationDestination(
                isPresented: Binding($model.destination.addAddress)
            ) {
                AddAddressView(model: model)
            }
            .navigationDestination(
                isPresented: Binding($model.destination.savedCards)
            ) {
                SavedCardsView(model: model)
            }
        }
        .task { await model.load() }
    }

    private var accountContent: some View {
        List {
            // Profile section
            if let profile = model.profile {
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.dsSurface)
                            .frame(width: 56, height: 56)
                            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName).font(.headline)
                            Text(profile.email).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(Strings.editButton) { model.showEditProfile() }
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Addresses section
            Section(Strings.savedAddressesHeader) {
                if model.addresses.isEmpty {
                    Text(Strings.noSavedAddresses)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.addresses) { address in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(address.fullName).font(.subheadline.weight(.medium))
                                if address.isDefault {
                                    Text(Strings.defaultLabel)
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.dsPrimary.opacity(0.12))
                                        .foregroundStyle(.dsPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(address.formatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { model.removeAddress(model.addresses[$0]) }
                    }
                }
                Button(Strings.addAddress) { model.showAddAddress() }
                    .foregroundStyle(.dsPrimary)
            }

            // Payment section
            Section(Strings.paymentMethodsHeader) {
                if model.cards.isEmpty {
                    Text(Strings.noSavedCards)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.cards) { card in
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundStyle(.dsPrimary)
                            Text(card.displayLabel)
                            Spacer()
                            if card.isDefault {
                                Text(Strings.defaultLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { model.removeCard(model.cards[$0]) }
                    }
                }
                Button(Strings.manageCards) { model.showSavedCards() }
                    .foregroundStyle(.dsPrimary)
            }

            Section {
                Button(Strings.signOut, role: .destructive) { }
            }
        }
    }
}

// MARK: - Sub-views

struct EditProfileView: View {
    let profile: UserProfile
    let model: AccountModel
    @State private var displayName: String

    init(profile: UserProfile, model: AccountModel) {
        self.profile = profile
        self.model   = model
        _displayName = State(initialValue: profile.displayName)
    }

    var body: some View {
        Form {
            Section(Strings.EditProfile.displayNameHeader) {
                TextField(Strings.EditProfile.namePlaceholder, text: $displayName)
            }
            Section(Strings.EditProfile.emailHeader) {
                Text(profile.email)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Strings.EditProfile.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Strings.EditProfile.saveButton) { model.destination = nil }
            }
        }
    }
}

struct AddAddressView: View {
    let model: AccountModel
    @State private var fullName   = ""
    @State private var line1      = ""
    @State private var city       = ""
    @State private var state      = ""
    @State private var postalCode = ""
    @State private var country    = Strings.AddAddress.defaultCountry

    var body: some View {
        Form {
            Section(Strings.AddAddress.recipientHeader) {
                TextField(Strings.AddAddress.fullNamePlaceholder, text: $fullName)
            }
            Section(Strings.AddAddress.addressHeader) {
                TextField(Strings.AddAddress.streetPlaceholder, text: $line1)
                TextField(Strings.AddAddress.cityPlaceholder, text: $city)
                HStack {
                    TextField(Strings.AddAddress.statePlaceholder, text: $state).frame(maxWidth: 100)
                    TextField(Strings.AddAddress.postcodePlaceholder, text: $postalCode)
                }
                Picker(Strings.AddAddress.countryPicker, selection: $country) {
                    ForEach(Strings.countries, id: \.self) { Text($0).tag($0) }
                }
            }
        }
        .navigationTitle(Strings.AddAddress.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Strings.AddAddress.saveButton) {
                    let address = SavedAddress(
                        fullName: fullName, line1: line1,
                        city: city, state: state, postalCode: postalCode,
                        country: country
                    )
                    model.addAddress(address)
                    model.destination = nil
                }
                .disabled(fullName.isEmpty || line1.isEmpty || city.isEmpty)
            }
        }
    }
}

struct SavedCardsView: View {
    let model: AccountModel

    var body: some View {
        List {
            ForEach(model.cards) { card in
                HStack {
                    Image(systemName: "creditcard").foregroundStyle(.dsPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.displayLabel).font(.subheadline.weight(.medium))
                        Text(Strings.SavedCards.expires(month: card.expiryMonth, year: card.expiryYear))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if card.isDefault { Image(systemName: "checkmark").foregroundStyle(.dsPrimary) }
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { model.removeCard(model.cards[$0]) }
            }
        }
        .navigationTitle(Strings.SavedCards.navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle      = "Account"
    static let loadingMessage       = "Loading account…"
    static let editButton           = "Edit"
    static let savedAddressesHeader = "Saved Addresses"
    static let noSavedAddresses     = "No saved addresses"
    static let defaultLabel         = "Default"
    static let addAddress           = "Add Address"
    static let paymentMethodsHeader = "Payment Methods"
    static let noSavedCards         = "No saved cards"
    static let manageCards          = "Manage Cards"
    static let signOut              = "Sign Out"
    static let countries = [
        "Australia", "Canada", "France", "Germany", "Ireland",
        "Italy", "Netherlands", "Spain", "United Kingdom", "United States",
    ]

    enum EditProfile {
        static let navigationTitle   = "Edit Profile"
        static let displayNameHeader = "Display Name"
        static let namePlaceholder   = "Name"
        static let emailHeader       = "Email"
        static let saveButton        = "Save"
    }

    enum AddAddress {
        static let navigationTitle     = "Add Address"
        static let recipientHeader     = "Recipient"
        static let addressHeader       = "Address"
        static let fullNamePlaceholder = "Full name"
        static let streetPlaceholder   = "Street address"
        static let cityPlaceholder     = "City"
        static let statePlaceholder    = "State / County"
        static let postcodePlaceholder = "Postcode"
        static let countryPicker       = "Country"
        static let saveButton          = "Save"
        static let defaultCountry      = "Ireland"
    }

    enum SavedCards {
        static let navigationTitle = "Saved Cards"
        static func expires(month: Int, year: Int) -> String { "Expires \(month)/\(year)" }
    }
}
