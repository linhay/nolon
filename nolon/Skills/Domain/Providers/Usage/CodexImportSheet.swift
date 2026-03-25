import SwiftUI
import Foundation
import AppKit
import ProviderUsage
import UniformTypeIdentifiers

struct CodexImportSheet: View {
    static func minimumSheetHeight(hasAnyCandidates: Bool) -> CGFloat {
        hasAnyCandidates ? 560 : 320
    }

    let sections: [ProviderUsageViewModel.CodexImportCandidateSection]
    let hasAnyCandidates: Bool
    let isRunningValidation: Bool
    let isRunningConnectionTests: Bool
    @Binding var isTargetingDropZone: Bool
    @Binding var searchText: String
    let globalErrorMessage: String?
    let onPickFiles: () -> Void
    let onPaste: () -> Void
    let onDropFiles: ([URL]) -> Void
    let onToggleSelection: (UUID, Bool) -> Void
    let onToggleGroupSelection: (String, Bool) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onRetry: (UUID) -> Void
    let onRetryAll: () -> Void
    let onRemove: (UUID) -> Void
    let onExportZIP: () -> Void
    let onExportSub2API: () -> Void
    let onImport: () -> Void
    let onCancel: () -> Void

    private var selectedCount: Int {
        sections.flatMap(\.items).filter { $0.validation.isValid && $0.isSelected }.count
    }

    private var canImport: Bool {
        selectedCount > 0
    }

    private var isBusy: Bool {
        isRunningValidation || isRunningConnectionTests
    }

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var importButtonTitle: String {
        guard selectedCount > 0 else {
            return NSLocalizedString("codex.import.sheet.import_selected", value: "导入选中", comment: "Import selected Codex accounts")
        }
        return String(
            format: NSLocalizedString("codex.import.sheet.import_selected_count", value: "导入 %d 个账号", comment: "Import selected Codex accounts with count"),
            selectedCount
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("codex.import.sheet.title", value: "导入账号", comment: "Codex import sheet title"))
                    .font(.title3.weight(.semibold))
                Text(NSLocalizedString(
                    "codex.import.sheet.subtitle",
                    value: "把账号文件先放进来，再决定导入哪些账号。",
                    comment: "Codex import sheet subtitle"
                ))
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            dropZone

            if let globalErrorMessage, !globalErrorMessage.isEmpty {
                errorBanner(globalErrorMessage)
            }

            if hasAnyCandidates {
                candidateToolbar
                candidateList
            }

            HStack(alignment: .center, spacing: 12) {
                Button(NSLocalizedString("generic.cancel", value: "Cancel", comment: "Cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                if isBusy {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(
                            isRunningValidation
                                ? NSLocalizedString("codex.import.sheet.progress.validating", value: "正在校验账号文件...", comment: "Codex import validating progress")
                                : NSLocalizedString("codex.import.sheet.progress.testing", value: "正在测试连接...", comment: "Codex import testing progress")
                        )
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                Spacer()
                Button(importButtonTitle) {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canImport || isRunningValidation)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: Self.minimumSheetHeight(hasAnyCandidates: hasAnyCandidates))
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.primary)
            Text(NSLocalizedString("codex.import.sheet.drop.title", value: "拖拽 auth.json 或 ZIP 到这里", comment: "Codex import drop title"))
                .font(.headline)
            Text(NSLocalizedString("codex.import.sheet.drop.subtitle", value: "支持 .json / .zip，也可以直接粘贴 auth JSON 或 localhost 登录回调链接。", comment: "Codex import drop subtitle"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            HStack(spacing: 10) {
                Button(NSLocalizedString("codex.import.sheet.pick_files", value: "选择文件", comment: "Pick import files")) {
                    onPickFiles()
                }
                .buttonStyle(.borderedProminent)
                Button(NSLocalizedString("codex.import.sheet.paste", value: "粘贴", comment: "Paste import content")) {
                    onPaste()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(isTargetingDropZone ? DesignSystem.Colors.primary.opacity(0.12) : DesignSystem.Colors.Background.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .strokeBorder(
                    isTargetingDropZone ? DesignSystem.Colors.primary : DesignSystem.Colors.Component.border.opacity(0.7),
                    style: StrokeStyle(lineWidth: isTargetingDropZone ? 2 : 1, dash: [6, 4])
                )
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargetingDropZone) { providers in
            resolveDroppedURLs(from: providers)
        }
    }

    private var candidateToolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(
                        format: NSLocalizedString("codex.accounts.selection.count", value: "已选 %d", comment: "Selected Codex account count"),
                        selectedCount
                    ))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
                    Text(String(
                        format: NSLocalizedString("codex.import.sheet.source_group_count", value: "%d 个来源组", comment: "Codex import source group count"),
                        sections.count
                    ))
                    .font(.caption2)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Spacer()

                SearchField(
                    placeholder: NSLocalizedString(
                        "codex.import.sheet.search.placeholder",
                        value: "搜索邮箱、名称或文件名",
                        comment: "Search import candidates placeholder"
                    ),
                    text: $searchText,
                    width: 260
                )
            }

            HStack(spacing: 10) {
                Spacer()

                Button(NSLocalizedString("codex.import.sheet.select_all", value: "全选", comment: "Select all import candidates")) {
                    onSelectAll()
                }
                .disabled(sections.flatMap(\.items).allSatisfy { !$0.validation.isValid })

                Button(NSLocalizedString("codex.import.sheet.deselect_all", value: "取消全选", comment: "Deselect all import candidates")) {
                    onDeselectAll()
                }
                .disabled(sections.flatMap(\.items).isEmpty)

                Button(NSLocalizedString("codex.import.sheet.action.export_zip", value: "导出 ZIP", comment: "Export selected import candidates to ZIP")) {
                    onExportZIP()
                }
                .disabled(!canImport || isRunningValidation)

                Button(NSLocalizedString("codex.import.sheet.action.export_sub2api", value: "导出 sub2api", comment: "Export selected import candidates to sub2api")) {
                    onExportSub2API()
                }
                .disabled(!canImport || isRunningValidation)

                Button(NSLocalizedString("codex.import.sheet.paste", value: "粘贴", comment: "Paste import content")) {
                    onPaste()
                }

                Button(NSLocalizedString("codex.import.sheet.retry_all", value: "重新测试全部", comment: "Retry all Codex import tests")) {
                    onRetryAll()
                }
                .disabled(sections.flatMap(\.items).filter(\.validation.isValid).isEmpty || isRunningConnectionTests || isRunningValidation)
            }
        }
    }

    private var candidateList: some View {
        Group {
            if sections.flatMap(\.items).isEmpty {
                if hasSearchText {
                    ContentUnavailableView(
                        NSLocalizedString("codex.import.sheet.search.empty.title", value: "没有匹配的候选账号", comment: "Empty search result title"),
                        systemImage: "magnifyingglass",
                        description: Text(NSLocalizedString(
                            "codex.import.sheet.search.empty.subtitle",
                            value: "换个关键字试试，或者清空搜索后查看全部候选项。",
                            comment: "Empty search result subtitle"
                        ))
                    )
                } else {
                    ContentUnavailableView(
                        NSLocalizedString("codex.import.sheet.empty.title", value: "还没有候选账号", comment: "Empty import candidates title"),
                        systemImage: "tray",
                        description: Text(NSLocalizedString(
                            "codex.import.sheet.empty.subtitle",
                            value: "拖拽或选择 auth.json / ZIP 后，候选账号会先显示在这里。",
                            comment: "Empty import candidates subtitle"
                        ))
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func sectionView(_ section: ProviderUsageViewModel.CodexImportCandidateSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.headline)
                    Text(String(
                        format: NSLocalizedString("codex.import.sheet.group.count", value: "%d / %d 已选", comment: "Selected count in import group"),
                        section.selectedItemCount,
                        section.selectableItemCount
                    ))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }

                Spacer()

                Button(
                    section.selectedItemCount == section.selectableItemCount && section.selectableItemCount > 0
                        ? NSLocalizedString("codex.import.sheet.group.deselect", value: "取消全选", comment: "Deselect group import candidates")
                        : NSLocalizedString("codex.import.sheet.group.select", value: "全选", comment: "Select group import candidates")
                ) {
                    let selectAllInGroup = !(section.selectedItemCount == section.selectableItemCount && section.selectableItemCount > 0)
                    onToggleGroupSelection(section.id, selectAllInGroup)
                }
                .disabled(section.selectableItemCount == 0)
                .font(.caption)
                .buttonStyle(.link)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(section.items) { candidate in
                    row(candidate)
                }
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

    private func row(_ candidate: ProviderUsageViewModel.CodexImportCandidate) -> some View {
        let isValid = candidate.validation.isValid

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { candidate.isSelected },
                        set: { onToggleSelection(candidate.id, $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!isValid)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.validation.suggestedName ?? candidate.sourceFileURL.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isValid ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                    if let email = candidate.validation.email, !email.isEmpty {
                        Text(email)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                        Text(candidate.sourceFileURL.lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    } else {
                        Text(candidate.sourceFileURL.lastPathComponent)
                            .font(.caption2)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    statusBadge(for: candidate)

                    if candidate.testStatus != .testing {
                        HStack(spacing: 8) {
                            if isValid {
                                Button(NSLocalizedString("codex.import.sheet.retry_single", value: "重试", comment: "Retry single import test")) {
                                    onRetry(candidate.id)
                                }
                                .disabled(isRunningValidation)
                                .buttonStyle(.link)
                            }

                            Button(NSLocalizedString("codex.import.sheet.remove", value: "移除", comment: "Remove import candidate")) {
                                onRemove(candidate.id)
                            }
                            .buttonStyle(.link)
                        }
                        .font(.caption2)
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
            }

            if let summary = candidate.testSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(candidate.testStatus == .failure ? DesignSystem.Colors.Status.error : DesignSystem.Colors.Text.secondary)
                    .padding(.leading, 26)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusL, style: .continuous)
                .fill(isValid ? DesignSystem.Colors.Background.elevated.opacity(0.6) : DesignSystem.Colors.Background.elevated.opacity(0.25))
        }
        .opacity(isValid ? 1 : 0.72)
    }

    private func errorBanner(_ message: String) -> some View {
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

    private func statusBadge(for candidate: ProviderUsageViewModel.CodexImportCandidate) -> some View {
        let label: String
        let color: Color
        switch candidate.testStatus {
        case .idle:
            label = NSLocalizedString("codex.import.sheet.status.idle", value: "待测试", comment: "Idle import test status")
            color = DesignSystem.Colors.Text.secondary
        case .testing:
            label = NSLocalizedString("codex.import.sheet.status.testing", value: "测试中", comment: "Testing import status")
            color = DesignSystem.Colors.primary
        case .success:
            label = NSLocalizedString("codex.import.sheet.status.connected", value: "已联通", comment: "Connected import status")
            color = DesignSystem.Colors.Status.success
        case .failure:
            label = candidate.validation.isValid
                ? NSLocalizedString("codex.import.sheet.status.failed", value: "失败", comment: "Failed import status")
                : NSLocalizedString("codex.import.sheet.status.invalid", value: "无效", comment: "Invalid import status")
            color = DesignSystem.Colors.Status.error
        }

        return Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func resolveDroppedURLs(from providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

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
                lock.lock()
                urls.append(resolvedURL)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            onDropFiles(urls)
        }
        return true
    }
}
