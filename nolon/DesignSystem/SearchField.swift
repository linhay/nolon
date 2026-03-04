import SwiftUI

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil
    var showSearching: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
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
                if showSearching {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                        Text(NSLocalizedString("remote.searching", value: "Searching...", comment: "Searching indicator"))
                            .dsSecondaryText(font: .callout)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: width ?? .infinity)
            .dsField(cornerRadius: DesignSystem.Metrics.cornerRadiusM)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                    .stroke(
                        isFocused
                        ? DesignSystem.Colors.Status.info
                        : (text.isEmpty
                           ? DesignSystem.Colors.Component.border.opacity(0.25)
                           : DesignSystem.Colors.Status.info.opacity(0.6)),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: text.isEmpty
                ? DesignSystem.Colors.Shadow.floating.opacity(0.08)
                : (isFocused ? DesignSystem.Colors.Status.info.opacity(0.35) : DesignSystem.Colors.Status.info.opacity(0.2)),
                radius: isFocused ? 14 : (text.isEmpty ? 6 : 12),
                x: 0,
                y: 4
            )

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
