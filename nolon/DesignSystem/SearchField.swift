import SwiftUI

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil
    var showSearching: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Metrics.spacingM) {
            HStack(spacing: DesignSystem.Metrics.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .lineLimit(1)
                    .frame(minHeight: 18)
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NSLocalizedString("Clear", comment: "Clear"))
                }
                HStack(spacing: DesignSystem.Metrics.spacingS - 2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundStyle(DesignSystem.Colors.Status.info)
                        .frame(width: 16, height: 16)
                    Text(NSLocalizedString("remote.searching", value: "Searching...", comment: "Searching indicator"))
                        .dsSecondaryText(font: .callout)
                }
                .opacity(showSearching ? 1 : 0)
                .accessibilityHidden(!showSearching)
            }
            .padding(.horizontal, DesignSystem.Metrics.spacingM)
            .padding(.vertical, DesignSystem.Metrics.spacingS)
            .frame(maxWidth: width ?? .infinity)
            .dsField(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                    .stroke(
                        isFocused
                        ? DesignSystem.Colors.Status.info
                        : (text.isEmpty
                           ? DesignSystem.Colors.Component.border.opacity(DesignSystem.Colors.Opacity.low)
                           : DesignSystem.Colors.Status.info.opacity(DesignSystem.Colors.Opacity.high)),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: text.isEmpty
                ? DesignSystem.Colors.Shadow.floating.opacity(DesignSystem.Colors.Opacity.subtle)
                : (isFocused ? DesignSystem.Colors.Status.info.opacity(0.35) : DesignSystem.Colors.Status.info.opacity(DesignSystem.Colors.Opacity.low)),
                radius: isFocused ? 14 : (text.isEmpty ? 6 : 12),
                x: 0,
                y: 4
            )
            .animation(DesignSystem.Animations.quick, value: isFocused)
            .animation(DesignSystem.Animations.quick, value: text.isEmpty)

            Button {
                isFocused = true
            } label: {
                Text("")
            }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 1, height: 1)
            .opacity(0)
            .accessibilityHidden(true)

            Button {
                if text.isEmpty {
                    isFocused = false
                } else {
                    text = ""
                }
            } label: {
                Text("")
            }
            .keyboardShortcut(.cancelAction)
            .frame(width: 1, height: 1)
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}
