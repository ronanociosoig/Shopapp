import SwiftUI
import SwiftUINavigation
import DesignSystem

public struct PastPurchasesView: View {
    @Bindable public var model: PastPurchasesModel

    public init(model: PastPurchasesModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    LoadingView(message: Strings.loadingMessage)
                } else if model.orders.isEmpty {
                    ContentUnavailableView(
                        Strings.emptyTitle,
                        systemImage: "bag",
                        description: Text(Strings.emptyDescription)
                    )
                } else {
                    List(model.orders) { order in
                        Button {
                            model.select(order)
                        } label: {
                            PastOrderRow(order: order)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await model.deleteOrder(order) }
                            } label: {
                                Label(Strings.deleteAction, systemImage: "trash")
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(Strings.navigationTitle)
            .navigationDestination(item: $model.destination.orderDetail) { order in
                PastOrderDetailView(order: order, model: model)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        model.openSupport()
                    } label: {
                        Label(Strings.supportButton, systemImage: "questionmark.circle")
                    }
                }
            }
        }
        .task {
            // Only auto-load from a fresh model — see AccountView/StoreView
            // for the same guard, same reason: without it, .task fires on
            // every appearance and clobbers state a caller (or a test)
            // already set explicitly.
            guard !model.suppressAutoLoad, !model.isLoading, model.orders.isEmpty else { return }
            await model.load()
        }
    }
}

// MARK: - Row

struct PastOrderRow: View {
    let order: PastOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Strings.orderNumber(order.id.uuidString.prefix(8).uppercased()))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                Spacer()
                DSPriceLabel(order.total)
            }
            HStack(spacing: 12) {
                Text(Strings.itemCount(order.itemCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(order.placedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(order.status.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor(order.status).opacity(0.12))
                    .foregroundStyle(statusColor(order.status))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .delivered:  return .dsSuccess
        case .shipped:    return .dsPrimary
        case .processing: return .dsWarning
        case .cancelled:  return .dsDestructive
        }
    }
}

// MARK: - Detail view

struct PastOrderDetailView: View {
    let order: PastOrder
    let model: PastPurchasesModel

    var body: some View {
        List {
            // MARK: Status & dates
            Section {
                LabeledContent(Strings.Detail.statusLabel) {
                    Text(order.status.rawValue)
                        .foregroundStyle(statusColor)
                }
                LabeledContent(Strings.Detail.placedLabel) {
                    Text(order.placedAt, style: .date)
                        .foregroundStyle(.secondary)
                }
                LabeledContent(deliveryDateLabel) {
                    Text(order.estimatedDelivery, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Items
            Section(Strings.Detail.itemsHeader) {
                ForEach(order.lines, id: \.productID) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(line.name)
                                .font(.subheadline)
                            Spacer()
                            DSPriceLabel(line.subtotal)
                        }
                        HStack(spacing: 8) {
                            Text(Strings.Detail.quantityLabel(line.quantity))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if line.hasExtendedGuarantee {
                                Label(Strings.Detail.guaranteeLabel, systemImage: "shield.checkered")
                                    .font(.caption)
                                    .foregroundStyle(.dsPrimary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // MARK: Price breakdown
            Section(Strings.Detail.priceBreakdownHeader) {
                LabeledContent(
                    Strings.Detail.subtotalLabel,
                    value: order.itemsSubtotal,
                    format: .currency(code: "EUR")
                )
                if order.deliveryCost > 0 {
                    LabeledContent(
                        Strings.Detail.deliveryLabel,
                        value: order.deliveryCost,
                        format: .currency(code: "EUR")
                    )
                } else {
                    LabeledContent(Strings.Detail.deliveryLabel) {
                        Text(Strings.Detail.freeDelivery).foregroundStyle(.secondary)
                    }
                }
                if order.guaranteeCost > 0 {
                    LabeledContent(
                        Strings.Detail.guaranteeCostLabel,
                        value: order.guaranteeCost,
                        format: .currency(code: "EUR")
                    )
                }
                HStack {
                    Text(Strings.Detail.totalLabel).font(.headline)
                    Spacer()
                    DSPriceLabel(order.total)
                }
            }

            // MARK: Delivery info
            Section(Strings.Detail.deliveryInfoHeader) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.deliveryOptionName)
                        .font(.subheadline)
                    Text(order.shippingAddress.formatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // MARK: Repeat order
            if order.status != .cancelled {
                Section {
                    PrimaryButton(Strings.Detail.repeatOrderButton) {
                        model.repeatOrder(order)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
                .padding(.horizontal)
            }

            // MARK: Rate order
            if order.status == .delivered {
                Section {
                    Button {
                        model.requestRating(for: order)
                    } label: {
                        Label(Strings.Detail.rateOrderButton, systemImage: "star.leadinghalf.filled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.dsPrimary)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
                .padding(.horizontal)
            }
        }
        .navigationTitle(Strings.orderNumber(order.id.uuidString.prefix(8).uppercased()))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var statusColor: Color {
        switch order.status {
        case .delivered:  return .dsSuccess
        case .shipped:    return .dsPrimary
        case .processing: return .dsWarning
        case .cancelled:  return .dsDestructive
        }
    }

    /// "Delivered on" for completed orders, "Estimated delivery" otherwise.
    private var deliveryDateLabel: String {
        order.status == .delivered
            ? Strings.Detail.deliveredOnLabel
            : Strings.Detail.estimatedDeliveryLabel
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle  = "Past Purchases"
    static let deleteAction     = "Delete"
    static let supportButton    = "Support"
    static let loadingMessage   = "Loading orders…"
    static let emptyTitle       = "No past orders"
    static let emptyDescription = "Your completed orders will appear here."
    static func orderNumber(_ id: String) -> String { "Order #\(id)" }
    static func itemCount(_ count: Int) -> String { "\(count) item(s)" }

    enum Detail {
        static let statusLabel          = "Status"
        static let placedLabel          = "Placed"
        static let estimatedDeliveryLabel = "Estimated delivery"
        static let deliveredOnLabel     = "Delivered on"
        static let itemsHeader          = "Items"
        static let priceBreakdownHeader = "Price Breakdown"
        static let subtotalLabel        = "Subtotal"
        static let deliveryLabel        = "Delivery"
        static let freeDelivery         = "Free"
        static let guaranteeCostLabel   = "Extended Guarantee"
        static let totalLabel           = "Total"
        static let deliveryInfoHeader   = "Delivery"
        static let repeatOrderButton    = "Repeat Order"
        static let rateOrderButton      = "Rate this order"
        static let guaranteeLabel       = "Extended Guarantee"
        static func quantityLabel(_ qty: Int) -> String { "Qty: \(qty)" }
    }
}
