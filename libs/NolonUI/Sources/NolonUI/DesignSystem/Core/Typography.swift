import SwiftUI

extension DesignSystem {
    public struct Typography {
        public static let h1 = Font.system(size: 28, weight: .bold)
        public static let h2 = Font.system(size: 22, weight: .bold)
        public static let h3 = Font.system(size: 17, weight: .semibold)

        public static let bodyLarge = Font.system(size: 15, weight: .regular)
        public static let body = Font.system(size: 13, weight: .regular)
        public static let bodySmall = Font.system(size: 11, weight: .regular)

        public static let buttonLarge = Font.system(size: 15, weight: .semibold)
        public static let button = Font.system(size: 13, weight: .semibold)
        public static let buttonSmall = Font.system(size: 11, weight: .semibold)

        public static let label = Font.system(size: 13, weight: .medium)
        public static let labelSmall = Font.system(size: 11, weight: .medium)

        public static let caption = Font.system(size: 11, weight: .regular)
        public static let caption2 = Font.system(size: 10, weight: .regular)

        public static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
        public static let codeSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
    }
}
