import SwiftUI
import DesignSystem

@main
struct DesignSystemApp: App {
    var body: some Scene {
        WindowGroup {
            DesignSystemCatalog()
        }
    }
}

// MARK: - Catalog

struct DesignSystemCatalog: View {
    @State private var destination: Destination?

    enum Destination: Hashable {
        case colours
        case typography
        case components
    }

    var body: some View {
        NavigationStack {
            List {
                CatalogRow(title: Strings.colours)    { destination = .colours }
                CatalogRow(title: Strings.typography) { destination = .typography }
                CatalogRow(title: Strings.components) { destination = .components }
            }
            .navigationTitle(Strings.navigationTitle)
            .navigationDestination(item: $destination) { destination in
                switch destination {
                case .colours:    ColourCatalog()
                case .typography: TypographyCatalog()
                case .components: ComponentCatalog()
                }
            }
        }
    }
}

// MARK: - Catalog Row

private struct CatalogRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Colour Catalog

struct ColourCatalog: View {
    private let swatches: [(String, Color)] = [
        (Strings.Colours.primary,     .dsPrimary),
        (Strings.Colours.secondary,   .dsSecondary),
        (Strings.Colours.success,     .dsSuccess),
        (Strings.Colours.destructive, .dsDestructive),
        (Strings.Colours.warning,     .dsWarning),
        (Strings.Colours.background,  .dsBackground),
        (Strings.Colours.surface,     .dsSurface),
        (Strings.Colours.border,      .dsBorder),
    ]

    var body: some View {
        List(swatches, id: \.0) { name, colour in
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colour)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.dsBorder, lineWidth: 1)
                    )
                Text(name)
                    .font(.body)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(Strings.colours)
    }
}

// MARK: - Typography Catalog

struct TypographyCatalog: View {
    private let styles: [(String, Font)] = [
        (Strings.Typography.largeTitle,  .largeTitle),
        (Strings.Typography.title,       .title),
        (Strings.Typography.title2,      .title2),
        (Strings.Typography.title3,      .title3),
        (Strings.Typography.headline,    .headline),
        (Strings.Typography.body,        .body),
        (Strings.Typography.callout,     .callout),
        (Strings.Typography.subheadline, .subheadline),
        (Strings.Typography.footnote,    .footnote),
        (Strings.Typography.caption,     .caption),
        (Strings.Typography.caption2,    .caption2),
    ]

    var body: some View {
        List(styles, id: \.0) { name, font in
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.Typography.sampleText)
                    .font(font)
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle(Strings.typography)
    }
}

// MARK: - Component Catalog

struct ComponentCatalog: View {
    @State private var isLoading = false

    var body: some View {
        List {
            Section(Strings.Components.buttonsSection) {
                DSPrimaryButton(Strings.Components.primaryButton) { }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            Section(Strings.Components.feedbackSection) {
                DSLoadingView()
                    .frame(height: 120)
                    .listRowInsets(.init())

                ErrorView(message: Strings.Components.errorMessage) { }
                    .frame(height: 160)
                    .listRowInsets(.init())
            }

            Section(Strings.Components.priceSection) {
                HStack {
                    Text(Strings.Components.priceLabel)
                    Spacer()
                    DSPriceLabel(299.99)
                }
            }
        }
        .navigationTitle(Strings.components)
    }
}

// MARK: - Strings

private enum Strings {
    static let navigationTitle = "Design System"
    static let colours         = "Colours"
    static let typography      = "Typography"
    static let components      = "Components"

    enum Colours {
        static let primary     = "Primary"
        static let secondary   = "Secondary"
        static let success     = "Success"
        static let destructive = "Destructive"
        static let warning     = "Warning"
        static let background  = "Background"
        static let surface     = "Surface"
        static let border      = "Border"
    }

    enum Typography {
        static let largeTitle  = "Large Title"
        static let title       = "Title"
        static let title2      = "Title 2"
        static let title3      = "Title 3"
        static let headline    = "Headline"
        static let body        = "Body"
        static let callout     = "Callout"
        static let subheadline = "Subheadline"
        static let footnote    = "Footnote"
        static let caption     = "Caption"
        static let caption2    = "Caption 2"
        static let sampleText  = "The quick brown fox"
    }

    enum Components {
        static let buttonsSection  = "Buttons"
        static let feedbackSection = "Feedback"
        static let priceSection    = "Price"
        static let primaryButton   = "Primary Button"
        static let errorMessage    = "Something went wrong."
        static let priceLabel      = "Price label"
    }
}
