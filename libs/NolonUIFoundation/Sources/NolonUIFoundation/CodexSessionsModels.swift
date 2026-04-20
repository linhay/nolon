import Foundation

public enum CodexSessionsSectionPresentationKind: Equatable, Sendable {
    case rewritableGroup
    case singleSessionOnly
    case readOnly
}

public struct CodexSessionsMetricData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let detailText: String?

    public init(id: String, title: String, value: String, detailText: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.detailText = detailText
    }
}

public struct CodexSessionsBadgeData: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct CodexSessionsActionItemData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let targetProviderID: String
    public let primaryText: String
    public let secondaryText: String?

    public init(
        id: String,
        title: String,
        targetProviderID: String,
        primaryText: String? = nil,
        secondaryText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.targetProviderID = targetProviderID
        self.primaryText = primaryText ?? targetProviderID
        self.secondaryText = secondaryText
    }

    public var menuLabelText: String {
        guard let secondaryText, !secondaryText.isEmpty else { return primaryText }
        return "\(primaryText) (\(secondaryText))"
    }
}

public struct CodexSessionsMetadataItemData: Identifiable, Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        case regular
        case code
    }

    public let id: String
    public let icon: String
    public let text: String
    public let style: Style

    public init(
        id: String,
        icon: String,
        text: String,
        style: Style = .regular
    ) {
        self.id = id
        self.icon = icon
        self.text = text
        self.style = style
    }
}

public struct CodexSessionsShareData: Equatable, Sendable {
    public let title: String
    public let item: String

    public init(title: String, item: String) {
        self.title = title
        self.item = item
    }
}

public struct CodexSessionsGroupingOptionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct CodexSessionsSortingOptionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public enum CodexSessionsOverviewDisplayMode: Equatable, Sendable {
    case compact
    case diagnostic
}

public struct CodexSessionsOverviewData: Equatable, Sendable {
    public let displayMode: CodexSessionsOverviewDisplayMode
    public let title: String
    public let subtitle: String
    public let refreshTitle: String
    public let groupingTitle: String?
    public let groupingOptions: [CodexSessionsGroupingOptionData]
    public let selectedGroupingID: String?
    public let sortingTitle: String?
    public let sortingOptions: [CodexSessionsSortingOptionData]
    public let selectedSortingID: String?
    public let statusMessage: String?
    public let backgroundScanningMessage: String?
    public let paginationMessage: String?
    public let metrics: [CodexSessionsMetricData]
    public let isRefreshDisabled: Bool

    public init(
        displayMode: CodexSessionsOverviewDisplayMode,
        title: String,
        subtitle: String,
        refreshTitle: String,
        groupingTitle: String?,
        groupingOptions: [CodexSessionsGroupingOptionData],
        selectedGroupingID: String?,
        sortingTitle: String?,
        sortingOptions: [CodexSessionsSortingOptionData],
        selectedSortingID: String?,
        statusMessage: String?,
        backgroundScanningMessage: String?,
        paginationMessage: String?,
        metrics: [CodexSessionsMetricData],
        isRefreshDisabled: Bool
    ) {
        self.displayMode = displayMode
        self.title = title
        self.subtitle = subtitle
        self.refreshTitle = refreshTitle
        self.groupingTitle = groupingTitle
        self.groupingOptions = groupingOptions
        self.selectedGroupingID = selectedGroupingID
        self.sortingTitle = sortingTitle
        self.sortingOptions = sortingOptions
        self.selectedSortingID = selectedSortingID
        self.statusMessage = statusMessage
        self.backgroundScanningMessage = backgroundScanningMessage
        self.paginationMessage = paginationMessage
        self.metrics = metrics
        self.isRefreshDisabled = isRefreshDisabled
    }
}

public enum CodexSessionsUsageDisplayData: Equatable, Sendable {
    case placeholder(text: String)
    case value(primaryText: String, secondaryText: String?)
    case failed(text: String)
}

public struct CodexSessionsRowData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let nameMetadataItems: [CodexSessionsMetadataItemData]
    public let idText: String
    public let idSecondaryText: String?
    public let timeText: String
    public let providerText: String
    public let usage: CodexSessionsUsageDisplayData
    public let isArchived: Bool
    public let isEditable: Bool
    public let summary: String?
    public let rolloutPath: String
    public let showInFinderTitle: String?
    public let copyPathTitle: String?
    public let stateRowCount: Int
    public let actions: [CodexSessionsActionItemData]
    public let readOnlyText: String?
    public let menuMetadataItems: [CodexSessionsMetadataItemData]

    public init(
        id: String,
        title: String,
        nameMetadataItems: [CodexSessionsMetadataItemData] = [],
        idText: String,
        idSecondaryText: String? = nil,
        timeText: String,
        providerText: String,
        usage: CodexSessionsUsageDisplayData,
        isArchived: Bool,
        isEditable: Bool,
        summary: String?,
        rolloutPath: String,
        showInFinderTitle: String?,
        copyPathTitle: String? = nil,
        stateRowCount: Int = 0,
        actions: [CodexSessionsActionItemData],
        readOnlyText: String?,
        menuMetadataItems: [CodexSessionsMetadataItemData] = []
    ) {
        self.id = id
        self.title = title
        self.nameMetadataItems = nameMetadataItems
        self.idText = idText
        self.idSecondaryText = idSecondaryText
        self.timeText = timeText
        self.providerText = providerText
        self.usage = usage
        self.isArchived = isArchived
        self.isEditable = isEditable
        self.summary = summary
        self.rolloutPath = rolloutPath
        self.showInFinderTitle = showInFinderTitle
        self.copyPathTitle = copyPathTitle
        self.stateRowCount = stateRowCount
        self.actions = actions
        self.readOnlyText = readOnlyText
        self.menuMetadataItems = menuMetadataItems
    }

    public var showsRevealInFinder: Bool {
        guard let showInFinderTitle else { return false }
        return !showInFinderTitle.isEmpty
    }
}

public struct CodexSessionsSectionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let usage: CodexSessionsUsageDisplayData?
    public let shareData: CodexSessionsShareData?
    public let titleSecondaryText: String?
    public let subtitle: String?
    public let presentationKind: CodexSessionsSectionPresentationKind
    public let badges: [CodexSessionsBadgeData]
    public let actions: [CodexSessionsActionItemData]
    public let actionMenuTitle: String?
    public let isExpanded: Bool
    public let expansionTitle: String?
    public let rows: [CodexSessionsRowData]

    public init(
        id: String,
        title: String,
        usage: CodexSessionsUsageDisplayData? = nil,
        shareData: CodexSessionsShareData? = nil,
        titleSecondaryText: String? = nil,
        subtitle: String?,
        presentationKind: CodexSessionsSectionPresentationKind = .rewritableGroup,
        badges: [CodexSessionsBadgeData],
        actions: [CodexSessionsActionItemData],
        actionMenuTitle: String?,
        isExpanded: Bool = false,
        expansionTitle: String? = nil,
        rows: [CodexSessionsRowData]
    ) {
        self.id = id
        self.title = title
        self.usage = usage
        self.shareData = shareData
        self.titleSecondaryText = titleSecondaryText
        self.subtitle = subtitle
        self.presentationKind = presentationKind
        self.badges = badges
        self.actions = actions
        self.actionMenuTitle = actionMenuTitle
        self.isExpanded = isExpanded
        self.expansionTitle = expansionTitle
        self.rows = rows
    }
}

public struct CodexSessionsLoadMoreData: Equatable, Sendable {
    public let title: String
    public let isDisabled: Bool

    public init(title: String, isDisabled: Bool) {
        self.title = title
        self.isDisabled = isDisabled
    }
}
