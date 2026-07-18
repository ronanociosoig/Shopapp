import Testing
import Foundation
@testable import Suggestions
import SuggestionsTesting

/// Tests that exercise complete user interaction flows through the Suggestions module.
@Suite("Suggestions — UI Interaction Tests")
@MainActor
struct SuggestionsUITests {

    @Test("User loads suggestions and sees products")
    func userLoadsSuggestions() async {
        let model = SuggestionsModel()
        await model.load()
        #expect(!model.products.isEmpty)
    }

    @Test("User loads personalised suggestions for a known user")
    func userLoadsPersonalisedSuggestions() async {
        let model = SuggestionsModel()
        await model.load(for: "user-42")
        #expect(!model.products.isEmpty)
    }

    @Test("User taps a suggestion and sees its detail")
    func userSelectsProduct() async {
        let model = SuggestionsModel()
        await model.load()

        guard let first = model.products.first else {
            Issue.record("Suggestions should be loaded")
            return
        }
        model.select(first)
        #expect(model.destination == .productDetail(first))
    }

    @Test("User adds a suggestion to the cart")
    func userAddsToCart() async {
        let model = SuggestionsModel()
        await model.load()

        guard let first = model.products.first else {
            Issue.record("Suggestions should be loaded")
            return
        }

        var addedID: UUID?
        model.onAddToCart = { id, _, _, _ in addedID = id }
        model.addToCart(first)
        #expect(addedID == first.id)
    }
}
