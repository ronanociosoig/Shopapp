import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct StoreView<SuggestionRow: View, PromotionBanner: View>: View {
    @Bindable public var model: StoreModel
    private let suggestionRow:   () -> SuggestionRow
    private let promotionBanner: () -> PromotionBanner

    public init(
        model: StoreModel,
        @ViewBuilder suggestionRow:   @escaping () -> SuggestionRow,
        @ViewBuilder promotionBanner: @escaping () -> PromotionBanner
    ) {
        self.model           = model
        self.suggestionRow   = suggestionRow
        self.promotionBanner = promotionBanner
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(Strings.navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            model.showCategoryFilter()
                        } label: {
                            Label(Strings.filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .navigationDestination(item: $model.destination.productDetail) { product in
                    StoreProductDetailView(product: product, model: model)
                }
        }
        .sheet(isPresented: Binding($model.destination.categoryFilter)) {
            CategoryFilterView(model: model)
        }
        .task {
            // Only auto-load from a fresh model. Guards against `.task` firing on every
            // appearance and clobbering state a caller (or a test) already set explicitly —
            // explicit reloads (e.g. the retry button below) still call model.load() directly.
            guard model.loadState == .idle else { return }
            await model.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .idle, .loading:
            LoadingView(message: Strings.loadingMessage)
        case .loaded:
            productGrid
        case .failed(let message):
            ErrorView(message: message) { Task { await model.load() } }
        }
    }

    private enum StoreRow {
        case products([StoreProduct])
        case suggestions
    }

    private var rows: [StoreRow] {
        var result: [StoreRow] = []
        let products = model.displayedProducts
        var productIndex = 0
        var outputRow = 0
        while productIndex < products.count {
            if outputRow >= 2 && (outputRow - 2) % 4 == 0 {
                result.append(.suggestions)
            } else {
                let pair = Array(products[productIndex ..< min(productIndex + 2, products.count)])
                result.append(.products(pair))
                productIndex += pair.count
            }
            outputRow += 1
        }
        return result
    }

    private var productGrid: some View {
        ScrollView {
            promotionBanner()
            if let category = model.selectedCategory {
                HStack {
                    Label(category, systemImage: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.dsPrimary)
                    Spacer()
                    Button(Strings.clearFilter) { model.selectedCategory = nil }
                        .font(.subheadline)
                }
                .padding(.horizontal)
            }

            LazyVStack(spacing: 16) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .products(let pair):
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(pair) { product in
                                StoreProductCard(product: product)
                                    .onTapGesture { model.select(product) }
                                    .frame(maxWidth: .infinity)
                            }
                            if pair.count == 1 {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    case .suggestions:
                        suggestionRow()
                    }
                }
            }
            .padding()
        }
    }
}

// No promotion banner — for StoreApp (suggestions only)
extension StoreView where PromotionBanner == EmptyView {
    public init(model: StoreModel, @ViewBuilder suggestionRow: @escaping () -> SuggestionRow) {
        self.init(model: model, suggestionRow: suggestionRow, promotionBanner: { EmptyView() })
    }
}

// No suggestions, no banner — for snapshot tests and basic use
extension StoreView where SuggestionRow == EmptyView, PromotionBanner == EmptyView {
    public init(model: StoreModel) {
        self.init(model: model, suggestionRow: { EmptyView() }, promotionBanner: { EmptyView() })
    }
}

// No suggestions, with banner — for PromotionsApp (store context)
extension StoreView where SuggestionRow == EmptyView {
    public init(model: StoreModel, @ViewBuilder promotionBanner: @escaping () -> PromotionBanner) {
        self.init(model: model, suggestionRow: { EmptyView() }, promotionBanner: promotionBanner)
    }
}

// MARK: - Sub-views

struct StoreProductCard: View {
    let product: StoreProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dsSurface)
                .frame(height: 120)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                .overlay(alignment: .topTrailing) {
                    if !product.isAvailable {
                        Text(Strings.soldOut)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.dsDestructive)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }
            Text(product.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            DSPriceLabel(product.price)
        }
        .opacity(product.isAvailable ? 1 : 0.6)
    }
}

struct StoreProductDetailView: View {
    let product: StoreProduct
    let model: StoreModel
    @State private var didAdd = false
    @State private var selectedColour: ProductColour?
    @State private var wantsGuarantee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColour.map { Color(hex: $0.hex).opacity(0.18) } ?? Color.dsSurface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
                    .animation(.easeInOut(duration: 0.2), value: selectedColour?.hex)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(product.name).font(.title2.bold())
                        Spacer()
                        DSPriceLabel(product.price)
                    }
                    Text(product.category)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.dsSurface)
                        .clipShape(Capsule())
                    Text(product.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // Colour picker
                if !product.availableColours.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if let selected = selectedColour {
                            Text(Strings.colourLabel(selected.name))
                                .font(.subheadline.weight(.medium))
                        }
                        HStack(spacing: 12) {
                            ForEach(product.availableColours) { colour in
                                Button { selectedColour = colour } label: {
                                    Circle()
                                        .fill(Color(hex: colour.hex))
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                                        .overlay(
                                            Circle().strokeBorder(
                                                selectedColour?.name == colour.name ? Color.dsPrimary : .clear,
                                                lineWidth: 2.5
                                            )
                                            .padding(-3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Extended guarantee upsell
                if product.supportsExtendedGuarantee {
                    Button { wantsGuarantee.toggle() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: wantsGuarantee ? "checkmark.shield.fill" : "shield")
                                .font(.title2)
                                .foregroundStyle(wantsGuarantee ? Color.dsPrimary : .secondary)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Strings.extendedGuaranteeTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(Strings.extendedGuaranteeSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: wantsGuarantee ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(wantsGuarantee ? Color.dsPrimary : .secondary)
                        }
                        .padding()
                        .background(Color.dsSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                if product.isAvailable {
                    PrimaryButton(didAdd ? Strings.addedToCart : Strings.addToCart) {
                        model.addToCart(product, wantsGuarantee: wantsGuarantee)
                        didAdd = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            didAdd = false
                        }
                    }
                    .disabled(didAdd)
                    .padding(.horizontal)
                } else {
                    Text(Strings.currentlyUnavailable)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(product.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { selectedColour = product.availableColours.first }
    }
}

struct CategoryFilterView: View {
    let model: StoreModel

    var body: some View {
        NavigationStack {
            List(model.categories, id: \.self) { category in
                HStack {
                    Text(category)
                    Spacer()
                    if model.selectedCategory == category {
                        Image(systemName: "checkmark").foregroundStyle(.dsPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectedCategory = category
                    model.destination = nil
                }
            }
            .navigationTitle(Strings.CategoryFilter.navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.CategoryFilter.done) { model.destination = nil }
                }
            }
        }
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle           = "Shop"
    static let filterLabel               = "Filter"
    static let loadingMessage            = "Loading products…"
    static let clearFilter               = "Clear"
    static let soldOut                   = "Sold out"
    static let currentlyUnavailable      = "Currently unavailable"
    static let extendedGuaranteeTitle    = "1-Year Extended Guarantee"
    static let extendedGuaranteeSubtitle = "+€9.99 · Extends the manufacturer warranty by 1 year"
    static let addToCart                 = "Add to Cart"
    static let addedToCart               = "Added to Cart ✓"
    static func colourLabel(_ name: String) -> String { "Colour: \(name)" }

    enum CategoryFilter {
        static let navigationTitle = "Filter by Category"
        static let done            = "Done"
    }
}
