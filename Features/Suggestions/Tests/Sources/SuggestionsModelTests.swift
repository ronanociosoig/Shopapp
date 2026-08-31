import Testing
import Foundation
@testable import Suggestions
import SuggestionsTesting

// MARK: - Helpers

private final class FailingSuggestionsRepository: SuggestionsRepository {
    func fetchSuggestions(for userId: String?) async throws -> [SuggestedProduct] {
        throw URLError(.notConnectedToInternet)
    }
}

// MARK: - Unit Tests

@Suite("SuggestionsModel — Unit Tests")
@MainActor
struct SuggestionsModelTests {

    // MARK: - Initial state

    @Test("Initial products array is empty")
    func initialProductsEmpty() {
        #expect(SuggestionsModel().products.isEmpty)
    }

    @Test("Initial isLoading is false")
    func initialIsLoadingFalse() {
        #expect(SuggestionsModel().isLoading == false)
    }

    @Test("Initial destination is nil")
    func initialDestinationNil() {
        #expect(SuggestionsModel().destination == nil)
    }

    // MARK: - load()

    @Test("load populates products on success")
    func loadPopulatesProducts() async {
        let model = SuggestionsModel()
        await model.load()
        #expect(!model.products.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test("load results in empty array on failure (silent fail)")
    func loadSilentlyFailsOnError() async {
        let model = SuggestionsModel(repository: FailingSuggestionsRepository())
        await model.load()
        #expect(model.products.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test("load accepts an optional userId")
    func loadAcceptsUserId() async {
        let model = SuggestionsModel()
        await model.load(for: "user-123")
        #expect(!model.products.isEmpty)
    }

    // MARK: - select()

    @Test("select sets destination to productDetail")
    func selectSetsDestination() {
        let model = SuggestionsModel()
        let product = SuggestedProduct.stubs[0]
        model.select(product)
        #expect(model.destination == .productDetail(product))
    }

    // MARK: - addToCart

    @Test("addToCart fires onAddToCart with correct primitives")
    func addToCartFiresCallback() {
        let model = SuggestionsModel()
        let product = SuggestedProduct.stubs[0]
        var captured: (UUID, String, Decimal, Bool)?
        model.onAddToCart = { id, name, price, wantsGuarantee in
            captured = (id, name, price, wantsGuarantee)
        }
        model.addToCart(product, wantsGuarantee: true)
        #expect(captured?.0 == product.id)
        #expect(captured?.1 == product.name)
        #expect(captured?.2 == product.price)
        #expect(captured?.3 == true)
    }

    @Test("addToCart defaults to wantsGuarantee false")
    func addToCartDefaultNoGuarantee() {
        let model = SuggestionsModel()
        var capturedGuarantee: Bool?
        model.onAddToCart = { _, _, _, g in capturedGuarantee = g }
        model.addToCart(SuggestedProduct.stubs[0])
        #expect(capturedGuarantee == false)
    }
}
