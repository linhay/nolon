import SwiftUI
import NolonUIFoundation

public struct AccountSummaryCard<Content: View>: View {
    private let presentation: AccountCardPresentation
    private let contentInsets: EdgeInsets
    @ViewBuilder private var content: Content

    public init(
        presentation: AccountCardPresentation = .neutral,
        contentInsets: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        @ViewBuilder content: () -> Content
    ) {
        self.presentation = presentation
        self.contentInsets = contentInsets
        self.content = content()
    }

    public var body: some View {
        content
            .padding(contentInsets)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(backgroundShape)
            .overlay(borderShape)
            .overlay(alignment: .topTrailing) {
                if presentation.showsSelectionBadge {
                    selectionBadge
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous))
            .animation(DesignSystem.Animations.standard, value: presentation.selectionStyle)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
            .fill(backgroundColor)
            .shadow(
                color: presentation.selectionStyle == .active ? DesignSystem.Colors.primary.opacity(0.12) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
            .strokeBorder(borderColor, style: borderStyle)
    }

    private var selectionBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(DesignSystem.Colors.primary)
            .background(Circle().fill(Color.white))
            .padding(10)
            .transition(.scale.combined(with: .opacity))
    }

    private var backgroundColor: Color {
        switch presentation.selectionStyle {
        case .neutral:
            return DesignSystem.Colors.Background.elevated
        case .active, .pending, .selected:
            return DesignSystem.Colors.primary.opacity(Self.backgroundOpacity(for: presentation.selectionStyle))
        }
    }

    private var borderColor: Color {
        switch presentation.selectionStyle {
        case .neutral:
            return DesignSystem.Colors.Component.border.opacity(0.5)
        case .active:
            return DesignSystem.Colors.primary
        case .pending:
            return DesignSystem.Colors.primary.opacity(0.6)
        case .selected:
            return DesignSystem.Colors.primary.opacity(0.8)
        }
    }

    private var borderStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: Self.borderLineWidth(for: presentation.selectionStyle),
            dash: Self.borderDash(for: presentation.selectionStyle)
        )
    }

    public static func backgroundOpacity(for selectionStyle: AccountCardSelectionStyle) -> Double {
        switch selectionStyle {
        case .neutral: return 0
        case .active: return 0.08
        case .pending: return 0.04
        case .selected: return 0.06
        }
    }

    public static func borderLineWidth(for selectionStyle: AccountCardSelectionStyle) -> CGFloat {
        switch selectionStyle {
        case .active: return 2.0
        case .selected: return 1.5
        case .neutral, .pending: return 1.0
        }
    }

    public static func borderDash(for selectionStyle: AccountCardSelectionStyle) -> [CGFloat] {
        switch selectionStyle {
        case .pending: return [5, 4]
        case .neutral, .active, .selected: return []
        }
    }
}

@MainActor
private struct AccountSummaryCardPreviewContainer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.group) {
            AccountSummaryCard(presentation: .neutral) {
                Text("Neutral card")
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
            }

            AccountSummaryCard(
                presentation: AccountCardPresentation(
                    selectionStyle: .selected,
                    showsSelectionBadge: true
                )
            ) {
                Text("Selected card")
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
            }
        }
        .padding(PreviewLayoutTokens.Spacing.page)
        .background(DesignSystem.Colors.Background.canvas)
    }
}

#Preview("Account Summary Card") {
    AccountSummaryCardPreviewContainer()
        .frame(width: 340, height: 220)
}
