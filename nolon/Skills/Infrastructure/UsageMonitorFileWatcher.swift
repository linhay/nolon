import Foundation
@preconcurrency import STFilePath

/// Watches usage-related filesystem locations (token accounts + Codex auth files) and triggers a refresh on change.
@MainActor
final class UsageMonitorFileWatcher {
    typealias OnChange = @MainActor (STPathChanged) -> Void

    private let onChange: OnChange
    private var watchers: [STPathWatcher] = []
    private var watchTasks: [Task<Void, Never>] = []
    private var debounceTask: Task<Void, Never>?
    private var latestChange: STPathChanged?
    private var targetPaths: [String] = []

    init(onChange: @escaping OnChange) {
        self.onChange = onChange
    }

    func startWatching(paths: [String]) {
        let targets = canonicalWatchedTargets(paths: paths)
        let desired = targets.map { $0.url.standardizedFileURL.path }
        if desired == targetPaths {
            return
        }

        stop()
        targetPaths = desired

        watchers = targets.map { STPathWatcher(path: $0) }
        watchTasks = watchers.map { watcher in
            Task { [weak self] in
                do {
                    for try await change in watcher.stream() {
                        await self?.scheduleChange(change)
                    }
                } catch {
                    // Ignore watcher errors; a later re-start will recreate watchers.
                }
            }
        }
    }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        latestChange = nil

        watchTasks.forEach { $0.cancel() }
        watchTasks.removeAll()

        watchers.forEach { $0.stop() }
        watchers.removeAll()

        targetPaths.removeAll()
    }

    private func scheduleChange(_ change: STPathChanged) async {
        latestChange = change
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            guard let self, !Task.isCancelled, let latest = self.latestChange else { return }
            self.latestChange = nil
            Task { @MainActor in
                self.onChange(latest)
            }
        }
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
