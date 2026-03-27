import SwiftUI
import NolonUIFoundation

public struct CodexRuntimeActionsBarView: View {
    public let data: CodexRuntimeActionsBarData
    public let onRefresh: () -> Void

    public init(data: CodexRuntimeActionsBarData, onRefresh: @escaping () -> Void) {
        self.data = data
        self.onRefresh = onRefresh
    }

    public var body: some View {
        HStack(spacing: 10) {
            Button(action: onRefresh) {
                Label(data.refreshTitle, systemImage: data.refreshSystemImage)
            }
            .disabled(data.isBusy)

            if let summary = data.stopSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .dsSecondaryText(font: .caption)
            }

            Spacer()
        }
    }
}

public struct CodexRuntimeProcessesSectionCard<Content: View>: View {
    public let data: CodexRuntimeProcessesSectionData
    public let isEmpty: Bool
    public let content: () -> Content

    public init(
        data: CodexRuntimeProcessesSectionData,
        isEmpty: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.data = data
        self.isEmpty = isEmpty
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.title)
                .font(.headline)

            if isEmpty {
                Text(data.emptyText)
                    .dsSecondaryText(font: .callout)
            } else {
                content()
            }
        }
        .padding(12)
        .dsCard(
            background: DesignSystem.Colors.Background.surface,
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Component.border,
            borderWidth: 1
        )
    }
}
