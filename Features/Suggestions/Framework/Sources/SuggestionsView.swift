import SwiftUI
import SwiftUINavigation
import DesignSystem

/// Embeddable horizontal suggestions strip.
///
/// When used standalone (e.g. SuggestionsApp) wrap it in a `NavigationStack`
/// via `SuggestionsContainerView`. When embedded in another feature's
/// `NavigationStack`, pass the model in and the destination push will happen
/// inside that stack.
public struct SuggestionsView: View {
    @Bindable public var model: SuggestionsModel

    public init(model: SuggestionsModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.sectionTitle)
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(model.products) { product in
                        Button {
                            model.select(product)
                        } label: {
                            SuggestionCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationDestination(item: $model.destination.productDetail) { product in
            SuggestedProductDetailView(product: product, onAddToCart: { wantsGuarantee in
                model.addToCart(product, wantsGuarantee: wantsGuarantee)
            })
        }
        .task {
            // Only auto-load from a fresh model — see AccountView/StoreView
            // for the same guard, same reason.
            guard !model.suppressAutoLoad, !model.isLoading, model.products.isEmpty else { return }
            await model.load()
        }
    }
}

/// Standalone container for micro-app and preview use — owns the NavigationStack.
public struct SuggestionsContainerView: View {
    @Bindable public var model: SuggestionsModel

    public init(model: SuggestionsModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                SuggestionsView(model: model)
                    .padding(.vertical)
            }
            .navigationTitle(Strings.navigationTitle)
        }
    }
}

// MARK: - Card

struct SuggestionCard: View {
    let product: SuggestedProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurface)
                .frame(width: 140, height: 100)
                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            Text(product.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
            PriceLabel(product.price)
        }
    }
}

// MARK: - Detail view

struct SuggestedProductDetailView: View {
    let product: SuggestedProduct
    let onAddToCart: (Bool) -> Void
    @State private var didAdd = false
    @State private var selectedColour: ProductColour?
    @State private var wantsGuarantee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedColour.map { Color(hex: $0.hex).opacity(0.18) } ?? Color.dsSurface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
                    .animation(.easeInOut(duration: 0.2), value: selectedColour?.hex)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(product.name).font(.title2.bold())
                        Spacer()
                        PriceLabel(product.price)
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

// MARK: - Strings

private enum Strings {
    static let sectionTitle              = "Suggested for You"
    static let navigationTitle           = "Suggestions"
    static let extendedGuaranteeTitle    = "1-Year Extended Guarantee"
    static let extendedGuaranteeSubtitle = "+€9.99 · Extends the manufacturer warranty by 1 year"
    static let addToCart                 = "Add to Cart"
    static let addedToCart               = "Added to Cart ✓"
    static func colourLabel(_ name: String) -> String { "Colour: \(name)" }
}
