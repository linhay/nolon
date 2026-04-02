import SwiftUI

public struct ProviderUsageTitleHeaderView<TrailingContent: View>: View {
    private let title: String
    private let trailingContent: TrailingContent

    public init(
        title: String,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.title = title
        self.trailingContent = trailingContent()
    }

    public var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)

            Spacer()

            trailingContent
        }
    }
}

public struct ProviderUsageEllipsisMenuButton<Content: View>: View {
    private let iconSize: CGFloat?
    private let content: () -> Content

    public init(
        iconSize: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.iconSize = iconSize
        self.content = content
    }

    public var body: some View {
        EllipsisMenuButton(iconSize: iconSize) {
            content()
        }
    }
}

public struct ProviderUsageCloseActionLabel: View {
    private let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Label(title, systemImage: "xmark.circle.fill")
            .dsIconLabelButton()
    }
}

public struct ProviderUsageMenuOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct ProviderUsageActionsMenuView<PrimaryContent: View>: View {
    private let primaryContent: PrimaryContent
    private let showDangerSection: Bool
    private let dangerSectionTitle: String
    private let dangerActionTitle: String
    private let onDangerAction: (() -> Void)?

    public init(
        showDangerSection: Bool,
        dangerSectionTitle: String,
        dangerActionTitle: String,
        onDangerAction: (() -> Void)?,
        @ViewBuilder primaryContent: () -> PrimaryContent
    ) {
        self.showDangerSection = showDangerSection
        self.dangerSectionTitle = dangerSectionTitle
        self.dangerActionTitle = dangerActionTitle
        self.onDangerAction = onDangerAction
        self.primaryContent = primaryContent()
    }

    public var body: some View {
        ProviderUsageEllipsisMenuButton {
            primaryContent

            if showDangerSection {
                Section {
                    Button(role: .destructive) {
                        onDangerAction?()
                    } label: {
                        ProviderUsageCloseActionLabel(title: dangerActionTitle)
                    }
                } header: {
                    Text(dangerSectionTitle)
                }
            }
        }
    }
}

public struct ProviderUsageMenuActionItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        systemImage: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
    }
}

public struct ProviderUsageMenuActionSectionModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let items: [ProviderUsageMenuActionItem]

    public init(
        id: String,
        title: String,
        items: [ProviderUsageMenuActionItem]
    ) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct ProviderUsageMenuActionsSectionView: View {
    public let section: ProviderUsageMenuActionSectionModel
    public let onTap: (ProviderUsageMenuActionItem) -> Void

    public init(
        section: ProviderUsageMenuActionSectionModel,
        onTap: @escaping (ProviderUsageMenuActionItem) -> Void
    ) {
        self.section = section
        self.onTap = onTap
    }

    public var body: some View {
        Section {
            ForEach(section.items) { item in
                Button {
                    onTap(item)
                } label: {
                    Label(item.title, systemImage: item.systemImage)
                }
                .disabled(!item.isEnabled)
            }
        } header: {
            Text(section.title)
        }
    }
}

public struct ProviderUsageMenuSortOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let isSelected: Bool

    public init(id: String, title: String, isSelected: Bool) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
    }
}

public struct ProviderUsageDisplayActionItem: Equatable, Sendable {
    public let title: String
    public let systemImage: String

    public init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }
}

public struct ProviderUsageDisplaySectionView: View {
    public let sectionTitle: String
    public let layoutTitle: String
    public let layoutSystemImage: String
    public let layoutOptions: [ProviderUsageMenuOption]
    @Binding private var selectedLayoutID: String

    public let groupingTitle: String?
    public let groupingSystemImage: String?
    public let groupingOptions: [ProviderUsageMenuOption]
    private let selectedGroupingID: Binding<String>?

    public let sortingTitle: String?
    public let sortingSystemImage: String?
    public let sortingOptions: [ProviderUsageMenuSortOption]
    public let onSelectSortingID: ((String) -> Void)?

    public let trailingAction: ProviderUsageDisplayActionItem?
    public let onTapTrailingAction: (() -> Void)?

    public init(
        sectionTitle: String,
        layoutTitle: String,
        layoutSystemImage: String,
        layoutOptions: [ProviderUsageMenuOption],
        selectedLayoutID: Binding<String>,
        groupingTitle: String? = nil,
        groupingSystemImage: String? = nil,
        groupingOptions: [ProviderUsageMenuOption] = [],
        selectedGroupingID: Binding<String>? = nil,
        sortingTitle: String? = nil,
        sortingSystemImage: String? = nil,
        sortingOptions: [ProviderUsageMenuSortOption] = [],
        onSelectSortingID: ((String) -> Void)? = nil,
        trailingAction: ProviderUsageDisplayActionItem? = nil,
        onTapTrailingAction: (() -> Void)? = nil
    ) {
        self.sectionTitle = sectionTitle
        self.layoutTitle = layoutTitle
        self.layoutSystemImage = layoutSystemImage
        self.layoutOptions = layoutOptions
        self._selectedLayoutID = selectedLayoutID
        self.groupingTitle = groupingTitle
        self.groupingSystemImage = groupingSystemImage
        self.groupingOptions = groupingOptions
        self.selectedGroupingID = selectedGroupingID
        self.sortingTitle = sortingTitle
        self.sortingSystemImage = sortingSystemImage
        self.sortingOptions = sortingOptions
        self.onSelectSortingID = onSelectSortingID
        self.trailingAction = trailingAction
        self.onTapTrailingAction = onTapTrailingAction
    }

    public var body: some View {
        Section {
            if let groupingTitle, let groupingSystemImage, let selectedGroupingID {
                Picker(selection: selectedGroupingID) {
                    ForEach(groupingOptions) { option in
                        Text(option.title).tag(option.id)
                    }
                } label: {
                    Label(groupingTitle, systemImage: groupingSystemImage)
                }
            }

            Picker(selection: $selectedLayoutID) {
                ForEach(layoutOptions) { option in
                    Text(option.title).tag(option.id)
                }
            } label: {
                Label(layoutTitle, systemImage: layoutSystemImage)
            }

            if let sortingTitle, let sortingSystemImage, let onSelectSortingID {
                Menu {
                    ForEach(sortingOptions) { option in
                        Button {
                            onSelectSortingID(option.id)
                        } label: {
                            HStack {
                                Text(option.title)
                                if option.isSelected {
                                    Spacer(minLength: 8)
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(sortingTitle, systemImage: sortingSystemImage)
                }
            }

            if let trailingAction {
                Button(action: { onTapTrailingAction?() }) {
                    Label(trailingAction.title, systemImage: trailingAction.systemImage)
                }
            }
        } header: {
            Text(sectionTitle)
        }
    }
}

public struct ProviderUsageScreenScaffold<Header: View, Content: View>: View {
    private let isEmbedded: Bool
    private let navigationTitle: String
    private let isShowingCopyToast: Bool
    private let copyToastMessage: String
    private let header: Header
    private let content: Content

    public init(
        isEmbedded: Bool,
        navigationTitle: String,
        isShowingCopyToast: Bool,
        copyToastMessage: String,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.isEmbedded = isEmbedded
        self.navigationTitle = navigationTitle
        self.isShowingCopyToast = isShowingCopyToast
        self.copyToastMessage = copyToastMessage
        self.header = header()
        self.content = content()
    }

    public var body: some View {
        Group {
            if isEmbedded {
                scaffoldContent
            } else {
                scaffoldContent.navigationTitle(navigationTitle)
            }
        }
    }

    private var scaffoldContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .bottomTrailingOverlay(isPresented: isShowingCopyToast) {
            ToastView(
                config: .init(
                    text: copyToastMessage,
                    systemImage: "doc.on.doc",
                    style: .success
                )
            )
        }
        .animation(Animation.easeOut(duration: 0.2), value: isShowingCopyToast)
    }
}
