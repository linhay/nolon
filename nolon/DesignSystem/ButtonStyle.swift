import SwiftUI

// MARK: - Button Styles

private struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(isEnabled ? DesignSystem.Colors.Text.onAccent : DesignSystem.Colors.Text.tertiary)
            .padding(.horizontal, DesignSystem.Metrics.buttonPaddingHorizontal)
            .padding(.vertical, DesignSystem.Metrics.buttonPaddingVertical)
            .background(isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
            .opacity(configuration.isPressed ? 0.92 : (isHovered ? 0.96 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering && isEnabled
            }
    }
}

private struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    let foreground: Color?
    let background: Color?
    let borderColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        let fg = foreground ?? (isEnabled ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.tertiary)
        let bg = background ?? DesignSystem.Colors.Component.controlFillSubtle
        let border = borderColor ?? DesignSystem.Colors.Component.border.opacity(0.30)

        return configuration.label
            .font(DesignSystem.Typography.button)
            .foregroundStyle(fg)
            .padding(.horizontal, DesignSystem.Metrics.buttonPaddingHorizontal)
            .padding(.vertical, DesignSystem.Metrics.buttonPaddingVertical)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : (isHovered ? 0.96 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering && isEnabled
            }
    }
}

private struct DSLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.label)
            .foregroundStyle(isEnabled ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.tertiary)
            .padding(.horizontal, DesignSystem.Metrics.spacingS - 2)
            .padding(.vertical, DesignSystem.Metrics.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS, style: .continuous)
                    .fill(configuration.isPressed ? DesignSystem.Colors.Component.controlFillSubtle : (isHovered ? DesignSystem.Colors.Component.controlFillSubtle.opacity(0.5) : Color.clear))
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animations.quick, value: configuration.isPressed)
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering && isEnabled
            }
    }
}

extension View {
    func dsPrimaryButton() -> some View {
        buttonStyle(DSPrimaryButtonStyle())
    }

    func dsSecondaryButton(
        foreground: Color? = nil,
        background: Color? = nil,
        borderColor: Color? = nil
    ) -> some View {
        buttonStyle(DSSecondaryButtonStyle(
            foreground: foreground,
            background: background,
            borderColor: borderColor
        ))
    }

    func dsLinkButton() -> some View {
        buttonStyle(DSLinkButtonStyle())
    }
}

extension View {
    func dsBorderlessButton() -> some View {
        buttonStyle(.borderless)
    }

    func dsBorderlessMenu() -> some View {
        menuStyle(.borderlessButton)
    }
}

private struct DSIconButtonModifier: ViewModifier {
    let size: CGFloat
    let foreground: Color
    let background: Color
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(isHovered ? background.opacity(0.8) : background)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(DesignSystem.Animations.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func dsIconButton(
        size: CGFloat = DesignSystem.Metrics.iconButtonSize,
        foreground: Color = DesignSystem.Colors.Text.secondary,
        background: Color = .clear,
        cornerRadius: CGFloat = DesignSystem.Metrics.cornerRadiusS
    ) -> some View {
        modifier(DSIconButtonModifier(
            size: size,
            foreground: foreground,
            background: background,
            cornerRadius: cornerRadius
        ))
    }
}

private struct DSIconLabelButtonModifier: ViewModifier {
    let foreground: Color
    let font: Font

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(foreground)
    }
}

extension View {
    func dsIconLabelButton(
        foreground: Color = DesignSystem.Colors.Text.primary,
        font: Font = DesignSystem.Typography.label
    ) -> some View {
        modifier(DSIconLabelButtonModifier(foreground: foreground, font: font))
    }
}

private struct DSIconLabelTextModifier: ViewModifier {
    let foreground: Color
    let font: Font

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(foreground)
    }
}

extension View {
    func dsIconLabelText(
        foreground: Color = DesignSystem.Colors.Text.secondary,
        font: Font = DesignSystem.Typography.caption2
    ) -> some View {
        modifier(DSIconLabelTextModifier(foreground: foreground, font: font))
    }
}

private struct DSEmptyStateTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundStyle(DesignSystem.Colors.Text.primary)
    }
}

extension View {
    func dsEmptyStateTitle() -> some View {
        modifier(DSEmptyStateTitleModifier())
    }
}

private struct DSEmptyStateIconModifier: ViewModifier {
    let color: Color
    let size: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .foregroundStyle(color)
    }
}

extension View {
    func dsEmptyStateIcon(
        color: Color = DesignSystem.Colors.Text.tertiary,
        size: CGFloat = 18
    ) -> some View {
        modifier(DSEmptyStateIconModifier(color: color, size: size))
    }
}

private struct DSEmptyStateErrorTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundStyle(DesignSystem.Colors.Status.error)
    }
}

extension View {
    func dsEmptyStateErrorTitle() -> some View {
        modifier(DSEmptyStateErrorTitleModifier())
    }
}

private struct DSErrorTextModifier: ViewModifier {
    let font: Font

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(DesignSystem.Colors.Status.error)
    }
}

extension View {
    func dsErrorText(font: Font = .caption) -> some View {
        modifier(DSErrorTextModifier(font: font))
    }
}

private struct DSSecondaryTextModifier: ViewModifier {
    let font: Font

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
    }
}

private struct DSTertiaryTextModifier: ViewModifier {
    let font: Font

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
    }
}

extension View {
    func dsSecondaryText(font: Font = .caption) -> some View {
        modifier(DSSecondaryTextModifier(font: font))
    }

    func dsTertiaryText(font: Font = .caption) -> some View {
        modifier(DSTertiaryTextModifier(font: font))
    }
}

extension Text {
    func dsSecondaryText(font: Font = .body) -> Text {
        self
            .font(font)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
    }

    func dsTertiaryText(font: Font = .caption) -> Text {
        self
            .font(font)
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
    }
}
