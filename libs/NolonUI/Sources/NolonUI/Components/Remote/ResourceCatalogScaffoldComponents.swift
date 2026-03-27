import SwiftUI

public struct CircularIconActionButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    public init(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

public struct ResourceCatalogToolbarView: View {
    @Binding var searchText: String
    let isSearching: Bool
    let searchPlaceholder: String
    let onRefresh: (() -> Void)?
    let onClose: (() -> Void)?

    public init(
        searchText: Binding<String>,
        isSearching: Bool,
        searchPlaceholder: String = NSLocalizedString(
            "remote.search.placeholder",
            value: "Search",
            comment: "Search placeholder"
        ),
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.isSearching = isSearching
        self.searchPlaceholder = searchPlaceholder
        self.onRefresh = onRefresh
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 12) {
            SearchField(
                placeholder: searchPlaceholder,
                text: $searchText,
                showSearching: isSearching
            )
            .frame(maxWidth: .infinity)

            if let onRefresh {
                CircularIconActionButton(
                    systemImage: "arrow.clockwise",
                    help: NSLocalizedString("Refresh", comment: "Refresh"),
                    action: onRefresh
                )
            }
            if let onClose {
                ResourceCenterCloseButton(action: onClose)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

public struct ResourceCatalogSectionBlock<Content: View>: View {
    let title: String
    let count: Int
    let content: () -> Content

    public init(
        title: String,
        count: Int,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.count = count
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .dsBadge(
                        foreground: DesignSystem.Colors.Text.secondary,
                        background: DesignSystem.Colors.Component.controlFillSubtle
                    )
                Spacer()
            }
            .padding(.top, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct InlineWarningBannerView: View {
    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    public init(
        message: String,
        retryTitle: String,
        onRetry: @escaping () -> Void
    ) {
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .dsSecondaryText(font: .callout)
                .lineLimit(2)
            Spacer()
            Button(retryTitle) {
                onRetry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.10),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.28),
            borderWidth: 1
        )
        .padding(.horizontal)
    }
}
