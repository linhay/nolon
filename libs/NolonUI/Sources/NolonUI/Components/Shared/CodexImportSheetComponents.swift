import SwiftUI
import Foundation
import UniformTypeIdentifiers
import NolonUIFoundation

public struct CodexImportErrorBannerView: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Status.error)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(DesignSystem.Colors.Status.error.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusM, style: .continuous)
                .strokeBorder(DesignSystem.Colors.Status.error.opacity(0.25), lineWidth: 1)
        }
    }
}

public struct CodexImportCandidateRowView: View {
    let data: CodexImportCandidateRowData
    let onSetSelected: @Sendable (Bool) -> Void
    let onRetry: @Sendable () -> Void
    let onRemove: @Sendable () -> Void

    public init(
        data: CodexImportCandidateRowData,
        onSetSelected: @escaping @Sendable (Bool) -> Void,
        onRetry: @escaping @Sendable () -> Void,
        onRemove: @escaping @Sendable () -> Void
    ) {
        self.data = data
        self.onSetSelected = onSetSelected
        self.onRetry = onRetry
        self.onRemove = onRemove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { data.isSelected },
                        set: onSetSelected
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(data.isSelectionDisabled)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(data.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(data.isValid ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                    if let email = data.email, !email.isEmpty {
                        Text(email)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        Text(data.sourceFileName)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    } else {
                        Text(data.sourceFileName)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge

                    HStack(spacing: 8) {
                        if data.canRetry {
                            Button(NSLocalizedString("codex.import.sheet.retry_single", value: "重试", comment: "Retry single import test")) {
                                onRetry()
                            }
                            .disabled(data.isRetryDisabled)
                            .buttonStyle(.link)
                        }

                        if data.canRemove {
                            Button(NSLocalizedString("codex.import.sheet.remove", value: "移除", comment: "Remove import candidate")) {
                                onRemove()
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }

            if let summary = data.testSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(data.statusBadge.tone == .error ? DesignSystem.Colors.Status.error : DesignSystem.Colors.Text.secondary)
                    .padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(data.isValid ? DesignSystem.Colors.Background.elevated.opacity(0.6) : DesignSystem.Colors.Background.elevated.opacity(0.25))
        }
        .opacity(data.isValid ? 1 : 0.72)
    }

    private var statusBadge: some View {
        Text(data.statusBadge.text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch data.statusBadge.tone {
        case .neutral:
            return DesignSystem.Colors.Text.secondary
        case .info:
            return DesignSystem.Colors.primary
        case .success:
            return DesignSystem.Colors.Status.success
        case .error:
            return DesignSystem.Colors.Status.error
        }
    }
}

public struct CodexImportSectionCardView<Content: View>: View {
    let data: CodexImportSectionCardData
    let onSelectAction: () -> Void
    let content: () -> Content

    public init(
        data: CodexImportSectionCardData,
        onSelectAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.data = data
        self.onSelectAction = onSelectAction
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(.headline)
                    Text(String(
                        format: NSLocalizedString("codex.import.sheet.group.count", value: "%d / %d 已选", comment: "Selected count in import group"),
                        data.selectedItemCount,
                        data.selectableItemCount
                    ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Spacer()

                Button(data.selectActionTitle) {
                    onSelectAction()
                }
                .disabled(data.isSelectActionDisabled)
                .font(.caption)
                .buttonStyle(.link)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            VStack(spacing: 4) {
                content()
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(DesignSystem.Colors.Background.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(DesignSystem.Colors.Component.border.opacity(0.45), lineWidth: 1)
        }
    }
}

public struct CodexImportDropZoneView: View {
    let data: CodexImportDropZoneData
    @Binding var isTargeted: Bool
    let onPickFiles: () -> Void
    let onPaste: () -> Void
    let onDroppedURLs: ([URL]) -> Void

    public init(
        data: CodexImportDropZoneData,
        isTargeted: Binding<Bool>,
        onPickFiles: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onDroppedURLs: @escaping ([URL]) -> Void
    ) {
        self.data = data
        self._isTargeted = isTargeted
        self.onPickFiles = onPickFiles
        self.onPaste = onPaste
        self.onDroppedURLs = onDroppedURLs
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.primary)
            Text(data.title)
                .font(.headline)
            Text(data.subtitle)
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            HStack(spacing: 10) {
                Button(data.pickFilesTitle) {
                    onPickFiles()
                }
                .buttonStyle(.borderedProminent)
                Button(data.pasteTitle) {
                    onPaste()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: data.minHeight)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(isTargeted ? DesignSystem.Colors.primary.opacity(0.12) : DesignSystem.Colors.Background.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(
                    isTargeted ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.7),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            resolveDroppedURLs(from: providers)
        }
    }

    private func resolveDroppedURLs(from providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        let accumulator = URLAccumulator()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let resolvedURL: URL? = {
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    }
                    if let url = item as? URL {
                        return url
                    }
                    if let string = item as? String {
                        return URL(string: string)
                    }
                    return nil
                }()
                guard let resolvedURL else { return }
                accumulator.append(resolvedURL)
            }
        }

        group.notify(queue: .main) {
            let urls = accumulator.snapshot()
            guard !urls.isEmpty else { return }
            onDroppedURLs(urls)
        }
        return true
    }
}

public struct CodexImportToolbarView: View {
    let data: CodexImportToolbarData
    @Binding var searchText: String
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onExportZip: () -> Void
    let onExportSub2api: () -> Void
    let onPaste: () -> Void
    let onRetryAll: () -> Void

    public init(
        data: CodexImportToolbarData,
        searchText: Binding<String>,
        onSelectAll: @escaping () -> Void,
        onDeselectAll: @escaping () -> Void,
        onExportZip: @escaping () -> Void,
        onExportSub2api: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onRetryAll: @escaping () -> Void
    ) {
        self.data = data
        self._searchText = searchText
        self.onSelectAll = onSelectAll
        self.onDeselectAll = onDeselectAll
        self.onExportZip = onExportZip
        self.onExportSub2api = onExportSub2api
        self.onPaste = onPaste
        self.onRetryAll = onRetryAll
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.selectedCountText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Text(data.sourceGroupCountText)
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Spacer()

                SearchField(
                    placeholder: data.searchPlaceholder,
                    text: $searchText,
                    width: 260
                )
            }

            HStack(spacing: 10) {
                Spacer()

                Button(data.selectAllTitle) {
                    onSelectAll()
                }
                .disabled(data.isSelectAllDisabled)

                Button(data.deselectAllTitle) {
                    onDeselectAll()
                }
                .disabled(data.isDeselectAllDisabled)

                Button(data.exportZipTitle) {
                    onExportZip()
                }
                .disabled(data.isExportZipDisabled)

                Button(data.exportSub2apiTitle) {
                    onExportSub2api()
                }
                .disabled(data.isExportSub2apiDisabled)

                Button(data.pasteTitle) {
                    onPaste()
                }

                Button(data.retryAllTitle) {
                    onRetryAll()
                }
                .disabled(data.isRetryAllDisabled)
            }
        }
    }
}

public struct CodexImportCandidateListContainerView<Content: View>: View {
    let data: CodexImportCandidateListContainerData
    let content: () -> Content

    public init(
        data: CodexImportCandidateListContainerData,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.data = data
        self.content = content
    }

    public var body: some View {
        Group {
            if !data.hasItems {
                if data.hasSearchText {
                    ContentUnavailableView(
                        data.emptySearchTitle,
                        systemImage: "magnifyingglass",
                        description: Text(data.emptySearchSubtitle)
                    )
                } else {
                    ContentUnavailableView(
                        data.emptyTitle,
                        systemImage: "tray",
                        description: Text(data.emptySubtitle)
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        content()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

public struct CodexImportSheetScaffold<DropZone: View, Toolbar: View, CandidateList: View>: View {
    let data: CodexImportSheetScaffoldData
    let globalErrorMessage: String?
    let onCancel: () -> Void
    let onImport: () -> Void
    let dropZone: () -> DropZone
    let toolbar: () -> Toolbar
    let candidateList: () -> CandidateList

    public init(
        data: CodexImportSheetScaffoldData,
        globalErrorMessage: String?,
        onCancel: @escaping () -> Void,
        onImport: @escaping () -> Void,
        @ViewBuilder dropZone: @escaping () -> DropZone,
        @ViewBuilder toolbar: @escaping () -> Toolbar,
        @ViewBuilder candidateList: @escaping () -> CandidateList
    ) {
        self.data = data
        self.globalErrorMessage = globalErrorMessage
        self.onCancel = onCancel
        self.onImport = onImport
        self.dropZone = dropZone
        self.toolbar = toolbar
        self.candidateList = candidateList
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.title3.weight(.semibold))
                Text(data.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            dropZone()

            if let globalErrorMessage, !globalErrorMessage.isEmpty {
                CodexImportErrorBannerView(message: globalErrorMessage)
            }

            if data.hasAnyCandidates {
                toolbar()
                candidateList()
            }

            HStack(alignment: .center, spacing: 12) {
                Button(data.cancelTitle) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                if data.isBusy {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(data.isRunningValidation ? data.validatingProgressText : data.testingProgressText)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                Spacer()
                Button(data.importButtonTitle) {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!data.canImport || data.isRunningValidation)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: data.minWidth, minHeight: data.minHeight)
    }
}

private final class URLAccumulator: @unchecked Sendable {
    private var urls: [URL] = []
    private let lock = NSLock()

    func append(_ url: URL) {
        lock.lock()
        urls.append(url)
        lock.unlock()
    }

    func snapshot() -> [URL] {
        lock.lock()
        let current = urls
        lock.unlock()
        return current
    }
}
