import SwiftUI
import NolonUIFoundation

public struct UsageSnapshotCardView<QuotaContent: View>: View {
    let data: UsageSnapshotCardData
    let quotaContent: () -> QuotaContent

    public init(
        data: UsageSnapshotCardData,
        @ViewBuilder quotaContent: @escaping () -> QuotaContent
    ) {
        self.data = data
        self.quotaContent = quotaContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch data.body {
            case .success(let footerItems):
                VStack(alignment: .leading, spacing: 12) {
                    quotaContent()
                    footer(items: footerItems)
                }
            case let .error(message, diagnostic, hints):
                errorContent(message: message, diagnostic: diagnostic, hints: hints)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.header.displayName)
                    .font(.headline)

                Spacer()

                Text(data.header.providerLabel)
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
            }

            if let identityLine = data.header.identityLine, !identityLine.isEmpty {
                Text(identityLine)
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let accountLine = data.header.accountLine, !accountLine.isEmpty {
                    keyValueRow(
                        title: NSLocalizedString("usage.metric.account", value: "Account", comment: "Account label"),
                        value: accountLine
                    )
                }
                if let planLine = data.header.planLine, !planLine.isEmpty {
                    keyValueRow(
                        title: NSLocalizedString("usage.metric.plan", value: "Plan", comment: "Plan label"),
                        value: planLine
                    )
                }
            }
            .dsTertiaryText(font: .caption)
            .textSelection(.enabled)
        }
    }

    private func keyValueRow(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("•")
            Text(value)
        }
    }

    private func footer(items: [String]) -> some View {
        let visibleItems = items.filter { !$0.isEmpty }
        return HStack(spacing: 8) {
            ForEach(Array(visibleItems.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("•")
                }
                Text(item)
            }
        }
        .font(.caption)
        .dsTertiaryText(font: .caption)
    }

    private func errorContent(message: String, diagnostic: String?, hints: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.monitor.error.title", value: "Failed to load usage", comment: "Error title"))
                .dsErrorText(font: .subheadline)
            Text(message)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .textSelection(.enabled)
            if let diagnostic, !diagnostic.isEmpty {
                Text("diagnostic: \(diagnostic)")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .textSelection(.enabled)
            }
            if !hints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(hints, id: \.self) { hint in
                        Text("• \(hint)")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
