import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct PromotionsView: View {
    @Bindable public var model: PromotionsModel

    public init(model: PromotionsModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    LoadingView(message: Strings.loadingMessage)
                } else if model.promotions.isEmpty {
                    ContentUnavailableView(
                        Strings.emptyTitle,
                        systemImage: "tag",
                        description: Text(Strings.emptyDescription)
                    )
                } else {
                    List(model.promotions) { promotion in
                        Button {
                            model.select(promotion)
                        } label: {
                            PromotionRow(promotion: promotion)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Strings.navigationTitle)
            .navigationDestination(item: $model.destination.promotionDetail) { promotion in
                PromotionDetailView(promotion: promotion)
            }
        }
        .task {
            // Only auto-load from a fresh model — see AccountView/StoreView
            // for the same guard, same reason.
            guard !model.suppressAutoLoad, !model.isLoading, model.promotions.isEmpty else { return }
            await model.load()
        }
    }
}

// MARK: - Row

struct PromotionRow: View {
    let promotion: Promotion

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(promotion.title)
                    .font(.headline)
                Text(promotion.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let expiry = promotion.expiresAt {
                    Text("Expires \(expiry, style: .date)")
                        .font(.caption2)
                        .foregroundStyle(Color.dsWarning)
                }
            }
            Spacer()
            Text(Strings.discountLabel(promotion.discountPercent))
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.dsDestructive.opacity(0.12))
                .foregroundStyle(Color.dsDestructive)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail view

struct PromotionDetailView: View {
    let promotion: Promotion

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(Strings.discountLabel(promotion.discountPercent))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color.dsDestructive)
                    Text(promotion.title)
                        .font(.title2.bold())
                    Text(promotion.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            if let expiry = promotion.expiresAt {
                Section(Strings.expiresSection) {
                    Label(expiry.formatted(date: .long, time: .omitted),
                          systemImage: "clock")
                        .foregroundStyle(Color.dsWarning)
                }
            }
            Section {
                PrimaryButton(Strings.applyPromotion) { }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
            .padding(.horizontal)
        }
        .navigationTitle(promotion.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Banner (embeddable strip)

/// A compact horizontal strip of promotion cards designed to be embedded
/// inside another feature's `NavigationStack` via `@ViewBuilder` injection.
///
/// When `model.promotions` is empty the view renders nothing, so the host
/// layout is unaffected until promotions have loaded.
public struct PromotionBannerView: View {
    @Bindable public var model: PromotionsModel
    private let sectionTitle: String

    public init(model: PromotionsModel, sectionTitle: String = "Today's Deals") {
        self.model        = model
        self.sectionTitle = sectionTitle
    }

    public var body: some View {
        Group {
            if !model.promotions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(sectionTitle)
                        .font(.headline)
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(model.promotions) { promotion in
                                Button {
                                    model.select(promotion)
                                } label: {
                                    PromotionCard(promotion: promotion)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .navigationDestination(item: $model.destination.promotionDetail) { promotion in
                    PromotionDetailView(promotion: promotion)
                }
            }
        }
        .task {
            // Only auto-load from a fresh model — see AccountView/StoreView
            // for the same guard, same reason.
            guard !model.suppressAutoLoad, !model.isLoading, model.promotions.isEmpty else { return }
            await model.load()
        }
    }
}

// MARK: - Card (compact, for banner)

struct PromotionCard: View {
    let promotion: Promotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Strings.discountLabel(promotion.discountPercent))
                .font(.title2.bold())
                .foregroundStyle(Color.dsDestructive)
            Text(promotion.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
            if let expiry = promotion.expiresAt {
                Text("Expires \(expiry, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(Color.dsWarning)
            }
        }
        .padding(12)
        .frame(width: 164)
        .background(Color.dsSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle   = "Promotions"
    static let loadingMessage    = "Loading promotions…"
    static let emptyTitle        = "No active promotions"
    static let emptyDescription  = "Check back soon for deals."
    static let applyPromotion    = "Apply Promotion"
    static let expiresSection    = "Expires"
    static let bannerSectionTitle = "Today's Deals"
    static func discountLabel(_ percent: Int) -> String { "\(percent)% OFF" }
}
