import SwiftUI

public struct AccountQuotaRow: Identifiable {
    public let id = UUID()
    public let title: String
    public let remainingText: String
    public let progress: CGFloat
    public let meta: String

    public init(title: String, remainingText: String, progress: CGFloat, meta: String) {
        self.title = title
        self.remainingText = remainingText
        self.progress = progress
        self.meta = meta
    }
}

public enum AccountQuotaStyle {
    public static func color(for progress: CGFloat) -> Color {
        if progress <= 0.1 {
            return DesignSystem.Colors.Status.error
        }
        if progress <= 0.25 {
            return DesignSystem.Colors.Status.warning
        }
        return DesignSystem.Colors.primary
    }
}

public struct AccountQuotaModule: View {
    @State private var viewModel = AccountQuotaModuleViewModel()
    public let rows: [AccountQuotaRow]
    public let creditsText: String

    public init(rows: [AccountQuotaRow], creditsText: String) {
        self.rows = rows
        self.creditsText = creditsText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PreviewLayoutTokens.Spacing.row) {
            ForEach(rows) { row in
                quotaRow(row)
            }
            HStack {
                Text("Credits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Text(creditsText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quotaRow(_ row: AccountQuotaRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(row.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Text(row.meta)
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                Spacer(minLength: 0)
                Text(row.remainingText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AccountQuotaStyle.color(for: row.progress))
            }
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AccountQuotaStyle.color(for: row.progress).opacity(0.22))
                            .frame(width: max(0, min(1, row.progress)) * totalWidth)
                    }
            }
            .frame(height: 8)
        }
    }
}

public struct AccountInlineQuotaProgress: View {
    @State private var viewModel = AccountInlineQuotaProgressViewModel()
    public let progress: CGFloat
    public let percentText: String

    public init(progress: CGFloat, percentText: String) {
        self.progress = progress
        self.percentText = percentText
    }

    public var body: some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignSystem.Colors.Component.controlFill)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AccountQuotaStyle.color(for: progress).opacity(0.22))
                            .frame(width: max(0, min(1, progress)) * totalWidth)
                    }
            }
            .frame(height: 8)

            Text(percentText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AccountQuotaStyle.color(for: progress))
        }
    }
}
