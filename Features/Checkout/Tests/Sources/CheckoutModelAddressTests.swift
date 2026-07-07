import Testing
import Foundation
@testable import Checkout

@Suite("CheckoutModel – address selection")
struct CheckoutModelAddressTests {

    // Convenience: two addresses where the first is the default.
    static let addresses = ShippingAddress.stubs   // stubs[0].isDefault == true

    // MARK: - Initialisation

    @Test("Loads selectedAddressID from the store on init")
    func loadsSelectedIDOnInit() {
        let stored = ShippingAddress.stubs[1].id
        let store  = StubSelectedAddressStore(id: stored)
        let model  = CheckoutModel(selectedAddressStore: store)
        #expect(model.selectedAddressID == stored)
    }

    @Test("selectedAddressID is nil when the store is empty")
    func selectedIDIsNilWhenStoreEmpty() {
        let model = CheckoutModel(selectedAddressStore: StubSelectedAddressStore())
        #expect(model.selectedAddressID == nil)
    }

    // MARK: - selectAddress

    @Test("selectAddress updates selectedAddressID")
    func selectAddressUpdatesID() {
        let model = CheckoutModel(selectedAddressStore: StubSelectedAddressStore())
        model.savedAddresses = Self.addresses
        model.selectAddress(Self.addresses[1])
        #expect(model.selectedAddressID == Self.addresses[1].id)
    }

    @Test("selectAddress persists the ID to the store")
    func selectAddressPersistsToStore() {
        let store = StubSelectedAddressStore()
        let model = CheckoutModel(selectedAddressStore: store)
        model.savedAddresses = Self.addresses
        model.selectAddress(Self.addresses[1])
        #expect(store.storedID == Self.addresses[1].id)
    }

    // MARK: - selectedAddress computed property

    @Test("selectedAddress returns the matching ShippingAddress")
    func selectedAddressReturnsMatch() {
        let model = CheckoutModel(selectedAddressStore: StubSelectedAddressStore())
        model.savedAddresses = Self.addresses
        model.selectAddress(Self.addresses[0])
        #expect(model.selectedAddress == Self.addresses[0])
    }

    @Test("selectedAddress returns nil when selectedAddressID matches no saved address")
    func selectedAddressReturnsNilForUnknownID() {
        let store = StubSelectedAddressStore(id: UUID())   // unknown ID
        let model = CheckoutModel(selectedAddressStore: store)
        model.savedAddresses = Self.addresses
        #expect(model.selectedAddress == nil)
    }

    @Test("selectedAddress returns nil when there are no saved addresses")
    func selectedAddressNilWithNoAddresses() {
        let store = StubSelectedAddressStore(id: Self.addresses[0].id)
        let model = CheckoutModel(selectedAddressStore: store)
        // savedAddresses is empty (default)
        #expect(model.selectedAddress == nil)
    }

    // MARK: - proceedToAddress auto-selection

    @Test("proceedToAddress auto-selects the default address when nothing is stored")
    func proceedAutoSelectsDefault() {
        let model = CheckoutModel(selectedAddressStore: StubSelectedAddressStore())
        model.savedAddresses = Self.addresses
        model.proceedToAddress()
        let defaultAddress = Self.addresses.first(where: { $0.isDefault })!
        #expect(model.selectedAddressID == defaultAddress.id)
    }

    @Test("proceedToAddress persists the auto-selected ID")
    func proceedPersistsAutoSelection() {
        let store = StubSelectedAddressStore()
        let model = CheckoutModel(selectedAddressStore: store)
        model.savedAddresses = Self.addresses
        model.proceedToAddress()
        let defaultAddress = Self.addresses.first(where: { $0.isDefault })!
        #expect(store.storedID == defaultAddress.id)
    }

    @Test("proceedToAddress falls back to first address when none is marked default")
    func proceedFallsBackToFirstWhenNoDefault() {
        let model = CheckoutModel(selectedAddressStore: StubSelectedAddressStore())
        let noDefault = Self.addresses.map {
            ShippingAddress(id: $0.id, fullName: $0.fullName, line1: $0.line1,
                            line2: $0.line2, city: $0.city, state: $0.state,
                            postalCode: $0.postalCode, country: $0.country, isDefault: false)
        }
        model.savedAddresses = noDefault
        model.proceedToAddress()
        #expect(model.selectedAddressID == noDefault[0].id)
    }

    @Test("proceedToAddress keeps an existing valid selection")
    func proceedKeepsValidSelection() {
        let store = StubSelectedAddressStore(id: Self.addresses[1].id)
        let model = CheckoutModel(selectedAddressStore: store)
        model.savedAddresses = Self.addresses
        model.proceedToAddress()
        #expect(model.selectedAddressID == Self.addresses[1].id)
    }

    @Test("proceedToAddress replaces a stale selection with the default")
    func proceedReplacesStaleSelection() {
        let staleID = UUID()
        let store   = StubSelectedAddressStore(id: staleID)
        let model   = CheckoutModel(selectedAddressStore: store)
        model.savedAddresses = Self.addresses
        model.proceedToAddress()
        let defaultAddress = Self.addresses.first(where: { $0.isDefault })!
        #expect(model.selectedAddressID == defaultAddress.id)
        #expect(store.storedID == defaultAddress.id)
    }

    @Test("proceedToAddress does not auto-select when there are no saved addresses")
    func proceedDoesNotAutoSelectWithNoAddresses() {
        let model = CheckoutModel(selectedAddressStore: StubSelectedAddressStore())
        model.proceedToAddress()
        #expect(model.selectedAddressID == nil)
    }
}
