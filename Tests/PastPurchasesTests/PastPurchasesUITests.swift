import Testing
import Foundation
@testable import PastPurchases

/// Tests that exercise complete user interaction flows through the PastPurchases module.
@Suite("PastPurchases — UI Interaction Tests")
@MainActor
struct PastPurchasesUITests {

    @Test("User loads orders and sees the list")
    func userLoadsOrders() async {
        let model = PastPurchasesModel()
        await model.load()
        #expect(!model.orders.isEmpty)
    }

    @Test("User taps an order and sees its detail")
    func userSelectsOrder() async {
        let model = PastPurchasesModel()
        await model.load()

        guard let first = model.orders.first else {
            Issue.record("Orders should be loaded")
            return
        }
        model.select(first)
        #expect(model.destination == .orderDetail(first))
    }

    @Test("User dismisses order detail and returns to list")
    func userDismissesOrderDetail() async {
        let model = PastPurchasesModel()
        await model.load()
        model.select(model.orders[0])
        model.destination = nil
        #expect(model.destination == nil)
    }

    @Test("User repeats an order — cart navigation is triggered")
    func userRepeatsOrder() async {
        let model = PastPurchasesModel()
        await model.load()

        guard let first = model.orders.first else {
            Issue.record("Orders should be loaded")
            return
        }

        var receivedOrder: PastOrder?
        model.onRepeatOrder = { receivedOrder = $0 }

        model.repeatOrder(first)
        #expect(receivedOrder?.id == first.id)
        #expect(model.shouldNavigateToCart == true)
    }

    @Test("A new order placed by the user appears at the top of the list")
    func newOrderAppearsAtTop() async {
        let model = PastPurchasesModel()
        await model.load()
        let before = model.orders.count

        await model.saveOrder(.stub)
        #expect(model.orders.count == before + 1)
        #expect(model.orders[0].id == PastOrder.stub.id)
    }
}
