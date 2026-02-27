import Foundation
import OSLog
@preconcurrency import STFilePath

/// Watches usage-related filesystem locations (token accounts + Codex auth files) and triggers a refresh on change.
@MainActor
public final class UsageMonitorFileWatcher {
    public typealias OnChange = @MainActor (STPathChanged) -> Void

    private static let logger = Logger(subsystem: "com.nolon", category: "UsageMonitorFileWatcher")

    private let onChange: OnChange
    private var watchers: [STPathWatcher] = []
    private var watchTasks: [Task<Void, Never>] = []
    private var debounceTask: Task<Void, Never>?
    private var latestChange: STPathChanged?
    private var targetPaths: [String] = []

    public init(onChange: @escaping OnChange) {
        self.onChange = onChange
    }

    public func startWatching(paths: [String]) {
        let targets = canonicalWatchedTargets(paths: paths)
        let desired = targets.map { $0.url.standardizedFileURL.path }
        if desired == targetPaths {
            return
        }

        stop()
        targetPaths = desired
        Self.logger.info("Start watching usage paths (\(desired.count, privacy: .public))")
        for path in desired {
            Self.logger.debug("Watching path: \(path, privacy: .public)")
        }

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

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        latestChange = nil

        watchTasks.forEach { $0.cancel() }
        watchTasks.removeAll()

        watchers.forEach { $0.stop() }
        watchers.removeAll()

        targetPaths.removeAll()
        Self.logger.info("Stopped watching usage paths")
    }

    public var watchedPathsForTesting: [String] {
        targetPaths
    }

    private func scheduleChange(_ change: STPathChanged) async {
        latestChange = change
        Self.logger.debug(
            "Detected change: kind=\(String(describing: change.kind), privacy: .public) path=\(change.path.url.path, privacy: .public)"
        )
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            guard let self, !Task.isCancelled, let latest = self.latestChange else { return }
            self.latestChange = nil
            Self.logger.info(
                "Dispatching debounced change: kind=\(String(describing: latest.kind), privacy: .public) path=\(latest.path.url.path, privacy: .public)"
            )
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
            let normalized = STPath(raw).url.standardizedFileURL.path
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
