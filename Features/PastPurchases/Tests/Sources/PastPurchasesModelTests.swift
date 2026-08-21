import Testing
import Foundation
@testable import PastPurchases
import PastPurchasesTesting

// MARK: - Helpers

private final class FailingPastPurchasesRepository: PastPurchasesRepository {
    func fetchOrders() async throws -> [PastOrder] { throw URLError(.notConnectedToInternet) }
    func saveOrder(_ order: PastOrder) async throws { throw URLError(.notConnectedToInternet) }
    func deleteOrder(id: UUID) async throws { throw URLError(.notConnectedToInternet) }
}

// MARK: - Unit Tests

@Suite("PastPurchasesModel — Unit Tests")
struct PastPurchasesModelTests {

    // MARK: - Initial state

    @Test("Initial orders array is empty")
    func initialOrdersEmpty() {
        #expect(PastPurchasesModel().orders.isEmpty)
    }

    @Test("Initial isLoading is false")
    func initialIsLoadingFalse() {
        #expect(PastPurchasesModel().isLoading == false)
    }

    @Test("Initial shouldNavigateToCart is false")
    func initialShouldNavigateToCartFalse() {
        #expect(PastPurchasesModel().shouldNavigateToCart == false)
    }

    @Test("Initial destination is nil")
    func initialDestinationNil() {
        #expect(PastPurchasesModel().destination == nil)
    }

    // MARK: - load()

    @Test("load populates orders on success")
    @MainActor
    func loadPopulatesOrders() async {
        let model = PastPurchasesModel()
        await model.load()
        #expect(!model.orders.isEmpty)
        #expect(model.isLoading == false)
    }

    @Test("load results in empty array on failure (silent fail)")
    @MainActor
    func loadSilentlyFailsOnError() async {
        let model = PastPurchasesModel(repository: FailingPastPurchasesRepository())
        await model.load()
        #expect(model.orders.isEmpty)
        #expect(model.isLoading == false)
    }

    // MARK: - select()

    @Test("select sets destination to orderDetail")
    func selectSetsDestination() {
        let model = PastPurchasesModel()
        model.select(.stub)
        #expect(model.destination == .orderDetail(.stub))
    }

    // MARK: - saveOrder()

    @Test("saveOrder inserts the new order at the front of the list")
    @MainActor
    func saveOrderInsertsAtFront() async {
        let model = PastPurchasesModel()
        await model.load()
        let initialCount = model.orders.count
        let newOrder = PastOrder.stub
        await model.saveOrder(newOrder)
        #expect(model.orders.count == initialCount + 1)
        #expect(model.orders[0].id == newOrder.id)
    }

    // MARK: - repeatOrder()

    @Test("repeatOrder fires onRepeatOrder with the given order")
    func repeatOrderFiresCallback() {
        let model = PastPurchasesModel()
        var received: PastOrder?
        model.onRepeatOrder = { received = $0 }
        model.repeatOrder(.stub)
        #expect(received?.id == PastOrder.stub.id)
    }

    @Test("repeatOrder sets shouldNavigateToCart to true")
    func repeatOrderSetsNavigateFlag() {
        let model = PastPurchasesModel()
        model.onRepeatOrder = { _ in }
        model.repeatOrder(.stub)
        #expect(model.shouldNavigateToCart == true)
    }

    @Test("repeatOrder does nothing when onRepeatOrder is not wired")
    func repeatOrderNoOpWithoutCallback() {
        let model = PastPurchasesModel()
        model.repeatOrder(.stub) // must not crash
        #expect(model.shouldNavigateToCart == true)
    }

    // MARK: - deleteOrder()

    @Test("deleteOrder removes the order from the list")
    @MainActor
    func deleteOrderRemovesFromList() async {
        let model = PastPurchasesModel()
        await model.load()
        let target = model.orders[0]
        let countBefore = model.orders.count
        await model.deleteOrder(target)
        #expect(model.orders.count == countBefore - 1)
        #expect(!model.orders.contains(where: { $0.id == target.id }))
    }

    // MARK: - openSupport()

    @Test("openSupport sets shouldOpenSupport to true")
    func openSupportSetsFlag() {
        let model = PastPurchasesModel()
        model.openSupport()
        #expect(model.shouldOpenSupport == true)
    }

    @Test("shouldOpenSupport starts as false")
    func initialShouldOpenSupportFalse() {
        #expect(PastPurchasesModel().shouldOpenSupport == false)
    }
}
