import Foundation
import Combine
@preconcurrency import STFilePath

/// A shared watcher pool that monitors local repository/cache folders and exposes a changing token
/// that SwiftUI can use to refresh remote browsing views.
@MainActor
public final class RemoteRepositoryWatchCenter: ObservableObject {
    public static let shared = RemoteRepositoryWatchCenter()

    /// A monotonically increasing token per repository key.
    @Published private(set) var tokenByKey: [String: Int] = [:]

    private var watchersByKey: [String: [STPathWatcher]] = [:]
    private var watchTasksByKey: [String: [Task<Void, Never>]] = [:]
    private var debounceTaskByKey: [String: Task<Void, Never>] = [:]
    private var targetPathsByKey: [String: [String]] = [:]

    private init() {}

    public func token(for repository: RemoteRepository?) -> Int {
        guard let repository else { return 0 }
        return tokenByKey[repositoryWatchKey(for: repository)] ?? 0
    }

    public func ensureWatching(repository: RemoteRepository) {
        let key = repositoryWatchKey(for: repository)
        let targets = watchedTargets(for: repository)
        startWatching(key: key, targets: targets)
    }

    public func ensureWatchingLocalFolder(repoId: String, basePaths: [String]) {
        let key = "local:\(repoId)"
        let targets = canonicalWatchedTargets(paths: basePaths)
        startWatching(key: key, targets: targets)
    }

    public func ensureWatchingGit(repoId: String, clonePath: String, effectiveSkillsPaths: [String]) {
        let key = "git:\(repoId)"
        var paths = effectiveSkillsPaths
        paths.append(clonePath)
        let targets = canonicalWatchedTargets(paths: paths)
        startWatching(key: key, targets: targets)
    }

    public func ensureWatchingGlobalCache() {
        let nolon = NolonManager.shared
        let key = "global-cache"
        let targets = canonicalWatchedTargets(paths: [
            nolon.skillsPath,
            nolon.userWorkflowsPath,
            nolon.mcpsPath,
        ])
        startWatching(key: key, targets: targets)
    }

    // MARK: - Internals

    private func repositoryWatchKey(for repository: RemoteRepository) -> String {
        switch repository.templateType {
        case .globalSkills:
            return "global-cache"
        case .clawdhub:
            return "clawdhub:\(repository.id)"
        case .localFolder:
            return "local:\(repository.id)"
        case .git:
            return "git:\(repository.id)"
        }
    }

    private func watchedTargets(for repository: RemoteRepository) -> [STPath] {
        switch repository.templateType {
        case .globalSkills:
            let nolon = NolonManager.shared
            return canonicalWatchedTargets(paths: [
                nolon.skillsPath,
                nolon.userWorkflowsPath,
                nolon.mcpsPath,
            ])
        case .clawdhub:
            return []
        case .localFolder, .git:
            return canonicalWatchedTargets(paths: repository.effectiveSkillsPaths)
        }
    }

    private func startWatching(key: String, targets: [STPath]) {
        guard !targets.isEmpty else { return }

        let existing = targetPathsByKey[key] ?? []
        let desired = targets.map { $0.url.standardizedFileURL.path }
        if existing == desired {
            return
        }

        stop(key: key)
        targetPathsByKey[key] = desired

        let watchers = targets.map { STPathWatcher(path: $0) }
        watchersByKey[key] = watchers

        let tasks = watchers.map { watcher in
            Task { [weak self] in
                do {
                    for try await _ in watcher.stream() {
                        await self?.scheduleBump(key: key)
                    }
                } catch {
                    // Ignore watcher errors; callers can re-register watchers.
                }
            }
        }
        watchTasksByKey[key] = tasks

        bump(key: key)
    }

    private func stop(key: String) {
        debounceTaskByKey[key]?.cancel()
        debounceTaskByKey[key] = nil

        watchTasksByKey[key]?.forEach { $0.cancel() }
        watchTasksByKey[key] = nil

        watchersByKey[key]?.forEach { $0.stop() }
        watchersByKey[key] = nil
        targetPathsByKey[key] = nil
    }

    private func scheduleBump(key: String) async {
        debounceTaskByKey[key]?.cancel()
        debounceTaskByKey[key] = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else { return }
            self.bump(key: key)
        }
    }

    private func bump(key: String) {
        // Milliseconds token avoids collisions within the same second.
        tokenByKey[key] = Int(Date().timeIntervalSince1970 * 1000)
    }

    private func canonicalWatchedTargets(paths: [String]) -> [STPath] {
        // Canonicalize + dedupe.
        var unique: [String] = []
        var seen = Set<String>()
        for raw in paths {
            let normalized = URL(fileURLWithPath: raw).standardizedFileURL.path
            guard seen.insert(normalized).inserted else { continue }
            unique.append(normalized)
        }

        // Prefer watching the target if it exists; otherwise watch its parent directory.
        var targets: [STPath] = []
        var seenTargets = Set<String>()
        for path in unique {
            let st = STPath(path)
            let target: STPath
            if st.isExists || st.isSymbolicLink {
                target = st
            } else {
                target = STPath((path as NSString).deletingLastPathComponent)
            }
            let key = target.url.standardizedFileURL.path
            guard !key.isEmpty, seenTargets.insert(key).inserted else { continue }
            targets.append(target)
        }
        return targets
    }
}
