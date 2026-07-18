#if canImport(UIKit)
import Testing
import SnapshotTesting
import SwiftUI
@testable import PastPurchases
import PastPurchasesTesting

// MARK: - CaseIterable conformances

extension PastPurchasesModel.Destination: CaseIterable {
    public static var allCases: [PastPurchasesModel.Destination] {
        [.orderDetail(.stub)]
    }
}

extension OrderStatus: CaseIterable {
    public static var allCases: [OrderStatus] {
        [.processing, .shipped, .delivered, .cancelled]
    }
}

// MARK: - Snapshot Tests

@Suite("PastPurchases — Snapshot Tests")
@MainActor
struct PastPurchasesSnapshotTests {

    @Test("Past purchases view renders correctly when loading")
    func loadingState() async throws {
        let model = PastPurchasesModel()
        model.isLoading = true
        assertSnapshot(
            of: PastPurchasesView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loading"
        )
    }

    @Test("Past purchases view renders correctly with orders")
    func loadedState() async throws {
        let model = PastPurchasesModel()
        model.orders = PastOrder.stubs
        assertSnapshot(
            of: PastPurchasesView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_loaded"
        )
    }

    @Test("Past purchases view renders correctly when empty")
    func emptyState() async throws {
        let model = PastPurchasesModel()
        assertSnapshot(
            of: PastPurchasesView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "state_empty"
        )
    }

    @Test(
        "Each navigation destination renders correctly",
        arguments: PastPurchasesModel.Destination.allCases
    )
    func destination(_ destination: PastPurchasesModel.Destination) async throws {
        let model = PastPurchasesModel()
        model.orders = PastOrder.stubs
        model.destination = destination
        assertSnapshot(
            of: PastPurchasesView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: snapshotName(destination)
        )
    }

    @Test("Order detail renders correctly for each order status", arguments: OrderStatus.allCases)
    func orderDetailStatus(status: OrderStatus) async throws {
        var order = PastOrder.stub
        order.status = status
        let model = PastPurchasesModel()
        model.orders = [order]
        model.destination = .orderDetail(order)
        assertSnapshot(
            of: PastPurchasesView(model: model),
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "order_detail_status_\(status.rawValue.lowercased())"
        )
    }
}

// MARK: - Helpers

private func snapshotName(_ destination: PastPurchasesModel.Destination) -> String {
    switch destination {
    case .orderDetail: return "destination_order_detail"
    }
}
#endif
