import SwiftUI

public extension Color {
    /// Initialise a `Color` from a 6-digit RGB hex string (with or without a leading `#`).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >>  8) & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

public extension ShapeStyle where Self == Color {
    static var dsPrimary:    Color { .blue }
    static var dsSecondary:  Color { Color(white: 0.45) }
    static var dsSuccess:    Color { .green }
    static var dsDestructive:Color { .red }
    static var dsWarning:    Color { .orange }
}

public extension Color {
    static let dsPrimary:     Color = .blue
    static let dsSecondary:   Color = Color(white: 0.45)
    static let dsSuccess:     Color = .green
    static let dsDestructive: Color = .red
    static let dsWarning:     Color = .orange
    static let dsBackground:  Color = Color(hue: 0, saturation: 0, brightness: 0.98)
    static let dsSurface:     Color = Color(hue: 0, saturation: 0, brightness: 0.95)
    static let dsBorder:      Color = Color(white: 0.8)
}
