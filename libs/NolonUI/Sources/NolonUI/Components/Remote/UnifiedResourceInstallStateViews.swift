import NolonUIFoundation
import SwiftUI

// MARK: - UnifiedResourceInstallStateViews

enum ResourceInstallState: Equatable {
    case installed
    case installing
    case failed(message: String)
    case installable

    static func resolve(isInstalled: Bool, isInstalling: Bool, errorMessage: String?) -> ResourceInstallState {
        if isInstalled {
            return .installed
        }

        if isInstalling {
            return .installing
        }

        if let errorMessage, !errorMessage.isEmpty {
            return .failed(message: errorMessage)
        }

        return .installable
    }
}

public struct ResourceInstallStateView: View {
    public struct Config {
        public var isInstalled: Bool
        public var isInstalling: Bool
        public var errorMessage: String?
        public var onInstall: () -> Void
        public var onRetry: () -> Void

        public init(
            isInstalled: Bool,
            isInstalling: Bool,
            errorMessage: String?,
            onInstall: @escaping () -> Void,
            onRetry: @escaping () -> Void
        ) {
            self.isInstalled = isInstalled
            self.isInstalling = isInstalling
            self.errorMessage = errorMessage
            self.onInstall = onInstall
            self.onRetry = onRetry
        }
    }

    @State private var viewModel = ResourceInstallStateViewViewModel()
    private let state: ResourceInstallState
    private let onInstall: () -> Void
    private let onRetry: () -> Void

    public init(config: Config) {
        self.state = ResourceInstallState.resolve(
            isInstalled: config.isInstalled,
            isInstalling: config.isInstalling,
            errorMessage: config.errorMessage
        )
        self.onInstall = config.onInstall
        self.onRetry = config.onRetry
    }

    public init(
        isInstalled: Bool,
        isInstalling: Bool,
        errorMessage: String?,
        onInstall: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.init(
            config: Config(
                isInstalled: isInstalled,
                isInstalling: isInstalling,
                errorMessage: errorMessage,
                onInstall: onInstall,
                onRetry: onRetry
            )
        )
    }

    public var body: some View {
        switch state {
        case .installed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text(NSLocalizedString("remote.status.installed", value: "Installed", comment: "Remote installed status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.Status.success,
                background: DesignSystem.Colors.Status.success.opacity(0.10)
            )

        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(NSLocalizedString("remote.status.installing", value: "Installing", comment: "Remote installing status"))
            }
            .fontWeight(.medium)
            .dsBadge(
                foreground: DesignSystem.Colors.secondary,
                background: DesignSystem.Colors.secondary.opacity(0.10)
            )

        case let .failed(message):
            Button {
                onRetry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle")
                    Text(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"))
                }
                .fontWeight(.semibold)
                .dsBadge(
                    foreground: DesignSystem.Colors.Status.error,
                    background: DesignSystem.Colors.Status.error.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
            .help(message)

        case .installable:
            Button {
                onInstall()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text(NSLocalizedString("action.install", value: "Install", comment: "Install action"))
                }
                .fontWeight(.semibold)
                .dsBadge(
                    foreground: DesignSystem.Colors.primary,
                    background: DesignSystem.Colors.primary.opacity(0.10),
                    horizontalPadding: 10,
                    verticalPadding: 6
                )
            }
            .dsLinkButton()
        }
    }
}

public struct ResourceInstallStateSectionsView<
    Item: Identifiable,
    InstalledContent: View,
    InstallingContent: View,
    AvailableContent: View,
    FooterContent: View
>: View {
    public struct Config {
        public var installedTitle: String
        public var installingTitle: String
        public var availableTitle: String
        public var installedItems: [Item]
        public var installingItems: [Item]
        public var availableItems: [Item]
        public var columns: [GridItem]
        public var installedContent: (Item) -> InstalledContent
        public var installingContent: (Item) -> InstallingContent
        public var availableContent: (Item) -> AvailableContent
        public var footerContent: () -> FooterContent

        public init(
            installedTitle: String,
            installingTitle: String,
            availableTitle: String,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.installedTitle = installedTitle
            self.installingTitle = installingTitle
            self.availableTitle = availableTitle
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }

        public init(
            sectionTitles: ResourceCatalogTabSectionTitles,
            installedItems: [Item],
            installingItems: [Item],
            availableItems: [Item],
            columns: [GridItem],
            @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
            @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
            @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
            @ViewBuilder footerContent: @escaping () -> FooterContent
        ) {
            self.installedTitle = sectionTitles.installedTitle
            self.installingTitle = sectionTitles.installingTitle
            self.availableTitle = sectionTitles.availableTitle
            self.installedItems = installedItems
            self.installingItems = installingItems
            self.availableItems = availableItems
            self.columns = columns
            self.installedContent = installedContent
            self.installingContent = installingContent
            self.availableContent = availableContent
            self.footerContent = footerContent
        }
    }

    let installedTitle: String
    let installingTitle: String
    let availableTitle: String
    let installedItems: [Item]
    let installingItems: [Item]
    let availableItems: [Item]
    let columns: [GridItem]
    let installedContent: (Item) -> InstalledContent
    let installingContent: (Item) -> InstallingContent
    let availableContent: (Item) -> AvailableContent
    let footerContent: () -> FooterContent

    public init(config: Config) {
        self.installedTitle = config.installedTitle
        self.installingTitle = config.installingTitle
        self.availableTitle = config.availableTitle
        self.installedItems = config.installedItems
        self.installingItems = config.installingItems
        self.availableItems = config.availableItems
        self.columns = config.columns
        self.installedContent = config.installedContent
        self.installingContent = config.installingContent
        self.availableContent = config.availableContent
        self.footerContent = config.footerContent
    }

    public init(
        sectionTitles: ResourceCatalogTabSectionTitles,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                sectionTitles: sectionTitles,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public init(
        installedTitle: String,
        installingTitle: String,
        availableTitle: String,
        installedItems: [Item],
        installingItems: [Item],
        availableItems: [Item],
        columns: [GridItem],
        @ViewBuilder installedContent: @escaping (Item) -> InstalledContent,
        @ViewBuilder installingContent: @escaping (Item) -> InstallingContent,
        @ViewBuilder availableContent: @escaping (Item) -> AvailableContent,
        @ViewBuilder footerContent: @escaping () -> FooterContent
    ) {
        self.init(
            config: Config(
                installedTitle: installedTitle,
                installingTitle: installingTitle,
                availableTitle: availableTitle,
                installedItems: installedItems,
                installingItems: installingItems,
                availableItems: availableItems,
                columns: columns,
                installedContent: installedContent,
                installingContent: installingContent,
                availableContent: availableContent,
                footerContent: footerContent
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ResourceCatalogGridSection(
                title: installedTitle,
                items: installedItems,
                columns: columns
            ) { item in
                installedContent(item)
            }
            ResourceCatalogGridSection(
                title: installingTitle,
                items: installingItems,
                columns: columns
            ) { item in
                installingContent(item)
            }
            ResourceCatalogGridSection(
                title: availableTitle,
                items: availableItems,
                columns: columns
            ) { item in
                availableContent(item)
            }
            footerContent()
        }
    }
}
