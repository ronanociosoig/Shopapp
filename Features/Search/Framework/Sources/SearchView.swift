import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct SearchView: View {
    @Bindable public var model: SearchModel

    public init(model: SearchModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(Strings.navigationTitle)
                .searchable(text: $model.query, prompt: Strings.searchPrompt)
                .onSubmit(of: .search) {
                    Task { await model.search() }
                }
                // Push: product detail with associated SearchProduct value
                .navigationDestination(item: $model.destination.productDetail) { product in
                    ProductDetailView(product: product, onAddToCart: { wantsGuarantee in
                        model.addToCart(product, wantsGuarantee: wantsGuarantee)
                    })
                }
                // Push: category browse with associated String value
                .navigationDestination(item: $model.destination.categoryBrowse) { category in
                    CategoryBrowseView(category: category, model: model)
                }
        }
        // Sheet: filters (no associated value — uses isPresented binding)
        .sheet(isPresented: Binding($model.destination.filters)) {
            FiltersView(onDismiss: { model.destination = nil })
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.searchState {
        case .idle:
            SuggestedCategoriesView(model: model)
        case .loading:
            LoadingView(message: Strings.loadingMessage)
        case .results(let products):
            SearchResultsView(products: products, model: model)
        case .empty:
            ContentUnavailableView(
                Strings.noResults(for: model.query),
                systemImage: "magnifyingglass",
                description: Text(Strings.emptyDescription)
            )
        case .error(let message):
            ErrorView(message: message) {
                Task { await model.search() }
            }
        }
    }
}

// MARK: - Sub-views

struct SearchResultsView: View {
    let products: [SearchProduct]
    let model: SearchModel

    var body: some View {
        List(products) { product in
            ProductRowView(product: product)
                .onTapGesture { model.selectProduct(product) }
        }
        .listStyle(.plain)
    }
}

struct SuggestedCategoriesView: View {
    let model: SearchModel
    private let categories = Strings.suggestedCategories

    var body: some View {
        List(categories, id: \.self) { category in
            Label(category, systemImage: "folder")
                .onTapGesture { model.browseCategory(category) }
        }
        .listStyle(.plain)
    }
}

struct ProductRowView: View {
    let product: SearchProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.headline)
            Text(product.category)
                .font(.caption)
                .foregroundStyle(.secondary)
            DSPriceLabel(product.price)
        }
        .padding(.vertical, 4)
    }
}

struct ProductDetailView: View {
    let product: SearchProduct
    let onAddToCart: (Bool) -> Void
    @State private var didAdd = false
    @State private var selectedColour: ProductColour?
    @State private var wantsGuarantee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColour.map { Color(hex: $0.hex).opacity(0.18) } ?? Color.dsSurface)
                    .frame(height: 240)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
                    .animation(.easeInOut(duration: 0.2), value: selectedColour?.hex)

                VStack(alignment: .leading, spacing: 8) {
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

                PrimaryButton(didAdd ? Strings.addedToCart : Strings.addToCart) {
                    onAddToCart(wantsGuarantee)
                    didAdd = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        didAdd = false
                    }
                }
                .disabled(didAdd)
                .padding(.horizontal)
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

struct CategoryBrowseView: View {
    let category: String
    let model: SearchModel

    var body: some View {
        List {
            ForEach(SearchProduct.stubs.filter { $0.category == category }) { product in
                ProductRowView(product: product)
                    .onTapGesture { model.selectProduct(product) }
            }
        }
        .listStyle(.plain)
        .navigationTitle(category)
    }
}

struct FiltersView: View {
    let onDismiss: () -> Void
    @State private var selectedCategory: String? = nil
    private let categories = Strings.suggestedCategories

    var body: some View {
        NavigationStack {
            Form {
                Section(Strings.Filters.categorySection) {
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            if selectedCategory == category {
                                Image(systemName: "checkmark").foregroundStyle(.dsPrimary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedCategory = category }
                    }
                }
            }
            .navigationTitle(Strings.Filters.navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.Filters.cancel, action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.Filters.apply, action: onDismiss)
                }
            }
        }
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle           = "Search"
    static let searchPrompt              = "Products, categories…"
    static let loadingMessage            = "Searching…"
    static let emptyDescription          = "Try a different search term or browse by category."
    static let extendedGuaranteeTitle    = "1-Year Extended Guarantee"
    static let extendedGuaranteeSubtitle = "+€9.99 · Extends the manufacturer warranty by 1 year"
    static let addToCart                 = "Add to Cart"
    static let addedToCart               = "Added to Cart ✓"
    static let suggestedCategories       = ["Electronics", "Furniture", "Clothing", "Books", "Sports"]
    static func colourLabel(_ name: String) -> String { "Colour: \(name)" }
    static func noResults(for query: String) -> String { "No results for \"\(query)\"" }

    enum Filters {
        static let navigationTitle = "Filters"
        static let categorySection = "Category"
        static let cancel          = "Cancel"
        static let apply           = "Apply"
    }
}
