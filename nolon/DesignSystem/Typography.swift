import SwiftUI

// MARK: - Typography System

extension DesignSystem {
    struct Typography {
        // MARK: Headings
        static let h1 = Font.system(size: 28, weight: .bold)
        static let h2 = Font.system(size: 22, weight: .bold)
        static let h3 = Font.system(size: 17, weight: .semibold)

        // MARK: Body Text
        static let bodyLarge = Font.system(size: 15, weight: .regular)
        static let body = Font.system(size: 13, weight: .regular)
        static let bodySmall = Font.system(size: 11, weight: .regular)

        // MARK: UI Elements
        static let buttonLarge = Font.system(size: 15, weight: .semibold)
        static let button = Font.system(size: 13, weight: .semibold)
        static let buttonSmall = Font.system(size: 11, weight: .semibold)

        static let label = Font.system(size: 13, weight: .medium)
        static let labelSmall = Font.system(size: 11, weight: .medium)

        static let caption = Font.system(size: 11, weight: .regular)
        static let caption2 = Font.system(size: 10, weight: .regular)

        // MARK: Monospace
        static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
        static let codeSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
}
