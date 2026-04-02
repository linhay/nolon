import Foundation
import CoreGraphics

public enum CodexImportStatusTone {
    case neutral
    case info
    case success
    case error
}

public struct CodexImportStatusBadgeData {
    public let text: String
    public let tone: CodexImportStatusTone

    public init(text: String, tone: CodexImportStatusTone) {
        self.text = text
        self.tone = tone
    }
}

public struct CodexImportCandidateRowData: Identifiable {
    public let id: UUID
    public let title: String
    public let email: String?
    public let readonlyDetails: [String]
    public let sourceFileName: String
    public let isValid: Bool
    public let isSelected: Bool
    public let testSummary: String?
    public let statusBadge: CodexImportStatusBadgeData
    public let canRetry: Bool
    public let canRemove: Bool
    public let isRetryDisabled: Bool
    public let isSelectionDisabled: Bool

    public init(
        id: UUID,
        title: String,
        email: String?,
        readonlyDetails: [String] = [],
        sourceFileName: String,
        isValid: Bool,
        isSelected: Bool,
        testSummary: String?,
        statusBadge: CodexImportStatusBadgeData,
        canRetry: Bool,
        canRemove: Bool,
        isRetryDisabled: Bool,
        isSelectionDisabled: Bool
    ) {
        self.id = id
        self.title = title
        self.email = email
        self.readonlyDetails = readonlyDetails
        self.sourceFileName = sourceFileName
        self.isValid = isValid
        self.isSelected = isSelected
        self.testSummary = testSummary
        self.statusBadge = statusBadge
        self.canRetry = canRetry
        self.canRemove = canRemove
        self.isRetryDisabled = isRetryDisabled
        self.isSelectionDisabled = isSelectionDisabled
    }
}

public struct CodexImportSectionCardData: Identifiable {
    public let id: String
    public let title: String
    public let selectedItemCount: Int
    public let selectableItemCount: Int
    public let selectActionTitle: String
    public let isSelectActionDisabled: Bool

    public init(
        id: String,
        title: String,
        selectedItemCount: Int,
        selectableItemCount: Int,
        selectActionTitle: String,
        isSelectActionDisabled: Bool
    ) {
        self.id = id
        self.title = title
        self.selectedItemCount = selectedItemCount
        self.selectableItemCount = selectableItemCount
        self.selectActionTitle = selectActionTitle
        self.isSelectActionDisabled = isSelectActionDisabled
    }
}

public struct CodexImportDropZoneData {
    public let title: String
    public let subtitle: String
    public let pickFilesTitle: String
    public let pasteTitle: String
    public let minHeight: CGFloat

    public init(
        title: String = NSLocalizedString(
            "codex.import.sheet.drop.title",
            value: "拖拽 auth.json 或 ZIP 到这里",
            comment: "Codex import drop title"
        ),
        subtitle: String = NSLocalizedString(
            "codex.import.sheet.drop.subtitle",
            value: "支持 .json / .zip，也可以直接粘贴 auth JSON 或 localhost 登录回调链接。",
            comment: "Codex import drop subtitle"
        ),
        pickFilesTitle: String = NSLocalizedString(
            "codex.import.sheet.pick_files",
            value: "选择文件",
            comment: "Pick import files"
        ),
        pasteTitle: String = NSLocalizedString(
            "codex.import.sheet.paste",
            value: "粘贴",
            comment: "Paste import content"
        ),
        minHeight: CGFloat = 140
    ) {
        self.title = title
        self.subtitle = subtitle
        self.pickFilesTitle = pickFilesTitle
        self.pasteTitle = pasteTitle
        self.minHeight = minHeight
    }
}

public struct CodexImportToolbarData {
    public let selectedCountText: String
    public let sourceGroupCountText: String
    public let searchPlaceholder: String
    public let selectAllTitle: String
    public let deselectAllTitle: String
    public let exportZipTitle: String
    public let pasteTitle: String
    public let retryAllTitle: String
    public let isSelectAllDisabled: Bool
    public let isDeselectAllDisabled: Bool
    public let isExportZipDisabled: Bool
    public let isRetryAllDisabled: Bool

    public init(
        selectedCountText: String,
        sourceGroupCountText: String,
        searchPlaceholder: String = NSLocalizedString(
            "codex.import.sheet.search.placeholder",
            value: "Search email, name, or file name",
            comment: "Search import candidates placeholder"
        ),
        selectAllTitle: String = NSLocalizedString("codex.import.sheet.select_all", value: "Select All", comment: "Select all import candidates"),
        deselectAllTitle: String = NSLocalizedString("codex.import.sheet.deselect_all", value: "Deselect All", comment: "Deselect all import candidates"),
        exportZipTitle: String = NSLocalizedString("codex.import.sheet.action.export_zip", value: "Export ZIP", comment: "Export selected import candidates to ZIP"),
        pasteTitle: String = NSLocalizedString("codex.import.sheet.paste", value: "Paste", comment: "Paste import content"),
        retryAllTitle: String = NSLocalizedString("codex.import.sheet.retry_all", value: "Retry All", comment: "Retry all Codex import tests"),
        isSelectAllDisabled: Bool,
        isDeselectAllDisabled: Bool,
        isExportZipDisabled: Bool,
        isRetryAllDisabled: Bool
    ) {
        self.selectedCountText = selectedCountText
        self.sourceGroupCountText = sourceGroupCountText
        self.searchPlaceholder = searchPlaceholder
        self.selectAllTitle = selectAllTitle
        self.deselectAllTitle = deselectAllTitle
        self.exportZipTitle = exportZipTitle
        self.pasteTitle = pasteTitle
        self.retryAllTitle = retryAllTitle
        self.isSelectAllDisabled = isSelectAllDisabled
        self.isDeselectAllDisabled = isDeselectAllDisabled
        self.isExportZipDisabled = isExportZipDisabled
        self.isRetryAllDisabled = isRetryAllDisabled
    }
}

public struct CodexImportSheetScaffoldData {
    public let title: String
    public let subtitle: String
    public let cancelTitle: String
    public let importButtonTitle: String
    public let validatingProgressText: String
    public let testingProgressText: String
    public let isBusy: Bool
    public let isRunningValidation: Bool
    public let canImport: Bool
    public let hasAnyCandidates: Bool
    public let minWidth: CGFloat
    public let minHeight: CGFloat

    public init(
        title: String = NSLocalizedString(
            "codex.import.sheet.title",
            value: "导入账号",
            comment: "Codex import sheet title"
        ),
        subtitle: String = NSLocalizedString(
            "codex.import.sheet.subtitle",
            value: "把账号文件先放进来，再决定导入哪些账号。",
            comment: "Codex import sheet subtitle"
        ),
        cancelTitle: String = NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel"),
        importButtonTitle: String,
        validatingProgressText: String = NSLocalizedString(
            "codex.import.sheet.progress.validating",
            value: "正在校验账号文件...",
            comment: "Codex import validating progress"
        ),
        testingProgressText: String = NSLocalizedString(
            "codex.import.sheet.progress.testing",
            value: "正在测试连接...",
            comment: "Codex import testing progress"
        ),
        isBusy: Bool,
        isRunningValidation: Bool,
        canImport: Bool,
        hasAnyCandidates: Bool,
        minWidth: CGFloat = 760,
        minHeight: CGFloat
    ) {
        self.title = title
        self.subtitle = subtitle
        self.cancelTitle = cancelTitle
        self.importButtonTitle = importButtonTitle
        self.validatingProgressText = validatingProgressText
        self.testingProgressText = testingProgressText
        self.isBusy = isBusy
        self.isRunningValidation = isRunningValidation
        self.canImport = canImport
        self.hasAnyCandidates = hasAnyCandidates
        self.minWidth = minWidth
        self.minHeight = minHeight
    }
}

public struct CodexImportCandidateListContainerData {
    public let hasItems: Bool
    public let hasSearchText: Bool
    public let emptySearchTitle: String
    public let emptySearchSubtitle: String
    public let emptyTitle: String
    public let emptySubtitle: String

    public init(
        hasItems: Bool,
        hasSearchText: Bool,
        emptySearchTitle: String = NSLocalizedString(
            "codex.import.sheet.search.empty.title",
            value: "No matching candidates",
            comment: "Empty search result title"
        ),
        emptySearchSubtitle: String = NSLocalizedString(
            "codex.import.sheet.search.empty.subtitle",
            value: "Try another keyword, or clear the search to see all candidates.",
            comment: "Empty search result subtitle"
        ),
        emptyTitle: String = NSLocalizedString(
            "codex.import.sheet.empty.title",
            value: "No candidates yet",
            comment: "Empty import candidates title"
        ),
        emptySubtitle: String = NSLocalizedString(
            "codex.import.sheet.empty.subtitle",
            value: "After dropping or choosing auth.json / ZIP, candidates will appear here.",
            comment: "Empty import candidates subtitle"
        )
    ) {
        self.hasItems = hasItems
        self.hasSearchText = hasSearchText
        self.emptySearchTitle = emptySearchTitle
        self.emptySearchSubtitle = emptySearchSubtitle
        self.emptyTitle = emptyTitle
        self.emptySubtitle = emptySubtitle
    }
}
