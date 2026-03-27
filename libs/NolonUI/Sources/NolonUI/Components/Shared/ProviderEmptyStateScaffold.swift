import SwiftUI

public struct ProviderEmptyStateScaffold<Content: View>: View {
    public enum Preset {
        case usageUnsupported
        case gatewayPickerEmpty

        public var emptyTitle: String {
            switch self {
            case .usageUnsupported:
                return NSLocalizedString(
                    "usage.monitor.unsupported.title",
                    value: "Usage not supported",
                    comment: "Unsupported title"
                )
            case .gatewayPickerEmpty:
                return NSLocalizedString(
                    "codex.gateway.accounts.picker.empty.title",
                    value: "没有可添加的账号",
                    comment: "Gateway account picker empty title"
                )
            }
        }

        public var emptySystemImage: String {
            switch self {
            case .usageUnsupported:
                return "chart.bar.xaxis"
            case .gatewayPickerEmpty:
                return "person.crop.circle.badge.checkmark"
            }
        }

        public var emptyDescription: String {
            switch self {
            case .usageUnsupported:
                return NSLocalizedString(
                    "usage.monitor.unsupported.desc",
                    value: "Usage is not configured for this provider yet.",
                    comment: "Unsupported description"
                )
            case .gatewayPickerEmpty:
                return NSLocalizedString(
                    "codex.gateway.accounts.picker.empty.desc",
                    value: "当前所有账号都已在此网关卡片中。",
                    comment: "Gateway account picker empty description"
                )
            }
        }
    }

    let isEmpty: Bool
    let emptyTitle: String
    let emptySystemImage: String
    let emptyDescription: String
    let content: () -> Content

    public init(
        isEmpty: Bool,
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.emptyTitle = emptyTitle
        self.emptySystemImage = emptySystemImage
        self.emptyDescription = emptyDescription
        self.content = content
    }

    public init(
        isEmpty: Bool,
        preset: Preset,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isEmpty: isEmpty,
            emptyTitle: preset.emptyTitle,
            emptySystemImage: preset.emptySystemImage,
            emptyDescription: preset.emptyDescription,
            content: content
        )
    }

    public var body: some View {
        if isEmpty {
            ProviderGridEmptyStateView(
                title: emptyTitle,
                systemImage: emptySystemImage,
                description: emptyDescription
            )
        } else {
            content()
        }
    }
}
