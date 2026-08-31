#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import Account
import AccountTesting

// MARK: - CaseIterable conformance

extension AccountModel.Destination: CaseIterable {
    public static var allCases: [AccountModel.Destination] {
        [
            .editProfile(.stub),
            .addAddress,
            .savedCards,
        ]
    }
}

// MARK: - Snapshot Tests

@Suite("Account — Snapshot Tests")
@MainActor
struct AccountSnapshotTests {

    @Test("Account view renders correctly when loading")
    func loadingState() async throws {
        let model = AccountModel()
        model.isLoading = true
        assertSnapshot(
            of: AccountView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loading"
        )
    }

    @Test("Account view renders correctly when signed out")
    func signedOut() async throws {
        // "Not loaded yet" and "signed out" are both nil profile / empty
        // addresses+cards — indistinguishable from the outside — so
        // AccountView's own guard can't tell this state apart from a
        // genuinely fresh model that should auto-load. Opt out explicitly
        // instead of racing AccountView's .task to capture before it fires.
        let model = AccountModel()
        model.suppressAutoLoad = true
        assertSnapshot(
            of: AccountView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "signed_out"
        )
    }

    @Test("Account view renders correctly when signed in with no addresses or cards")
    func signedInEmpty() async throws {
        let model = AccountModel()
        model.profile = .stub
        assertSnapshot(
            of: AccountView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "signed_in_empty"
        )
    }

    @Test("Account view renders correctly when signed in with full data")
    func signedInWithData() async throws {
        let model = AccountModel()
        model.profile   = .stub
        model.addresses = SavedAddress.stubs
        model.cards     = [.stub]
        assertSnapshot(
            of: AccountView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "signed_in"
        )
    }

    @Test("Account view renders correctly with multiple saved cards")
    func signedInWithMultipleCards() async throws {
        let model = AccountModel()
        model.profile   = .stub
        model.addresses = SavedAddress.stubs
        model.cards     = [
            .stub,
            SavedCard(
                id: UUID(uuidString: "00000000-0000-0000-BBBB-000000000099")!,
                token: "tok_stub_mc_5555",
                lastFour: "5555",
                brand: .mastercard,
                expiryMonth: 8,
                expiryYear: 2027
            ),
            SavedCard(
                id: UUID(uuidString: "00000000-0000-0000-BBBB-0000000000AA")!,
                token: "tok_stub_amex_3782",
                lastFour: "3782",
                brand: .amex,
                expiryMonth: 3,
                expiryYear: 2029
            ),
        ]
        assertSnapshot(
            of: AccountView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "signed_in_multiple_cards"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: AccountModel.Destination.allCases
    )
    func destination(_ destination: AccountModel.Destination) async throws {
        let model = AccountModel()
        model.profile   = .stub
        model.addresses = SavedAddress.stubs
        model.cards     = [.stub]
        model.destination = destination
        assertSnapshot(
            of: AccountView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ destination: AccountModel.Destination) -> String {
    switch destination {
    case .editProfile:  return "destination_edit_profile"
    case .addAddress:   return "destination_add_address"
    case .savedCards:   return "destination_saved_cards"
    }
}
#endif
