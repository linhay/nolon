import Foundation

public struct CodexSessionsMetricData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let value: String

    public init(id: String, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
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

    public init(id: String, title: String, targetProviderID: String) {
        self.id = id
        self.title = title
        self.targetProviderID = targetProviderID
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

public struct CodexSessionsGroupingOptionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct CodexSessionsOverviewData: Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let refreshTitle: String
    public let groupingTitle: String?
    public let groupingOptions: [CodexSessionsGroupingOptionData]
    public let selectedGroupingID: String?
    public let statusMessage: String?
    public let backgroundScanningMessage: String?
    public let paginationMessage: String?
    public let metrics: [CodexSessionsMetricData]
    public let isRefreshDisabled: Bool

    public init(
        title: String,
        subtitle: String,
        refreshTitle: String,
        groupingTitle: String?,
        groupingOptions: [CodexSessionsGroupingOptionData],
        selectedGroupingID: String?,
        statusMessage: String?,
        backgroundScanningMessage: String?,
        paginationMessage: String?,
        metrics: [CodexSessionsMetricData],
        isRefreshDisabled: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.refreshTitle = refreshTitle
        self.groupingTitle = groupingTitle
        self.groupingOptions = groupingOptions
        self.selectedGroupingID = selectedGroupingID
        self.statusMessage = statusMessage
        self.backgroundScanningMessage = backgroundScanningMessage
        self.paginationMessage = paginationMessage
        self.metrics = metrics
        self.isRefreshDisabled = isRefreshDisabled
    }
}

public struct CodexSessionsRowData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let providerName: String?
    public let isArchived: Bool
    public let isEditable: Bool
    public let summary: String?
    public let badges: [CodexSessionsBadgeData]
    public let metadataItems: [CodexSessionsMetadataItemData]
    public let rolloutPath: String
    public let showInFinderTitle: String?
    public let actions: [CodexSessionsActionItemData]
    public let actionMenuTitle: String?
    public let readOnlyText: String?

    public init(
        id: String,
        title: String,
        providerName: String?,
        isArchived: Bool,
        isEditable: Bool,
        summary: String?,
        badges: [CodexSessionsBadgeData],
        metadataItems: [CodexSessionsMetadataItemData],
        rolloutPath: String,
        showInFinderTitle: String?,
        actions: [CodexSessionsActionItemData],
        actionMenuTitle: String?,
        readOnlyText: String?
    ) {
        self.id = id
        self.title = title
        self.providerName = providerName
        self.isArchived = isArchived
        self.isEditable = isEditable
        self.summary = summary
        self.badges = badges
        self.metadataItems = metadataItems
        self.rolloutPath = rolloutPath
        self.showInFinderTitle = showInFinderTitle
        self.actions = actions
        self.actionMenuTitle = actionMenuTitle
        self.readOnlyText = readOnlyText
    }

    public var showsRevealInFinder: Bool {
        guard let showInFinderTitle else { return false }
        return !showInFinderTitle.isEmpty
    }
}

public struct CodexSessionsSectionData: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let badges: [CodexSessionsBadgeData]
    public let actions: [CodexSessionsActionItemData]
    public let actionMenuTitle: String?
    public let isCollapsed: Bool
    public let rows: [CodexSessionsRowData]

    public init(
        id: String,
        title: String,
        subtitle: String?,
        badges: [CodexSessionsBadgeData],
        actions: [CodexSessionsActionItemData],
        actionMenuTitle: String?,
        isCollapsed: Bool = false,
        rows: [CodexSessionsRowData]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.actions = actions
        self.actionMenuTitle = actionMenuTitle
        self.isCollapsed = isCollapsed
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
