import SwiftUI
import Observation
import OSLog
import STFilePath
import NolonResourceKit

@MainActor
@Observable
final class RemoteRepositorySidebarViewModel {

    private let logger = Logger(subsystem: "com.nolon", category: "RemoteRepositorySidebarViewModel")
    
    // Directory selection for Git repos
    var showingDirectoryPicker = false
    var pendingRepository: RemoteRepository?
    var detectedCandidates: [GitRepository.SkillsDirectoryCandidate] = []
    var selectedDirectoryIndices: Set<Int> = []
    
    // Token input for SSH-unavailable repos
    var showingTokenInput = false
    var tokenInputRepository: RemoteRepository?
    var tokenInputHost: String = ""
    var inputToken: String = ""
    
    // Repository management
    var showingAddRepository = false
    var editingRepository: RemoteRepository?  // For edit mode
    var isSyncing = false
    var syncingRepositoryID: String?
    var syncingRepositoryName: String?
    var syncCompletionMessage: String?
    var syncCompletionRepositoryName: String?
    var syncCompletionStyle: SyncCompletionStyle?

    private var syncCompletionToken: UUID?
    private var repositorySelectionTask: Task<Void, Never>?
    private var syncCompletionDismissTask: Task<Void, Never>?

    private let syncSuccessDisplayDuration: TimeInterval = 1.6

    private let syncFailureDisplayDuration: TimeInterval = 2.6
    private let syncOrchestrator = RepositorySyncOrchestrator()

    enum SyncCompletionStyle {
        case success
        case failure
    }

    nonisolated deinit {}

    @MainActor
    func cancelPendingTasks() {
        repositorySelectionTask?.cancel()
        syncCompletionDismissTask?.cancel()
    }
    
    func handleDirectoryCandidatesFound(repo: RemoteRepository, candidates: [GitRepository.SkillsDirectoryCandidate]) {
        pendingRepository = repo
        detectedCandidates = candidates
        let preferredPaths = Set(repo.skillsPaths)
        if preferredPaths.isEmpty {
            selectedDirectoryIndices = Set(0..<candidates.count)
        } else {
            selectedDirectoryIndices = Set(
                candidates.enumerated().compactMap { index, candidate in
                    preferredPaths.contains(candidate.path) ? index : nil
                }
            )
        }
        repositorySelectionTask?.cancel()
        repositorySelectionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(RemoteRefreshPolicy.repositorySelectionDelay))
            guard let self, !Task.isCancelled else { return }
            self.showingDirectoryPicker = true
        }
    }
    
    func syncRepository(_ repo: RemoteRepository, settings: ProviderSettings) async {
        guard repo.templateType == .git else { return }
        
        syncCompletionMessage = nil
        syncCompletionRepositoryName = nil
        syncCompletionStyle = nil
        isSyncing = true
        syncingRepositoryID = repo.id
        syncingRepositoryName = Self.displayName(for: repo)
        defer {
            isSyncing = false
            syncingRepositoryID = nil
            syncingRepositoryName = nil
        }
        
        do {
            let (result, plan) = try await syncOrchestrator.sync(repository: repo)
            
            if result.success {
                let updatedRepo = plan.repository
                if plan.shouldPromptDirectorySelection {
                    pendingRepository = updatedRepo
                    detectedCandidates = plan.detectedDirectories
                    selectedDirectoryIndices = Set(0..<plan.detectedDirectories.count)
                    showingDirectoryPicker = true
                }
                
                settings.updateRemoteRepository(updatedRepo)
                showSyncCompletion(
                    message: result.message,
                    style: .success,
                    repositoryName: Self.displayName(for: repo)
                )
            } else {
                showSyncCompletion(
                    message: result.message,
                    style: .failure,
                    repositoryName: Self.displayName(for: repo)
                )
            }
        } catch GitRepository.SyncError.sshNotAvailable(let host) {
            // SSH not available, prompt for token
            tokenInputRepository = repo
            tokenInputHost = host
            inputToken = repo.accessToken ?? ""
            showingTokenInput = true
        } catch {
            showSyncCompletion(
                message: error.localizedDescription,
                style: .failure,
                repositoryName: Self.displayName(for: repo)
            )
        }
    }

    private func showSyncCompletion(message: String, style: SyncCompletionStyle, repositoryName: String) {
        let token = UUID()
        syncCompletionToken = token
        withAnimation(.easeInOut(duration: 0.2)) {
            syncCompletionMessage = message.isEmpty
                ? NSLocalizedString("generic.error", comment: "Error")
                : message
            syncCompletionRepositoryName = repositoryName
            syncCompletionStyle = style
        }

        let duration = style == .success ? syncSuccessDisplayDuration : syncFailureDisplayDuration
        syncCompletionDismissTask?.cancel()
        syncCompletionDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, self.syncCompletionToken == token else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                self.syncCompletionMessage = nil
                self.syncCompletionRepositoryName = nil
                self.syncCompletionStyle = nil
            }
        }
    }
    
    func removeRepository(_ repo: RemoteRepository, settings: ProviderSettings) async {
        // For Git repos, also delete the cloned directory
        if repo.templateType == .git {
            do {
                try GitRepository.deleteRepository(repo)
            } catch {
                logger.error("Failed to delete cloned repository: \(error.localizedDescription)")
            }
        }
        
        settings.removeRemoteRepository(repo)
    }

    func selectedRepositoryAfterRemoving(
        removedRepositoryIDs: Set<String>,
        currentSelection: RemoteRepository?
    ) -> RemoteRepository? {
        guard let currentSelection else { return nil }
        return removedRepositoryIDs.contains(currentSelection.id) ? nil : currentSelection
    }
    
    func revealInFinder(_ repo: RemoteRepository) {
        let targets = revealTargets(for: repo)
        guard !targets.isEmpty else {
            logger.warning("Reveal in Finder skipped: no resolvable path for repository \(repo.name, privacy: .public)")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(targets)
    }

    func revealTargets(
        for repo: RemoteRepository,
        baseClonePath: URL? = nil,
        fileManager: FileManager = .default
    ) -> [URL] {
        let candidatePaths = revealCandidatePaths(for: repo, baseClonePath: baseClonePath)
        var result: [URL] = []
        var seen = Set<String>()

        for path in candidatePaths {
            guard let resolved = nearestExistingRevealURL(forPath: path, fileManager: fileManager) else { continue }
            let standardized = resolved.standardizedFileURL
            guard seen.insert(standardized.path).inserted else { continue }
            result.append(standardized)
        }

        if result.isEmpty, repo.templateType == .git {
            let fallbackRoot = (baseClonePath ?? repo.localClonePath).standardizedFileURL.path
            if let fallback = nearestExistingRevealURL(forPath: fallbackRoot, fileManager: fileManager) {
                let standardized = fallback.standardizedFileURL
                if seen.insert(standardized.path).inserted {
                    result.append(standardized)
                }
            }
        }

        return result
    }

    private func revealCandidatePaths(for repo: RemoteRepository, baseClonePath: URL?) -> [String] {
        guard repo.templateType == .git else {
            return repo.effectiveSkillsPaths
        }

        let clonePath = (baseClonePath ?? repo.localClonePath).standardizedFileURL
        guard !repo.skillsPaths.isEmpty else {
            return [clonePath.path]
        }

        return repo.skillsPaths.map { rawPath in
            let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "." {
                return clonePath.path
            }
            if (trimmed as NSString).isAbsolutePath {
                return URL(fileURLWithPath: trimmed).standardizedFileURL.path
            }
            return clonePath.appendingPathComponent(trimmed).standardizedFileURL.path
        }
    }

    private func nearestExistingRevealURL(forPath path: String, fileManager: FileManager) -> URL? {
        guard !path.isEmpty else { return nil }

        var candidate = URL(fileURLWithPath: path).standardizedFileURL
        while candidate.path != "/" {
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent().standardizedFileURL
            if parent.path == candidate.path {
                break
            }
            candidate = parent
        }

        return nil
    }
    
    func confirmDirectorySelection(settings: ProviderSettings) -> RemoteRepository? {
        guard var repo = pendingRepository else { return nil }
        
        let selectedPaths = selectedDirectoryIndices.compactMap { index -> String? in
            guard index < detectedCandidates.count else { return nil }
            return detectedCandidates[index].path
        }
        
        repo.skillsPaths = selectedPaths
        
        settings.upsertRemoteRepository(repo)
        pendingRepository = nil
        detectedCandidates = []
        selectedDirectoryIndices = []
        return repo
    }
    
    func confirmTokenInput(settings: ProviderSettings) {
        guard var repo = tokenInputRepository else { return }
        
        repo.accessToken = inputToken.isEmpty ? nil : inputToken
        settings.updateRemoteRepository(repo)
        
        // Retry sync with the new token
        Task {
            await syncRepository(repo, settings: settings)
        }
        
        tokenInputRepository = nil
        inputToken = ""
    }

    func shouldPresentAddRepositorySheet(for pendingURL: String?) -> Bool {
        guard !showingAddRepository, editingRepository == nil else { return false }
        guard let pendingURL else { return false }
        let intent = RepositoryDraftService().parseImportIntent(from: pendingURL)
        return intent.kind == .gitRepository
    }

    private static func displayName(for repo: RemoteRepository) -> String {
        guard repo.templateType == .git else { return repo.name }

        guard let gitURL = repo.gitURL else { return repo.name }
        if let extracted = RemoteRepository.extractURLComponents(from: gitURL) {
            return "\(extracted.owner)@\(extracted.repo)"
        }

        let fallback = repo.provider.extractComponents(from: gitURL)
        return "\(fallback.owner)@\(fallback.repoName)"
    }
}
