import Foundation
@preconcurrency import STFilePath

/// Watches provider-related filesystem locations (skills/workflows/MCP config) and triggers a refresh on change.
@MainActor
public final class ProviderResourceMonitor {
    public typealias OnChange = @MainActor () -> Void

    private let onChange: OnChange
    private var watchers: [STPathWatcher] = []
    private var watchTasks: [Task<Void, Never>] = []
    private var debounceTask: Task<Void, Never>?

    public init(onChange: @escaping OnChange) {
        self.onChange = onChange
    }

    public func startWatching(provider: Provider) {
        stop()

        let targets = watchedTargets(for: provider)
        guard !targets.isEmpty else { return }

        watchers = targets.map { STPathWatcher(path: $0) }
        watchTasks = watchers.map { watcher in
            Task { [weak self] in
                do {
                    for try await _ in watcher.stream() {
                        await self?.scheduleRefresh()
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

        watchTasks.forEach { $0.cancel() }
        watchTasks.removeAll()

        watchers.forEach { $0.stop() }
        watchers.removeAll()
    }

    private func scheduleRefresh() async {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            self.onChange()
        }
    }

    private func watchedTargets(for provider: Provider) -> [STPath] {
        var paths: [String] = []
        paths.append(provider.defaultSkillsPath)
        paths.append(provider.workflowPath)
        paths.append(contentsOf: provider.additionalSkillsPaths ?? [])

        if let templateId = provider.templateId,
           let template = ProviderTemplate(rawValue: templateId) {
            paths.append(template.defaultMcpConfigPath.path)
        }

        // Canonicalize + dedupe.
        var unique: [String] = []
        var seen = Set<String>()
        for raw in paths {
            let normalized = URL(fileURLWithPath: raw).standardizedFileURL.path
            guard seen.insert(normalized).inserted else { continue }
            unique.append(normalized)
        }

        // Prefer watching the target if it exists; otherwise watch its parent directory so we can
        // still pick up creation of the target later.
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

