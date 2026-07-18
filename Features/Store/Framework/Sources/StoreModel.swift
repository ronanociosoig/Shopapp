import Foundation
import Observation
import SwiftUINavigation

enum StoreLoadState: Equatable {
    case idle
    case loading
    case loaded([StoreProduct])
    case failed(String)
}

@Observable
public final class StoreModel {
    var loadState: StoreLoadState = .idle
    var selectedCategory: String?
    var destination: Destination?

    /// Called by the composition root to route add-to-cart events to the Checkout module.
    /// Typed on Foundation primitives so the Store module stays independent of Checkout.
    /// Called by the composition root with (id, name, price, wantsExtendedGuarantee).
    public var onAddToCart: ((UUID, String, Decimal, Bool) -> Void)?

    private let repository: StoreRepositoryProtocol

    public init(repository: StoreRepositoryProtocol) {
        self.repository = repository
    }

    @CasePathable
    enum Destination: Equatable {
        case productDetail(StoreProduct)
        case categoryFilter
    }

    var categories: [String] {
        guard case .loaded(let products) = loadState else { return [] }
        return Array(Set(products.map(\.category))).sorted()
    }

    var displayedProducts: [StoreProduct] {
        guard case .loaded(let products) = loadState else { return [] }
        guard let category = selectedCategory else { return products }
        return products.filter { $0.category == category }
    }

    @MainActor
    func load() async {
        loadState = .loading
        do {
            let products = try await repository.fetchProducts(category: nil)
            loadState = .loaded(products)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func select(_ product: StoreProduct) {
        destination = .productDetail(product)
    }

    func showCategoryFilter() {
        destination = .categoryFilter
    }

    func addToCart(_ product: StoreProduct, wantsGuarantee: Bool = false) {
        onAddToCart?(product.id, product.name, product.price, wantsGuarantee)
    }
}
