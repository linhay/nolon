import AppKit
import SwiftUI

// MARK: - Design System Namespace

enum DesignSystem {
    enum Colors {}
}

// MARK: - Color Definitions

extension DesignSystem.Colors {

    // MARK: Brand

    static let primary = Color(light: 0x007AFF, dark: 0x0A84FF)
    static let secondary = Color(light: 0x5856D6, dark: 0x5E5CE6)

    // MARK: Background

    struct Background {
        static let canvas = Color(light: 0xF5F5F7, dark: 0x000000)
        static let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
        static let elevated = Color(light: 0xFFFFFF, dark: 0x2C2C2E)
    }

    // MARK: Text

    struct Text {
        static let primary = Color(light: 0x000000, dark: 0xFFFFFF)
        static let secondary = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.60)
        static let tertiary = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.30)
        static let quaternary = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.18)
    }

    // MARK: Status

    struct Status {
        static let info = Color(light: 0x007AFF, dark: 0x0A84FF)
        static let success = Color(light: 0x34C759, dark: 0x30D158)
        static let warning = Color(light: 0xFF9500, dark: 0xFF9F0A)
        static let error = Color(light: 0xFF3B30, dark: 0xFF453A)
    }

    // MARK: Component

    struct Component {
        static let border = Color(light: 0xC6C6C8, dark: 0x38383A)
        static let separator = Color(light: 0xC6C6C8, dark: 0x38383A)
    }
}

// MARK: - Helpers

extension Color {
    init(light: Int, dark: Int) {
        self.init(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
                        ? NSColor(Color(hex: light)) : NSColor(Color(hex: dark))
                }))
    }

    init(light: Color, dark: Color) {
        self.init(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    appearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
                        ? NSColor(light) : NSColor(dark)
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
