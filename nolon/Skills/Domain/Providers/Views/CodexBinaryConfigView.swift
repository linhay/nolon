import Observation
import ProviderCatalog
import CodexProvider
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import STFilePath
import NolonResourceKit
import NolonUI
import NolonUIFoundation

@MainActor
@Observable
final class CodexBinaryConfigViewModel {
    var manifest: CodexBinaryManifest = .default
    var isLoading = false
    var isCheckingUpdates = false
    var errorMessage: String?
    var preferredModelDraft: String = ""
    var currentCLIVersion: String = ""
    var isDownloadingRemoteVersion = false
    var remoteDownloadProgress: CodexDownloadProgress?
    var remoteReleases: [CodexRemoteRelease] = []
    var activeRemoteDownloadTag: String?
    var pathStatus: CodexBinaryManager.CodexPathStatus?
    var isConfiguringPath = false
    var isCheckingPath = false
    var isSyncingRemoteVersions = false
    var remoteVersionSyncFailed = false
    var selectedVersionRowID: String?

    private let manager: CodexBinaryManager
    private let provider: Provider

    init(provider: Provider, manager: CodexBinaryManager = .shared) {
        self.provider = provider
        self.manager = manager
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do { _ = try await manager.discoverXcodeAgentVersions() } catch {}

        do {
            // Fast path: render from local manifest/cache first, avoid waiting on network.
            manifest = try await manager.loadManifest()
            preferredModelDraft = loadModelFromConfig() ?? manifest.preferredModel ?? ""
            applyCachedRemoteRelease(from: manifest)
            ensureValidSelectedRow()
            isLoading = false
        } catch {
            // Recover from malformed/corrupted manifest without blocking the page.
            do {
                manifest = .default
                _ = try await manager.saveManifest(manifest)
                preferredModelDraft = loadModelFromConfig() ?? manifest.preferredModel ?? ""
                applyCachedRemoteRelease(from: manifest)
                ensureValidSelectedRow()
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                return
            }
        }

        await refreshCurrentCLIVersion()
        if !isCodexXcodeProvider {
            await refreshPathStatus()
        } else {
            pathStatus = nil
        }

        // Slow path: refresh update status and remote versions in background.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSyncingRemoteVersions = true
            self.remoteVersionSyncFailed = false
            self.manifest = await self.manager.checkForRustReleaseUpdateIfNeeded(force: false)
            self.applyCachedRemoteRelease(from: self.manifest)
            await self.refreshRemoteReleases()
            self.remoteVersionSyncFailed = self.manifest.updateState == .checkFailed
            self.ensureValidSelectedRow()
            self.isSyncingRemoteVersions = false
        }
    }

    func checkUpdates(force: Bool = true) async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        manifest = await manager.checkForRustReleaseUpdateIfNeeded(force: force)
        await refreshRemoteReleases()
        ensureValidSelectedRow()
    }

    func importLocalBinary(from url: URL) async {
        do {
            _ = try await manager.importBinary(from: url)
            manifest = try await manager.loadManifest()
            await refreshCurrentCLIVersion()
            ensureValidSelectedRow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadLatest() async {
        guard let raw = manifest.lastSeenRemoteAssetURL, let url = URL(string: raw) else {
            return
        }

        do {
            isDownloadingRemoteVersion = true
            remoteDownloadProgress = CodexDownloadProgress(fractionCompleted: nil, completedBytes: nil, totalBytes: nil)
            activeRemoteDownloadTag = manifest.lastSeenRemoteTag
            _ = try await manager.downloadAndImport(from: url, progress: { [weak self] progress in
                self?.remoteDownloadProgress = progress
            })
            manifest = try await manager.loadManifest()
            await refreshRemoteReleases()
            await refreshCurrentCLIVersion()
            ensureValidSelectedRow()
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        } catch {
            errorMessage = error.localizedDescription
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        }
    }

    func downloadRemoteRelease(_ release: CodexRemoteRelease) async {
        do {
            isDownloadingRemoteVersion = true
            remoteDownloadProgress = CodexDownloadProgress(fractionCompleted: nil, completedBytes: nil, totalBytes: nil)
            activeRemoteDownloadTag = release.tag
            _ = try await manager.downloadAndImport(from: release.assetURL, progress: { [weak self] progress in
                self?.remoteDownloadProgress = progress
            })
            manifest = try await manager.loadManifest()
            await refreshRemoteReleases()
            await refreshCurrentCLIVersion()
            ensureValidSelectedRow(preferredRowID: "remote-\(release.tag)")
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        } catch {
            errorMessage = error.localizedDescription
            remoteDownloadProgress = nil
            isDownloadingRemoteVersion = false
            activeRemoteDownloadTag = nil
        }
    }

    func activate(versionId: String) async {
        do {
            try await manager.activate(versionId: versionId)
            manifest = try await manager.loadManifest()
            await refreshCurrentCLIVersion()
            ensureValidSelectedRow(preferredRowID: "local-\(versionId)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(versionId: String) async {
        do {
            try await manager.remove(versionId: versionId)
            manifest = try await manager.loadManifest()
            await refreshCurrentCLIVersion()
            ensureValidSelectedRow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applySelectedModel(_ model: String) async {
        do {
            let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            try await manager.applyModelToConfig(trimmed, configFile: resolvedConfigFile())
            manifest = try await manager.loadManifest()
            preferredModelDraft = trimmed
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPathStatus() async {
        guard !isCodexXcodeProvider else {
            pathStatus = nil
            return
        }
        isCheckingPath = true
        defer { isCheckingPath = false }
        pathStatus = await manager.codexPathStatus()
    }

    func installPath() async {
        guard !isCodexXcodeProvider else { return }
        isConfiguringPath = true
        defer { isConfiguringPath = false }
        do {
            try await manager.installCodexPathToShellProfile()
            pathStatus = await manager.codexPathStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPreferredModel() async {
        do {
            try await manager.clearPreferredModel(configFile: resolvedConfigFile())
            manifest = try await manager.loadManifest()
            preferredModelDraft = ""
            await refreshCurrentCLIVersion()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openModelConfig() async {
        let configFile = resolvedConfigFile()
        let configPath = configFile ?? STFile("\(NSHomeDirectory())/.codex/config.toml")
        do {
            _ = STFolder(configPath.url.deletingLastPathComponent()).createIfNotExists()
            if !configPath.isExists {
                let initialModel = preferredModelDraft.nonEmpty ?? "gpt-5.3-codex"
                try "model = \"\(initialModel)\"\n".write(to: configPath.url, atomically: true, encoding: .utf8)
            }
            NSWorkspace.shared.open(configPath.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openGitHubReleases() {
        guard let url = URL(string: "https://github.com/openai/codex/releases") else { return }
        NSWorkspace.shared.open(url)
    }

    func isCodexProvider() -> Bool {
        provider.templateId == "codex" || provider.templateId == "codexXcode"
    }

    var isCodexXcodeProvider: Bool {
        provider.templateId == "codexXcode"
    }

    func statusText() -> String {
        switch manifest.updateState {
        case .idle:
            return NSLocalizedString("codex.binary.update.idle", value: "Not checked yet", comment: "Update status")
        case .checking:
            return NSLocalizedString("codex.binary.update.checking", value: "Checking updates...", comment: "Update status")
        case .upToDate:
            return NSLocalizedString("codex.binary.update.up_to_date", value: "Up to date", comment: "Update status")
        case .updateAvailable:
            guard hasUpdateAvailable else {
                return NSLocalizedString("codex.binary.update.up_to_date", value: "Up to date", comment: "Update status")
            }
            if let version = manifest.lastSeenRemoteVersion {
                return String(
                    format: NSLocalizedString("codex.binary.update.available", value: "Update available: %@", comment: "Update status"),
                    version
                )
            }
            return NSLocalizedString("codex.binary.update.available_generic", value: "Update available", comment: "Update status")
        case .checkFailed:
            return NSLocalizedString("codex.binary.update.failed", value: "Update check failed", comment: "Update status")
        }
    }

    var localVersionsSorted: [ManagedCodexVersion] {
        manifest.versions.sorted { lhs, rhs in
            let compared = CodexBinaryManager.compareVersion(lhs.detectedVersion, rhs.detectedVersion)
            if compared == 0 {
                return lhs.importedAt > rhs.importedAt
            }
            return compared > 0
        }
    }

    var showBetaVersions: Bool {
        manifest.includeBetaVersions
    }

    var remoteVersion: (version: String, assetURL: URL)? {
        guard manifest.updateState == .updateAvailable,
              manifest.lastSeenRemoteAssetURL != nil,
              let version = manifest.lastSeenRemoteVersion,
              let raw = manifest.lastSeenRemoteAssetURL,
              let url = URL(string: raw) else {
            return nil
        }
        let alreadyInstalled = manifest.versions.contains { $0.detectedVersion == version }
        return alreadyInstalled ? nil : (version, url)
    }

    var hasUpdateAvailable: Bool {
        remoteVersion != nil
    }

    var remoteReleaseRows: [CodexRemoteRelease] {
        let installed = Set(manifest.versions.map(\.detectedVersion))
        let installedURLs = Set(manifest.versions.compactMap(\.sourceURL))
        let candidates = showBetaVersions
            ? remoteReleases
            : remoteReleases.filter { !$0.isPrerelease }
        let filtered = candidates.filter { candidate in
            if installed.contains(candidate.version) { return false }
            if installedURLs.contains(candidate.assetURL.absoluteString) { return false }
            return true
        }
        return filtered.sorted { lhs, rhs in
            let compared = CodexBinaryManager.compareVersion(lhs.version, rhs.version)
            if compared == 0 {
                return lhs.tag > rhs.tag
            }
            return compared > 0
        }
    }

    var combinedVersionRows: [VersionRow] {
        let local = localVersionsSorted.map { VersionRow.local($0) }
        let remote = remoteReleaseRows.map { VersionRow.remote($0) }
        return (local + remote).sorted { lhs, rhs in
            let compared = CodexBinaryManager.compareVersion(lhs.versionString, rhs.versionString)
            if compared == 0 {
                return lhs.secondarySortKey > rhs.secondarySortKey
            }
            return compared > 0
        }
    }

    var primaryActionTitle: String {
        if hasUpdateAvailable, let version = manifest.lastSeenRemoteVersion, !version.isEmpty {
            return String(
                format: NSLocalizedString(
                    "codex.binary.download_specific",
                    value: "Download %@",
                    comment: "Download specific version"
                ),
                version
            )
        }
        return NSLocalizedString("codex.binary.check_updates", value: "Check Updates", comment: "Check updates")
    }

    func runPrimaryAction() async {
        if hasUpdateAvailable {
            await downloadLatest()
        } else {
            await checkUpdates(force: true)
        }
    }

    func setShowBetaVersions(_ enabled: Bool) async {
        do {
            try await manager.setIncludeBetaVersions(enabled)
            manifest = try await manager.loadManifest()
            await checkUpdates(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshRemoteReleases() async {
        do {
            remoteReleases = try await manager.fetchRemoteReleases(includePrerelease: showBetaVersions)
            remoteVersionSyncFailed = false
            ensureValidSelectedRow()
        } catch {
            // Keep existing/cached rows; remote list failure should not block Binary page.
            remoteVersionSyncFailed = true
        }
    }

    private func applyCachedRemoteRelease(from manifest: CodexBinaryManifest) {
        guard let tag = manifest.lastSeenRemoteTag,
              let version = manifest.lastSeenRemoteVersion,
              let raw = manifest.lastSeenRemoteAssetURL,
              let assetURL = URL(string: raw) else {
            if remoteReleases.isEmpty {
                remoteReleases = []
            }
            return
        }

        let cached = CodexRemoteRelease(
            tag: tag,
            version: version,
            assetURL: assetURL,
            htmlURL: manifest.lastSeenRemoteHTMLURL.flatMap(URL.init(string:)),
            publishedAt: manifest.lastSeenRemotePublishedAt,
            notes: manifest.lastSeenRemoteNotes,
            isPrerelease: !CodexBinaryManager.isStableVersion(version)
        )

        if remoteReleases.isEmpty {
            remoteReleases = [cached]
            return
        }

        if !remoteReleases.contains(where: { $0.tag == cached.tag }) {
            remoteReleases.insert(cached, at: 0)
        }
    }

    func selectVersionRow(_ rowID: String) {
        selectedVersionRowID = rowID
    }

    func selectedReleaseNotesData() -> CodexBinaryReleaseNotesData? {
        guard let selectedVersionRowID,
              let row = combinedVersionRows.first(where: { $0.id == selectedVersionRowID }) else {
            return nil
        }
        let release = release(for: row)
        return CodexBinaryReleaseNotesData(
            title: NSLocalizedString(
                "codex.binary.release_notes.title",
                value: "Release Notes",
                comment: "Release notes title"
            ),
            versionText: "v\(row.versionString)",
            subtitleText: release.flatMap(Self.releaseSubtitle(for:)),
            notesMarkdown: release?.notes,
            actionURL: release?.htmlURL
        )
    }

    private func release(for row: VersionRow) -> CodexRemoteRelease? {
        switch row {
        case .remote(let release):
            return release
        case .local(let version):
            if let sourceURL = version.sourceURL,
               let matched = remoteReleases.first(where: { $0.assetURL.absoluteString == sourceURL }) {
                return matched
            }
            if let matched = remoteReleases.first(where: { $0.version == version.detectedVersion }) {
                return matched
            }
            if manifest.lastSeenRemoteVersion == version.detectedVersion,
               let tag = manifest.lastSeenRemoteTag,
               let raw = manifest.lastSeenRemoteAssetURL,
               let assetURL = URL(string: raw) {
                return CodexRemoteRelease(
                    tag: tag,
                    version: version.detectedVersion,
                    assetURL: assetURL,
                    htmlURL: manifest.lastSeenRemoteHTMLURL.flatMap(URL.init(string:)),
                    publishedAt: manifest.lastSeenRemotePublishedAt,
                    notes: manifest.lastSeenRemoteNotes,
                    isPrerelease: !CodexBinaryManager.isStableVersion(version.detectedVersion)
                )
            }
            return nil
        }
    }

    private func ensureValidSelectedRow(preferredRowID: String? = nil) {
        let validIDs = Set(combinedVersionRows.map(\.id))
        if let preferredRowID, validIDs.contains(preferredRowID) {
            selectedVersionRowID = preferredRowID
            return
        }
        if let selectedVersionRowID, validIDs.contains(selectedVersionRowID) {
            return
        }
        selectedVersionRowID = combinedVersionRows.first?.id
    }

    private static func releaseSubtitle(for release: CodexRemoteRelease) -> String? {
        guard let publishedAt = release.publishedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return String(
            format: NSLocalizedString(
                "codex.binary.release_notes.subtitle",
                value: "Published %@",
                comment: "Release notes published date"
            ),
            formatter.string(from: publishedAt)
        )
    }

    func resolvedConfigFile() -> STFile? {
        let rawSkillsPath = (provider.defaultSkillsPath as NSString).expandingTildeInPath
        if !rawSkillsPath.isEmpty {
            let skillsFolder = STFolder(rawSkillsPath)
            let codexHome = STFolder(skillsFolder.url.deletingLastPathComponent())
            return STFile(codexHome.url.appendingPathComponent("config.toml"))
        }

        return STFile("\(NSHomeDirectory())/.codex/config.toml")
    }

    private func loadModelFromConfig() -> String? {
        guard let configFile = resolvedConfigFile(),
              configFile.isExists,
              let content = try? configFile.read() else {
            return nil
        }
        return Self.parsePreferredModel(from: content)
    }

    static func parsePreferredModel(from content: String) -> String? {
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let equalIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard key == "model" else { continue }
            let rhs = trimmed[trimmed.index(after: equalIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if rhs.hasPrefix("\""), rhs.hasSuffix("\""), rhs.count >= 2 {
                return String(rhs.dropFirst().dropLast())
            }
            return rhs.nonEmpty
        }
        return nil
    }

    private func refreshCurrentCLIVersion() async {
        do {
            if isCodexXcodeProvider {
                if let xcodeURL = await manager.xcodeAgentCodexBinaryURL(),
                   let version = await manager.detectCodexVersion(at: xcodeURL),
                   !version.isEmpty
                {
                    currentCLIVersion = version
                    return
                }
            } else if let version = try await manager.currentCLIVersion(), !version.isEmpty {
                currentCLIVersion = version
                return
            }
        } catch {
            // Keep UI resilient; fallback to unknown.
        }
        currentCLIVersion = NSLocalizedString("codex.binary.cli_version.unknown", value: "Unknown", comment: "Unknown CLI version")
    }
}

enum VersionRow: Identifiable, Hashable {
    case remote(CodexRemoteRelease)
    case local(ManagedCodexVersion)

    var id: String {
        switch self {
        case .remote(let release):
            return "remote-\(release.tag)"
        case .local(let version):
            return "local-\(version.id)"
        }
    }

    var versionString: String {
        switch self {
        case .remote(let release):
            return release.version
        case .local(let version):
            return version.detectedVersion
        }
    }

    var secondarySortKey: String {
        switch self {
        case .remote(let release):
            return release.tag
        case .local(let version):
            return version.id
        }
    }
}

struct CodexBinaryConfigView: View {
    let provider: Provider
    @State private var viewModel: CodexBinaryConfigViewModel
    @State private var showingImporter = false

    init(provider: Provider) {
        self.provider = provider
        self._viewModel = State(initialValue: CodexBinaryConfigViewModel(provider: provider))
    }

    var body: some View {
        NolonUI.CodexBinaryPageScaffold(
            isSupported: viewModel.isCodexProvider(),
            isLoading: viewModel.isLoading,
            unsupportedTitle: NSLocalizedString("codex.binary.not_supported.title", value: "Not Supported", comment: "Not supported"),
            unsupportedSystemImage: "shippingbox",
            unsupportedDescription: NSLocalizedString("codex.binary.not_supported.desc", value: "Binary management is only available for Codex providers.", comment: "Not supported"),
            checkingUpdatesText: viewModel.isCheckingUpdates
                ? NSLocalizedString("codex.binary.update.checking", value: "Checking updates...", comment: "Update status")
                : nil
        ) {
            content
        }
        .task {
            await viewModel.load()
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await viewModel.importLocalBinary(from: url) }
        }
        .messageAlert(
            title: NSLocalizedString("codex.binary.error.title", value: "Binary Error", comment: "Binary error"),
            message: $viewModel.errorMessage
        )
    }

    private var content: some View {
        NolonUI.ProviderTabScrollScaffold {
                NolonUI.CodexAdvancedSectionHeaderView(
                    title: NSLocalizedString(
                        "codex.binary.section.update_versions",
                        value: "Versions",
                        comment: "Merged versions section"
                    )
                )
                mergedVersionSection
        }
    }

    private var mergedVersionSection: some View {
        NolonUI.CodexBinaryVersionsSectionView(
            statusHeaderData: binaryStatusHeaderData,
            actionBarData: actionBarData,
            versionTableData: versionTableData,
            releaseNotesData: viewModel.selectedReleaseNotesData(),
            onPrimaryAction: {
                Task { await viewModel.runPrimaryAction() }
            },
            onCheckUpdates: {
                Task { await viewModel.checkUpdates(force: true) }
            },
            onImportLocal: {
                showingImporter = true
            },
            onOpenGitHub: {
                viewModel.openGitHubReleases()
            },
            onToggleBeta: { enabled in
                Task { await viewModel.setShowBetaVersions(enabled) }
            },
            onTapRow: { rowID in
                viewModel.selectVersionRow(rowID)
                handleVersionTableSelect(rowID: rowID)
            },
            onTapAction: { rowID in
                viewModel.selectVersionRow(rowID)
                handleVersionTableAction(rowID: rowID)
            }
        )
    }

    private var binaryStatusHeaderData: CodexBinaryStatusHeaderData {
        CodexBinaryStatusHeaderData(
            hasUpdateAvailable: viewModel.hasUpdateAvailable,
            statusText: viewModel.statusText(),
            currentCLIVersion: viewModel.currentCLIVersion,
            isSyncingRemoteVersions: viewModel.isSyncingRemoteVersions,
            remoteVersionSyncFailed: viewModel.remoteVersionSyncFailed
        )
    }

    private var actionBarData: CodexBinaryActionBarData {
        CodexBinaryActionBarData(
            primaryActionTitle: viewModel.primaryActionTitle,
            isBusy: viewModel.isCheckingUpdates || viewModel.isDownloadingRemoteVersion,
            showBetaEnabled: viewModel.showBetaVersions
        )
    }

    private var versionTableData: CodexBinaryVersionTableData {
        let rows = viewModel.combinedVersionRows.map { row in
            switch row {
            case .remote(let release):
                let isActiveDownload = viewModel.isDownloadingRemoteVersion && viewModel.activeRemoteDownloadTag == release.tag
                let progressFraction = isActiveDownload ? viewModel.remoteDownloadProgress?.fractionCompleted : nil
                let progressText: String?
                if isActiveDownload,
                   let progress = viewModel.remoteDownloadProgress,
                   let completed = progress.completedBytes,
                   let total = progress.totalBytes {
                    progressText = CodexBinaryFormatters.byteProgressText(completed: completed, total: total)
                } else {
                    progressText = nil
                }
                return CodexBinaryVersionRowData(
                    id: row.id,
                    kind: .remote,
                    nameText: String(
                        format: NSLocalizedString("codex.binary.version.github", value: "Codex %@", comment: "GitHub version name"),
                        release.version
                    ),
                    versionText: "v\(release.version)",
                    sourceText: NSLocalizedString("codex.binary.source.github", value: "GitHub", comment: "GitHub source"),
                    stateText: isActiveDownload
                        ? NSLocalizedString("codex.binary.state.downloading", value: "Downloading", comment: "Downloading state")
                        : NSLocalizedString("codex.binary.state.available", value: "Available", comment: "Available state"),
                    stateTone: .warning,
                    actionTitle: isActiveDownload ? nil : NSLocalizedString("codex.binary.download", value: "Download", comment: "Download"),
                    actionEnabled: !viewModel.isDownloadingRemoteVersion,
                    isActionInProgress: isActiveDownload,
                    progressFraction: progressFraction,
                    progressText: progressText,
                    inProgressFallbackText: NSLocalizedString("codex.binary.downloading", value: "Downloading…", comment: "Downloading label"),
                    isSelectable: false
                )
            case .local(let version):
                let isActive = viewModel.manifest.selectedVersionId == version.id
                return CodexBinaryVersionRowData(
                    id: row.id,
                    kind: .local,
                    nameText: version.displayName,
                    versionText: "v\(version.detectedVersion)",
                    sourceText: version.source,
                    stateText: isActive
                        ? NSLocalizedString("codex.binary.active", value: "Active", comment: "Active")
                        : NSLocalizedString("codex.binary.inactive", value: "Inactive", comment: "Inactive"),
                    stateTone: isActive ? .success : .secondary,
                    actionTitle: NSLocalizedString("generic.delete", value: "Delete", comment: "Delete"),
                    actionEnabled: !isActive,
                    isActionInProgress: false,
                    progressFraction: nil,
                    progressText: nil,
                    inProgressFallbackText: nil,
                    isSelectable: !isActive
                )
            }
        }

        return CodexBinaryVersionTableData(rows: rows)
    }

    private func handleVersionTableSelect(rowID: String) {
        guard let row = viewModel.combinedVersionRows.first(where: { $0.id == rowID }) else { return }
        guard case .local(let version) = row else { return }
        guard viewModel.manifest.selectedVersionId != version.id else { return }
        Task { await viewModel.activate(versionId: version.id) }
    }

    private func handleVersionTableAction(rowID: String) {
        guard let row = viewModel.combinedVersionRows.first(where: { $0.id == rowID }) else { return }
        switch row {
        case .remote(let release):
            Task { await viewModel.downloadRemoteRelease(release) }
        case .local(let version):
            Task { await viewModel.remove(versionId: version.id) }
        }
    }
}
