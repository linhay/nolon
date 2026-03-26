import SwiftUI
import MarkdownUI

@MainActor
public extension Theme {
    static var nolon: Theme {
        Theme()
        .text {
            ForegroundColor(DesignSystem.Colors.Text.primary)
            FontSize(14)
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: .zero, bottom: .em(1))
                .markdownTextStyle {
                    ForegroundColor(DesignSystem.Colors.Text.secondary)
                    FontSize(14)
                }
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    ForegroundColor(DesignSystem.Colors.Text.primary)
                    FontWeight(.bold)
                    FontSize(.em(2))
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 20, bottom: 12)
                .markdownTextStyle {
                    ForegroundColor(DesignSystem.Colors.Text.primary)
                    FontWeight(.bold)
                    FontSize(.em(1.57))
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    ForegroundColor(DesignSystem.Colors.Text.primary)
                    FontWeight(.semibold)
                    FontSize(.em(1.21))
                }
        }
        .code {
            ForegroundColor(DesignSystem.Colors.Text.primary)
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.93))
            BackgroundColor(DesignSystem.Colors.primary.opacity(0.10))
        }
        .codeBlock { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.2))
                .markdownTextStyle {
                    ForegroundColor(DesignSystem.Colors.Text.primary)
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.93))
                }
                .padding(16)
                .background(DesignSystem.Colors.Component.controlFillSubtle)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.Component.border.opacity(0.35), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: 0, bottom: 16)
        }
        .link {
            ForegroundColor(DesignSystem.Colors.primary)
            UnderlineStyle(.single)
        }
    }
}
