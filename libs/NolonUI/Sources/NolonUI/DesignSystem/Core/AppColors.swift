import AppKit
import SwiftUI

extension DesignSystem.Colors {
    public static let primary = Color(light: 0x007AFF, dark: 0x0A84FF)
    public static let secondary = Color(light: 0x5856D6, dark: 0x5E5CE6)

    public struct Background {
        public static let canvas = Color(light: 0xF5F5F7, dark: 0x000000)
        public static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
        public static let elevated = Color(light: 0xFFFFFF, dark: 0x2C2C2E)
    }

    public struct Text {
        public static let primary = Color(light: 0x000000, dark: 0xFFFFFF)
        public static let secondary = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.60)
        public static let tertiary = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.30)
        public static let quaternary = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.18)
        public static let onAccent = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    }

    public struct Status {
        public static let info = Color(light: 0x007AFF, dark: 0x0A84FF)
        public static let success = Color(light: 0x34C759, dark: 0x30D158)
        public static let warning = Color(light: 0xFF9500, dark: 0xFF9F0A)
        public static let error = Color(light: 0xFF3B30, dark: 0xFF453A)
    }

    public struct Component {
        public static let border = Color(light: 0xC6C6C8, dark: 0x38383A)
        public static let separator = Color(light: 0xC6C6C8, dark: 0x38383A)

        public static let controlFill = Color(light: 0xFFFFFF, dark: 0x1C1C1E).opacity(0.35)
        public static let controlFillStrong = Color(light: 0xFFFFFF, dark: 0x1C1C1E).opacity(0.55)
        public static let controlFillSubtle = Color(light: 0xFFFFFF, dark: 0x1C1C1E).opacity(0.18)
        public static let disabledFill = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.12)
    }

    public struct Overlay {
        public static let scrim = Color(light: 0x000000, dark: 0x000000).opacity(0.40)
    }

    public struct Shadow {
        public static let floating = Color(light: 0x000000, dark: 0x000000).opacity(0.20)
    }

    public struct Opacity {
        public static let high: Double = 0.60
        public static let medium: Double = 0.40
        public static let low: Double = 0.20
        public static let subtle: Double = 0.12
    }
}

private extension Color {
    init(light: Int, dark: Int) {
        self.init(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
                        ? NSColor(Color(hex: light)) : NSColor(Color(hex: dark))
                }))
    }

    init(hex: Int, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
