import Testing
import Foundation
import CheckoutTesting
@testable import Checkout
@testable import CheckoutApp

/// Regression coverage for the scenario catalog itself — not the funnel's
/// rendering (CheckoutSnapshotTests already owns that), but whether each
/// named scenario still produces the business state it claims to.
///
/// CheckoutScenario's own doc comments frame each case as representing
/// something specific — "one item opted in", "payment was declined" — and
/// nothing enforced those claims before this file: CheckoutScenarioFactory
/// always compiles, but nothing stopped it from silently drifting into
/// producing a model that no longer matches what its scenario's name
/// promises. A snapshot test would duplicate coverage CheckoutSnapshotTests
/// already has (the same model states, already asserted pixel-by-pixel);
/// what's actually missing is a state-correctness check, which is a unit
/// test, not a rendering one.
///
/// Parametrized over CheckoutScenario.allCases with an exhaustive switch, so
/// a new scenario case with no corresponding assertion is a compile error —
/// the same structural-coverage discipline ADR-0010 applies to Destination,
/// one level up the stack.
@Suite("Checkout Scenarios — business-state coverage")
@MainActor
struct CheckoutScenarioTests {

    @Test(
        "Each scenario's built model matches what it claims to represent",
        arguments: CheckoutScenario.allCases
    )
    func scenario(_ scenario: CheckoutScenario) {
        let model = CheckoutScenarioFactory().makeModel(for: scenario)

        switch scenario {
        case .cart:
            #expect(model.cart == CartItem.stubs)
            #expect(model.savedAddresses == [.stub])
            #expect(model.path.isEmpty)
            #expect(model.destination == nil)

        case .emptyCart:
            #expect(model.cart.isEmpty)
            #expect(model.destination == nil)

        case .addressSelection:
            #expect(model.path == [.address])
            #expect(model.savedAddresses == ShippingAddress.stubs)

        case .orderOptions:
            #expect(model.path == [.address, .orderOptions(.stub)])
            #expect(model.extendedGuaranteeItems == [CartItem.stubs[0].product.id])

        case .paymentMethod:
            #expect(model.path == [.address, .orderOptions(.stub), .paymentMethod(.stub)])

        case .cardEntry:
            #expect(model.path == [.address, .orderOptions(.stub), .paymentMethod(.stub), .paymentEntry(.stub)])

        case .processing:
            #expect(model.destination == .processing)
            #expect(!model.cart.isEmpty)

        case .confirmation:
            guard case .confirmation(let order) = model.destination else {
                Issue.record("Expected .confirmation destination, got \(String(describing: model.destination))")
                return
            }
            #expect(!order.items.isEmpty)
            #expect(order.shippingAddress == .stub)
            #expect(order.deliveryOption == .standard)

        case .paymentFailed:
            #expect(model.destination == .paymentFailed(.cardDeclined))
            // The funnel is still underneath the sheet — payment failure doesn't clear it.
            #expect(model.path == [.address, .orderOptions(.stub), .paymentMethod(.stub), .paymentEntry(.stub)])
        }
    }
}
